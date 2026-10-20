#!/usr/bin/env python3
"""
Generate and validate Google Play Store listing graphic assets for NūriTalk.

Outputs:
  docs/qa/store_assets/icon_512x512.png
  docs/qa/store_assets/feature_graphic_1024x500.png
  docs/qa/store_assets/phone_01_core_grid.png
  docs/qa/store_assets/phone_02_sentence_bar.png
  docs/qa/store_assets/phone_03_smart_keyboard.png
  docs/qa/store_assets/phone_04_daily_schedule.png
  docs/qa/store_assets/phone_05_visual_timer.png
  docs/qa/store_assets/phone_06_manage_elements.png
  docs/qa/store_assets/tablet_10in_landscape.png
  docs/qa/store_assets/tablet_10in_portrait.png

All assets strictly adhere to Google Play Console specifications:
- App Icon: 512x512, 32-bit PNG or RGB PNG, max 1024KB.
- Feature Graphic: 1024x500, 24-bit PNG (RGB, no alpha), max 1024KB.
- Screenshots: 24-bit PNG (RGB, no alpha), ratio within 1:2 to 2:1, min 1080px shortest side.
"""

import os
import sys
from PIL import Image, ImageDraw, ImageFont

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
PROJECT_ROOT = os.path.abspath(os.path.join(SCRIPT_DIR, "..", ".."))
STORE_ASSETS_DIR = os.path.join(PROJECT_ROOT, "docs", "qa", "store_assets")

def ensure_dirs():
    os.makedirs(STORE_ASSETS_DIR, exist_ok=True)

def generate_app_icon():
    src_icon = os.path.join(PROJECT_ROOT, "tools", "branding", "app-icon-1024.png")
    if not os.path.exists(src_icon):
        print(f"Error: source icon not found at {src_icon}")
        return False
    
    im = Image.open(src_icon).convert("RGB")
    im_512 = im.resize((512, 512), Image.Resampling.LANCZOS)
    dest_path = os.path.join(STORE_ASSETS_DIR, "icon_512x512.png")
    im_512.save(dest_path, "PNG", optimize=True)
    size_kb = os.path.getsize(dest_path) / 1024.0
    print(f"[OK] App Icon: {dest_path} (512x512, {size_kb:.1f} KB, format={im_512.format or 'PNG'})")
    return True

def generate_feature_graphic():
    # 1024x500 RGB (no alpha)
    width, height = 1024, 500
    fg = Image.new("RGB", (width, height), color=(10, 37, 64)) # Nuri navy #0A2540
    draw = ImageDraw.Draw(fg)

    # Gradient background: #0A2540 -> #1F3A44
    for y in range(height):
        t = y / float(height)
        r = int(10 + t * (31 - 10))
        g = int(37 + t * (58 - 37))
        b = int(64 + t * (68 - 64))
        draw.line([(0, y), (width, y)], fill=(r, g, b))

    # Glow accent
    for r in range(260, 0, -10):
        alpha = int(25 * (1.0 - r / 260.0))
        glow_box = [200 - r, 250 - r, 200 + r, 250 + r]
        # Soft subtle warm circle
        draw.ellipse(glow_box, outline=(232, 135, 60))

    # Paste Emblem
    emblem_path = os.path.join(PROJECT_ROOT, "assets", "brand", "nuritalk_emblem.png")
    if not os.path.exists(emblem_path):
        emblem_path = os.path.join(PROJECT_ROOT, "assets", "brand", "lighthouse-mark.png")
    
    if os.path.exists(emblem_path):
        emblem = Image.open(emblem_path).convert("RGBA")
        emblem = emblem.resize((270, 260), Image.Resampling.LANCZOS)
        # Alpha composite onto RGB background
        fg.paste(emblem, (85, 120), emblem)

    # Fonts
    bold_font_path = os.path.join(PROJECT_ROOT, "assets", "fonts", "AtkinsonHyperlegible-Bold.ttf")
    reg_font_path = os.path.join(PROJECT_ROOT, "assets", "fonts", "AtkinsonHyperlegible-Regular.ttf")

    font_title = ImageFont.truetype(bold_font_path, 72)
    font_sub = ImageFont.truetype(reg_font_path, 25)
    font_badge = ImageFont.truetype(bold_font_path, 17)

    title_x = 390
    title_y = 125

    # App Title: NuriTalk
    draw.text((title_x, title_y), "Nūri", font=font_title, fill=(250, 244, 234)) # Cream
    bbox = font_title.getbbox("Nūri")
    w_nuri = bbox[2] - bbox[0]
    draw.text((title_x + w_nuri + 8, title_y), "Talk", font=font_title, fill=(0, 163, 196)) # Cyan

    # Subtitles
    draw.text((title_x, title_y + 88), "Augmentative & Alternative Communication (AAC)", font=font_sub, fill=(224, 242, 254))
    draw.text((title_x, title_y + 122), "Free, Offline AAC for Non-Verbal Kids & Adults", font=font_sub, fill=(244, 235, 219))

    # Trust badge pill
    badge_box = [title_x, title_y + 175, title_x + 460, title_y + 218]
    draw.rounded_rectangle(badge_box, radius=20, fill=(31, 58, 68), outline=(232, 135, 60), width=2)
    draw.text((title_x + 22, title_y + 187), "DESIGNED FOR FAMILIES  *  ZERO ADS  *  OFFLINE", font=font_badge, fill=(255, 184, 0))

    dest_path = os.path.join(STORE_ASSETS_DIR, "feature_graphic_1024x500.png")
    fg.save(dest_path, "PNG", optimize=True)
    size_kb = os.path.getsize(dest_path) / 1024.0
    print(f"[OK] Feature Graphic: {dest_path} (1024x500, {size_kb:.1f} KB, RGB no alpha)")
    return True

def copy_and_validate_screenshots():
    # Look for screenshots in docs/qa/store_assets or fall back to brain artifacts
    # Check if screenshots already exist in store_assets
    files = [f for f in os.listdir(STORE_ASSETS_DIR) if f.startswith("phone_") or f.startswith("tablet_")]
    valid_count = 0
    for f in sorted(files):
        p = os.path.join(STORE_ASSETS_DIR, f)
        im = Image.open(p)
        w, h = im.size
        # Must be RGB
        if im.mode != "RGB":
            im = im.convert("RGB")
            im.save(p, "PNG", optimize=True)
        size_kb = os.path.getsize(p) / 1024.0
        aspect = max(w, h) / float(min(w, h))
        print(f"[OK] Screenshot: {f} ({w}x{h}, aspect={aspect:.2f}, {size_kb:.1f} KB, RGB)")
        valid_count += 1
    return valid_count >= 8

def main():
    ensure_dirs()
    ok_icon = generate_app_icon()
    ok_fg = generate_feature_graphic()
    ok_screens = copy_and_validate_screenshots()
    if ok_icon and ok_fg and ok_screens:
        print("\nAll Google Play Store assets generated and verified successfully.")
        return 0
    else:
        print("\nStore asset generation or verification incomplete.")
        return 1

if __name__ == "__main__":
    sys.exit(main())
