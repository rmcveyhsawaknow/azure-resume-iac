# CoverTab Order Assets

Place the following image files in this directory before running `generate_order_package.py`:

## Required Files

| File pattern | Description |
|---|---|
| `front_<name>.png` / `.jpg` | Custom front image for each honorTab design variant. One file per design. Example: `front_alpha_company.png` |
| `command_crest.png` / `.jpg` | Command crest image printed on the **back** of every honorTab. Common to all designs. |

## Notes

- `front_*` images are resized to fit the honorTab dimensions (2.0" × 2.75" at 300 DPI = 600 × 825 px).
- The `command_crest` image is tiled the same way on Layer 3 of each batch PSD.
- Supported formats: `.png`, `.jpg`, `.jpeg` (case-insensitive).
- Each unique `front_*` file produces its own set of batch PSDs under `output/<item_name>/`.
