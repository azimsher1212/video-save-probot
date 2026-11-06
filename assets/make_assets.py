"""Forward Ai brend rasmlari: avatar, tavsif rasmi, tanishuv kartalari, kirish animatsiyasi."""
import math
import os
import random
import subprocess
import sys

from PIL import Image, ImageDraw, ImageFilter, ImageFont

LOGO_SRC = sys.argv[1]
OUT = sys.argv[2]
os.makedirs(OUT, exist_ok=True)
F = "/usr/share/fonts/opentype/inter/Inter-{}.otf"
EMOJI = "/usr/share/fonts/truetype/noto/NotoColorEmoji.ttf"


def font(w, s):
    return ImageFont.truetype(F.format(w), s)


LBLUE, DBLUE, RED = (38, 140, 220), (12, 78, 150), (240, 40, 40)
NAVY = (6, 10, 28)


# ---- logo (F belgisi)ni ajratib olish, oq fonni shaffof qilish ----
def extract_mark():
    im = Image.open(LOGO_SRC).convert("RGBA")
    mark = im.crop((105, 135, 505, 365))
    px = mark.load()
    for y in range(mark.height):
        for x in range(mark.width):
            r, g, b, a = px[x, y]
            m = min(r, g, b)
            if m > 200 and max(r, g, b) - m < 30:  # oq / och kulrang
                px[x, y] = (r, g, b, 0)
            elif m > 160 and max(r, g, b) - m < 40:
                px[x, y] = (r, g, b, int(255 * (220 - m) / 60))
    return mark.crop(mark.getbbox())


MARK = extract_mark()


def bg(w, h, seed=1, glow=True):
    """Chuqur ko'k fon + ko'k/qizil nur dog'lari."""
    img = Image.new("RGB", (w, h), NAVY)
    lay = Image.new("RGB", (w, h), (0, 0, 0))
    d = ImageDraw.Draw(lay)
    rnd = random.Random(seed)
    if glow:
        for (cx, cy, r, c) in [(0.15, 0.1, 0.55, (30, 90, 230)), (0.95, 0.85, 0.5, (200, 30, 60)),
                               (0.7, 0.05, 0.35, (60, 40, 200))]:
            R = int(r * max(w, h))
            d.ellipse((cx * w - R, cy * h - R, cx * w + R, cy * h + R), fill=c)
        lay = lay.filter(ImageFilter.GaussianBlur(max(w, h) * 0.12))
        img = Image.blend(img, lay, 0.55)
    # nuqtali tekstura
    d2 = ImageDraw.Draw(img)
    for _ in range(int(w * h / 900)):
        x, y = rnd.randrange(w), rnd.randrange(h)
        v = rnd.randint(25, 70)
        d2.point((x, y), fill=(v, v, v + 20))
    return img


def paste_mark(img, cx, cy, width, glow=True):
    m = MARK.resize((width, int(MARK.height * width / MARK.width)), Image.LANCZOS)
    x, y = int(cx - m.width / 2), int(cy - m.height / 2)
    if glow:
        g = Image.new("RGBA", img.size, (0, 0, 0, 0))
        g.paste((90, 150, 255, 160), (x, y), m)
        g = g.filter(ImageFilter.GaussianBlur(width * 0.08))
        img.paste(g, (0, 0), g)
    img.paste(m, (x, y), m)
    return m


def text_c(d, xy, s, f, fill=(255, 255, 255), anchor="mm"):
    d.text(xy, s, font=f, fill=fill, anchor=anchor)


def emoji(img, xy, ch, size):
    ef = ImageFont.truetype(EMOJI, 109)
    tmp = Image.new("RGBA", (140, 140), (0, 0, 0, 0))
    ImageDraw.Draw(tmp).text((70, 70), ch, font=ef, embedded_color=True, anchor="mm")
    tmp = tmp.crop(tmp.getbbox()).resize((size, size), Image.LANCZOS)
    img.paste(tmp, (int(xy[0] - size / 2), int(xy[1] - size / 2)), tmp)


# ---------- 1. Avatar 640x640 ----------
def avatar():
    S = 640
    img = bg(S, S, 3).convert("RGBA")
    d = ImageDraw.Draw(img)
    # yorug'lik halqasi
    ring = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    rd = ImageDraw.Draw(ring)
    for i, c in enumerate([LBLUE, DBLUE, RED]):
        a0 = -90 + i * 120
        rd.arc((70, 70, S - 70, S - 70), a0 + 8, a0 + 112, fill=c + (255,), width=14)
    glow = ring.filter(ImageFilter.GaussianBlur(14))
    img.alpha_composite(glow)
    img.alpha_composite(ring)
    paste_mark(img, S / 2, S / 2 - 40, 300)
    # "AI" belgisi
    pill_w, pill_h = 150, 72
    px0, py0 = S / 2 - pill_w / 2, S / 2 + 95
    d.rounded_rectangle((px0, py0, px0 + pill_w, py0 + pill_h), 36, fill=(255, 255, 255))
    text_c(d, (S / 2, py0 + pill_h / 2 + 1), "AI", font("Black", 48), fill=NAVY)
    img.convert("RGB").save(f"{OUT}/avatar.jpg", quality=95)


# ---------- 2. Tavsif rasmi 640x360 (BotFather description picture) ----------
def description():
    W, H = 1280, 720
    img = bg(W, H, 5).convert("RGBA")
    d = ImageDraw.Draw(img)
    paste_mark(img, 330, 300, 420)
    d.text((620, 220), "Forward Ai", font=font("Black", 104), fill="white", anchor="lm")
    d.text((624, 305), "FORWARD® aqlli yordamchisi", font=font("Medium", 38), fill=(170, 185, 230), anchor="lm")
    feats = [("💬", "Savol-javob"), ("🎨", "Rasm yaratish"), ("🎙", "Ovozli xabar"),
             ("📄", "Hujjat tahlili"), ("🌐", "Tarjima"), ("🔎", "Internet")]
    for i, (e, t) in enumerate(feats):
        col, row = i % 3, i // 3
        x, y = 90 + col * 380, 520 + row * 92
        o = Image.new("RGBA", img.size, (0, 0, 0, 0))
        ImageDraw.Draw(o).rounded_rectangle((x, y, x + 350, y + 72), 36, fill=(255, 255, 255, 24), outline=(255, 255, 255, 60), width=2)
        img.alpha_composite(o)
        d = ImageDraw.Draw(img)
        emoji(img, (x + 40, y + 36), e, 40)
        d.text((x + 74, y + 36), t, font=font("SemiBold", 30), fill="white", anchor="lm")
    # pastki chiziqlar
    for i, c in enumerate([LBLUE, DBLUE, RED]):
        d.rectangle((i * W / 3, H - 10, (i + 1) * W / 3, H), fill=c)
    img.convert("RGB").resize((640, 360), Image.LANCZOS).save(f"{OUT}/description.jpg", quality=92)
    img.convert("RGB").save(f"{OUT}/description_hd.jpg", quality=92)


# ---------- 3. Tanishuv kartalari 1280x720 ----------
TOUR = [
    ("💬", "Savol bering", "Har qanday mavzuda — o'zbek, rus, ingliz tilida",
     ["Biznes uchun reklama matni yozib ber", "Bugungi dollar kursi qancha?", "Ingliz tilini qanday tez o'rgansam?"]),
    ("🎨", "Rasm yarating", "So'z bilan tasvirlang — AI chizib beradi",
     ["/img qor ostidagi Samarqand", "Kafel do'koni uchun reklama banneri", "Minimal logo, ko'k va qizil"]),
    ("🎙", "Ovoz, rasm, hujjat", "Yuboring — tushunadi va tahlil qiladi",
     ["Ovozli xabar → javob + ovozda o'qish", "PDF, Word, Excel → xulosa", "Video, YouTube havola → mazmuni"]),
    ("🚀", "Ilova va Premium", "Open tugmasi — Telegram ichidagi ilova",
     ["Chat, rasm studiyasi, galereya", "Kuniga 30 ta bepul so'rov", "Premium — cheksiz foydalanish"]),
]


def tour():
    W, H = 1280, 720
    for i, (e, title, sub, items) in enumerate(TOUR):
        img = bg(W, H, 10 + i).convert("RGBA")
        d = ImageDraw.Draw(img)
        # yuqori: logo + qadam
        m = MARK.resize((90, int(MARK.height * 90 / MARK.width)), Image.LANCZOS)
        img.paste(m, (70, 58), m)
        d.text((180, 82), "Forward Ai", font=font("Bold", 34), fill="white", anchor="lm")
        o = Image.new("RGBA", img.size, (0, 0, 0, 0))
        od = ImageDraw.Draw(o)
        for k in range(4):
            x = W - 70 - (3 - k) * 56
            od.rounded_rectangle((x - 34 if k == i else x - 10, 74, x + 10, 94), 10,
                                 fill=(255, 255, 255, 255) if k == i else (255, 255, 255, 70))
        # katta emoji doira
        cx, cy = 250, 400
        ring = Image.new("RGBA", (W, H), (0, 0, 0, 0))
        rd = ImageDraw.Draw(ring)
        rd.ellipse((cx - 150, cy - 150, cx + 150, cy + 150), fill=(60, 110, 255, 90))
        ring = ring.filter(ImageFilter.GaussianBlur(40))
        img.alpha_composite(ring)
        od.ellipse((cx - 125, cy - 125, cx + 125, cy + 125), fill=(255, 255, 255, 22), outline=(255, 255, 255, 70), width=3)
        for j in range(len(items)):
            y = 450 + j * 72
            od.rounded_rectangle((470, y, 1210, y + 58), 29, fill=(255, 255, 255, 22))
        img.alpha_composite(o)
        d = ImageDraw.Draw(img)
        emoji(img, (cx, cy), e, 150)
        # matn
        d.text((470, 250), f"{i + 1}/4", font=font("Bold", 30), fill=(120, 160, 255), anchor="lm")
        d.text((470, 312), title, font=font("Black", 72), fill="white", anchor="lm")
        d.text((472, 378), sub, font=font("Medium", 30), fill=(170, 185, 230), anchor="lm")
        for j, it in enumerate(items):
            y = 450 + j * 72
            d.ellipse((492, y + 21, 508, y + 37), fill=[LBLUE, DBLUE, RED][j])
            d.text((528, y + 29), it, font=font("SemiBold", 28), fill="white", anchor="lm")
        for k, c in enumerate([LBLUE, DBLUE, RED]):
            d.rectangle((k * W / 3, H - 8, (k + 1) * W / 3, H), fill=c)
        img.convert("RGB").save(f"{OUT}/tour{i + 1}.jpg", quality=90)


# ---------- 4. Kirish animatsiyasi (MP4, 3.6 s) ----------
def ease(t):
    t = max(0.0, min(1.0, t))
    return 1 - (1 - t) ** 3


def welcome_anim():
    W, H, FPS, N = 960, 540, 30, 108
    base = bg(W, H, 21).convert("RGBA")
    # belgini 3 chiziqqa bo'lamiz: ustunlar bo'yicha rang bilan
    m = MARK.resize((330, int(MARK.height * 330 / MARK.width)), Image.LANCZOS)
    mw, mh = m.size
    px = m.load()
    parts = [Image.new("RGBA", m.size, (0, 0, 0, 0)) for _ in range(3)]
    pp = [p.load() for p in parts]
    for y in range(mh):
        for x in range(mw):
            r, g, b, a = px[x, y]
            if a < 10:
                continue
            k = 2 if r > 150 and g < 120 else (0 if b > 180 and r < 120 and g > 110 else 1)
            pp[k][x, y] = (r, g, b, a)
    fr = f"{OUT}/_frames"
    os.makedirs(fr, exist_ok=True)
    rnd = random.Random(4)
    parts_xy = [(rnd.uniform(0, W), rnd.uniform(0, H), rnd.uniform(0.5, 2.2), rnd.uniform(0, 6.28)) for _ in range(70)]
    title_f, sub_f = font("Black", 76), font("Medium", 28)
    for n in range(N):
        t = n / FPS
        img = base.copy()
        d = ImageDraw.Draw(img)
        # suzuvchi zarrachalar
        for (x, y, s, ph) in parts_xy:
            yy = (y - t * 40 * s) % H
            a = int(90 + 80 * math.sin(ph + t * 3))
            d.ellipse((x - s, yy - s, x + s, yy + s), fill=(160, 190, 255, a))
        cx = 250
        cy = H / 2 - 20
        # chiziqlar ketma-ket chapdan uchib kiradi
        for k in range(3):
            e = ease((t - 0.15 - k * 0.18) / 0.55)
            if e <= 0:
                continue
            off = int((1 - e) * -420)
            layer = parts[k].copy()
            if e < 1:
                al = layer.getchannel("A").point(lambda v: int(v * e))
                layer.putalpha(al)
            img.alpha_composite(layer, (int(cx - mw / 2 + off), int(cy - mh / 2)))
        # nur chaqnashi
        fl = ease((t - 1.15) / 0.35) * (1 - ease((t - 1.5) / 0.6))
        if fl > 0:
            g = Image.new("RGBA", (W, H), (0, 0, 0, 0))
            gd = ImageDraw.Draw(g)
            R = 260
            gd.ellipse((cx - R, cy - R, cx + R, cy + R), fill=(120, 170, 255, int(120 * fl)))
            img.alpha_composite(g.filter(ImageFilter.GaussianBlur(60)))
        # matn
        te = ease((t - 1.3) / 0.6)
        if te > 0:
            tx = int(455 + (1 - te) * 60)
            layer = Image.new("RGBA", (W, H), (0, 0, 0, 0))
            ld = ImageDraw.Draw(layer)
            ld.text((tx, cy - 30), "Forward Ai", font=title_f, fill=(255, 255, 255, int(255 * te)), anchor="lm")
            se = ease((t - 1.8) / 0.6)
            ld.text((tx + 3, cy + 45), "Aqlli yordamchingiz", font=sub_f, fill=(170, 185, 230, int(255 * se)), anchor="lm")
            img.alpha_composite(layer)
        # pastki rangli chiziq to'ladi
        be = ease((t - 0.3) / 2.6)
        for k, c in enumerate([LBLUE, DBLUE, RED]):
            x0 = k * W / 3
            d.rectangle((x0, H - 8, x0 + (W / 3) * be, H), fill=c)
        img.convert("RGB").save(f"{fr}/{n:04d}.png")
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-framerate", str(FPS), "-i", f"{fr}/%04d.png",
                    "-c:v", "libx264", "-preset", "veryfast", "-crf", "23", "-pix_fmt", "yuv420p",
                    "-movflags", "+faststart", "-an", f"{OUT}/welcome.mp4"], check=True)
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", f"{OUT}/welcome.mp4", "-vf",
                    "fps=15,scale=480:-1:flags=lanczos,split[a][b];[a]palettegen[p];[b][p]paletteuse",
                    f"{OUT}/welcome.gif"], check=True)
    Image.open(f"{fr}/{N - 1:04d}.png").convert("RGB").save(f"{OUT}/welcome_last.jpg", quality=90)
    for f in os.listdir(fr):
        os.remove(f"{fr}/{f}")
    os.rmdir(fr)


avatar()
description()
tour()
welcome_anim()
print("ok", sorted(os.listdir(OUT)))
