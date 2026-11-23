"""Deploy 云序 launcher icons into Android / iOS project folders.

Run from anywhere:  python design_output/logo/deploy_icons.py
Sizes follow Android mipmap densities and the iOS AppIcon Contents.json.
"""

import sys
from pathlib import Path

from PIL import Image

sys.path.insert(0, str(Path(__file__).parent))
from render_png import draw_icon  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]

ANDROID = {
    "android/app/src/main/res/mipmap-mdpi/ic_launcher.png": 48,
    "android/app/src/main/res/mipmap-hdpi/ic_launcher.png": 72,
    "android/app/src/main/res/mipmap-xhdpi/ic_launcher.png": 96,
    "android/app/src/main/res/mipmap-xxhdpi/ic_launcher.png": 144,
    "android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png": 192,
}

IOS_DIR = "ios/Runner/Assets.xcassets/AppIcon.appiconset"
IOS = {
    "Icon-App-20x20@1x.png": 20,
    "Icon-App-20x20@2x.png": 40,
    "Icon-App-20x20@3x.png": 60,
    "Icon-App-29x29@1x.png": 29,
    "Icon-App-29x29@2x.png": 58,
    "Icon-App-29x29@3x.png": 87,
    "Icon-App-40x40@1x.png": 40,
    "Icon-App-40x40@2x.png": 80,
    "Icon-App-40x40@3x.png": 120,
    "Icon-App-60x60@2x.png": 120,
    "Icon-App-60x60@3x.png": 180,
    "Icon-App-76x76@1x.png": 76,
    "Icon-App-76x76@2x.png": 152,
    "Icon-App-83.5x83.5@2x.png": 167,
    "Icon-App-1024x1024@1x.png": 1024,
}


def main():
    total = 0
    for rel, size in ANDROID.items():
        path = ROOT / rel
        path.parent.mkdir(parents=True, exist_ok=True)
        draw_icon(size, solid=True).convert("RGB").save(path)
        print(f"android {size:>4}  {rel}")
        total += 1
    for name, size in IOS.items():
        path = ROOT / IOS_DIR / name
        path.parent.mkdir(parents=True, exist_ok=True)
        img = draw_icon(size, solid=True).convert("RGB")
        img.save(path)
        print(f"ios     {size:>4}  {name}")
        total += 1
    print(f"\nDeployed {total} launcher icons.")


if __name__ == "__main__":
    main()
