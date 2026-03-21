#!/usr/bin/env python3
"""
generate_order_package.py

Processes CoverTab honorTab orders from the order_assets directory and
generates all output files needed for production:

  1. Order manifest (JSON) — lists every design variant found in order_assets/.
  2. Per-item output directories — preprocessed front and back image copies.
  3. Bulk SVG (Extension 1) — 40 honorTab blank cutout shapes arranged in a
     10-column × 4-row grid (portrait), sized to fit a 12" × 24" laser-cut sheet.
  4. Batch PSDs (Extension 2) — for each front image, PSD files in batch sizes
     of 1, 10, 20, 40, and 80 honorTabs.  Each PSD contains three layers:
       • Layer 1 — Alignment: 10 honorTab outlines side by side (portrait).
       • Layer 2 — Front: custom image tiled across every honorTab position.
       • Layer 3 — Back: command-crest image tiled across every position.

Operator workflow
-----------------
1. Laser-cut blanks using bulk_40_cutout.svg (one 12" × 24" sheet = 40 blanks).
2. Open the appropriate batch PSD for the print run:
   a. Print Layer 1 to establish alignment registration on the print bed.
   b. Place the cut blanks on the alignment marks; print Layer 2 (front image).
   c. Flip each blank over (same alignment); print Layer 3 (command crest).

Usage
-----
    python generate_order_package.py [--assets-dir DIR] [--output-dir DIR]
                                     [--batch-sizes N [N ...]] [--skip-psd]
                                     [-v]

Defaults
--------
    --assets-dir  <script_dir>/../order_assets/
    --output-dir  <script_dir>/../output/

Dependencies
------------
    pip install -r ../requirements.txt
    (Pillow, numpy, pytoshop)
"""

import argparse
import json
import logging
import shutil
import sys
from datetime import datetime
from pathlib import Path

# ── Physical constants ────────────────────────────────────────────────────────

# HonorTab dimensions (inches, portrait orientation)
HONOR_TAB_W_IN: float = 2.0
HONOR_TAB_H_IN: float = 2.75
CORNER_RADIUS_IN: float = 0.125

# Laser-cut material sheet (12" × 24"); placed with 24" across, 12" down.
SHEET_W_IN: float = 24.0
SHEET_H_IN: float = 12.0
GRID_COLS: int = 10
GRID_ROWS: int = 4       # 10 × 4 = 40 blanks per sheet

# Print resolution for PSD files
PSD_DPI: int = 300

# SVG coordinate precision: 1 SVG user unit = 0.01 inch
SVG_SCALE: int = 100

# Default PSD batch sizes (number of honorTabs per batch)
DEFAULT_BATCH_SIZES: list[int] = [1, 10, 20, 40, 80]

SUPPORTED_EXTS: frozenset[str] = frozenset({".png", ".jpg", ".jpeg"})

log = logging.getLogger(__name__)


# ── Helpers ───────────────────────────────────────────────────────────────────

def _px(inches: float) -> float:
    """Convert inches to SVG user units (1 unit = 0.01 inch)."""
    return round(inches * SVG_SCALE, 4)


def _tab_px(inches: float) -> int:
    """Convert inches to pixel count at PSD_DPI."""
    return round(inches * PSD_DPI)


# ── Asset discovery ───────────────────────────────────────────────────────────

def scan_assets(assets_dir: Path) -> tuple[list[Path], Path | None]:
    """
    Scan *assets_dir* for front images and the command-crest image.

    Returns
    -------
    front_images : list[Path]
        Sorted list of ``front_*.<ext>`` files.
    crest_image : Path | None
        Path to ``command_crest.<ext>``, or *None* if not found.
    """
    if not assets_dir.is_dir():
        raise FileNotFoundError(f"Assets directory not found: {assets_dir}")

    front_images: list[Path] = []
    for f in assets_dir.iterdir():
        if f.stem.lower().startswith("front_") and f.suffix.lower() in SUPPORTED_EXTS:
            front_images.append(f)
    front_images.sort(key=lambda p: p.name.lower())

    crest_image: Path | None = None
    for ext in (".png", ".jpg", ".jpeg"):
        candidate = assets_dir / f"command_crest{ext}"
        if candidate.exists():
            crest_image = candidate
            break

    log.info("Found %d front image(s) in %s", len(front_images), assets_dir)
    if crest_image:
        log.info("Command crest: %s", crest_image.name)
    else:
        log.warning("No command_crest image found in %s — back layer will be blank", assets_dir)

    return front_images, crest_image


# ── Order manifest ────────────────────────────────────────────────────────────

def build_manifest(
    front_images: list[Path],
    crest_image: Path | None,
    assets_dir: Path,
) -> dict:
    """Build a JSON-serialisable order manifest."""
    repo_root = assets_dir.parent.parent
    orders = []
    for img_path in front_images:
        try:
            front_rel = str(img_path.relative_to(repo_root))
        except ValueError:
            front_rel = str(img_path)
        try:
            back_rel = str(crest_image.relative_to(repo_root)) if crest_image else None
        except ValueError:
            back_rel = str(crest_image) if crest_image else None
        orders.append(
            {
                "item_name": img_path.stem,
                "front_image": front_rel,
                "back_image": back_rel,
                "batch_sizes": DEFAULT_BATCH_SIZES,
            }
        )
    return {
        "generated_at": datetime.now().isoformat(),
        "total_items": len(orders),
        "orders": orders,
    }


# ── Per-item output ───────────────────────────────────────────────────────────

def prepare_item_output(
    item_name: str,
    front_img: Path,
    crest_img: Path | None,
    output_dir: Path,
) -> Path:
    """Create a per-item subdirectory and copy source images into it."""
    item_dir = output_dir / item_name
    item_dir.mkdir(parents=True, exist_ok=True)

    dest_front = item_dir / f"{item_name}_front{front_img.suffix}"
    shutil.copy2(front_img, dest_front)
    log.debug("  → %s", dest_front.name)

    if crest_img:
        dest_back = item_dir / f"{item_name}_back{crest_img.suffix}"
        shutil.copy2(crest_img, dest_back)
        log.debug("  → %s", dest_back.name)

    return item_dir


# ── Extension 1: Bulk SVG (40-blank laser-cut sheet) ─────────────────────────

def generate_bulk_cutout_svg(output_dir: Path) -> Path:
    """
    Generate ``bulk_40_cutout.svg`` containing 40 honorTab blank outlines
    arranged in a 10-column × 4-row grid on a 24" × 12" sheet.

    Each honorTab is drawn in portrait orientation (2.0" × 2.75") and centred
    within its grid cell.  The sheet border is rendered as a dashed reference
    line and is not intended for cutting.

    Parameters
    ----------
    output_dir : Path
        Directory where the SVG file is written.

    Returns
    -------
    Path
        Full path to the generated SVG file.
    """
    svg_path = output_dir / "bulk_40_cutout.svg"

    sheet_w = _px(SHEET_W_IN)
    sheet_h = _px(SHEET_H_IN)

    cell_w = SHEET_W_IN / GRID_COLS
    cell_h = SHEET_H_IN / GRID_ROWS

    # Centre the honorTab within its cell
    offset_x = (cell_w - HONOR_TAB_W_IN) / 2
    offset_y = (cell_h - HONOR_TAB_H_IN) / 2

    tab_w = _px(HONOR_TAB_W_IN)
    tab_h = _px(HONOR_TAB_H_IN)
    rx = _px(CORNER_RADIUS_IN)

    lines: list[str] = [
        '<?xml version="1.0" encoding="UTF-8"?>',
        (
            f'<svg xmlns="http://www.w3.org/2000/svg"'
            f' width="{SHEET_W_IN}in" height="{SHEET_H_IN}in"'
            f' viewBox="0 0 {sheet_w} {sheet_h}">'
        ),
        "  <!-- CoverTab HonorTab Bulk Cutout — 40 blanks (10 cols × 4 rows) -->",
        f"  <!-- Material: {SHEET_W_IN}\" × {SHEET_H_IN}\" | "
        f"HonorTab: {HONOR_TAB_W_IN}\" × {HONOR_TAB_H_IN}\" portrait -->",
        "  <style>",
        "    .tab-outline { fill: none; stroke: #000000; stroke-width: 0.5; }",
        "    .sheet-border { fill: none; stroke: #cccccc;"
        " stroke-width: 1; stroke-dasharray: 10 5; }",
        "  </style>",
        "",
        f'  <rect class="sheet-border" x="0" y="0"'
        f' width="{sheet_w}" height="{sheet_h}"/>',
        "",
    ]

    tab_num = 1
    for row in range(GRID_ROWS):
        for col in range(GRID_COLS):
            x = _px(col * cell_w + offset_x)
            y = _px(row * cell_h + offset_y)
            lines.append(f"  <!-- Tab {tab_num}: col={col + 1}, row={row + 1} -->")
            lines.append(
                f'  <rect class="tab-outline" x="{x}" y="{y}"'
                f' width="{tab_w}" height="{tab_h}" rx="{rx}" ry="{rx}"/>'
            )
            tab_num += 1

    lines.append("</svg>")

    svg_path.write_text("\n".join(lines), encoding="utf-8")
    log.info("Bulk SVG written: %s", svg_path.name)
    return svg_path


# ── Extension 2: Batch PSDs ───────────────────────────────────────────────────

def _require_pil():
    """Import PIL, raising a clear RuntimeError if Pillow is missing."""
    try:
        from PIL import Image, ImageDraw  # noqa: PLC0415

        return Image, ImageDraw
    except ImportError as exc:
        raise RuntimeError(
            "Pillow is required for PSD generation.\n"
            "Install it with: pip install Pillow"
        ) from exc


def _require_pytoshop():
    """Import pytoshop + numpy, raising a clear RuntimeError if either is missing."""
    try:
        import numpy as np  # noqa: PLC0415
        from pytoshop.enums import ChannelId, ColorMode, Compression  # noqa: PLC0415
        from pytoshop.user import nested_layers  # noqa: PLC0415

        return np, nested_layers, ChannelId, ColorMode, Compression
    except ImportError as exc:
        raise RuntimeError(
            "pytoshop and numpy are required for PSD generation.\n"
            "Install with: pip install pytoshop numpy"
        ) from exc


def _grid_dims(batch_size: int) -> tuple[int, int]:
    """
    Return (rows, cols) for the honorTab grid in a given batch PSD.

    Batches of 10 or more are arranged as rows of 10.
    A batch of 1 is a single-column, single-row sheet.
    """
    if batch_size == 1:
        return 1, 1
    rows = max(1, batch_size // 10)
    return rows, 10


def _build_alignment_layer(batch_size: int, Image, ImageDraw):
    """
    Build a PIL RGBA image for Layer 1 (alignment outlines).

    Draws black honorTab rounded-rectangle outlines on a transparent
    background, arranged in the grid defined by *batch_size*.
    """
    rows, cols = _grid_dims(batch_size)
    tab_w = _tab_px(HONOR_TAB_W_IN)
    tab_h = _tab_px(HONOR_TAB_H_IN)
    rx = _tab_px(CORNER_RADIUS_IN)
    line_w = max(2, _tab_px(0.01))

    canvas = Image.new("RGBA", (cols * tab_w, rows * tab_h), (255, 255, 255, 0))
    draw = ImageDraw.Draw(canvas)

    for row in range(rows):
        for col in range(cols):
            x0 = col * tab_w
            y0 = row * tab_h
            draw.rounded_rectangle(
                [(x0, y0), (x0 + tab_w - 1, y0 + tab_h - 1)],
                radius=rx,
                outline=(0, 0, 0, 255),
                width=line_w,
            )

    return canvas


def _build_image_layer(source_path: Path, batch_size: int, Image):
    """
    Build a PIL RGBA image for a print layer by tiling *source_path* across
    every honorTab position in the batch grid.

    Parameters
    ----------
    source_path : Path
        Image file to tile (front custom image or command-crest).
    batch_size : int
        Total number of honorTabs in this batch.
    Image : PIL.Image module
        Injected to avoid a top-level import.
    """
    rows, cols = _grid_dims(batch_size)
    tab_w = _tab_px(HONOR_TAB_W_IN)
    tab_h = _tab_px(HONOR_TAB_H_IN)

    canvas = Image.new("RGBA", (cols * tab_w, rows * tab_h), (255, 255, 255, 255))
    src = Image.open(source_path).convert("RGBA").resize(
        (tab_w, tab_h), Image.LANCZOS
    )

    for row in range(rows):
        for col in range(cols):
            canvas.paste(src, (col * tab_w, row * tab_h), mask=src)

    return canvas


def _blank_layer(batch_size: int, Image):
    """Return a plain white opaque PIL image for use when no source image is available."""
    rows, cols = _grid_dims(batch_size)
    tab_w = _tab_px(HONOR_TAB_W_IN)
    tab_h = _tab_px(HONOR_TAB_H_IN)
    return Image.new("RGBA", (cols * tab_w, rows * tab_h), (255, 255, 255, 255))


def _pil_to_psd_layer(pil_img, name: str, np, nested_layers, ChannelId, Compression):
    """Convert a PIL RGBA image into a pytoshop Image layer."""
    rgba = pil_img.convert("RGBA")
    arr = np.array(rgba, dtype=np.uint8)
    r, g, b, a = arr[:, :, 0], arr[:, :, 1], arr[:, :, 2], arr[:, :, 3]
    h, w = r.shape
    return nested_layers.Image(
        name=name,
        channels={
            ChannelId.transparency: a,
            0: r,
            1: g,
            2: b,
        },
        bottom=h,
        right=w,
    )


def generate_batch_psd(
    front_img: Path,
    crest_img: Path | None,
    batch_size: int,
    output_dir: Path,
) -> Path:
    """
    Generate a multi-layer PSD for a single design at a given batch size.

    The PSD contains three layers (top → bottom in Photoshop's layer panel):

    * **Layer 1 — Alignment**: black outlines of all honorTab positions.
    * **Layer 2 — Front (Custom Image)**: the front design tiled across
      every position; operator prints this after placing blanks on the
      alignment marks.
    * **Layer 3 — Back (Command Crest)**: the common back design tiled
      across every position; operator flips blanks and prints this last.

    Parameters
    ----------
    front_img : Path
        Custom front image for this design variant.
    crest_img : Path | None
        Command-crest image (back), or *None* for a blank white back layer.
    batch_size : int
        Number of honorTabs in this batch (1 / 10 / 20 / 40 / 80).
    output_dir : Path
        Directory where the ``.psd`` file is written.

    Returns
    -------
    Path
        Full path to the generated PSD file.
    """
    Image, ImageDraw = _require_pil()
    np, nested_layers, ChannelId, ColorMode, Compression = _require_pytoshop()

    item_name = front_img.stem
    psd_path = output_dir / f"{item_name}_batch_{batch_size:04d}up.psd"

    # Build PIL images for each layer
    layer1_img = _build_alignment_layer(batch_size, Image, ImageDraw)
    layer2_img = _build_image_layer(front_img, batch_size, Image)
    if crest_img is not None:
        layer3_img = _build_image_layer(crest_img, batch_size, Image)
    else:
        layer3_img = _blank_layer(batch_size, Image)

    # Convert to pytoshop layers (index 0 = topmost in Photoshop panel)
    psd_layer1 = _pil_to_psd_layer(
        layer1_img,
        "Layer 1 — Alignment",
        np, nested_layers, ChannelId, Compression,
    )
    psd_layer2 = _pil_to_psd_layer(
        layer2_img,
        "Layer 2 — Front (Custom Image)",
        np, nested_layers, ChannelId, Compression,
    )
    psd_layer3 = _pil_to_psd_layer(
        layer3_img,
        "Layer 3 — Back (Command Crest)",
        np, nested_layers, ChannelId, Compression,
    )

    # Layer order: topmost first in the list
    psd = nested_layers.nested_layers_to_psd(
        [psd_layer1, psd_layer2, psd_layer3],
        ColorMode.rgb,
        compression=Compression.raw,
    )

    with open(psd_path, "wb") as f:
        psd.write(f)

    log.info("    PSD %4d-up → %s", batch_size, psd_path.name)
    return psd_path


# ── Main entry point ──────────────────────────────────────────────────────────

def main(argv: list[str] | None = None) -> None:
    _script_dir = Path(__file__).resolve().parent
    _product_dir = _script_dir.parent

    parser = argparse.ArgumentParser(
        description="Generate CoverTab honorTab order package (manifest, SVG, and PSDs).",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=__doc__,
    )
    parser.add_argument(
        "--assets-dir",
        type=Path,
        default=_product_dir / "order_assets",
        metavar="DIR",
        help=(
            "Directory containing order assets "
            "(default: %(default)s)"
        ),
    )
    parser.add_argument(
        "--output-dir",
        type=Path,
        default=_product_dir / "output",
        metavar="DIR",
        help="Directory to write output files (default: %(default)s)",
    )
    parser.add_argument(
        "--batch-sizes",
        nargs="+",
        type=int,
        default=DEFAULT_BATCH_SIZES,
        metavar="N",
        help=f"PSD batch sizes to generate (default: {DEFAULT_BATCH_SIZES})",
    )
    parser.add_argument(
        "--skip-psd",
        action="store_true",
        help="Skip PSD generation (useful when Pillow/pytoshop are not installed)",
    )
    parser.add_argument(
        "-v", "--verbose",
        action="store_true",
        help="Enable verbose (DEBUG) logging",
    )
    args = parser.parse_args(argv)

    logging.basicConfig(
        level=logging.DEBUG if args.verbose else logging.INFO,
        format="%(levelname)s: %(message)s",
    )

    output_dir: Path = args.output_dir
    output_dir.mkdir(parents=True, exist_ok=True)

    # ── Step 1: Scan assets ──────────────────────────────────────────────────
    log.info("=== Step 1: Scanning assets ===")
    front_images, crest_image = scan_assets(args.assets_dir)

    if not front_images:
        log.error(
            "No front_*.(png|jpg|jpeg) images found in %s", args.assets_dir
        )
        sys.exit(1)

    # ── Step 2: Build and write order manifest ───────────────────────────────
    log.info("=== Step 2: Building order manifest ===")
    manifest = build_manifest(front_images, crest_image, args.assets_dir)
    manifest_path = output_dir / "order_manifest.json"
    manifest_path.write_text(json.dumps(manifest, indent=2), encoding="utf-8")
    log.info("Manifest written: %s (%d item(s))", manifest_path.name, manifest["total_items"])

    # ── Step 3: Per-item output ──────────────────────────────────────────────
    log.info("=== Step 3: Preparing per-item output directories ===")
    for img_path in front_images:
        log.info("  Item: %s", img_path.stem)
        prepare_item_output(img_path.stem, img_path, crest_image, output_dir)

    # ── Step 4 (Extension 1): Bulk 40-blank laser-cut SVG ───────────────────
    log.info("=== Step 4: Generating bulk 40-blank cutout SVG ===")
    svg_path = generate_bulk_cutout_svg(output_dir)
    log.info("SVG: %s", svg_path)

    # ── Step 5 (Extension 2): Per-item batch PSDs ───────────────────────────
    if args.skip_psd:
        log.info("=== Step 5: Skipping PSD generation (--skip-psd) ===")
    else:
        log.info("=== Step 5: Generating batch PSDs ===")
        batch_sizes: list[int] = sorted(set(args.batch_sizes))
        for img_path in front_images:
            item_name = img_path.stem
            item_dir = output_dir / item_name
            log.info("  Item: %s", item_name)
            for batch_size in batch_sizes:
                try:
                    generate_batch_psd(img_path, crest_image, batch_size, item_dir)
                except RuntimeError as exc:
                    log.error("PSD generation failed: %s", exc)
                    log.info("Re-run with --skip-psd to skip PSD generation.")
                    sys.exit(1)

    log.info("=== Order package complete ===")
    log.info("Output: %s", output_dir)


if __name__ == "__main__":
    main()
