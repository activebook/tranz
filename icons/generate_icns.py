#!/usr/bin/env python3
"""
Generate macOS-compliant AppIcon.icns and iconset from prototype PNG.
Adheres strictly to Apple Human Interface Guidelines (HIG) for macOS Big Sur/Monterey/Sonoma/Sequoia.
"""

import os
import subprocess
from PIL import Image, ImageDraw, ImageFilter

def generate_macos_app_icon(proto_path: str, output_iconset_dir: str, output_icns_path: str, master_png_path: str):
    # 1. Load prototype
    src = Image.open(proto_path).convert("RGBA")
    
    # 2. Card bounds inside icon_proto.png
    # Measured bounds of the squircle card: left=141, top=117, right=1113, bottom=1103
    crop_box = (141, 117, 1113, 1103)
    card_crop = src.crop(crop_box)
    
    # 3. Standard Apple HIG dimensions for 1024x1024 master canvas:
    # Body is 824x824 centered (100px padding left/right/top/bottom)
    target_body_size = 824
    card_824 = card_crop.resize((target_body_size, target_body_size), Image.Resampling.LANCZOS)
    
    # 4. Apple Continuous Rounded Rectangle Mask (4x supersampled for pristine anti-aliasing)
    ss = 4
    W = target_body_size * ss
    radius = 185 * ss # Apple standard radius (~22.45% of width)
    
    mask_img = Image.new("L", (W, W), 0)
    draw = ImageDraw.Draw(mask_img)
    draw.rounded_rectangle([0, 0, W-1, W-1], radius=radius, fill=255)
    mask_824 = mask_img.resize((target_body_size, target_body_size), Image.Resampling.LANCZOS)
    card_824.putalpha(mask_824)
    
    # 5. Build 1024x1024 canvas with authentic multi-layer macOS drop shadows
    canvas = Image.new("RGBA", (1024, 1024), (0, 0, 0, 0))
    body_x = (1024 - target_body_size) // 2
    body_y = (1024 - target_body_size) // 2
    
    full_mask = Image.new("L", (1024, 1024), 0)
    full_mask.paste(mask_824, (body_x, body_y))
    
    # Layer 1: Broad soft ambient shadow
    s1 = Image.new("RGBA", (1024, 1024), (0, 0, 0, int(255 * 0.08)))
    s1.putalpha(full_mask.filter(ImageFilter.GaussianBlur(radius=28)))
    c1 = Image.new("RGBA", (1024, 1024), (0, 0, 0, 0))
    c1.paste(s1, (0, 18))
    
    # Layer 2: Medium ambient shadow
    s2 = Image.new("RGBA", (1024, 1024), (0, 0, 0, int(255 * 0.14)))
    s2.putalpha(full_mask.filter(ImageFilter.GaussianBlur(radius=14)))
    c2 = Image.new("RGBA", (1024, 1024), (0, 0, 0, 0))
    c2.paste(s2, (0, 10))
    
    # Layer 3: Contact key shadow
    s3 = Image.new("RGBA", (1024, 1024), (0, 0, 0, int(255 * 0.18)))
    s3.putalpha(full_mask.filter(ImageFilter.GaussianBlur(radius=5)))
    c3 = Image.new("RGBA", (1024, 1024), (0, 0, 0, 0))
    c3.paste(s3, (0, 5))
    
    # Composite layers
    canvas = Image.alpha_composite(canvas, c1)
    canvas = Image.alpha_composite(canvas, c2)
    canvas = Image.alpha_composite(canvas, c3)
    canvas.paste(card_824, (body_x, body_y), card_824)
    
    # Save master 1024x1024 PNG
    os.makedirs(os.path.dirname(master_png_path), exist_ok=True)
    canvas.save(master_png_path, "PNG")
    print(f"✅ Generated master 1024x1024 PNG: {master_png_path}")
    
    # 6. Generate all 10 standard Apple iconset sizes
    # Icon sizes table: (filename, pixel_dimension)
    icon_sizes = [
        ("icon_16x16.png", 16),
        ("icon_16x16@2x.png", 32),
        ("icon_32x32.png", 32),
        ("icon_32x32@2x.png", 64),
        ("icon_128x128.png", 128),
        ("icon_128x128@2x.png", 256),
        ("icon_256x256.png", 256),
        ("icon_256x256@2x.png", 512),
        ("icon_512x512.png", 512),
        ("icon_512x512@2x.png", 1024),
    ]
    
    os.makedirs(output_iconset_dir, exist_ok=True)
    for filename, dim in icon_sizes:
        filepath = os.path.join(output_iconset_dir, filename)
        resized = canvas.resize((dim, dim), Image.Resampling.LANCZOS)
        resized.save(filepath, "PNG")
        print(f"  • Created iconset entry: {filename} ({dim}x{dim})")
    
    # 7. Convert iconset to .icns using macOS iconutil
    cmd = ["iconutil", "-c", "icns", output_iconset_dir, "-o", output_icns_path]
    res = subprocess.run(cmd, capture_output=True, text=True)
    if res.returncode != 0:
        raise RuntimeError(f"iconutil failed: {res.stderr}")
    print(f"✅ Generated native macOS ICNS: {output_icns_path}")

if __name__ == "__main__":
    proto = "/Users/mac/Github/tranz/icons/icon_proto.png"
    iconset = "/Users/mac/Github/tranz/icons/AppIcon.iconset"
    icns = "/Users/mac/Github/tranz/icons/AppIcon.icns"
    master = "/Users/mac/Github/tranz/icons/AppIcon.png"
    
    generate_macos_app_icon(proto, iconset, icns, master)
