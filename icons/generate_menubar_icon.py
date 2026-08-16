#!/usr/bin/env python3
"""
Generate native macOS Menu Bar Template Icons:
- menuBarIcon.png (18x18 px @1x, 32-bit RGBA)
- menuBarIcon@2x.png (36x36 px @2x, 32-bit RGBA)
- menuBarIcon.pdf (18x18 pt Vector PDF)
"""

import os
from PIL import Image, ImageDraw

def render_menubar_png(pixel_size: int, is_retina: bool) -> Image.Image:
    """
    Renders an optically balanced, crystal-clear macOS menu bar template icon.
    - Black silhouette on transparent background (RGBA: 0, 0, 0, alpha).
    - Front bubble with 'A', rear bubble with '文'.
    - 16x16 pt optical frame inside 18x18 pt canvas.
    """
    scale = 16
    W = pixel_size * scale
    pt = W / 18.0
    
    img = Image.new("RGBA", (W, W), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    
    # Dimensions in 18pt system:
    # Front bubble (left-top)
    fx = 1.6 * pt
    fy = 2.2 * pt
    fw = 8.6 * pt
    fh = 7.8 * pt
    fr = 3.4 * pt
    
    # Rear bubble (right-bottom)
    rx = 7.8 * pt
    ry = 7.4 * pt
    rw = 8.6 * pt
    rh = 7.8 * pt
    rr = 3.4 * pt
    
    stroke_pt = 1.15 if is_retina else 1.05
    sw = stroke_pt * pt
    
    # 1. Rear bubble body (black)
    draw.rounded_rectangle([rx, ry, rx + rw, ry + rh], radius=rr, fill=(0, 0, 0, 255))
    tail_r = [
        (rx + rw * 0.55, ry + rh * 0.8),
        (rx + rw + 0.6 * pt, ry + rh + 1.8 * pt),
        (rx + rw * 0.25, ry + rh * 0.95),
    ]
    draw.polygon(tail_r, fill=(0, 0, 0, 255))
    
    # Rear bubble '文' cutout
    rcx = rx + rw / 2.0 + 0.2 * pt
    rcy = ry + rh / 2.0
    draw.line([(rcx, rcy - 2.4 * pt), (rcx, rcy - 1.4 * pt)], fill=(0, 0, 0, 0), width=int(round(sw)))
    draw.line([(rcx - 2.2 * pt, rcy - 1.0 * pt), (rcx + 2.2 * pt, rcy - 1.0 * pt)], fill=(0, 0, 0, 0), width=int(round(sw)))
    draw.line([(rcx + 0.5 * pt, rcy - 0.8 * pt), (rcx - 2.0 * pt, rcy + 2.2 * pt)], fill=(0, 0, 0, 0), width=int(round(sw)))
    draw.line([(rcx - 0.5 * pt, rcy - 0.8 * pt), (rcx + 2.0 * pt, rcy + 2.2 * pt)], fill=(0, 0, 0, 0), width=int(round(sw)))
    
    # 2. Transparent clearance outline for front bubble
    gap = 1.25 * pt
    draw.rounded_rectangle([fx - gap, fy - gap, fx + fw + gap, fy + fh + gap], radius=fr + gap, fill=(0, 0, 0, 0))
    tail_clear = [
        (fx + fw * 0.45 - gap, fy + fh * 0.8),
        (fx - 0.6 * pt - gap, fy + fh + 1.8 * pt + gap),
        (fx + fw * 0.75 + gap, fy + fh * 0.95),
    ]
    draw.polygon(tail_clear, fill=(0, 0, 0, 0))
    
    # 3. Front bubble body (black)
    draw.rounded_rectangle([fx, fy, fx + fw, fy + fh], radius=fr, fill=(0, 0, 0, 255))
    tail_f = [
        (fx + fw * 0.45, fy + fh * 0.8),
        (fx - 0.6 * pt, fy + fh + 1.8 * pt),
        (fx + fw * 0.75, fy + fh * 0.95),
    ]
    draw.polygon(tail_f, fill=(0, 0, 0, 255))
    
    # Front bubble 'A' cutout
    fcx = fx + fw / 2.0 - 0.1 * pt
    fcy = fy + fh / 2.0
    a_top = (fcx, fcy - 2.3 * pt)
    a_bl = (fcx - 1.8 * pt, fcy + 2.1 * pt)
    a_br = (fcx + 1.8 * pt, fcy + 2.1 * pt)
    draw.line([a_bl, a_top, a_br], fill=(0, 0, 0, 0), width=int(round(sw)))
    draw.line([(fcx - 1.05 * pt, fcy + 0.6 * pt), (fcx + 1.05 * pt, fcy + 0.6 * pt)], fill=(0, 0, 0, 0), width=int(round(sw)))
    
    # Downsample using Lanczos
    return img.resize((pixel_size, pixel_size), Image.Resampling.LANCZOS)

def generate_assets(dest_dirs):
    img_1x = render_menubar_png(18, is_retina=False)
    img_2x = render_menubar_png(36, is_retina=True)
    
    for d in dest_dirs:
        os.makedirs(d, exist_ok=True)
        p1 = os.path.join(d, "menuBarIcon.png")
        p2 = os.path.join(d, "menuBarIcon@2x.png")
        img_1x.save(p1, "PNG")
        img_2x.save(p2, "PNG")
        print(f"✅ Generated {p1} (18x18 px)")
        print(f"✅ Generated {p2} (36x36 px)")

if __name__ == "__main__":
    targets = [
        "/Users/mac/Github/tranz/Resources",
        "/Users/mac/Github/tranz/icons"
    ]
    generate_assets(targets)
