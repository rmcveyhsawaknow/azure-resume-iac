#!/usr/bin/env python3
"""
generate-covertab-cut-sheet.py — Generate an SVG cut sheet for CoverTab blanks.

Material:  12" × 24" sheet (acrylic or leather)
Blank:      2" × 2.75" finished size
Gap:        1/16" (0.0625") between adjacent blank edges
Margin:     Blanks are centred on the sheet; effective margins exceed 1/16" on all sides

Optimal layout — Orientation B (2.75" along 12" width, 2" along 24" height):
  4 columns × 11 rows = 44 blanks per sheet  (84% material utilization)
  vs. Orientation A (2" × 2.75"):  5 × 8 = 40 blanks

Usage:
  python3 generate-covertab-cut-sheet.py [-o OUTPUT]

  -o, --output  Path for the generated SVG (default: covertab-cut-sheet.svg)
"""

import argparse
import math

# ---------------------------------------------------------------------------
# Dimensions — all values in inches
# ---------------------------------------------------------------------------
SHEET_W: float = 12.0    # sheet width
SHEET_H: float = 24.0    # sheet height

# Blank oriented with the 2.75" side along the sheet width axis.
# This yields 4 columns × 11 rows = 44 blanks (vs 5 × 8 = 40 in the other orientation).
BLANK_W: float = 2.75    # blank width  (along sheet X axis)
BLANK_H: float = 2.0     # blank height (along sheet Y axis)

GAP: float = 1 / 16      # 0.0625" — space between adjacent blank edges

# ---------------------------------------------------------------------------
# SVG rendering constants
# ---------------------------------------------------------------------------
SVG_DPI: int = 96        # SVG user units per inch (CSS/SVG standard)

# Laser-cut line style — hairline red, no fill.
# Most laser-cutter software (LightBurn, RDWorks, etc.) interprets red
# strokes as cut operations.
CUT_STROKE_COLOR: str = "#FF0000"
CUT_STROKE_WIDTH: float = 0.001  # inches (hairline)

# Sheet outline — grey reference rectangle, not sent to the laser.
SHEET_OUTLINE_COLOR: str = "#CCCCCC"


# ---------------------------------------------------------------------------
# Layout calculation
# ---------------------------------------------------------------------------

def calculate_layout() -> tuple[int, int, float, float]:
    """Return (cols, rows, x_offset, y_offset) that centre the grid on the sheet."""
    cols = math.floor((SHEET_W + GAP) / (BLANK_W + GAP))
    rows = math.floor((SHEET_H + GAP) / (BLANK_H + GAP))

    used_w = cols * BLANK_W + (cols - 1) * GAP
    used_h = rows * BLANK_H + (rows - 1) * GAP

    x_offset = (SHEET_W - used_w) / 2.0
    y_offset = (SHEET_H - used_h) / 2.0
    return cols, rows, x_offset, y_offset


# ---------------------------------------------------------------------------
# SVG helpers
# ---------------------------------------------------------------------------

def _px(inches: float) -> float:
    """Convert inches to SVG user units."""
    return round(inches * SVG_DPI, 6)


def _fmt(val: float) -> str:
    """Format a floating-point SVG attribute value, stripping trailing zeros."""
    return f"{val:.4f}".rstrip("0").rstrip(".")


# ---------------------------------------------------------------------------
# SVG generation
# ---------------------------------------------------------------------------

def generate_svg(output_path: str = "covertab-cut-sheet.svg") -> None:
    cols, rows, ox, oy = calculate_layout()
    total = cols * rows

    # --- Console summary -------------------------------------------------------
    used_w = cols * BLANK_W + (cols - 1) * GAP
    used_h = rows * BLANK_H + (rows - 1) * GAP
    util_pct = (total * BLANK_W * BLANK_H) / (SHEET_W * SHEET_H) * 100

    print("=" * 52)
    print("  CoverTab Cut Sheet — Layout Summary")
    print("=" * 52)
    print(f"  Sheet         : {SHEET_W}\" × {SHEET_H}\"")
    print(f"  Blank size    : {BLANK_W}\" × {BLANK_H}\" (width × height)")
    print(f"  Gap           : {GAP:.4f}\"  (1/16\")")
    print(f"  Layout        : {cols} columns × {rows} rows = {total} blanks")
    print(f"  Grid footprint: {used_w:.4f}\" × {used_h:.4f}\"")
    print(f"  Left/right margin : {ox:.5f}\"")
    print(f"  Top/bottom margin : {oy:.5f}\"")
    print(f"  Material utilization: {util_pct:.1f}%")
    print(f"  Output        : {output_path}")
    print("=" * 52)

    # --- Build SVG lines -------------------------------------------------------
    sheet_w_px = _px(SHEET_W)
    sheet_h_px = _px(SHEET_H)
    stroke_px  = _px(CUT_STROKE_WIDTH)
    blank_w_px = _px(BLANK_W)
    blank_h_px = _px(BLANK_H)

    lines: list[str] = []
    lines.append('<?xml version="1.0" encoding="UTF-8"?>')
    lines.append(
        f'<svg xmlns="http://www.w3.org/2000/svg"'
        f' width="{SHEET_W}in" height="{SHEET_H}in"'
        f' viewBox="0 0 {_fmt(sheet_w_px)} {_fmt(sheet_h_px)}">'
    )
    lines.append(f"  <!-- CoverTab cut sheet: {cols} cols × {rows} rows = {total} blanks -->")
    lines.append(f"  <!-- Blank: {BLANK_W}\" × {BLANK_H}\"  Gap: {GAP}\"  Sheet: {SHEET_W}\" × {SHEET_H}\" -->")
    lines.append(f"  <!-- Red rectangles = cut paths (hairline, no fill) -->")
    lines.append("")

    # Sheet boundary (reference only — do not cut)
    lines.append("  <!-- Sheet boundary: reference only, do not cut -->")
    lines.append(
        f'  <rect x="0" y="0"'
        f' width="{_fmt(sheet_w_px)}" height="{_fmt(sheet_h_px)}"'
        f' fill="none"'
        f' stroke="{SHEET_OUTLINE_COLOR}"'
        f' stroke-width="{_fmt(stroke_px * 4)}"/>'
    )
    lines.append("")

    # Cut paths
    lines.append(f"  <!-- {total} CoverTab blank cut paths -->")
    lines.append(
        f'  <g id="blanks" fill="none"'
        f' stroke="{CUT_STROKE_COLOR}"'
        f' stroke-width="{_fmt(stroke_px)}">'
    )

    for row in range(rows):
        for col in range(cols):
            x_in = ox + col * (BLANK_W + GAP)
            y_in = oy + row * (BLANK_H + GAP)
            x_px = _px(x_in)
            y_px = _px(y_in)
            lines.append(
                f'    <rect x="{_fmt(x_px)}" y="{_fmt(y_px)}"'
                f' width="{_fmt(blank_w_px)}" height="{_fmt(blank_h_px)}"/>'
            )

    lines.append("  </g>")
    lines.append("</svg>")

    svg_content = "\n".join(lines) + "\n"
    with open(output_path, "w", encoding="utf-8") as fh:
        fh.write(svg_content)

    print(f"\n✓  SVG written → {output_path}")


# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------

def main() -> None:
    parser = argparse.ArgumentParser(
        description=(
            'Generate an SVG laser-cut sheet for CoverTab blanks.\n'
            'Sheet: 12"×24"  |  Blank: 2"×2.75"  |  Gap: 1/16"\n'
            'Optimal layout: 4 cols × 11 rows = 44 blanks per sheet.'
        ),
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    parser.add_argument(
        "-o", "--output",
        default="covertab-cut-sheet.svg",
        help='Output SVG file path (default: covertab-cut-sheet.svg)',
    )
    args = parser.parse_args()
    generate_svg(args.output)


if __name__ == "__main__":
    main()
