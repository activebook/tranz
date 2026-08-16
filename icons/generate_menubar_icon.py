#!/usr/bin/env python3
"""
Generate native macOS Menu Bar Template Icons based on menubar_proto.png:
- Dual speech bubbles with 'A' and '文' cutouts
- Top curved exchange arrow pointing left
- Bottom curved exchange arrow pointing right
- Optimized for maximum vertical presence, optical balance, and clarity in macOS status bar.
- Strictly adheres to Apple macOS Menu Bar Template specifications (RGBA 0,0,0,alpha).
"""

import os
from PIL import Image, ImageDraw

def render_menubar_template(pixel_size: int, is_retina: bool = False) -> Image.Image:
    """
    Renders an optically balanced, vertically full macOS menu bar template icon
    derived from the menubar_proto.png motif.
    """
    scale = 16
    W = pixel_size * scale
    pt = W / 18.0 # 1 point in supersampled coordinates
    
    img = Image.new("RGBA", (W, W), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    
    # 1. Top Curved Exchange Arrow (pointing left)
    # Spans y from 0.8 pt to 4.2 pt
    arrow_w = (1.5 if is_retina else 1.4) * pt
    arc_top = [4.5 * pt, 0.7 * pt, 13.5 * pt, 6.4 * pt]
    draw.arc(arc_top, start=215, end=350, fill=(0, 0, 0, 255), width=int(round(arrow_w)))
    
    # Top Arrowhead (pointing left/down-left)
    tip_t = (4.8 * pt, 3.2 * pt)
    head_t = [
        tip_t,
        (tip_t[0] + 2.0 * pt, tip_t[1] - 1.4 * pt),
        (tip_t[0] + 1.4 * pt, tip_t[1] + 1.2 * pt)
    ]
    draw.polygon(head_t, fill=(0, 0, 0, 255))
    
    # 2. Bottom Curved Exchange Arrow (pointing right)
    # Spans y from 13.8 pt to 17.3 pt
    arc_bot = [4.5 * pt, 11.6 * pt, 13.5 * pt, 17.3 * pt]
    draw.arc(arc_bot, start=35, end=170, fill=(0, 0, 0, 255), width=int(round(arrow_w)))
    
    # Bottom Arrowhead (pointing right/up-right)
    tip_b = (13.2 * pt, 14.8 * pt)
    head_b = [
        tip_b,
        (tip_b[0] - 2.0 * pt, tip_b[1] + 1.4 * pt),
        (tip_b[0] - 1.4 * pt, tip_b[1] - 1.2 * pt)
    ]
    draw.polygon(head_b, fill=(0, 0, 0, 255))
    
    # 3. Right Rear Bubble (y in [5.2, 13.4], height = 8.2 pt!)
    rx = 7.8 * pt
    ry = 5.2 * pt
    rw = 8.2 * pt
    rh = 8.2 * pt
    rr = 3.6 * pt
    
    draw.rounded_rectangle([rx, ry, rx + rw, ry + rh], radius=rr, fill=(0, 0, 0, 255))
    # Rear tail
    tail_r = [
        (rx + rw * 0.55, ry + rh * 0.8),
        (rx + rw + 0.4 * pt, ry + rh + 1.3 * pt),
        (rx + rw * 0.25, ry + rh * 0.95),
    ]
    draw.polygon(tail_r, fill=(0, 0, 0, 255))
    
    # '文' cutout in rear bubble
    rcx = rx + rw / 2.0 + 0.1 * pt
    rcy = ry + rh / 2.0
    sw = (1.25 if is_retina else 1.15) * pt
    # Top dot
    draw.line([(rcx, rcy - 2.3 * pt), (rcx, rcy - 1.2 * pt)], fill=(0, 0, 0, 0), width=int(round(sw)))
    # Horizontal bar
    draw.line([(rcx - 2.1 * pt, rcy - 0.7 * pt), (rcx + 2.1 * pt, rcy - 0.7 * pt)], fill=(0, 0, 0, 0), width=int(round(sw)))
    # Left stroke
    draw.line([(rcx + 0.4 * pt, rcy - 0.5 * pt), (rcx - 1.8 * pt, rcy + 2.1 * pt)], fill=(0, 0, 0, 0), width=int(round(sw)))
    # Right stroke
    draw.line([(rcx - 0.4 * pt, rcy - 0.5 * pt), (rcx + 1.8 * pt, rcy + 2.1 * pt)], fill=(0, 0, 0, 0), width=int(round(sw)))
    
    # 4. Transparent Clearance Outline around front bubble
    fx = 2.0 * pt
    fy = 3.8 * pt
    fw = 8.4 * pt
    fh = 8.4 * pt
    fr = 3.6 * pt
    
    gap = 1.2 * pt
    draw.rounded_rectangle([fx - gap, fy - gap, fx + fw + gap, fy + fh + gap], radius=fr + gap, fill=(0, 0, 0, 0))
    tail_c = [
        (fx + fw * 0.4 - gap, fy + fh * 0.8),
        (fx - 0.4 * pt - gap, fy + fh + 1.3 * pt + gap),
        (fx + fw * 0.7 + gap, fy + fh * 0.95),
    ]
    draw.polygon(tail_c, fill=(0, 0, 0, 0))
    
    # 5. Left Front Bubble (black)
    draw.rounded_rectangle([fx, fy, fx + fw, fy + fh], radius=fr, fill=(0, 0, 0, 255))
    tail_f = [
        (fx + fw * 0.4, fy + fh * 0.8),
        (fx - 0.4 * pt, fy + fh + 1.3 * pt),
        (fx + fw * 0.7, fy + fh * 0.95),
    ]
    draw.polygon(tail_f, fill=(0, 0, 0, 255))
    
    # 'A' cutout in front bubble
    fcx = fx + fw / 2.0 - 0.1 * pt
    fcy = fy + fh / 2.0
    a_top = (fcx, fcy - 2.2 * pt)
    a_bl = (fcx - 1.7 * pt, fcy + 2.0 * pt)
    a_br = (fcx + 1.7 * pt, fcy + 2.0 * pt)
    draw.line([a_bl, a_top, a_br], fill=(0, 0, 0, 0), width=int(round(sw)))
    draw.line([(fcx - 0.95 * pt, fcy + 0.45 * pt), (fcx + 0.95 * pt, fcy + 0.45 * pt)], fill=(0, 0, 0, 0), width=int(round(sw)))
    
    # Downsample using high-order Lanczos interpolation
    final_icon = img.resize((pixel_size, pixel_size), Image.Resampling.LANCZOS)
    return final_icon

def generate_menubar_icons():
    dest_dirs = [
        "/Users/mac/Github/tranz/Resources",
        "/Users/mac/Github/tranz/icons"
    ]
    
    img_1x = render_menubar_template(18, is_retina=False)
    img_2x = render_menubar_template(36, is_retina=True)
    
    for d in dest_dirs:
        os.makedirs(d, exist_ok=True)
        p1 = os.path.join(d, "menuBarIcon.png")
        p2 = os.path.join(d, "menuBarIcon@2x.png")
        img_1x.save(p1, "PNG")
        img_2x.save(p2, "PNG")
        print(f"✅ Generated {p1} (18x18 px)")
        print(f"✅ Generated {p2} (36x36 px)")

if __name__ == "__main__":
    generate_menubar_icons()
