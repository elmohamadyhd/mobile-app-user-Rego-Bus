"""Build native splash PNGs for flutter_native_splash.

Exports the white G mark only (no wordmark, no glass badge):
- native_splash_logo.png          — 512×512 for pre–Android 12
- native_splash_logo_android12.png — 1152×1152 for Android 12+

Requires: pip install pillow
Requires: Node.js (uses npx @resvg/resvg-js-cli to rasterize the SVG mark)
"""

from __future__ import annotations

import subprocess
import sys
import tempfile
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
LOGO_SVG = ROOT / "assets" / "new-logo-white.svg"

OUT_LEGACY = ROOT / "assets" / "native_splash_logo.png"
OUT_ANDROID12 = ROOT / "assets" / "native_splash_logo_android12.png"

# Pre–Android 12 center bitmap in launch_background.
LEGACY_CANVAS = 512
LEGACY_MARK = 200

# Android 12: 1152×1152 canvas, mark within 768px diameter safe zone.
ANDROID12_CANVAS = 1152
ANDROID12_MARK = 480

RENDER_SCALE = 3


def _fit_contain(image: Image.Image, max_size: int) -> Image.Image:
    """Scale [image] to fit inside max_size×max_size, preserving aspect ratio."""
    width, height = image.size
    scale = min(max_size / width, max_size / height)
    new_w = max(1, round(width * scale))
    new_h = max(1, round(height * scale))
    return image.resize((new_w, new_h), Image.Resampling.LANCZOS)


def rasterize_svg(path: Path, max_size: int) -> Image.Image:
    """Rasterize an SVG and fit it inside max_size×max_size (BoxFit.contain)."""
    render_size = max_size * RENDER_SCALE
    with tempfile.NamedTemporaryFile(suffix=".png", delete=False) as tmp:
        tmp_path = Path(tmp.name)

    try:
        subprocess.run(
            [
                "npx",
                "--yes",
                "@resvg/resvg-js-cli",
                str(path),
                str(tmp_path),
                "--fit-width",
                str(render_size),
            ],
            check=True,
            capture_output=True,
            text=True,
            shell=True,
        )
        image = Image.open(tmp_path).convert("RGBA")
    finally:
        tmp_path.unlink(missing_ok=True)

    return _fit_contain(image, max_size)


def _compose(canvas_size: int, mark_size: int) -> Image.Image:
    mark = rasterize_svg(LOGO_SVG, mark_size)
    canvas = Image.new("RGBA", (canvas_size, canvas_size), (0, 0, 0, 0))

    lx = (canvas_size - mark.width) // 2
    ly = (canvas_size - mark.height) // 2
    canvas.paste(mark, (lx, ly), mark)

    if canvas.getchannel("A").getextrema()[0] == 255:
        print(
            f"Warning: {canvas_size}px canvas has no transparency — check SVG export.",
            file=sys.stderr,
        )

    return canvas


def main() -> None:
    legacy = _compose(LEGACY_CANVAS, LEGACY_MARK)
    legacy.save(OUT_LEGACY, "PNG")
    print(f"Saved {OUT_LEGACY} ({legacy.size[0]}x{legacy.size[1]})")

    android12 = _compose(ANDROID12_CANVAS, ANDROID12_MARK)
    android12.save(OUT_ANDROID12, "PNG")
    print(f"Saved {OUT_ANDROID12} ({android12.size[0]}x{android12.size[1]})")


if __name__ == "__main__":
    main()
