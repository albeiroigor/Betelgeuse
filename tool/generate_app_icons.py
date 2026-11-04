#!/usr/bin/env python3

from __future__ import annotations

import re
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "assets" / "icon" / "betelgeuse.png"
BACKGROUND = (15, 17, 21, 255)
SS = 4

ANDROID_RES = ROOT / "android" / "app" / "src" / "main" / "res"
IOS_ICONS = ROOT / "ios" / "Runner" / "Assets.xcassets" / "AppIcon.appiconset"
MACOS_ICONS = ROOT / "macos" / "Runner" / "Assets.xcassets" / "AppIcon.appiconset"
WINDOWS_ICON = ROOT / "windows" / "runner" / "resources" / "app_icon.ico"
LINUX_ICONS = ROOT / "linux" / "icons" / "hicolor"
ASSET_ICON = ROOT / "assets" / "icon" / "betelgeuse_square.png"
ASSET_ROUNDED = ROOT / "assets" / "icon" / "betelgeuse_rounded.png"

ANDROID_LEGACY = {
    "mdpi": 48,
    "hdpi": 72,
    "xhdpi": 96,
    "xxhdpi": 144,
    "xxxhdpi": 192,
}
ANDROID_ADAPTIVE = {
    "mdpi": 108,
    "hdpi": 162,
    "xhdpi": 216,
    "xxhdpi": 324,
    "xxxhdpi": 432,
}
LINUX_SIZES = (16, 24, 32, 48, 64, 128, 256, 512)


def load_logo() -> Image.Image:
    logo = Image.open(SOURCE).convert("RGBA")
    bbox = logo.getbbox()
    if bbox is None:
        raise SystemExit(f"{SOURCE} no tiene contenido visible")
    return logo.crop(bbox)


LOGO = load_logo()


def resized_logo(width: int) -> Image.Image:
    height = max(1, round(LOGO.height * width / LOGO.width))
    return LOGO.resize((width, height), Image.LANCZOS)


def place_logo(canvas: Image.Image, width: int) -> None:
    logo = resized_logo(width)
    x = (canvas.width - logo.width) // 2
    y = (canvas.height - logo.height) // 2
    canvas.alpha_composite(logo, (x, y))


def square_icon(size: int, *, logo_ratio: float = 0.64) -> Image.Image:
    canvas = Image.new("RGBA", (size, size), BACKGROUND)
    place_logo(canvas, round(size * logo_ratio))
    return canvas


def rounded_icon(
    size: int,
    *,
    logo_ratio: float = 0.64,
    inset_ratio: float = 0.0,
    radius_ratio: float = 0.22,
    border: bool = False,
) -> Image.Image:
    canvas = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    inset = round(size * inset_ratio)
    box = (inset, inset, size - inset - 1, size - inset - 1)
    radius = max(1, round((size - inset * 2) * radius_ratio))
    ImageDraw.Draw(canvas).rounded_rectangle(box, radius=radius, fill=BACKGROUND)
    body = size - inset * 2
    place_logo(canvas, round(body * logo_ratio))
    if border and size >= 128:
        ImageDraw.Draw(canvas).rounded_rectangle(
            box,
            radius=radius,
            outline=(255, 255, 255, 22),
            width=max(1, size // 512),
        )
    return canvas


def render(func, size: int, **kwargs) -> Image.Image:
    large = func(size * SS, **kwargs)
    return large.resize((size, size), Image.LANCZOS)


def save_png(image: Image.Image, path: Path, *, opaque: bool = False) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    if opaque:
        background = Image.new("RGB", image.size, BACKGROUND[:3])
        if image.mode == "RGBA":
            background.paste(image, mask=image.getchannel("A"))
            image = background
        else:
            image = image.convert("RGB")
    image.save(path, "PNG", optimize=True)


def write_adaptive_xml(res: Path, *, monochrome: bool) -> None:
    qualifier = "mipmap-anydpi-v33" if monochrome else "mipmap-anydpi-v26"
    path = res / qualifier
    path.mkdir(parents=True, exist_ok=True)
    extra = (
        '    <monochrome android:drawable="@mipmap/ic_launcher_monochrome" />\n'
        if monochrome
        else ""
    )
    for name in ("ic_launcher", "ic_launcher_round"):
        (path / f"{name}.xml").write_text(
            '<?xml version="1.0" encoding="utf-8"?>\n'
            '<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">\n'
            '    <background android:drawable="@color/ic_launcher_background" />\n'
            '    <foreground android:drawable="@mipmap/ic_launcher_foreground" />\n'
            f"{extra}"
            "</adaptive-icon>\n",
            encoding="utf-8",
        )


def generate_android() -> None:
    (ANDROID_RES / "values").mkdir(parents=True, exist_ok=True)
    (ANDROID_RES / "values" / "colors.xml").write_text(
        '<?xml version="1.0" encoding="utf-8"?>\n'
        "<resources>\n"
        '    <color name="ic_launcher_background">#0F1115</color>\n'
        "</resources>\n",
        encoding="utf-8",
    )

    for density, size in ANDROID_LEGACY.items():
        folder = ANDROID_RES / f"mipmap-{density}"
        folder.mkdir(parents=True, exist_ok=True)
        save_png(render(square_icon, size, logo_ratio=0.64), folder / "ic_launcher.png")

        round_canvas = Image.new("RGBA", (size * SS, size * SS), (0, 0, 0, 0))
        ImageDraw.Draw(round_canvas).ellipse(
            (0, 0, size * SS - 1, size * SS - 1), fill=BACKGROUND
        )
        place_logo(round_canvas, round(size * SS * 0.64))
        save_png(
            round_canvas.resize((size, size), Image.LANCZOS),
            folder / "ic_launcher_round.png",
        )

    for density, size in ANDROID_ADAPTIVE.items():
        folder = ANDROID_RES / f"mipmap-{density}"
        folder.mkdir(parents=True, exist_ok=True)
        foreground = Image.new("RGBA", (size * SS, size * SS), (0, 0, 0, 0))
        place_logo(foreground, round(size * SS * 66 / 108))
        save_png(
            foreground.resize((size, size), Image.LANCZOS),
            folder / "ic_launcher_foreground.png",
        )

        mono = Image.new("RGBA", (size * SS, size * SS), (0, 0, 0, 0))
        logo = resized_logo(round(size * SS * 66 / 108)).convert("RGBA")
        silhouette = Image.new("RGBA", logo.size, (255, 255, 255, 255))
        silhouette.putalpha(logo.getchannel("A"))
        mono.alpha_composite(
            silhouette,
            ((mono.width - logo.width) // 2, (mono.height - logo.height) // 2),
        )
        save_png(
            mono.resize((size, size), Image.LANCZOS),
            folder / "ic_launcher_monochrome.png",
        )

    write_adaptive_xml(ANDROID_RES, monochrome=False)
    write_adaptive_xml(ANDROID_RES, monochrome=True)


def generate_ios() -> None:
    if not IOS_ICONS.exists():
        return
    for file in IOS_ICONS.glob("Icon-App-*.png"):
        match = re.search(r"Icon-App-([\d.]+)x([\d.]+)@(\d)x\.png$", file.name)
        if not match:
            continue
        size = round(float(match.group(1)) * int(match.group(3)))
        save_png(render(square_icon, size, logo_ratio=0.64), file, opaque=True)


def generate_macos() -> None:
    if not MACOS_ICONS.exists():
        return
    for file in MACOS_ICONS.glob("app_icon_*.png"):
        size = int(file.stem.rsplit("_", 1)[1])
        save_png(
            render(
                rounded_icon,
                size,
                logo_ratio=0.64,
                inset_ratio=0.1,
                radius_ratio=0.225,
                border=True,
            ),
            file,
        )


def generate_windows() -> None:
    if not WINDOWS_ICON.parent.exists():
        return
    master = render(rounded_icon, 256, logo_ratio=0.66, radius_ratio=0.18)
    master.save(
        WINDOWS_ICON,
        format="ICO",
        sizes=[(16, 16), (24, 24), (32, 32), (48, 48), (64, 64), (128, 128), (256, 256)],
    )


def generate_linux() -> None:
    for size in LINUX_SIZES:
        save_png(
            render(rounded_icon, size, logo_ratio=0.66, radius_ratio=0.18),
            LINUX_ICONS / f"{size}x{size}" / "apps" / "betelgeuse.png",
        )


def generate_app_assets() -> None:
    save_png(render(square_icon, 512, logo_ratio=0.64), ASSET_ICON)
    save_png(
        render(rounded_icon, 512, logo_ratio=0.66, radius_ratio=0.18),
        ASSET_ROUNDED,
    )


def main() -> None:
    generate_android()
    generate_ios()
    generate_macos()
    generate_windows()
    generate_linux()
    generate_app_assets()
    print("Iconos generados.")


if __name__ == "__main__":
    main()
