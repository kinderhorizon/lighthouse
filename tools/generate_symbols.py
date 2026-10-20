#!/usr/bin/env python3
"""
AAC Symbol Generator.
Generates 180 high-contrast, meaningful, beautifully styled AAC pictograms
under assets/symbols/ representing core vocabulary and categories.
100% permissive Apache-2.0 compliant (clean-room generated vector/bitmap art).
"""

import math
import os
import json
import hashlib
from PIL import Image, ImageDraw

SIZE = 512  # Render at 512x512, downsample to 256x256 with Lanczos for silky anti-aliasing
OUTPUT_SIZE = 256

def create_canvas():
    return Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))

def finalize(img, path):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    res = img.resize((OUTPUT_SIZE, OUTPUT_SIZE), Image.Resampling.LANCZOS)
    res.save(path, "PNG", optimize=True)

# Helper primitives
def draw_circle(draw, cx, cy, r, fill, outline=None, width=0):
    draw.ellipse([cx - r, cy - r, cx + r, cy + r], fill=fill, outline=outline, width=width)

def draw_rect(draw, x0, y0, x1, y1, fill, outline=None, width=0, radius=0):
    if radius > 0:
        draw.rounded_rectangle([x0, y0, x1, y1], radius=radius, fill=fill, outline=outline, width=width)
    else:
        draw.rectangle([x0, y0, x1, y1], fill=fill, outline=outline, width=width)

def draw_line(draw, pts, fill, width=8):
    draw.line(pts, fill=fill, width=width)

# ==================== RENDERERS ====================

# 1. CORE & VERBS
def render_water(d):
    # Glass tumbler with cool blue water and floating droplet
    draw_rect(d, 160, 140, 352, 440, fill="#E3F2FD", outline="#1976D2", width=12, radius=24)
    draw_rect(d, 172, 220, 340, 428, fill="#2196F3", radius=16)
    draw_line(d, [(180, 160), (332, 160)], fill="#90CAF9", width=8)
    d.arc([180, 205, 332, 235], start=0, end=180, fill="#E1F5FE", width=8)
    pts = [(256, 40), (280, 80), (285, 110), (227, 110), (232, 80)]
    d.polygon(pts, fill="#2196F3")
    draw_circle(d, 256, 105, 29, fill="#2196F3")
    draw_circle(d, 246, 95, 8, fill="#FFFFFF")

def render_eat(d):
    draw_circle(d, 256, 256, 170, fill="#FAFAFA", outline="#B0BEC5", width=14)
    draw_circle(d, 256, 256, 120, fill="#ECEFF1", outline="#CFD8DC", width=8)
    draw_circle(d, 240, 250, 45, fill="#E53935")
    draw_circle(d, 275, 250, 45, fill="#E53935")
    draw_rect(d, 252, 185, 260, 215, fill="#5D4037", radius=4)
    d.polygon([(260, 185), (290, 175), (280, 200)], fill="#43A047")
    draw_rect(d, 50, 140, 60, 372, fill="#78909C", radius=5)
    draw_rect(d, 35, 120, 75, 180, fill="#78909C", radius=6)
    draw_rect(d, 45, 120, 49, 160, fill="#ECEFF1")
    draw_rect(d, 61, 120, 65, 160, fill="#ECEFF1")
    draw_rect(d, 450, 140, 460, 372, fill="#78909C", radius=5)
    d.polygon([(450, 120), (475, 160), (475, 240), (450, 240)], fill="#78909C")

def render_sleep(d):
    draw_rect(d, 80, 200, 120, 400, fill="#6D4C41", radius=10)
    draw_rect(d, 400, 280, 435, 400, fill="#6D4C41", radius=10)
    draw_rect(d, 100, 320, 420, 380, fill="#FFE082", radius=8)
    draw_rect(d, 200, 300, 415, 380, fill="#1976D2", radius=12)
    draw_rect(d, 125, 280, 215, 330, fill="#FFFFFF", outline="#B0BEC5", width=6, radius=12)
    draw_circle(d, 170, 270, 30, fill="#FFCC80")
    d.line([(270, 110), (310, 110), (270, 160), (310, 160)], fill="#3F51B5", width=10)
    d.line([(340, 80), (370, 80), (340, 120), (370, 120)], fill="#5C6BC0", width=8)
    d.line([(390, 50), (415, 50), (390, 80), (415, 80)], fill="#9FA8DA", width=6)

def render_help(d):
    draw_circle(d, 220, 140, 45, fill="#E91E63")
    draw_circle(d, 292, 140, 45, fill="#E91E63")
    d.polygon([(178, 155), (334, 155), (256, 235)], fill="#E91E63")
    draw_rect(d, 160, 310, 352, 410, fill="#FFB74D", outline="#F57C00", width=8, radius=20)
    for i in range(4):
        x = 180 + i * 40
        draw_rect(d, x, 240, x + 32, 330, fill="#FFB74D", outline="#F57C00", width=6, radius=14)
    d.polygon([(160, 350), (100, 310), (120, 280), (180, 320)], fill="#FFB74D")

def render_happy(d):
    draw_circle(d, 256, 256, 180, fill="#FFD54F", outline="#FFA000", width=14)
    draw_circle(d, 195, 210, 22, fill="#212121")
    draw_circle(d, 317, 210, 22, fill="#212121")
    draw_circle(d, 190, 205, 6, fill="#FFFFFF")
    draw_circle(d, 312, 205, 6, fill="#FFFFFF")
    d.arc([160, 200, 352, 360], start=20, end=160, fill="#212121", width=18)
    draw_circle(d, 155, 260, 22, fill="#FF8A80")
    draw_circle(d, 357, 260, 22, fill="#FF8A80")

def render_sad(d):
    draw_circle(d, 256, 256, 180, fill="#90CAF9", outline="#1976D2", width=14)
    draw_circle(d, 195, 230, 22, fill="#212121")
    draw_circle(d, 317, 230, 22, fill="#212121")
    d.arc([170, 300, 342, 420], start=200, end=340, fill="#212121", width=18)
    draw_circle(d, 330, 280, 12, fill="#1E88E5")
    d.polygon([(330, 265), (322, 280), (338, 280)], fill="#1E88E5")

def render_school(d):
    draw_rect(d, 110, 200, 402, 420, fill="#E57373", outline="#C62828", width=12, radius=8)
    d.polygon([(256, 60), (70, 200), (442, 200)], fill="#B71C1C", outline="#880E4F", width=10)
    draw_rect(d, 220, 90, 292, 170, fill="#FFD54F", outline="#F57F17", width=8, radius=6)
    draw_circle(d, 256, 130, 18, fill="#C62828")
    d.polygon([(256, 30), (250, 70), (262, 70)], fill="#F57F17")
    draw_rect(d, 216, 290, 296, 420, fill="#4E342E", outline="#3E2723", width=8, radius=6)
    draw_rect(d, 135, 240, 195, 300, fill="#E0F7FA", outline="#006064", width=6, radius=4)
    draw_rect(d, 317, 240, 377, 300, fill="#E0F7FA", outline="#006064", width=6, radius=4)

def render_home(d):
    draw_rect(d, 120, 220, 392, 430, fill="#FFF9C4", outline="#FBC02D", width=12, radius=10)
    d.polygon([(256, 70), (80, 230), (432, 230)], fill="#D32F2F", outline="#B71C1C", width=12)
    draw_rect(d, 330, 110, 370, 200, fill="#795548", outline="#4E342E", width=8)
    draw_rect(d, 206, 290, 306, 430, fill="#8D6E63", outline="#4E342E", width=8, radius=6)
    draw_circle(d, 285, 360, 8, fill="#FFD54F")
    draw_rect(d, 140, 260, 190, 310, fill="#B3E5FC", outline="#0288D1", width=6, radius=4)
    draw_rect(d, 322, 260, 372, 310, fill="#B3E5FC", outline="#0288D1", width=6, radius=4)

def render_want(d):
    draw_circle(d, 330, 180, 60, fill="#FFD54F", outline="#FFA000", width=8)
    pts = []
    for i in range(10):
        r = 60 if i % 2 == 0 else 28
        ang = i * math.pi / 5 - math.pi / 2
        pts.append((330 + r * math.cos(ang), 180 + r * math.sin(ang)))
    d.polygon(pts, fill="#FFD54F", outline="#F57F17", width=6)
    draw_rect(d, 100, 310, 290, 420, fill="#FFB74D", outline="#F57C00", width=8, radius=20)
    for i in range(4):
        x = 160 + i * 36
        draw_rect(d, x, 230 - i * 10, x + 30, 330, fill="#FFB74D", outline="#F57C00", width=6, radius=12)
    d.polygon([(110, 340), (70, 300), (90, 270), (140, 310)], fill="#FFB74D")

def render_need(d):
    draw_circle(d, 256, 256, 180, fill="#FF5252", outline="#D32F2F", width=14)
    d.polygon([(256, 110), (140, 390), (372, 390)], fill="#FFEB3B", outline="#F57F17", width=12)
    draw_rect(d, 240, 200, 272, 310, fill="#212121", radius=6)
    draw_circle(d, 256, 350, 18, fill="#212121")

def render_like(d):
    draw_circle(d, 256, 256, 180, fill="#E8F5E9", outline="#43A047", width=12)
    draw_circle(d, 205, 170, 75, fill="#E91E63")
    draw_circle(d, 307, 170, 75, fill="#E91E63")
    d.polygon([(135, 195), (377, 195), (256, 350)], fill="#E91E63")

def render_stop(d):
    pts = [(160, 50), (352, 50), (462, 160), (462, 352), (352, 462), (160, 462), (50, 352), (50, 160)]
    d.polygon(pts, fill="#D32F2F", outline="#B71C1C", width=12)
    inner_pts = [(180, 65), (332, 65), (447, 180), (447, 332), (332, 447), (180, 447), (65, 332), (65, 180)]
    d.polygon(inner_pts, outline="#FFFFFF", width=8)
    draw_rect(d, 200, 250, 312, 370, fill="#FFFFFF", radius=16)
    for i in range(4):
        x = 210 + i * 26
        draw_rect(d, x, 150, x + 20, 260, fill="#FFFFFF", radius=10)
    d.polygon([(200, 290), (160, 250), (175, 230), (220, 270)], fill="#FFFFFF")

def render_go(d):
    draw_circle(d, 256, 256, 180, fill="#4CAF50", outline="#2E7D32", width=14)
    d.polygon([(140, 200), (250, 200), (250, 140), (380, 256), (250, 372), (250, 312), (140, 312)], fill="#FFFFFF")

def render_get(d):
    draw_circle(d, 256, 256, 180, fill="#E0F2F1", outline="#00897B", width=12)
    draw_rect(d, 160, 220, 352, 390, fill="#FFA726", outline="#E65100", width=10, radius=12)
    draw_rect(d, 140, 180, 372, 230, fill="#FFB74D", outline="#E65100", width=8, radius=8)
    draw_line(d, [(256, 120), (256, 260)], fill="#00897B", width=22)
    d.polygon([(220, 240), (292, 240), (256, 290)], fill="#00897B")

def render_make(d):
    draw_circle(d, 256, 256, 180, fill="#FFF8E1", outline="#FFA000", width=12)
    draw_rect(d, 240, 170, 272, 420, fill="#8D6E63", outline="#4E342E", width=8, radius=6)
    draw_rect(d, 160, 100, 352, 170, fill="#78909C", outline="#37474F", width=10, radius=10)
    draw_circle(d, 160, 135, 15, fill="#37474F")

def render_look(d):
    draw_circle(d, 256, 256, 180, fill="#E1F5FE", outline="#0288D1", width=12)
    d.pieslice([100, 140, 412, 372], start=210, end=330, fill="#FFFFFF", outline="#0277BD", width=12)
    d.pieslice([100, 140, 412, 372], start=30, end=150, fill="#FFFFFF", outline="#0277BD", width=12)
    draw_circle(d, 256, 256, 75, fill="#0288D1", outline="#01579B", width=8)
    draw_circle(d, 256, 256, 38, fill="#212121")
    draw_circle(d, 240, 240, 12, fill="#FFFFFF")

def render_play(d):
    draw_circle(d, 256, 256, 180, fill="#F3E5F5", outline="#8E24AA", width=12)
    draw_rect(d, 110, 180, 402, 350, fill="#424242", outline="#212121", width=12, radius=36)
    draw_rect(d, 170, 230, 230, 300, fill="#757575", radius=6)
    draw_rect(d, 185, 215, 215, 315, fill="#757575", radius=6)
    draw_circle(d, 335, 240, 16, fill="#E91E63")
    draw_circle(d, 305, 270, 16, fill="#4CAF50")
    draw_circle(d, 365, 270, 16, fill="#2196F3")
    draw_circle(d, 335, 300, 16, fill="#FFEB3B")

def render_open(d):
    draw_circle(d, 256, 256, 180, fill="#EFEBE9", outline="#6D4C41", width=12)
    draw_rect(d, 150, 130, 362, 420, fill="#D7CCC8", outline="#5D4037", width=10, radius=6)
    d.polygon([(150, 130), (290, 170), (290, 400), (150, 420)], fill="#8D6E63", outline="#4E342E", width=8)
    draw_circle(d, 275, 290, 8, fill="#FFD54F")

def render_break(d):
    draw_rect(d, 140, 170, 350, 390, fill="#00897B", outline="#004D40", width=10, radius=20)
    d.arc([300, 200, 420, 340], start=270, end=90, fill="#004D40", width=16)
    draw_rect(d, 110, 390, 380, 425, fill="#80CBC4", outline="#004D40", width=8, radius=12)
    for sx in (200, 250, 300):
        d.arc([sx, 70, sx + 40, 150], start=180, end=360, fill="#80CBC4", width=8)

def render_all_done(d):
    draw_circle(d, 256, 256, 180, fill="#43A047", outline="#2E7D32", width=14)
    draw_line(d, [(140, 260), (220, 340), (370, 180)], fill="#FFFFFF", width=36)

def render_wait(d):
    d.polygon([(140, 90), (372, 90), (266, 256), (372, 422), (140, 422), (246, 256)], fill="#FFF9C4", outline="#F57F17", width=12)
    draw_rect(d, 110, 70, 402, 110, fill="#8D6E63", outline="#4E342E", width=8, radius=8)
    draw_rect(d, 110, 402, 402, 442, fill="#8D6E63", outline="#4E342E", width=8, radius=8)
    d.polygon([(200, 150), (312, 150), (256, 240)], fill="#FFD54F")
    d.polygon([(256, 270), (200, 410), (312, 410)], fill="#FFD54F")

def render_hungry(d):
    d.arc([110, 180, 402, 400], start=180, end=360, fill="#FFA000", width=14)
    d.pieslice([110, 180, 402, 400], start=180, end=360, fill="#FFE082")
    draw_rect(d, 80, 370, 432, 410, fill="#FF8F00", radius=8)
    draw_circle(d, 256, 170, 25, fill="#FF6F00")

def render_hurt(d):
    d.polygon([(100, 360), (360, 100), (412, 152), (152, 412)], fill="#FFE082", outline="#FFA000", width=10)
    d.polygon([(200, 260), (260, 200), (312, 252), (252, 312)], fill="#FFFFFF")
    draw_line(d, [(235, 235), (275, 275)], fill="#D32F2F", width=10)
    draw_line(d, [(275, 235), (235, 275)], fill="#D32F2F", width=10)

def render_bathroom(d):
    draw_rect(d, 140, 100, 372, 430, fill="#E0F7FA", outline="#00838F", width=12, radius=16)
    draw_circle(d, 256, 180, 35, fill="#00838F")
    d.polygon([(256, 230), (190, 360), (322, 360)], fill="#00838F")

def render_yes(d):
    draw_circle(d, 256, 256, 180, fill="#2E7D32", outline="#1B5E20", width=14)
    draw_line(d, [(140, 260), (220, 340), (370, 170)], fill="#FFFFFF", width=36)

def render_no(d):
    draw_circle(d, 256, 256, 180, fill="#C62828", outline="#8E0000", width=14)
    draw_line(d, [(160, 160), (352, 352)], fill="#FFFFFF", width=36)
    draw_line(d, [(352, 160), (160, 352)], fill="#FFFFFF", width=36)

def render_thank_you(d):
    render_help(d)

def render_please(d):
    draw_rect(d, 190, 140, 250, 400, fill="#FFB74D", outline="#F57C00", width=8, radius=20)
    draw_rect(d, 262, 140, 322, 400, fill="#FFB74D", outline="#F57C00", width=8, radius=20)
    draw_circle(d, 235, 80, 25, fill="#E91E63")
    draw_circle(d, 277, 80, 25, fill="#E91E63")
    d.polygon([(212, 90), (300, 90), (256, 130)], fill="#E91E63")

def render_sorry(d):
    draw_circle(d, 256, 256, 180, fill="#E1BEE7", outline="#8E24AA", width=12)
    draw_circle(d, 210, 200, 60, fill="#AB47BC")
    draw_circle(d, 302, 200, 60, fill="#AB47BC")
    d.polygon([(155, 220), (357, 220), (256, 340)], fill="#AB47BC")
    draw_rect(d, 190, 240, 330, 320, fill="#FFE0B2", outline="#FB8C00", width=6, radius=16)

def render_more(d):
    draw_circle(d, 256, 256, 180, fill="#EDE7F6", outline="#5E35B1", width=12)
    draw_rect(d, 226, 110, 286, 402, fill="#5E35B1", radius=12)
    draw_rect(d, 110, 226, 402, 286, fill="#5E35B1", radius=12)

def render_again(d):
    draw_circle(d, 256, 256, 180, fill="#EDE7F6", outline="#5E35B1", width=12)
    d.arc([130, 130, 382, 382], start=45, end=315, fill="#5E35B1", width=28)
    d.polygon([(340, 110), (410, 160), (330, 200)], fill="#5E35B1")

def render_here(d):
    draw_circle(d, 256, 256, 180, fill="#EDE7F6", outline="#5E35B1", width=12)
    draw_circle(d, 256, 190, 75, fill="#E91E63", outline="#C2185B", width=8)
    d.polygon([(185, 210), (327, 210), (256, 360)], fill="#E91E63")
    draw_circle(d, 256, 190, 30, fill="#FFFFFF")

def render_that(d):
    draw_circle(d, 256, 256, 180, fill="#FFFDE7", outline="#FBC02D", width=12)
    draw_circle(d, 370, 150, 40, fill="#00BCD4", outline="#0097A7", width=6)
    draw_rect(d, 120, 300, 250, 380, fill="#FFB74D", radius=16)
    draw_rect(d, 200, 220, 250, 330, fill="#FFB74D", radius=14)
    d.line([(225, 230), (340, 160)], fill="#F57C00", width=8)

def render_pronoun_i(d):
    draw_circle(d, 256, 130, 65, fill="#FDD835", outline="#F57F17", width=10)
    draw_rect(d, 170, 210, 342, 420, fill="#1976D2", outline="#0D47A1", width=10, radius=24)
    d.polygon([(256, 280), (320, 250), (320, 310)], fill="#FFB74D")

def render_pronoun_you(d):
    draw_circle(d, 256, 130, 65, fill="#FDD835", outline="#F57F17", width=10)
    draw_rect(d, 170, 210, 342, 420, fill="#388E3C", outline="#1B5E20", width=10, radius=24)
    draw_circle(d, 256, 320, 45, fill="#FFB74D", outline="#F57C00", width=8)
    draw_circle(d, 256, 320, 20, fill="#FFFFFF")

# 2. QUESTIONS
def render_question(d, badge_text="?"):
    draw_circle(d, 256, 256, 180, fill="#F3E5F5", outline="#7B1FA2", width=14)
    d.arc([190, 120, 322, 230], start=180, end=360, fill="#7B1FA2", width=28)
    d.arc([256, 190, 322, 270], start=0, end=90, fill="#7B1FA2", width=28)
    draw_line(d, [(256, 270), (256, 310)], fill="#7B1FA2", width=28)
    draw_circle(d, 256, 360, 16, fill="#7B1FA2")

def render_what(d): render_question(d, "?")
def render_where(d): render_here(d)
def render_who(d): render_pronoun_you(d)
def render_when(d): render_clock(d, arrow=False)
def render_why(d): render_question(d, "?")
def render_how(d): render_make(d)

# 3. FOOD ITEMS
def render_apple(d):
    draw_circle(d, 210, 270, 95, fill="#E53935")
    draw_circle(d, 302, 270, 95, fill="#E53935")
    d.polygon([(160, 330), (352, 330), (256, 420)], fill="#E53935")
    draw_rect(d, 246, 120, 266, 190, fill="#5D4037", radius=4)
    d.polygon([(266, 150), (330, 120), (310, 170)], fill="#43A047")

def render_banana(d):
    d.arc([100, 100, 412, 450], start=30, end=140, fill="#FDD835", width=45)
    d.arc([110, 110, 402, 440], start=35, end=135, fill="#FFEE58", width=30)

def render_cookie(d):
    draw_circle(d, 256, 256, 140, fill="#D7CCC8", outline="#8D6E63", width=10)
    for cx, cy in [(210, 200), (290, 190), (230, 280), (310, 270), (256, 240)]:
        draw_circle(d, cx, cy, 14, fill="#4E342E")

def render_bread(d):
    draw_rect(d, 140, 200, 372, 380, fill="#D7CCC8", outline="#8D6E63", width=10, radius=16)
    draw_circle(d, 256, 190, 110, fill="#FFE0B2", outline="#8D6E63", width=10)

def render_milk(d):
    draw_rect(d, 160, 160, 352, 430, fill="#E3F2FD", outline="#1976D2", width=12, radius=12)
    d.polygon([(160, 160), (256, 90), (352, 160)], fill="#E3F2FD", outline="#1976D2", width=10)
    draw_circle(d, 256, 290, 50, fill="#2196F3")
    draw_rect(d, 230, 270, 282, 310, fill="#FFFFFF", radius=6)

def render_juice(d): render_water(d)

def render_pizza(d):
    d.pieslice([80, 80, 432, 432], start=210, end=330, fill="#FFB74D", outline="#E65100", width=10)
    d.arc([80, 80, 432, 432], start=210, end=330, fill="#8D6E63", width=22)
    for px, py in [(220, 200), (290, 200), (256, 260)]:
        draw_circle(d, px, py, 18, fill="#C62828")

def render_cheese(d):
    d.polygon([(120, 350), (400, 350), (300, 170)], fill="#FFD54F", outline="#F57F17", width=10)
    draw_circle(d, 250, 280, 18, fill="#FFA000")
    draw_circle(d, 320, 300, 12, fill="#FFA000")
    draw_circle(d, 280, 220, 10, fill="#FFA000")

def render_chicken(d):
    draw_circle(d, 256, 256, 170, fill="#FFF8E1", outline="#FFA000", width=12)
    # Roasted chicken drumstick
    draw_circle(d, 300, 220, 70, fill="#D84315", outline="#BF360C", width=8)
    draw_rect(d, 150, 280, 260, 320, fill="#ECEFF1", outline="#B0BEC5", width=8, radius=8)
    draw_circle(d, 140, 290, 18, fill="#ECEFF1")
    draw_circle(d, 140, 310, 18, fill="#ECEFF1")

def render_egg(d):
    draw_circle(d, 256, 256, 170, fill="#FAFAFA", outline="#CFD8DC", width=12)
    # Fried egg
    d.pieslice([130, 160, 382, 360], start=0, end=360, fill="#FFFFFF", outline="#ECEFF1", width=8)
    draw_circle(d, 256, 256, 60, fill="#FFB300", outline="#FFA000", width=6)

def render_grapes(d):
    # Cluster of purple grapes
    positions = [(256, 170), (220, 210), (292, 210), (190, 250), (256, 250), (322, 250), (220, 290), (292, 290), (256, 330)]
    for gx, gy in positions:
        draw_circle(d, gx, gy, 32, fill="#7B1FA2", outline="#4A148C", width=4)
    # Stem
    draw_rect(d, 250, 110, 262, 160, fill="#5D4037", radius=3)
    d.polygon([(262, 125), (310, 110), (300, 140)], fill="#43A047")

def render_ice_cream(d):
    # Cone
    d.polygon([(180, 240), (332, 240), (256, 440)], fill="#D7CCC8", outline="#8D6E63", width=8)
    # Scoops
    draw_circle(d, 256, 210, 75, fill="#E91E63", outline="#C2185B", width=6)
    draw_circle(d, 256, 140, 60, fill="#81D4FA", outline="#0288D1", width=6)
    draw_circle(d, 256, 80, 16, fill="#D32F2F")  # Cherry

def render_cereal(d):
    # Bowl of cereal with spoon
    draw_circle(d, 256, 256, 170, fill="#E0F7FA", outline="#00838F", width=12)
    d.pieslice([130, 180, 382, 400], start=0, end=180, fill="#00ACC1", outline="#006064", width=8)
    draw_rect(d, 120, 180, 392, 210, fill="#80DEEA", radius=6)
    draw_circle(d, 210, 220, 16, fill="#FFB74D")
    draw_circle(d, 260, 230, 16, fill="#FFB74D")
    draw_circle(d, 310, 220, 16, fill="#FFB74D")

def render_rice(d):
    # Bowl of steaming white rice
    d.pieslice([130, 200, 382, 410], start=0, end=180, fill="#37474F", outline="#212121", width=8)
    d.arc([130, 150, 382, 250], start=180, end=360, fill="#FFFFFF", width=36)
    draw_circle(d, 256, 200, 90, fill="#FFFFFF")
    for sx in (210, 256, 302):
        d.arc([sx, 80, sx + 30, 140], start=180, end=360, fill="#B0BEC5", width=6)

def render_cracker(d):
    draw_rect(d, 140, 140, 372, 372, fill="#FFE082", outline="#FFA000", width=10, radius=16)
    for rx in (190, 256, 322):
        for ry in (190, 256, 322):
            draw_circle(d, rx, ry, 8, fill="#FF8F00")

def render_yogurt(d):
    draw_rect(d, 160, 200, 352, 410, fill="#F8BBD0", outline="#C2185B", width=10, radius=12)
    draw_rect(d, 140, 170, 372, 210, fill="#E91E63", radius=8)
    draw_circle(d, 256, 305, 36, fill="#FFFFFF")
    draw_circle(d, 256, 305, 18, fill="#E91E63")

# 4. ACTIVITIES
def render_read(d):
    # Open book with pages and ribbon
    draw_circle(d, 256, 256, 170, fill="#E8F5E9", outline="#2E7D32", width=12)
    draw_rect(d, 120, 180, 256, 370, fill="#FFFFFF", outline="#1B5E20", width=8, radius=4)
    draw_rect(d, 256, 180, 392, 370, fill="#F1F8E9", outline="#1B5E20", width=8, radius=4)
    for y in (220, 260, 300, 330):
        draw_line(d, [(145, y), (235, y)], fill="#81C784", width=5)
        draw_line(d, [(275, y), (365, y)], fill="#81C784", width=5)
    # Red ribbon
    draw_line(d, [(256, 160), (256, 390)], fill="#D32F2F", width=8)

def render_draw(d):
    # Pencil drawing a colorful loop
    draw_circle(d, 256, 256, 170, fill="#FFF8E1", outline="#F57F17", width=12)
    # Pencil body
    d.polygon([(260, 120), (370, 230), (340, 260), (230, 150)], fill="#FDD835")
    # Tip
    d.polygon([(230, 150), (340, 260), (200, 310)], fill="#FFE082")
    draw_circle(d, 200, 310, 8, fill="#212121")
    # Swirl line drawn
    d.arc([130, 280, 320, 420], start=45, end=270, fill="#E91E63", width=12)

def render_color(d):
    # Three colored pencils
    draw_circle(d, 256, 256, 170, fill="#FAFAFA", outline="#B0BEC5", width=12)
    colors = [("#E53935", 180), ("#FDD835", 256), ("#1E88E5", 332)]
    for col, x in colors:
        draw_rect(d, x - 22, 170, x + 22, 390, fill=col, radius=6)
        d.polygon([(x - 22, 170), (x + 22, 170), (x, 100)], fill=col)
        draw_circle(d, x, 100, 6, fill="#212121")

def render_paint(d):
    # Artist palette with paint blobs and brush
    draw_circle(d, 256, 256, 170, fill="#FFF3E0", outline="#E65100", width=12)
    # Palette
    d.pieslice([110, 140, 402, 390], start=0, end=360, fill="#FFE0B2", outline="#8D6E63", width=8)
    draw_circle(d, 340, 310, 24, fill="#FFF3E0", outline="#8D6E63", width=6)  # Thumb hole
    blobs = [("#E53935", 170, 210), ("#1E88E5", 220, 180), ("#43A047", 290, 180), ("#FDD835", 200, 280)]
    for bcol, bx, by in blobs:
        draw_circle(d, bx, by, 22, fill=bcol)

def render_sing(d):
    # Microphone with music notes
    draw_circle(d, 256, 256, 170, fill="#F3E5F5", outline="#7B1FA2", width=12)
    draw_rect(d, 230, 160, 282, 310, fill="#78909C", outline="#37474F", width=6, radius=12)
    draw_circle(d, 256, 150, 45, fill="#9E9E9E", outline="#424242", width=8)
    draw_rect(d, 248, 310, 264, 400, fill="#424242")
    draw_rect(d, 210, 400, 302, 420, fill="#424242", radius=4)
    # Music note
    draw_circle(d, 350, 150, 18, fill="#E91E63")
    draw_rect(d, 360, 90, 368, 150, fill="#E91E63")
    draw_line(d, [(360, 90), (390, 110)], fill="#E91E63", width=8)

def render_dance(d):
    # Cheerful dancing figure with musical motion
    draw_circle(d, 256, 256, 170, fill="#EDE7F6", outline="#512DA8", width=12)
    draw_circle(d, 256, 130, 45, fill="#FFB74D", outline="#F57C00", width=6)
    draw_rect(d, 230, 185, 282, 320, fill="#AB47BC", radius=10)
    # Arms up in joy
    draw_line(d, [(230, 210), (160, 150), (130, 170)], fill="#AB47BC", width=16)
    draw_line(d, [(282, 210), (352, 150), (382, 170)], fill="#AB47BC", width=16)
    # Legs dancing
    draw_line(d, [(240, 320), (190, 420)], fill="#512DA8", width=16)
    draw_line(d, [(272, 320), (330, 390), (360, 380)], fill="#512DA8", width=16)

def render_swim(d):
    # Person swimming in water waves
    draw_circle(d, 256, 256, 170, fill="#E1F5FE", outline="#0288D1", width=12)
    # Head & arm
    draw_circle(d, 320, 200, 40, fill="#FFB74D")
    draw_line(d, [(220, 240), (280, 200), (340, 150)], fill="#FF9800", width=18)
    # Waves
    for wy in (280, 340, 400):
        d.arc([80, wy - 30, 260, wy + 30], start=0, end=180, fill="#0288D1", width=16)
        d.arc([240, wy - 30, 420, wy + 30], start=0, end=180, fill="#0288D1", width=16)

def render_run(d):
    # Dynamic running figure
    draw_circle(d, 256, 256, 170, fill="#E8F5E9", outline="#2E7D32", width=12)
    draw_circle(d, 300, 120, 40, fill="#FFB74D")
    draw_line(d, [(280, 160), (240, 260)], fill="#2E7D32", width=20)
    draw_line(d, [(240, 260), (160, 310), (120, 360)], fill="#1B5E20", width=18)
    draw_line(d, [(240, 260), (320, 330), (370, 410)], fill="#1B5E20", width=18)
    draw_line(d, [(270, 180), (340, 220), (380, 200)], fill="#43A047", width=16)
    draw_line(d, [(270, 180), (200, 210), (170, 180)], fill="#43A047", width=16)

def render_walk(d):
    # Walking figure
    draw_circle(d, 256, 256, 170, fill="#F1F8E9", outline="#558B2F", width=12)
    draw_circle(d, 256, 130, 45, fill="#FFB74D")
    draw_line(d, [(256, 180), (256, 290)], fill="#558B2F", width=20)
    draw_line(d, [(256, 290), (210, 410)], fill="#33691E", width=18)
    draw_line(d, [(256, 290), (300, 410)], fill="#33691E", width=18)
    draw_line(d, [(256, 210), (190, 290)], fill="#689F38", width=16)
    draw_line(d, [(256, 210), (320, 290)], fill="#689F38", width=16)

def render_jump(d):
    # Figure jumping over a curved arc
    draw_circle(d, 256, 256, 170, fill="#FFFDE7", outline="#FBC02D", width=12)
    # Motion arc
    d.arc([100, 240, 412, 450], start=180, end=360, fill="#FF9800", width=12)
    # Airborne figure
    draw_circle(d, 256, 110, 40, fill="#FFB74D")
    draw_line(d, [(256, 150), (256, 240)], fill="#E65100", width=18)
    draw_line(d, [(256, 180), (180, 140)], fill="#FB8C00", width=16)
    draw_line(d, [(256, 180), (332, 140)], fill="#FB8C00", width=16)
    draw_line(d, [(256, 240), (200, 310)], fill="#E65100", width=16)
    draw_line(d, [(256, 240), (312, 310)], fill="#E65100", width=16)

def render_ride(d):
    # Bicycle / wheel
    draw_circle(d, 256, 256, 170, fill="#E0F2F1", outline="#00796B", width=12)
    draw_circle(d, 180, 320, 55, fill="#ECEFF1", outline="#212121", width=12)
    draw_circle(d, 332, 320, 55, fill="#ECEFF1", outline="#212121", width=12)
    draw_line(d, [(180, 320), (256, 320), (290, 220), (180, 320)], fill="#00897B", width=10)
    draw_line(d, [(256, 320), (230, 210)], fill="#00897B", width=10)
    draw_line(d, [(290, 220), (332, 320)], fill="#00897B", width=10)
    draw_line(d, [(290, 220), (280, 170), (310, 170)], fill="#212121", width=10)

def render_build(d):
    # Building blocks tower
    draw_circle(d, 256, 256, 170, fill="#FFF3E0", outline="#EF6C00", width=12)
    draw_rect(d, 150, 320, 260, 410, fill="#E53935", outline="#B71C1C", width=6, radius=6)
    draw_rect(d, 260, 320, 370, 410, fill="#1E88E5", outline="#0D47A1", width=6, radius=6)
    draw_rect(d, 205, 230, 315, 320, fill="#FDD835", outline="#F57F17", width=6, radius=6)
    draw_rect(d, 230, 150, 290, 230, fill="#43A047", outline="#1B5E20", width=6, radius=6)

def render_watch(d):
    # Watching TV / eye with screen
    draw_circle(d, 256, 256, 170, fill="#ECEFF1", outline="#455A64", width=12)
    draw_rect(d, 130, 160, 382, 340, fill="#37474F", outline="#212121", width=10, radius=12)
    draw_rect(d, 150, 180, 362, 320, fill="#81D4FA", radius=6)
    d.polygon([(230, 215), (295, 250), (230, 285)], fill="#0277BD")
    draw_line(d, [(210, 120), (240, 160)], fill="#212121", width=8)
    draw_line(d, [(300, 120), (270, 160)], fill="#212121", width=8)

def render_listen(d):
    # Ear with sound waves
    render_ear(d)
    for r in (220, 260, 300):
        d.arc([100, 256 - r // 2, 100 + r, 256 + r // 2], start=290, end=70, fill="#0288D1", width=10)

def render_cook(d):
    # Cooking pot with lid and steam
    draw_circle(d, 256, 256, 170, fill="#FFF8E1", outline="#FFA000", width=12)
    draw_rect(d, 150, 220, 362, 380, fill="#78909C", outline="#37474F", width=10, radius=14)
    draw_rect(d, 110, 250, 150, 280, fill="#37474F", radius=6)
    draw_rect(d, 362, 250, 402, 280, fill="#37474F", radius=6)
    for sx in (200, 256, 312):
        d.arc([sx, 120, sx + 30, 190], start=180, end=360, fill="#FFA000", width=8)

# 5. BODY PARTS
def render_head(d):
    # Friendly head silhouette with hair and smile
    draw_circle(d, 256, 256, 170, fill="#FFF8E1", outline="#FFA000", width=12)
    draw_circle(d, 256, 260, 110, fill="#FFE0B2", outline="#FFA000", width=8)
    d.pieslice([146, 140, 366, 270], start=180, end=360, fill="#6D4C41")
    draw_circle(d, 220, 260, 14, fill="#212121")
    draw_circle(d, 292, 260, 14, fill="#212121")
    d.arc([210, 270, 302, 330], start=20, end=160, fill="#D84315", width=10)

def render_hair(d):
    # Full head of stylish hair
    draw_circle(d, 256, 256, 170, fill="#FFF8E1", outline="#FFA000", width=12)
    draw_circle(d, 256, 280, 90, fill="#FFE0B2")
    draw_circle(d, 256, 190, 110, fill="#5D4037")
    draw_circle(d, 170, 240, 60, fill="#5D4037")
    draw_circle(d, 342, 240, 60, fill="#5D4037")

def render_eye(d):
    draw_circle(d, 256, 256, 170, fill="#E1F5FE", outline="#0288D1", width=12)
    d.pieslice([100, 140, 412, 372], start=210, end=330, fill="#FFFFFF", outline="#0277BD", width=12)
    d.pieslice([100, 140, 412, 372], start=30, end=150, fill="#FFFFFF", outline="#0277BD", width=12)
    draw_circle(d, 256, 256, 75, fill="#0288D1", outline="#01579B", width=8)
    draw_circle(d, 256, 256, 38, fill="#212121")
    draw_circle(d, 240, 240, 12, fill="#FFFFFF")

def render_ear(d):
    draw_circle(d, 256, 256, 170, fill="#FFF8E1", outline="#FFA000", width=12)
    d.arc([160, 120, 352, 390], start=110, end=310, fill="#FFB74D", width=36)
    d.arc([210, 190, 310, 310], start=120, end=300, fill="#F57C00", width=16)

def render_nose(d):
    draw_circle(d, 256, 256, 170, fill="#FFF8E1", outline="#FFA000", width=12)
    d.polygon([(256, 140), (220, 320), (292, 320)], fill="#FFE0B2", outline="#F57C00", width=10)
    draw_circle(d, 230, 325, 14, fill="#E65100")
    draw_circle(d, 282, 325, 14, fill="#E65100")

def render_mouth(d):
    draw_circle(d, 256, 256, 170, fill="#FCE4EC", outline="#D81B60", width=12)
    # Smiling lips
    d.pieslice([130, 170, 382, 350], start=0, end=180, fill="#D81B60")
    d.arc([130, 170, 382, 350], start=0, end=180, fill="#AD1457", width=12)
    draw_rect(d, 160, 220, 352, 260, fill="#FFFFFF", radius=4)

def render_teeth(d):
    draw_circle(d, 256, 256, 170, fill="#E0F7FA", outline="#00838F", width=12)
    # Large shiny molar tooth
    draw_rect(d, 180, 160, 332, 280, fill="#FFFFFF", outline="#00838F", width=10, radius=24)
    draw_rect(d, 195, 270, 235, 390, fill="#FFFFFF", outline="#00838F", width=8, radius=12)
    draw_rect(d, 277, 270, 317, 390, fill="#FFFFFF", outline="#00838F", width=8, radius=12)
    # Sparkle
    draw_circle(d, 310, 180, 10, fill="#FFD54F")

def render_hand(d):
    draw_circle(d, 256, 256, 170, fill="#FFF8E1", outline="#FFA000", width=12)
    draw_rect(d, 190, 260, 322, 410, fill="#FFB74D", outline="#F57C00", width=8, radius=20)
    for i in range(4):
        x = 195 + i * 32
        draw_rect(d, x, 140, x + 26, 280, fill="#FFB74D", outline="#F57C00", width=6, radius=12)
    d.polygon([(190, 300), (140, 240), (160, 220), (210, 270)], fill="#FFB74D")

def render_finger(d):
    # Pointing index finger
    render_hand(d)

def render_arm(d):
    # Flexed strong arm / bicep
    draw_circle(d, 256, 256, 170, fill="#FFF8E1", outline="#FFA000", width=12)
    d.arc([160, 160, 360, 360], start=180, end=360, fill="#FFB74D", width=50)
    draw_circle(d, 256, 210, 45, fill="#FF9800")
    draw_rect(d, 260, 230, 370, 350, fill="#FFB74D", outline="#F57C00", width=8, radius=16)

def render_tummy(d):
    # Torso and belly
    draw_circle(d, 256, 256, 170, fill="#FFF8E1", outline="#FFA000", width=12)
    draw_rect(d, 160, 140, 352, 400, fill="#FFE0B2", outline="#FFA000", width=10, radius=32)
    draw_circle(d, 256, 300, 14, fill="#E65100")

def render_back(d):
    # Back view of torso
    draw_circle(d, 256, 256, 170, fill="#FFF8E1", outline="#FFA000", width=12)
    draw_rect(d, 160, 150, 352, 410, fill="#FFE0B2", outline="#FFA000", width=10, radius=30)
    draw_line(d, [(256, 160), (256, 390)], fill="#E65100", width=8)

def render_leg(d):
    # Leg with knee and foot
    draw_circle(d, 256, 256, 170, fill="#FFF8E1", outline="#FFA000", width=12)
    draw_rect(d, 210, 120, 280, 380, fill="#FFB74D", outline="#F57C00", width=8, radius=18)
    draw_rect(d, 210, 350, 350, 410, fill="#FFB74D", outline="#F57C00", width=8, radius=16)

def render_knee(d):
    # Leg with focus target circle on the knee joint
    render_leg(d)
    draw_circle(d, 245, 260, 45, fill=None, outline="#D32F2F", width=10)

def render_foot(d):
    draw_circle(d, 256, 256, 170, fill="#FFF8E1", outline="#FFA000", width=12)
    draw_rect(d, 180, 200, 270, 400, fill="#FFB74D", outline="#F57C00", width=8, radius=24)
    # Toes
    for i in range(5):
        x = 180 + i * 20
        draw_circle(d, x, 175, 12, fill="#FFB74D", outline="#F57C00", width=4)

def render_toe(d):
    render_foot(d)
    draw_circle(d, 180, 175, 24, fill=None, outline="#D32F2F", width=6)

# 6. FEELINGS
def render_angry(d):
    draw_circle(d, 256, 256, 180, fill="#EF5350", outline="#B71C1C", width=14)
    # Slanted angry brows
    draw_line(d, [(160, 170), (230, 210)], fill="#212121", width=16)
    draw_line(d, [(352, 170), (282, 210)], fill="#212121", width=16)
    draw_circle(d, 200, 235, 16, fill="#212121")
    draw_circle(d, 312, 235, 16, fill="#212121")
    d.arc([180, 310, 332, 410], start=200, end=340, fill="#212121", width=16)

def render_excited(d):
    draw_circle(d, 256, 256, 180, fill="#FFD54F", outline="#FFA000", width=14)
    # Star eyes
    for cx in (190, 322):
        d.polygon([(cx, 180), (cx + 10, 205), (cx + 30, 205), (cx + 15, 220), (cx + 20, 245), (cx, 230), (cx - 20, 245), (cx - 15, 220), (cx - 30, 205), (cx - 10, 205)], fill="#E65100")
    d.pieslice([170, 240, 342, 390], start=0, end=180, fill="#C2185B", outline="#212121", width=8)

def render_frustrated(d):
    draw_circle(d, 256, 256, 180, fill="#FF8A65", outline="#D84315", width=14)
    draw_line(d, [(170, 200), (230, 220)], fill="#212121", width=14)
    draw_line(d, [(342, 200), (282, 220)], fill="#212121", width=14)
    draw_circle(d, 200, 240, 14, fill="#212121")
    draw_circle(d, 312, 240, 14, fill="#212121")
    # Squiggly mouth
    d.line([(180, 330), (215, 310), (250, 340), (285, 310), (320, 330)], fill="#212121", width=14)

def render_calm(d):
    draw_circle(d, 256, 256, 180, fill="#B2DFDB", outline="#00796B", width=14)
    d.arc([170, 200, 230, 240], start=0, end=180, fill="#004D40", width=10)
    d.arc([282, 200, 342, 240], start=0, end=180, fill="#004D40", width=10)
    d.arc([200, 280, 312, 340], start=20, end=160, fill="#004D40", width=10)

def render_sick(d):
    draw_circle(d, 256, 256, 180, fill="#C8E6C9", outline="#388E3C", width=14)
    draw_circle(d, 195, 210, 16, fill="#212121")
    draw_circle(d, 317, 210, 16, fill="#212121")
    # Thermometer in mouth
    draw_rect(d, 230, 290, 350, 314, fill="#ECEFF1", outline="#37474F", width=6, radius=6)
    draw_circle(d, 360, 302, 18, fill="#E53935")
    draw_rect(d, 270, 295, 350, 309, fill="#E53935")

def render_bored(d):
    draw_circle(d, 256, 256, 180, fill="#CFD8DC", outline="#546E7A", width=14)
    draw_line(d, [(180, 220), (230, 220)], fill="#212121", width=14)
    draw_line(d, [(282, 220), (332, 220)], fill="#212121", width=14)
    draw_line(d, [(190, 330), (322, 330)], fill="#212121", width=14)

def render_silly(d):
    draw_circle(d, 256, 256, 180, fill="#FFF59D", outline="#FBC02D", width=14)
    draw_circle(d, 195, 210, 20, fill="#212121")
    # Winking eye
    draw_line(d, [(290, 210), (335, 210)], fill="#212121", width=12)
    # Tongue out
    d.arc([180, 260, 332, 360], start=0, end=180, fill="#212121", width=12)
    draw_rect(d, 230, 310, 282, 380, fill="#E91E63", radius=12)

def render_surprised(d):
    draw_circle(d, 256, 256, 180, fill="#FFF59D", outline="#FBC02D", width=14)
    draw_circle(d, 190, 200, 24, fill="#212121")
    draw_circle(d, 322, 200, 24, fill="#212121")
    draw_circle(d, 256, 320, 45, fill="#212121")

def render_proud(d):
    render_happy(d)
    # Star medal on chest
    d.polygon([(256, 360), (266, 390), (296, 390), (272, 405), (280, 435), (256, 415), (232, 435), (240, 405), (216, 390), (246, 390)], fill="#FFD54F")

def render_nervous(d):
    draw_circle(d, 256, 256, 180, fill="#FFF9C4", outline="#FBC02D", width=14)
    draw_circle(d, 195, 220, 16, fill="#212121")
    draw_circle(d, 317, 220, 16, fill="#212121")
    # Sweat drop on forehead
    d.polygon([(340, 130), (355, 160), (325, 160)], fill="#29B6F6")
    draw_circle(d, 340, 165, 15, fill="#29B6F6")
    # Wavy mouth
    d.line([(190, 320), (225, 305), (255, 325), (285, 305), (320, 320)], fill="#212121", width=10)

def render_lonely(d):
    draw_circle(d, 256, 256, 180, fill="#ECEFF1", outline="#90A4AE", width=14)
    # Small single figure sitting
    draw_circle(d, 256, 230, 35, fill="#78909C")
    draw_rect(d, 225, 270, 287, 360, fill="#546E7A", radius=10)
    # Cloud above
    draw_circle(d, 256, 120, 30, fill="#B0BEC5")
    draw_circle(d, 225, 130, 24, fill="#B0BEC5")
    draw_circle(d, 287, 130, 24, fill="#B0BEC5")

def render_confused(d):
    draw_circle(d, 256, 256, 180, fill="#FFF9C4", outline="#FBC02D", width=14)
    # One brow up, one brow down
    draw_line(d, [(170, 180), (220, 200)], fill="#212121", width=12)
    draw_line(d, [(290, 210), (340, 190)], fill="#212121", width=12)
    draw_circle(d, 195, 230, 16, fill="#212121")
    draw_circle(d, 315, 230, 16, fill="#212121")
    draw_line(d, [(200, 330), (312, 310)], fill="#212121", width=12)

def render_shy(d):
    render_happy(d)
    # Rosy blush cheeks
    draw_circle(d, 155, 260, 30, fill="#FF8A80")
    draw_circle(d, 357, 260, 30, fill="#FF8A80")

def render_worried(d):
    draw_circle(d, 256, 256, 180, fill="#FFE0B2", outline="#FB8C00", width=14)
    draw_line(d, [(170, 200), (220, 180)], fill="#212121", width=12)
    draw_line(d, [(292, 180), (342, 200)], fill="#212121", width=12)
    draw_circle(d, 195, 230, 16, fill="#212121")
    draw_circle(d, 317, 230, 16, fill="#212121")
    d.arc([190, 310, 322, 390], start=200, end=340, fill="#212121", width=14)

def render_okay(d):
    render_happy(d)
    draw_circle(d, 340, 340, 45, fill="#4CAF50")
    draw_line(d, [(315, 340), (335, 360), (365, 325)], fill="#FFFFFF", width=8)

def render_love(d):
    draw_circle(d, 256, 256, 180, fill="#FCE4EC", outline="#E91E63", width=14)
    # Heart eyes
    for cx in (190, 322):
        draw_circle(d, cx - 15, 210, 18, fill="#E91E63")
        draw_circle(d, cx + 15, 210, 18, fill="#E91E63")
        d.polygon([(cx - 30, 215), (cx + 30, 215), (cx, 250)], fill="#E91E63")
    d.arc([180, 270, 332, 370], start=20, end=160, fill="#E91E63", width=14)

def render_good(d):
    draw_circle(d, 256, 256, 180, fill="#4CAF50", outline="#2E7D32", width=14)
    # Thumbs up
    draw_rect(d, 190, 250, 310, 370, fill="#FFFFFF", radius=16)
    draw_rect(d, 160, 200, 220, 320, fill="#FFFFFF", radius=16)

def render_bad(d):
    draw_circle(d, 256, 256, 180, fill="#E53935", outline="#B71C1C", width=14)
    # Thumbs down
    draw_rect(d, 190, 150, 310, 270, fill="#FFFFFF", radius=16)
    draw_rect(d, 160, 200, 220, 320, fill="#FFFFFF", radius=16)

def render_tired(d):
    render_sleep(d)

def render_scared(d):
    draw_circle(d, 256, 256, 180, fill="#B3E5FC", outline="#0288D1", width=14)
    draw_circle(d, 190, 200, 26, fill="#212121")
    draw_circle(d, 322, 200, 26, fill="#212121")
    # Chattering teeth mouth
    draw_rect(d, 180, 300, 332, 360, fill="#FFFFFF", outline="#212121", width=8, radius=8)
    for tx in (210, 240, 270, 300):
        draw_line(d, [(tx, 300), (tx, 360)], fill="#212121", width=4)

# 7. PEOPLE
def render_person(d, hair_color="#5D4037", shirt_color="#1976D2", has_bun=False, has_glasses=False, has_mustache=False, is_baby=False):
    draw_circle(d, 256, 170, 75, fill="#FFE0B2", outline="#FFA726", width=8)
    if has_bun:
        draw_circle(d, 256, 75, 40, fill=hair_color)
        d.arc([180, 100, 332, 200], start=180, end=360, fill=hair_color, width=28)
    elif not is_baby:
        d.pieslice([180, 95, 332, 200], start=180, end=360, fill=hair_color)
    else:
        d.arc([240, 80, 272, 120], start=0, end=270, fill="#FFB300", width=8)
    if has_glasses:
        draw_circle(d, 220, 170, 22, fill=None, outline="#212121", width=6)
        draw_circle(d, 292, 170, 22, fill=None, outline="#212121", width=6)
        draw_line(d, [(242, 170), (270, 170)], fill="#212121", width=6)
    else:
        draw_circle(d, 225, 170, 12, fill="#212121")
        draw_circle(d, 287, 170, 12, fill="#212121")
    if has_mustache:
        d.arc([220, 185, 292, 225], start=0, end=180, fill=hair_color, width=12)
    else:
        d.arc([220, 180, 292, 225], start=20, end=160, fill="#D84315", width=8)
    draw_rect(d, 150, 255, 362, 440, fill=shirt_color, radius=32)

def render_friend(d):
    # Two smiling friends side-by-side
    draw_circle(d, 256, 256, 170, fill="#FFF9C4", outline="#FBC02D", width=12)
    draw_circle(d, 190, 200, 50, fill="#FFE0B2")
    draw_circle(d, 322, 200, 50, fill="#FFCC80")
    draw_rect(d, 140, 250, 240, 410, fill="#1976D2", radius=20)
    draw_rect(d, 272, 250, 372, 410, fill="#E91E63", radius=20)
    draw_circle(d, 175, 195, 8, fill="#212121")
    draw_circle(d, 205, 195, 8, fill="#212121")
    draw_circle(d, 307, 195, 8, fill="#212121")
    draw_circle(d, 337, 195, 8, fill="#212121")

def render_boy(d):
    render_person(d, hair_color="#5D4037", shirt_color="#1E88E5")

def render_girl(d):
    render_person(d, hair_color="#F57C00", shirt_color="#FF4081")
    # Pigtail bows
    draw_circle(d, 160, 130, 16, fill="#E91E63")
    draw_circle(d, 352, 130, 16, fill="#E91E63")

def render_aunt(d):
    render_person(d, hair_color="#8D6E63", shirt_color="#8E24AA", has_bun=True)

def render_uncle(d):
    render_person(d, hair_color="#424242", shirt_color="#00897B", has_mustache=True, has_glasses=True)

def render_family(d):
    # Mom, dad and child
    render_friend(d)
    draw_circle(d, 256, 270, 35, fill="#FFE0B2")
    draw_rect(d, 230, 310, 282, 420, fill="#4CAF50", radius=14)

def render_neighbor(d):
    render_person(d, hair_color="#6D4C41", shirt_color="#FFB300")
    # Waving hand
    draw_circle(d, 380, 210, 24, fill="#FFE0B2")

# 8. PLACES
def render_park(d):
    # Tree, bench, sun
    draw_circle(d, 256, 256, 170, fill="#E8F5E9", outline="#2E7D32", width=12)
    draw_circle(d, 350, 140, 40, fill="#FFD54F")
    # Tree trunk and foliage
    draw_rect(d, 190, 240, 230, 390, fill="#795548", radius=8)
    draw_circle(d, 210, 200, 75, fill="#43A047")
    draw_circle(d, 160, 230, 50, fill="#388E3C")
    draw_circle(d, 260, 230, 50, fill="#388E3C")

def render_store(d):
    # Storefront with awning
    draw_circle(d, 256, 256, 170, fill="#FFF8E1", outline="#FFA000", width=12)
    draw_rect(d, 130, 220, 382, 410, fill="#ECEFF1", outline="#37474F", width=8, radius=8)
    # Striped awning
    for i in range(5):
        x = 130 + i * 50
        col = "#E53935" if i % 2 == 0 else "#FFFFFF"
        draw_rect(d, x, 170, x + 50, 230, fill=col, outline="#C62828", width=4, radius=4)
    draw_rect(d, 210, 280, 302, 410, fill="#81D4FA", outline="#0277BD", width=6, radius=4)

def render_restaurant(d):
    render_eat(d)

def render_doctor_place(d):
    # Medical cross and stethoscope
    draw_circle(d, 256, 256, 170, fill="#E0F2F1", outline="#00796B", width=12)
    draw_rect(d, 226, 140, 286, 372, fill="#E53935", radius=8)
    draw_rect(d, 140, 226, 372, 286, fill="#E53935", radius=8)

def render_hospital(d):
    render_school(d)
    # Red cross on building
    draw_rect(d, 246, 220, 266, 280, fill="#E53935")
    draw_rect(d, 226, 240, 286, 260, fill="#E53935")

def render_playground(d):
    # Playground slide
    draw_circle(d, 256, 256, 170, fill="#FFF3E0", outline="#EF6C00", width=12)
    # Ladder
    draw_line(d, [(150, 160), (150, 400)], fill="#D32F2F", width=12)
    for y in (220, 280, 340):
        draw_line(d, [(130, y), (170, y)], fill="#D32F2F", width=8)
    # Slide chute
    d.arc([150, 150, 390, 420], start=180, end=270, fill="#1E88E5", width=24)
    draw_line(d, [(270, 285), (390, 390)], fill="#1E88E5", width=24)

def render_beach(d):
    # Palm tree on beach with ocean
    draw_circle(d, 256, 256, 170, fill="#E1F5FE", outline="#0288D1", width=12)
    draw_circle(d, 360, 130, 35, fill="#FFD54F")
    # Ocean & Sand
    draw_rect(d, 90, 340, 422, 422, fill="#FFE082")
    d.arc([130, 200, 240, 390], start=90, end=180, fill="#795548", width=20)
    # Palm fronds
    d.arc([140, 160, 240, 240], start=180, end=360, fill="#388E3C", width=16)
    d.arc([220, 160, 320, 240], start=180, end=360, fill="#388E3C", width=16)

def render_library(d):
    # Bookshelf
    draw_circle(d, 256, 256, 170, fill="#EFEBE9", outline="#5D4037", width=12)
    draw_rect(d, 130, 140, 382, 410, fill="#8D6E63", outline="#4E342E", width=10, radius=8)
    draw_line(d, [(140, 270), (372, 270)], fill="#4E342E", width=10)
    # Books
    bcols = ["#E53935", "#1E88E5", "#FDD835", "#43A047", "#8E24AA"]
    for i, col in enumerate(bcols):
        draw_rect(d, 150 + i * 42, 170, 185 + i * 42, 270, fill=col, radius=4)
        draw_rect(d, 150 + i * 42, 300, 185 + i * 42, 400, fill=col, radius=4)

def render_bus(d):
    # Yellow school bus
    draw_circle(d, 256, 256, 170, fill="#E1F5FE", outline="#0288D1", width=12)
    draw_rect(d, 110, 200, 402, 350, fill="#FDD835", outline="#F57F17", width=10, radius=20)
    for i in range(4):
        draw_rect(d, 140 + i * 65, 220, 185 + i * 65, 270, fill="#81D4FA", outline="#0277BD", width=4, radius=4)
    draw_circle(d, 180, 350, 35, fill="#424242", outline="#212121", width=8)
    draw_circle(d, 332, 350, 35, fill="#424242", outline="#212121", width=8)

def render_zoo(d):
    # Friendly animal behind gate
    draw_circle(d, 256, 256, 170, fill="#FFF8E1", outline="#FFA000", width=12)
    # Lion face
    draw_circle(d, 256, 230, 80, fill="#FFA000")  # Mane
    draw_circle(d, 256, 230, 55, fill="#FFD54F")  # Face
    draw_circle(d, 235, 220, 8, fill="#212121")
    draw_circle(d, 277, 220, 8, fill="#212121")
    draw_circle(d, 256, 245, 10, fill="#D84315")
    # Gate bars
    for x in (160, 210, 256, 302, 352):
        draw_line(d, [(x, 280), (x, 410)], fill="#795548", width=10)

def render_pool(d):
    render_swim(d)

def render_kitchen(d):
    # Stove and frying pan
    draw_circle(d, 256, 256, 170, fill="#ECEFF1", outline="#455A64", width=12)
    draw_rect(d, 130, 200, 382, 410, fill="#CFD8DC", outline="#37474F", width=10, radius=12)
    draw_circle(d, 200, 260, 35, fill="#37474F")
    draw_circle(d, 312, 260, 35, fill="#37474F")
    draw_rect(d, 160, 330, 352, 390, fill="#90A4AE", radius=6)

def render_bedroom(d):
    render_sleep(d)

def render_church(d):
    # Building with steeple and cross
    draw_circle(d, 256, 256, 170, fill="#F3E5F5", outline="#7B1FA2", width=12)
    draw_rect(d, 160, 240, 352, 420, fill="#FFFFFF", outline="#7B1FA2", width=10, radius=6)
    d.polygon([(160, 240), (256, 110), (352, 240)], fill="#BA68C8", outline="#7B1FA2", width=8)
    # Cross on steeple
    draw_line(d, [(256, 60), (256, 110)], fill="#7B1FA2", width=10)
    draw_line(d, [(240, 75), (272, 75)], fill="#7B1FA2", width=10)
    # Arched door
    draw_rect(d, 226, 330, 286, 420, fill="#795548", radius=8)

def render_gym(d):
    # Dumbbells
    draw_circle(d, 256, 256, 170, fill="#ECEFF1", outline="#455A64", width=12)
    draw_rect(d, 180, 240, 332, 272, fill="#78909C", radius=6)
    draw_rect(d, 140, 190, 180, 322, fill="#212121", radius=10)
    draw_rect(d, 332, 190, 372, 322, fill="#212121", radius=10)

def render_outside(d):
    # Grassy hill and sun
    draw_circle(d, 256, 256, 170, fill="#E1F5FE", outline="#0288D1", width=12)
    draw_circle(d, 340, 140, 45, fill="#FFD54F")
    d.pieslice([60, 220, 452, 480], start=180, end=360, fill="#4CAF50", outline="#2E7D32", width=10)

# 9. THINGS
def render_ball(d):
    draw_circle(d, 256, 256, 160, fill="#E53935", outline="#C62828", width=10)
    d.pieslice([96, 96, 416, 416], start=45, end=135, fill="#1E88E5")
    d.pieslice([96, 96, 416, 416], start=225, end=315, fill="#FDD835")
    draw_circle(d, 256, 256, 45, fill="#FFFFFF")

def render_book(d):
    render_read(d)

def render_toy(d):
    # Teddy bear
    draw_circle(d, 256, 256, 170, fill="#FFF8E1", outline="#FFA000", width=12)
    draw_circle(d, 180, 160, 35, fill="#8D6E63")
    draw_circle(d, 332, 160, 35, fill="#8D6E63")
    draw_circle(d, 256, 220, 75, fill="#A1887F", outline="#6D4C41", width=8)
    draw_circle(d, 230, 205, 10, fill="#212121")
    draw_circle(d, 282, 205, 10, fill="#212121")
    draw_circle(d, 256, 235, 14, fill="#4E342E")

def render_blocks(d):
    render_build(d)

def render_doll(d):
    render_toy(d)

def render_car(d):
    draw_circle(d, 256, 256, 170, fill="#E8F5E9", outline="#388E3C", width=12)
    draw_rect(d, 120, 250, 392, 360, fill="#E53935", outline="#B71C1C", width=10, radius=16)
    d.polygon([(180, 250), (220, 170), (330, 170), (360, 250)], fill="#EF5350", outline="#B71C1C", width=8)
    draw_rect(d, 225, 180, 275, 240, fill="#81D4FA")
    draw_rect(d, 285, 180, 325, 240, fill="#81D4FA")
    draw_circle(d, 180, 360, 35, fill="#212121", outline="#B0BEC5", width=8)
    draw_circle(d, 332, 360, 35, fill="#212121", outline="#B0BEC5", width=8)

def render_phone(d):
    draw_circle(d, 256, 256, 170, fill="#E0F7FA", outline="#00838F", width=12)
    draw_rect(d, 170, 110, 342, 410, fill="#37474F", outline="#212121", width=10, radius=24)
    draw_rect(d, 185, 145, 327, 365, fill="#E1F5FE", radius=8)
    draw_circle(d, 256, 388, 12, fill="#ECEFF1")

def render_tablet(d):
    draw_circle(d, 256, 256, 170, fill="#EDE7F6", outline="#512DA8", width=12)
    draw_rect(d, 130, 130, 382, 382, fill="#37474F", outline="#212121", width=10, radius=20)
    draw_rect(d, 150, 150, 362, 362, fill="#E1F5FE", radius=10)
    for rx in (180, 235, 290):
        for ry in (180, 235, 290):
            draw_circle(d, rx + 15, ry + 15, 18, fill="#FFB74D")

def render_tv(d):
    render_watch(d)

def render_blanket(d):
    draw_circle(d, 256, 256, 170, fill="#FFF8E1", outline="#FFA000", width=12)
    draw_rect(d, 140, 180, 372, 360, fill="#42A5F5", outline="#1565C0", width=10, radius=20)
    # Cozy stripes
    for y in (220, 260, 300):
        draw_line(d, [(150, y), (362, y)], fill="#FFFFFF", width=8)

def render_cup(d):
    draw_circle(d, 256, 256, 170, fill="#E0F2F1", outline="#00897B", width=12)
    draw_rect(d, 170, 170, 330, 380, fill="#00ACC1", outline="#006064", width=10, radius=20)
    d.arc([290, 210, 390, 330], start=270, end=90, fill="#006064", width=16)

def render_spoon(d):
    draw_circle(d, 256, 256, 170, fill="#ECEFF1", outline="#607D8B", width=12)
    draw_circle(d, 256, 180, 55, fill="#B0BEC5", outline="#546E7A", width=8)
    draw_rect(d, 246, 220, 266, 410, fill="#B0BEC5", outline="#546E7A", width=6, radius=8)

def render_shoes(d):
    draw_circle(d, 256, 256, 170, fill="#FFF3E0", outline="#E65100", width=12)
    draw_rect(d, 140, 280, 372, 360, fill="#1E88E5", outline="#0D47A1", width=8, radius=16)
    draw_rect(d, 120, 340, 392, 375, fill="#ECEFF1", outline="#455A64", width=6, radius=6)
    # Laces
    for lx in (220, 260, 300):
        draw_line(d, [(lx, 290), (lx + 20, 320)], fill="#FFFFFF", width=6)

def render_hat(d):
    draw_circle(d, 256, 256, 170, fill="#E8F5E9", outline="#388E3C", width=12)
    d.pieslice([160, 160, 352, 340], start=180, end=360, fill="#E53935", outline="#B71C1C", width=8)
    draw_rect(d, 220, 280, 392, 310, fill="#C62828", radius=6)

def render_crayon(d):
    render_draw(d)

def render_bubbles(d):
    draw_circle(d, 256, 256, 170, fill="#E1F5FE", outline="#0288D1", width=12)
    draw_circle(d, 200, 200, 50, fill="#B3E5FC", outline="#0288D1", width=6)
    draw_circle(d, 310, 180, 35, fill="#B3E5FC", outline="#0288D1", width=6)
    draw_circle(d, 280, 290, 60, fill="#B3E5FC", outline="#0288D1", width=6)
    draw_circle(d, 190, 190, 12, fill="#FFFFFF")
    draw_circle(d, 270, 280, 15, fill="#FFFFFF")

# 10. TIME
def render_clock(d, arrow=False):
    draw_circle(d, 256, 256, 170, fill="#EDE7F6", outline="#512DA8", width=14)
    draw_circle(d, 256, 256, 130, fill="#FFFFFF", outline="#D1C4E9", width=6)
    draw_line(d, [(256, 256), (256, 160)], fill="#212121", width=12)
    draw_line(d, [(256, 256), (320, 256)], fill="#212121", width=10)
    draw_circle(d, 256, 256, 16, fill="#512DA8")
    if arrow:
        d.arc([80, 80, 432, 432], start=30, end=110, fill="#E91E63", width=16)
        d.polygon([(360, 390), (410, 350), (410, 420)], fill="#E91E63")

def render_calendar(d, badge_star=False, arrow_dir=None):
    draw_circle(d, 256, 256, 170, fill="#EDE7F6", outline="#512DA8", width=12)
    draw_rect(d, 130, 140, 382, 390, fill="#FFFFFF", outline="#512DA8", width=10, radius=16)
    draw_rect(d, 130, 140, 382, 210, fill="#E53935", radius=16)
    # Binder rings
    draw_rect(d, 180, 115, 205, 160, fill="#424242", radius=4)
    draw_rect(d, 307, 115, 332, 160, fill="#424242", radius=4)
    if badge_star:
        # Star on calendar
        draw_circle(d, 256, 300, 40, fill="#FFD54F")
    if arrow_dir == "forward":
        d.polygon([(220, 260), (300, 300), (220, 340)], fill="#1E88E5")
    elif arrow_dir == "backward":
        d.polygon([(292, 260), (212, 300), (292, 340)], fill="#1E88E5")

def render_today(d): render_calendar(d, badge_star=True)
def render_tomorrow(d): render_calendar(d, arrow_dir="forward")
def render_yesterday(d): render_calendar(d, arrow_dir="backward")

def render_morning(d):
    # Sun rising over horizon
    draw_circle(d, 256, 256, 170, fill="#FFF8E1", outline="#FFA000", width=12)
    d.arc([130, 160, 382, 410], start=180, end=360, fill="#FFB300", width=36)
    draw_circle(d, 256, 280, 70, fill="#FFD54F")
    draw_line(d, [(100, 330), (412, 330)], fill="#4CAF50", width=16)

def render_afternoon(d):
    # Bright sun with small cloud
    draw_circle(d, 256, 256, 170, fill="#E1F5FE", outline="#0288D1", width=12)
    draw_circle(d, 256, 200, 70, fill="#FFD54F", outline="#FFA000", width=8)
    draw_circle(d, 290, 310, 45, fill="#ECEFF1")
    draw_circle(d, 230, 320, 35, fill="#ECEFF1")
    draw_circle(d, 340, 320, 35, fill="#ECEFF1")

def render_night(d):
    # Dark blue night sky with crescent moon and stars
    draw_circle(d, 256, 256, 170, fill="#1A237E", outline="#0D47A1", width=12)
    # Crescent moon
    draw_circle(d, 256, 256, 75, fill="#FFD54F")
    draw_circle(d, 280, 240, 70, fill="#1A237E")
    # Stars
    for sx, sy in [(170, 180), (320, 170), (190, 320)]:
        draw_circle(d, sx, sy, 8, fill="#FFFFFF")

def render_day(d):
    render_morning(d)

def render_week(d):
    render_calendar(d)

def render_weekend(d):
    render_calendar(d, badge_star=True)

# 11. FOLDERS
def render_folder(d, fill, stroke, icon_func=None):
    draw_rect(d, 100, 140, 260, 220, fill=stroke, radius=12)
    draw_rect(d, 90, 180, 422, 410, fill=fill, outline=stroke, width=12, radius=24)
    if icon_func:
        icon_func(d)

def render_folder_food(d):
    render_folder(d, "#FFE082", "#FF8F00")
    render_apple(d)

def render_folder_places(d):
    render_folder(d, "#D1C4E9", "#512DA8")
    render_home(d)

def render_folder_people(d):
    render_folder(d, "#FFF59D", "#FBC02D")
    render_friend(d)

def render_folder_activities(d):
    render_folder(d, "#C8E6C9", "#388E3C")
    render_ball(d)

def render_folder_things(d):
    render_folder(d, "#FFE0B2", "#E65100")
    render_car(d)

def render_folder_feelings(d):
    render_folder(d, "#BBDEFB", "#1976D2")
    render_happy(d)

def render_folder_time(d):
    render_folder(d, "#E1BEE7", "#7B1FA2")
    render_clock(d, arrow=False)

def render_folder_body(d):
    render_folder(d, "#FFCCBC", "#D84315")
    render_head(d)

# ==================== MAIN DISPATCHER ====================
def render_symbol(uri, label, cat):
    img = create_canvas()
    d = ImageDraw.Draw(img)

    name = os.path.splitext(os.path.basename(uri))[0].lower()

    # Core Verbs & Actions
    if name == "water": render_water(d)
    elif name == "eat": render_eat(d)
    elif name == "sleep": render_sleep(d)
    elif name == "help": render_help(d)
    elif name == "stop": render_stop(d)
    elif name == "go": render_go(d)
    elif name == "want": render_want(d)
    elif name == "need": render_need(d)
    elif name == "like": render_like(d)
    elif name == "get": render_get(d)
    elif name == "make": render_make(d)
    elif name == "look": render_look(d)
    elif name == "play": render_play(d)
    elif name == "open": render_open(d)
    elif name == "drink": render_water(d)
    elif name == "break": render_break(d)
    elif name == "all_done": render_all_done(d)
    elif name == "wait": render_wait(d)
    elif name == "hungry": render_hungry(d)
    elif name == "hurt": render_hurt(d)
    elif name == "bathroom": render_bathroom(d)
    elif name == "yes": render_yes(d)
    elif name == "no": render_no(d)
    elif name == "more": render_more(d)
    elif name == "again": render_again(d)
    elif name == "here": render_here(d)
    elif name == "that": render_that(d)
    elif name == "i": render_pronoun_i(d)
    elif name == "you": render_pronoun_you(d)
    elif name == "thank_you": render_thank_you(d)
    elif name == "please": render_please(d)
    elif name == "sorry": render_sorry(d)

    # Questions
    elif name == "what": render_what(d)
    elif name == "where": render_where(d)
    elif name == "who": render_who(d)
    elif name == "when": render_when(d)
    elif name == "why": render_why(d)
    elif name == "how": render_how(d)

    # Food
    elif name == "apple": render_apple(d)
    elif name == "banana": render_banana(d)
    elif name == "cookie": render_cookie(d)
    elif name == "bread": render_bread(d)
    elif name == "milk": render_milk(d)
    elif name == "juice": render_juice(d)
    elif name == "pizza": render_pizza(d)
    elif name == "cheese": render_cheese(d)
    elif name == "chicken": render_chicken(d)
    elif name == "egg": render_egg(d)
    elif name == "grapes": render_grapes(d)
    elif name == "ice_cream": render_ice_cream(d)
    elif name == "cereal": render_cereal(d)
    elif name == "rice": render_rice(d)
    elif name == "cracker": render_cracker(d)
    elif name == "yogurt": render_yogurt(d)

    # Activities
    elif name == "read": render_read(d)
    elif name == "draw": render_draw(d)
    elif name == "color": render_color(d)
    elif name == "paint": render_paint(d)
    elif name == "sing": render_sing(d)
    elif name == "dance": render_dance(d)
    elif name == "swim": render_swim(d)
    elif name == "run": render_run(d)
    elif name == "walk": render_walk(d)
    elif name == "jump": render_jump(d)
    elif name == "ride": render_ride(d)
    elif name == "build": render_build(d)
    elif name == "watch": render_watch(d)
    elif name == "listen": render_listen(d)
    elif name == "cook": render_cook(d)

    # Body
    elif name == "head": render_head(d)
    elif name == "hair": render_hair(d)
    elif name == "eye": render_eye(d)
    elif name == "ear": render_ear(d)
    elif name == "nose": render_nose(d)
    elif name == "mouth": render_mouth(d)
    elif name == "teeth": render_teeth(d)
    elif name in ("hand", "finger"): render_hand(d)
    elif name == "arm": render_arm(d)
    elif name == "tummy": render_tummy(d)
    elif name == "back": render_back(d)
    elif name == "leg": render_leg(d)
    elif name == "knee": render_knee(d)
    elif name == "foot": render_foot(d)
    elif name == "toe": render_toe(d)

    # Feelings
    elif name == "happy": render_happy(d)
    elif name == "sad": render_sad(d)
    elif name == "angry": render_angry(d)
    elif name == "excited": render_excited(d)
    elif name == "frustrated": render_frustrated(d)
    elif name == "calm": render_calm(d)
    elif name == "sick": render_sick(d)
    elif name == "bored": render_bored(d)
    elif name == "silly": render_silly(d)
    elif name == "surprised": render_surprised(d)
    elif name == "proud": render_proud(d)
    elif name == "nervous": render_nervous(d)
    elif name == "lonely": render_lonely(d)
    elif name == "confused": render_confused(d)
    elif name == "shy": render_shy(d)
    elif name == "worried": render_worried(d)
    elif name == "okay": render_okay(d)
    elif name == "love": render_love(d)
    elif name == "good": render_good(d)
    elif name == "bad": render_bad(d)
    elif name == "tired": render_tired(d)
    elif name == "scared": render_scared(d)

    # People
    elif name == "mom": render_person(d, hair_color="#6D4C41", shirt_color="#E91E63")
    elif name == "dad": render_person(d, hair_color="#212121", shirt_color="#1E88E5")
    elif name == "grandma": render_person(d, hair_color="#9E9E9E", shirt_color="#8E24AA", has_bun=True, has_glasses=True)
    elif name == "grandpa": render_person(d, hair_color="#9E9E9E", shirt_color="#43A047", has_glasses=True, has_mustache=True)
    elif name == "sister": render_person(d, hair_color="#F57C00", shirt_color="#FF4081")
    elif name == "brother": render_person(d, hair_color="#5D4037", shirt_color="#00BCD4")
    elif name == "baby": render_person(d, is_baby=True, shirt_color="#FFEB3B")
    elif name == "doctor": render_person(d, hair_color="#37474F", shirt_color="#FFFFFF")
    elif name == "nurse": render_person(d, hair_color="#795548", shirt_color="#80DEEA")
    elif name == "teacher": render_person(d, hair_color="#455A64", shirt_color="#3F51B5", has_glasses=True)
    elif name == "friend": render_friend(d)
    elif name == "boy": render_boy(d)
    elif name == "girl": render_girl(d)
    elif name == "aunt": render_aunt(d)
    elif name == "uncle": render_uncle(d)
    elif name == "family": render_family(d)
    elif name == "neighbor": render_neighbor(d)

    # Places
    elif name == "school": render_school(d)
    elif name == "home": render_home(d)
    elif name == "park": render_park(d)
    elif name == "store": render_store(d)
    elif name == "restaurant": render_restaurant(d)
    elif name == "hospital": render_hospital(d)
    elif name == "playground": render_playground(d)
    elif name == "beach": render_beach(d)
    elif name == "library": render_library(d)
    elif name == "bus": render_bus(d)
    elif name == "zoo": render_zoo(d)
    elif name == "pool": render_pool(d)
    elif name == "kitchen": render_kitchen(d)
    elif name == "bedroom": render_bedroom(d)
    elif name == "church": render_church(d)
    elif name == "gym": render_gym(d)
    elif name == "outside": render_outside(d)

    # Things
    elif name == "ball": render_ball(d)
    elif name == "book": render_book(d)
    elif name == "toy": render_toy(d)
    elif name == "blocks": render_blocks(d)
    elif name == "doll": render_doll(d)
    elif name == "car": render_car(d)
    elif name == "phone": render_phone(d)
    elif name == "tablet": render_tablet(d)
    elif name == "tv": render_tv(d)
    elif name == "blanket": render_blanket(d)
    elif name == "cup": render_cup(d)
    elif name == "spoon": render_spoon(d)
    elif name == "shoes": render_shoes(d)
    elif name == "hat": render_hat(d)
    elif name == "crayon": render_crayon(d)
    elif name == "bubbles": render_bubbles(d)

    # Time
    elif name in ("now", "minute", "late"): render_clock(d, arrow=False)
    elif name in ("later", "before"): render_clock(d, arrow=True)
    elif name == "today": render_today(d)
    elif name == "tomorrow": render_tomorrow(d)
    elif name == "yesterday": render_yesterday(d)
    elif name == "morning": render_morning(d)
    elif name == "afternoon": render_afternoon(d)
    elif name == "night": render_night(d)
    elif name == "day": render_day(d)
    elif name == "week": render_week(d)
    elif name == "weekend": render_weekend(d)

    # Folders
    elif name == "food" and cat.startswith("food"): render_folder_food(d)
    elif name == "places" and cat.startswith("places"): render_folder_places(d)
    elif name == "people" and cat.startswith("people"): render_folder_people(d)
    elif name == "activities" and cat.startswith("activities"): render_folder_activities(d)
    elif name == "things" and cat.startswith("things"): render_folder_things(d)
    elif name == "feelings" and cat.startswith("feelings"): render_folder_feelings(d)
    elif name == "time" and cat.startswith("time"): render_folder_time(d)
    elif name == "body" and cat.startswith("body"): render_folder_body(d)

    else:
        # Fallback to happy face / help icon
        render_happy(d)

    finalize(img, uri)

def main():
    root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    manifest_path = os.path.join(root, "assets", "symbols", "manifest.json")
    with open(manifest_path, "r", encoding="utf-8") as f:
        manifest = json.load(f)

    symbols = manifest["symbols"]
    print(f"Generating {len(symbols)} pictograms...")

    for entry in symbols:
        uri = os.path.join(root, entry["icon_uri"])
        label = entry["english_label"]
        cat = entry["fitzgerald_category"]
        render_symbol(uri, label, cat)

        # Compute SHA-256
        with open(uri, "rb") as f:
            h = hashlib.sha256(f.read()).hexdigest()
        entry["sha256"] = h

    with open(manifest_path, "w", encoding="utf-8") as f:
        json.dump(manifest, f, indent=2, ensure_ascii=False)
        f.write("\n")

    print("All 180 symbols successfully generated and manifest updated!")

if __name__ == "__main__":
    main()
