"""Foydalanuvchi bergan FORWARD robot maskoti asosida: welcome animatsiya, tanishuv kartalari, Mini App rasmlari."""
import math
import os
import random
import subprocess
import sys

from PIL import Image, ImageDraw, ImageFilter

sys.argv = ["x", "/tmp/vsp-main/assets/forward_logo.jpg", "/home/claude/brand/out"]
exec(open("/home/claude/brand/make_assets.py").read().split("# ---------- 1. Avatar")[0])

_src = open("/home/claude/brand/make_assets.py").read()
exec(_src[_src.index("TOUR = ["):_src.index("\n]\n", _src.index("TOUR = [")) + 3])
OUT = "/home/claude/brand/out"
MASCOT = Image.open("/home/claude/brand/m/mascot.jpg").convert("RGB")


def ease(t):
    t = max(0.0, min(1.0, t))
    return 1 - (1 - t) ** 3


def circle(im, size, ring=True):
    im = im.resize((size, size), Image.LANCZOS).convert("RGBA")
    mask = Image.new("L", (size, size), 0)
    ImageDraw.Draw(mask).ellipse((0, 0, size - 1, size - 1), fill=255)
    im.putalpha(mask)
    if not ring:
        return im
    pad = 14
    out = Image.new("RGBA", (size + pad * 2, size + pad * 2), (0, 0, 0, 0))
    d = ImageDraw.Draw(out)
    for i, c in enumerate([LBLUE, DBLUE, RED]):
        a0 = -90 + i * 120
        d.arc((2, 2, size + pad * 2 - 3, size + pad * 2 - 3), a0 + 6, a0 + 114, fill=c + (255,), width=8)
    out.alpha_composite(im, (pad, pad))
    return out


def with_glow(base, layer, xy, blur=30, col=(90, 150, 255, 170)):
    g = Image.new("RGBA", base.size, (0, 0, 0, 0))
    a = layer.getchannel("A")
    g.paste(col, xy, a)
    base.alpha_composite(g.filter(ImageFilter.GaussianBlur(blur)))
    base.alpha_composite(layer, xy)


# ---------- Tanishuv kartalari: maskot doirada ----------
def tour_cards():
    W, H = 1280, 720
    for i, (e, title, sub, items) in enumerate(TOUR):
        img = bg(W, H, 10 + i).convert("RGBA")
        d = ImageDraw.Draw(img)
        m = MARK.resize((90, int(MARK.height * 90 / MARK.width)), Image.LANCZOS)
        img.paste(m, (70, 58), m)
        d.text((180, 82), "Forward Ai", font=font("Bold", 34), fill="white", anchor="lm")
        o = Image.new("RGBA", img.size, (0, 0, 0, 0))
        od = ImageDraw.Draw(o)
        for k in range(4):
            x = W - 70 - (3 - k) * 56
            od.rounded_rectangle((x - 34 if k == i else x - 10, 74, x + 10, 94), 10,
                                 fill=(255, 255, 255, 255) if k == i else (255, 255, 255, 70))
        for j in range(len(items)):
            y = 450 + j * 72
            od.rounded_rectangle((470, y, 1210, y + 58), 29, fill=(255, 255, 255, 22))
        img.alpha_composite(o)
        c = circle(MASCOT, 300)
        with_glow(img, c, (250 - c.width // 2, 410 - c.height // 2))
        # emoji nishon
        d = ImageDraw.Draw(img)
        bx, by = 345, 520
        d.ellipse((bx - 46, by - 46, bx + 46, by + 46), fill=(255, 255, 255), outline=RED, width=5)
        emoji(img, (bx, by), e, 54)
        d.text((470, 250), f"{i + 1}/4", font=font("Bold", 30), fill=(120, 160, 255), anchor="lm")
        d.text((470, 312), title, font=font("Black", 72), fill="white", anchor="lm")
        d.text((472, 378), sub, font=font("Medium", 30), fill=(170, 185, 230), anchor="lm")
        for j, it in enumerate(items):
            y = 450 + j * 72
            d.ellipse((492, y + 21, 508, y + 37), fill=[LBLUE, (90, 120, 230), RED][j])
            d.text((528, y + 29), it, font=font("SemiBold", 28), fill="white", anchor="lm")
        for k, col in enumerate([LBLUE, DBLUE, RED]):
            d.rectangle((k * W / 3, H - 8, (k + 1) * W / 3, H), fill=col)
        img.convert("RGB").save(f"{OUT}/tour{i + 1}.jpg", quality=90)


# ---------- Welcome animatsiya: maskot "uchib kiradi", salom beradi ----------
def welcome():
    W, H, FPS, N = 960, 540, 30, 120
    base = bg(W, H, 21).convert("RGBA")
    mc = circle(MASCOT, 330)
    fr = f"{OUT}/_mf"
    os.makedirs(fr, exist_ok=True)
    rnd = random.Random(7)
    parts = [(rnd.uniform(0, W), rnd.uniform(0, H), rnd.uniform(0.6, 2.2), rnd.uniform(0, 6.3)) for _ in range(80)]
    tf, sf, bf = font("Black", 74), font("Medium", 28), font("Bold", 26)
    cx, cy = 255, H // 2 - 6
    for n in range(N):
        t = n / FPS
        img = base.copy()
        d = ImageDraw.Draw(img)
        for (x, y, sz, ph) in parts:
            yy = (y - t * 45 * sz) % H
            a = int(90 + 80 * math.sin(ph + t * 3))
            d.ellipse((x - sz, yy - sz, x + sz, yy + sz), fill=(160, 190, 255, a))
        # maskot: pastdan sakrab chiqadi (elastik), keyin yengil tebranadi
        e = ease((t - 0.1) / 0.7)
        bounce = math.sin(min(1, max(0, (t - 0.1) / 0.7)) * math.pi) * 0.12
        sc = max(0.01, e * (1 + bounce))
        float_y = math.sin(t * 3.2) * 6 if t > 0.9 else 0
        if e > 0:
            s = max(2, int(mc.width * sc))
            m = mc.resize((s, s), Image.LANCZOS)
            if e < 1:
                m.putalpha(m.getchannel("A").point(lambda v: int(v * min(1, e * 1.4))))
            with_glow(img, m, (int(cx - s / 2), int(cy - s / 2 + (1 - e) * 120 + float_y)), blur=36)
        # "Salom!" pufakchasi
        be = ease((t - 0.95) / 0.35)
        if be > 0:
            o = Image.new("RGBA", (W, H), (0, 0, 0, 0))
            od = ImageDraw.Draw(o)
            bx, by = 345, 105
            od.rounded_rectangle((bx, by, bx + 150, by + 56), 28, fill=(255, 255, 255, int(255 * be)))
            od.polygon([(bx + 22, by + 50), (bx + 4, by + 80), (bx + 50, by + 54)], fill=(255, 255, 255, int(255 * be)))
            od.text((bx + 75, by + 29), "Salom! 👋"[:6], font=bf, fill=(12, 40, 110, int(255 * be)), anchor="mm")
            img.alpha_composite(o)
        te = ease((t - 1.2) / 0.6)
        if te > 0:
            tx = int(470 + (1 - te) * 60)
            o = Image.new("RGBA", (W, H), (0, 0, 0, 0))
            od = ImageDraw.Draw(o)
            od.text((tx, cy - 34), "Forward Ai", font=tf, fill=(255, 255, 255, int(255 * te)), anchor="lm")
            se = ease((t - 1.7) / 0.6)
            od.text((tx + 3, cy + 40), "Aqlli yordamchingiz", font=sf, fill=(170, 185, 230, int(255 * se)), anchor="lm")
            img.alpha_composite(o)
        bb = ease((t - 0.3) / 3.0)
        for k, col in enumerate([LBLUE, DBLUE, RED]):
            x0 = k * W / 3
            d.rectangle((x0, H - 8, x0 + (W / 3) * bb, H), fill=col)
        img.convert("RGB").save(f"{fr}/{n:04d}.png")
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-framerate", str(FPS), "-i", f"{fr}/%04d.png",
                    "-c:v", "libx264", "-preset", "veryfast", "-crf", "22", "-pix_fmt", "yuv420p",
                    "-movflags", "+faststart", "-an", f"{OUT}/welcome.mp4"], check=True)
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", f"{OUT}/welcome.mp4", "-vf",
                    "fps=15,scale=480:-1:flags=lanczos,split[a][b];[a]palettegen[p];[b][p]paletteuse",
                    f"{OUT}/welcome.gif"], check=True)
    Image.open(f"{fr}/{N - 1:04d}.png").convert("RGB").save(f"{OUT}/welcome_last.jpg", quality=90)
    for f in os.listdir(fr):
        os.remove(f"{fr}/{f}")
    os.rmdir(fr)


tour_cards()
welcome()
# Mini App uchun maskot (doira, shaffof fon)
circle(MASCOT, 360, ring=False).save(f"{OUT}/mascot.png", optimize=True)
MASCOT.save(f"{OUT}/avatar_mascot.jpg", quality=95)
print("ok")
