"""FORWARD AI — Telegram bot + Google Gemini (bepul).

Imkoniyatlar: chat (rejimlar), internetdan qidiruv, rasm tahlili, rasm yaratish,
ovozli xabar, ovozda javob, hujjat (PDF/DOCX/XLSX/TXT), video, YouTube xulosasi,
guruh moderatsiyasi, kunlik limit, Telegram Stars premium, admin buyruqlari.
"""
import asyncio
import html
import time
from contextlib import asynccontextmanager
import base64
import pathlib
import io
import logging
import os
import re
import urllib.parse
import wave
from collections import defaultdict, deque

import aiohttp
from aiogram import Bot, Dispatcher, F
from aiogram.enums import ChatType
from aiogram.filters import Command, CommandObject, CommandStart
from aiogram.types import (BufferedInputFile, CallbackQuery, InlineKeyboardButton,
                           InlineKeyboardMarkup, KeyboardButton, LabeledPrice, Message,
                           PreCheckoutQuery, ReplyKeyboardMarkup)
from aiogram.exceptions import TelegramBadRequest
from aiogram.types import ErrorEvent, FSInputFile, InputMediaPhoto, MenuButtonWebApp, WebAppInfo
from aiogram.utils.web_app import safe_parse_webapp_init_data
from aiogram.webhook.aiohttp_server import SimpleRequestHandler, setup_application
from aiohttp import web
from google import genai
from google.genai import types

logging.basicConfig(level=logging.INFO)
log = logging.getLogger("forward-ai")

# ---------- Sozlamalar ----------
BOT_TOKEN = os.environ["BOT_TOKEN"]
GEMINI_API_KEY = os.environ["GEMINI_API_KEY"]
CHAT_MODEL = os.getenv("CHAT_MODEL", "gemini-3.8-flash")
TTS_MODEL = os.getenv("TTS_MODEL", "gemini-3.8-flash-lite-tts")
FAST_MODEL = os.getenv("FAST_MODEL", "gemini-3.5-flash-lite")  # tarjima, moderatsiya va zaxira uchun
# Ishga tushganda qaysi model ishlashini tekshirib, birinchi ishlaganini tanlaymiz
CHAT_CANDIDATES = [CHAT_MODEL, "gemini-3.8-flash", "gemini-3.6-flash", "gemini-3.5-flash", "gemini-3.5-flash-lite", "gemini-3-flash-preview"]
FAST_CANDIDATES = [FAST_MODEL, "gemini-3.5-flash-lite", "gemini-3.1-flash-lite", "gemini-3.8-flash"]
TTS_CANDIDATES = [TTS_MODEL, "gemini-3.8-flash-lite-tts", "gemini-3.8-flash-tts", "gemini-3.1-flash-tts-preview"]
SELFTEST_KEY = os.getenv("SELFTEST_KEY", "")
ASSETS = pathlib.Path(__file__).with_name("assets")
SUPABASE_URL = os.getenv("SUPABASE_URL", "")
SUPABASE_KEY = os.getenv("SUPABASE_KEY", "")
DB_SECRET = os.getenv("DB_SECRET", "")
ADMIN_USERNAMES = {u.strip().lstrip("@").lower() for u in os.getenv("ADMIN_USERNAMES", "Forward_admin1").split(",") if u.strip()}
ADMIN_CONTACT = os.getenv("ADMIN_CONTACT", "@Forward_admin1")
FREE_LIMIT = int(os.getenv("FREE_LIMIT", "30"))
PREMIUM_STARS = int(os.getenv("PREMIUM_STARS", "100"))
PREMIUM_DAYS = int(os.getenv("PREMIUM_DAYS", "30"))
REQUIRED_CHANNEL = os.getenv("REQUIRED_CHANNEL", "")  # masalan @forwardtowardsdreams (bot kanalda admin bo'lishi kerak)
AI_MODERATION = os.getenv("AI_MODERATION", "0") == "1"
BAD_WORDS = {w.strip() for w in os.getenv("BAD_WORDS", "").lower().split(",") if w.strip()}
PORT = int(os.getenv("PORT", "10000"))
BASE_URL = os.getenv("RENDER_EXTERNAL_URL", "")
WEBHOOK_SECRET = re.sub(r"[^A-Za-z0-9]", "", BOT_TOKEN)[-32:]

BASE_PROMPT = ("Sen FORWARD AI — FORWARD® brendining aqlli yordamchisisan. Foydalanuvchi qaysi tilda "
               "yozsa, o'sha tilda (asosan o'zbek lotin) javob ber. Javoblar aniq va foydali bo'lsin. "
               "Telegram uchun yoz: **qalin** va ro'yxatlar mumkin, jadval va # sarlavha ishlatma. "
               "Keraksiz uzun kirish so'zlarisiz, to'g'ridan-to'g'ri javob ber.")
MODES = {
    "assistant": ("🤖 Yordamchi", "Har qanday savolga yordam ber."),
    "search": ("🔎 Internet", "Internetdan eng so'nggi ma'lumotni qidirib, manbalar bilan javob ber."),
    "image": ("🎨 Rasm yaratish", ""),
    "translate": ("🌐 Tarjimon", "Sen tarjimonsan. Matn o'zbekcha bo'lsa ingliz va rus tiliga, boshqa tilda bo'lsa o'zbekchaga tarjima qil. Faqat tarjimani yoz."),
    "business": ("💼 Biznes", "Sen biznes maslahatchisisan: reklama matni, Instagram/Telegram post, savdo skripti, biznes reja, narx hisob-kitobi, mijozga javob yozib berasan. O'zbekiston bozorini hisobga ol."),
    "creative": ("✍️ Kreativ", "Sen ijodkorsan: she'r, hikoya, tabrik, slogan, ssenariy yozasan."),
    "coder": ("💻 Dasturchi", "Sen tajribali dasturchisan. Kod yoz, xatolarni tushuntir va tuzat."),
    "teacher": ("📚 O'qituvchi", "Sen sabrli o'qituvchisan. Mavzuni oddiy tilda, misollar bilan tushuntir, oxirida 1-2 savol ber."),
}
BTN_TO_MODE = {v[0]: k for k, v in MODES.items()}
BTN_PREMIUM, BTN_PROFILE, BTN_HELP = "⭐ Premium", "👤 Profil", "ℹ️ Yordam"

MENU = ReplyKeyboardMarkup(resize_keyboard=True, keyboard=[
    [KeyboardButton(text=MODES["assistant"][0]), KeyboardButton(text=MODES["search"][0])],
    [KeyboardButton(text=MODES["image"][0]), KeyboardButton(text=MODES["translate"][0])],
    [KeyboardButton(text=MODES["business"][0]), KeyboardButton(text=MODES["creative"][0])],
    [KeyboardButton(text=MODES["coder"][0]), KeyboardButton(text=MODES["teacher"][0])],
    [KeyboardButton(text=BTN_PREMIUM), KeyboardButton(text=BTN_PROFILE), KeyboardButton(text=BTN_HELP)],
])
TTS_KB = InlineKeyboardMarkup(inline_keyboard=[[InlineKeyboardButton(text="🔊 Ovozda eshitish", callback_data="tts")]])

LINK_RE = re.compile(r"(https?://|t\.me/|www\.|@\w+bot\b)", re.I)
ARABIC_RE = re.compile(r"[؀-ۿ]")
YT_RE = re.compile(r"https?://(www\.)?(youtube\.com/(watch\?v=|shorts/)|youtu\.be/)[\w\-]+[^\s]*")

bot = Bot(BOT_TOKEN)
dp = Dispatcher()
ai = genai.Client(api_key=GEMINI_API_KEY)
http: aiohttp.ClientSession | None = None

history: dict[int, deque] = defaultdict(lambda: deque(maxlen=12))
last_answer: dict[int, str] = {}
local_users: dict[int, dict] = {}  # Supabase bo'lmasa vaqtinchalik xotira


# ---------- Ma'lumotlar bazasi (Supabase RPC) ----------
async def rpc(fn: str, **params):
    if not (SUPABASE_URL and SUPABASE_KEY and DB_SECRET):
        return None
    async with http.post(
        f"{SUPABASE_URL}/rest/v1/rpc/{fn}",
        json={"p_secret": DB_SECRET, **params},
        headers={"apikey": SUPABASE_KEY, "Authorization": f"Bearer {SUPABASE_KEY}"},
        timeout=aiohttp.ClientTimeout(total=15),
    ) as r:
        if r.status >= 300:
            log.warning("rpc %s %s %s", fn, r.status, await r.text())
            return None
        return await r.json()


async def get_user(m_user) -> dict:
    name = getattr(m_user, "full_name", None) or " ".join(filter(None, [m_user.first_name, getattr(m_user, "last_name", None)]))
    u = await rpc("fai_touch", p_id=m_user.id, p_username=m_user.username or "", p_name=name)
    if u is None:
        u = local_users.setdefault(m_user.id, {"id": m_user.id, "mode": "assistant", "banned": False,
                                               "used_today": 0, "premium": False, "premium_until": None})
    return u


async def use_quota(user_id: int):
    n = await rpc("fai_use", p_id=user_id)
    if n is None and user_id in local_users:
        local_users[user_id]["used_today"] += 1


async def set_mode(user_id: int, mode: str):
    if await rpc("fai_set_mode", p_id=user_id, p_mode=mode) is None and user_id in local_users:
        local_users[user_id]["mode"] = mode


def is_admin_user(u) -> bool:
    return (u.username or "").lower() in ADMIN_USERNAMES


# ---------- Yordamchi funksiyalar ----------
def is_group(m: Message) -> bool:
    return m.chat.type in (ChatType.GROUP, ChatType.SUPERGROUP)


async def addressed_to_bot(m: Message) -> bool:
    if not is_group(m):
        return True
    me = await bot.me()
    text = (m.text or m.caption or "").lower()
    if f"@{me.username}".lower() in text:
        return True
    return bool(m.reply_to_message and m.reply_to_message.from_user
                and m.reply_to_message.from_user.id == me.id)


async def download(file_id: str) -> bytes:
    f = await bot.get_file(file_id)
    buf = io.BytesIO()
    await bot.download_file(f.file_path, buf)
    return buf.getvalue()


def md_to_html(t: str) -> str:
    """Gemini markdown'ini Telegram HTML'ga aylantiradi."""
    blocks = re.split(r"(```[\s\S]*?```)", t)
    out = []
    for b in blocks:
        if b.startswith("```") and b.endswith("```") and len(b) >= 6:
            code = re.sub(r"^```[\w+-]*\n?", "", b)[:-3]
            out.append(f"<pre>{html.escape(code.strip())}</pre>")
            continue
        b = html.escape(b, quote=False)
        b = re.sub(r"`([^`\n]+)`", r"<code>\1</code>", b)
        b = re.sub(r"\*\*([^*\n]+?)\*\*", r"<b>\1</b>", b)
        b = re.sub(r"(?m)^#{1,6}\s*(.+)$", r"<b>\1</b>", b)
        b = re.sub(r"(?m)^(\s*)[*\-]\s+", r"\1• ", b)
        b = re.sub(r"(?<![*\w])\*([^*\n]+?)\*(?![*\w])", r"<i>\1</i>", b)
        out.append(b)
    return "".join(out)


def split_text(text: str, n: int = 3500) -> list[str]:
    parts, cur = [], ""
    for para in text.split("\n"):
        while len(para) > n:
            if cur:
                parts.append(cur)
                cur = ""
            parts.append(para[:n])
            para = para[n:]
        if cur and len(cur) + len(para) + 1 > n:
            parts.append(cur)
            cur = para
        else:
            cur = f"{cur}\n{para}" if cur else para
    if cur:
        parts.append(cur)
    fixed, carry = [], False  # ``` bloklari bo'linib ketmasligi uchun
    for p in parts:
        if carry:
            p = "```\n" + p
        carry = p.count("```") % 2 == 1
        fixed.append(p + ("\n```" if carry else ""))
    return fixed or ["..."]


async def send_long(m: Message, text: str, tts: bool = True):
    chunks = split_text(text)
    for i, c in enumerate(chunks):
        kb = TTS_KB if (tts and i == len(chunks) - 1 and not is_group(m)) else None
        try:
            await m.answer(md_to_html(c), parse_mode="HTML", reply_markup=kb, disable_web_page_preview=True)
        except TelegramBadRequest:
            await m.answer(c, reply_markup=kb, disable_web_page_preview=True)


@asynccontextmanager
async def busy(chat_id: int, action: str = "typing"):
    """Javob tayyorlanguncha 'yozmoqda...' holatini ushlab turadi."""
    async def loop():
        while True:
            try:
                await bot.send_chat_action(chat_id, action)
            except Exception:
                pass
            await asyncio.sleep(4.5)
    task = asyncio.create_task(loop())
    try:
        yield
    finally:
        task.cancel()


async def check_access(m: Message) -> dict | None:
    """Ban, kanalga obuna va kunlik limitni tekshiradi. Ruxsat bo'lsa user qaytaradi."""
    u = await get_user(m.from_user)
    if u.get("banned"):
        await m.answer("⛔ Siz bloklangansiz. Admin: " + ADMIN_CONTACT)
        return None
    if REQUIRED_CHANNEL and not is_group(m):
        try:
            mem = await bot.get_chat_member(REQUIRED_CHANNEL, m.from_user.id)
            if mem.status in ("left", "kicked"):
                kb = InlineKeyboardMarkup(inline_keyboard=[[InlineKeyboardButton(
                    text="📢 Obuna bo'lish", url=f"https://t.me/{REQUIRED_CHANNEL.lstrip('@')}")]])
                await m.answer(f"Botdan foydalanish uchun {REQUIRED_CHANNEL} kanaliga obuna bo'ling.", reply_markup=kb)
                return None
        except Exception as e:
            log.warning("channel check: %s", e)
    if not u.get("premium") and not is_admin_user(m.from_user) and u.get("used_today", 0) >= FREE_LIMIT:
        await m.answer(f"⏳ Bugungi bepul limit ({FREE_LIMIT} ta so'rov) tugadi.\n"
                       f"Ertaga yana davom eting yoki ⭐ Premium oling — cheksiz foydalanish.")
        return None
    return u


def thinking(level: str):
    return types.ThinkingConfig(thinking_level=level) if THINKING_OK else None


THINKING_OK = True


def _retryable(e: Exception) -> bool:
    s = str(e)
    return isinstance(e, asyncio.TimeoutError) or any(k in s for k in (
        "429", "500", "502", "503", "504", "RESOURCE_EXHAUSTED", "UNAVAILABLE", "overloaded", "DEADLINE"))


async def gemini(contents, config=None, model: str | None = None, timeout: float = 75):
    """Gemini'ni chaqiradi: xato bo'lsa bir marta qayta, keyin tezkor zaxira model bilan urinadi."""
    models = [model or CHAT_MODEL]
    if FAST_MODEL not in models:
        models.append(FAST_MODEL)
    last = None
    for i, mdl in enumerate(models):
        for attempt in range(2 if i == 0 else 1):
            try:
                return await asyncio.wait_for(
                    ai.aio.models.generate_content(model=mdl, contents=contents, config=config), timeout)
            except Exception as e:
                last = e
                log.warning("gemini %s (%s): %s", mdl, attempt, str(e)[:200])
                if "NOT_FOUND" in str(e) or "404" in str(e):
                    break  # bu model yo'q — keyingisiga o'tamiz
                if not _retryable(e):
                    raise
                await asyncio.sleep(1.2)
    raise last


def resp_text(resp) -> str:
    try:
        t = resp.text
    except Exception:
        t = None
    if t and t.strip():
        return t.strip()
    reason = ""
    try:
        reason = str(resp.candidates[0].finish_reason)
    except Exception:
        pass
    if "SAFETY" in reason or "PROHIBITED" in reason:
        return "Kechirasiz, bu so'rovga javob bera olmayman. Boshqacha so'rab ko'ring."
    return "Javob olinmadi, savolni boshqacharoq yozib ko'ring."


async def ask_ai(chat_id: int, parts: list, mode: str = "assistant", hist: list | None = None) -> str:
    parts = [types.Part.from_text(text=p) if isinstance(p, str) else p for p in parts]
    base = hist if hist is not None else list(history[chat_id])
    contents = base + [types.Content(role="user", parts=parts)]
    heavy = any(getattr(p, "inline_data", None) or getattr(p, "file_data", None) for p in parts)
    config = types.GenerateContentConfig(
        system_instruction=BASE_PROMPT + " " + MODES.get(mode, MODES["assistant"])[1],
        thinking_config=thinking("medium" if mode == "coder" else "low"),
        max_output_tokens=4096,
    )
    global GROUNDING_BLOCK_UNTIL
    use_grounding = mode == "search" and time.time() > GROUNDING_BLOCK_UNTIL
    if use_grounding:
        config.tools = [types.Tool(google_search=types.GoogleSearch())]
    try:
        if mode == "search" and not use_grounding:
            raise RuntimeError("grounding o'chirilgan")
        resp = await gemini(contents, config, timeout=150 if heavy else 75)
    except Exception as e:
        if mode != "search":
            raise
        if "429" in str(e) or "RESOURCE_EXHAUSTED" in str(e):
            GROUNDING_BLOCK_UNTIL = time.time() + 3600
        # Google qidiruv ishlamasa — bepul jonli manbalar bilan javob beramiz
        query = " ".join(p.text for p in parts if p.text)[:300]
        found = await live_context(query)
        config.tools = None
        extra = (f"Quyida internetdan topilgan natijalar ({time.strftime('%Y-%m-%d')}). Shularga tayanib javob ber, "
                 f"oxirida 1-3 manba havolasini yoz:\n\n{found}") if found else \
            "Internetga ulanib bo'lmadi. Bilganingcha javob ber va ma'lumot eskirgan bo'lishi mumkinligini ayt."
        contents[-1] = types.Content(role="user", parts=parts + [types.Part.from_text(text=extra)])
        resp = await gemini(contents, config, timeout=75)
    answer = resp_text(resp)
    if hist is not None:
        return answer
    user_text = " ".join(p.text for p in parts if p.text) or "[media]"
    history[chat_id].append(types.Content(role="user", parts=[types.Part.from_text(text=user_text[:3000])]))
    history[chat_id].append(types.Content(role="model", parts=[types.Part.from_text(text=answer[:3000])]))
    last_answer[chat_id] = answer
    return answer


UZ_CITIES = {"toshkent": "Tashkent", "samarqand": "Samarkand", "buxoro": "Bukhara", "andijon": "Andijan",
             "farg'ona": "Fergana", "fargona": "Fergana", "namangan": "Namangan", "qarshi": "Karshi",
             "nukus": "Nukus", "xiva": "Khiva", "urganch": "Urgench", "jizzax": "Jizzakh", "termiz": "Termez",
             "navoiy": "Navoi", "guliston": "Gulistan", "qo'qon": "Kokand", "chirchiq": "Chirchiq",
             "moskva": "Moscow", "dubay": "Dubai", "istanbul": "Istanbul", "seul": "Seoul", "pekin": "Beijing",
             "guanchjou": "Guangzhou", "yiwu": "Yiwu", "urumchi": "Urumqi"}
WMO = {0: "ochiq osmon", 1: "asosan ochiq", 2: "qisman bulutli", 3: "bulutli", 45: "tuman", 48: "tuman",
       51: "mayda yomg'ir", 53: "mayda yomg'ir", 55: "mayda yomg'ir", 61: "yomg'ir", 63: "yomg'ir",
       65: "kuchli yomg'ir", 71: "qor", 73: "qor", 75: "kuchli qor", 80: "jala", 81: "jala", 82: "kuchli jala",
       95: "momaqaldiroq", 96: "do'l bilan momaqaldiroq", 99: "do'l bilan momaqaldiroq"}


async def _get_json(url: str, timeout: float = 10):
    async with http.get(url, timeout=aiohttp.ClientTimeout(total=timeout),
                        headers={"User-Agent": "ForwardAi/1.0 (+https://t.me/ForwardAi_assistent_Bot)"}) as r:
        return await r.json(content_type=None)


async def cbu_rates() -> str:
    data = await _get_json("https://cbu.uz/uz/arkhiv-kursov-valyut/json/")
    want = {"USD", "EUR", "RUB", "CNY", "KZT", "TRY", "GBP", "AED", "KRW"}
    rows = [f"1 {d['Ccy']} = {d['Rate']} so'm ({'+' if not str(d.get('Diff', '')).startswith('-') else ''}{d.get('Diff')})"
            for d in data if d.get("Ccy") in want]
    return f"O'zbekiston Markaziy banki rasmiy kursi ({data[0].get('Date')}):\n" + "\n".join(rows) + " (manba: cbu.uz)"


async def weather(query: str) -> str:
    low = query.lower()
    city = next((v for k, v in UZ_CITIES.items() if k in low), "Tashkent")
    g = await _get_json(f"https://geocoding-api.open-meteo.com/v1/search?name={urllib.parse.quote(city)}&count=1")
    p = g["results"][0]
    w = await _get_json(
        f"https://api.open-meteo.com/v1/forecast?latitude={p['latitude']}&longitude={p['longitude']}"
        "&current=temperature_2m,apparent_temperature,weather_code,wind_speed_10m,relative_humidity_2m"
        "&daily=weather_code,temperature_2m_max,temperature_2m_min,precipitation_probability_max&timezone=auto&forecast_days=3")
    c, d = w["current"], w["daily"]
    lines = [f"{p['name']} ob-havosi (hozir, {c['time']}): {c['temperature_2m']}°C, his qilinishi {c['apparent_temperature']}°C, "
             f"{WMO.get(c['weather_code'], '')}, shamol {c['wind_speed_10m']} km/soat, namlik {c['relative_humidity_2m']}%"]
    for i in range(len(d["time"])):
        lines.append(f"{d['time'][i]}: {d['temperature_2m_min'][i]}…{d['temperature_2m_max'][i]}°C, "
                     f"{WMO.get(d['weather_code'][i], '')}, yog'ingarchilik ehtimoli {d['precipitation_probability_max'][i]}%")
    return "\n".join(lines) + " (manba: open-meteo.com)"


async def wiki(query: str) -> str:
    out = []
    for lang in ("uz", "en"):
        try:
            j = await _get_json(f"https://{lang}.wikipedia.org/w/api.php?action=query&list=search&format=json&srlimit=2"
                                f"&srsearch={urllib.parse.quote(query[:200])}")
            for h in j.get("query", {}).get("search", []):
                snip = html.unescape(re.sub(r"<[^>]+>", "", h.get("snippet", "")))
                out.append(f"Vikipediya ({lang}): {h['title']} — {snip} "
                           f"(https://{lang}.wikipedia.org/wiki/{urllib.parse.quote(h['title'].replace(' ', '_'))})")
        except Exception as e:
            log.info("wiki %s: %s", lang, e)
    return "\n".join(out)


async def live_context(query: str) -> str:
    """So'rovga mos jonli ma'lumotlar: valyuta kursi, ob-havo, Vikipediya, DuckDuckGo."""
    low = query.lower()
    jobs = []
    if re.search(r"kurs|dollar|valyut|yevro|evro|euro|rubl|yuan|so'm|курс|доллар", low):
        jobs.append(cbu_rates())
    if re.search(r"ob-?havo|havo|harorat|yomg'ir|qor |weather|погод", low):
        jobs.append(weather(query))
    jobs += [web_search(query), wiki(query)]
    res = await asyncio.gather(*jobs, return_exceptions=True)
    parts = [r for r in res if isinstance(r, str) and r.strip()]
    for r in res:
        if isinstance(r, Exception):
            log.info("live_context: %s", r)
    return "\n\n".join(parts)


GROUNDING_BLOCK_UNTIL = 0.0


async def web_search(query: str, n: int = 6) -> str:
    """DuckDuckGo (bepul, kalitsiz) natijalari: sarlavha, qisqa matn, havola."""
    try:
        async with http.get("https://html.duckduckgo.com/html/", params={"q": query, "kl": "wt-wt"},
                            headers={"User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 "
                                                   "(KHTML, like Gecko) Chrome/130.0 Safari/537.36",
                                     "Accept-Language": "uz,ru;q=0.8,en;q=0.6"},
                            timeout=aiohttp.ClientTimeout(total=12)) as r:
            page = await r.text()
        links = re.findall(r'class="result__a"[^>]*href="([^"]+)"[^>]*>(.*?)</a>', page, re.S)
        links = [(urllib.parse.unquote(re.sub(r"^.*?uddg=([^&]+).*$", r"\1", u)), t) for u, t in links]
        snips = re.findall(r'class="result__snippet"[^>]*>(.*?)</a>', page, re.S)
        out = []
        for i, (u, t) in enumerate(links[:n]):
            clean = lambda x: html.unescape(re.sub(r"<[^>]+>", "", x)).strip()  # noqa: E731
            out.append(f"{i + 1}. {clean(t)} — {clean(snips[i]) if i < len(snips) else ''} ({u})")
        return "\n".join(out)
    except Exception as e:
        log.warning("web_search: %s", e)
        return ""


def friendly_error(e: Exception) -> str:
    s = str(e)
    if "429" in s or "RESOURCE_EXHAUSTED" in s:
        return "⏳ Hozir so'rovlar juda ko'p. 1 daqiqadan keyin qayta yuboring."
    if isinstance(e, asyncio.TimeoutError) or "DEADLINE" in s:
        return "⌛ Javob juda uzoq tayyorlandi. Savolni qisqaroq qilib qayta yuboring."
    if "INVALID_ARGUMENT" in s or "400" in s:
        return "Bu faylni o'qib bo'lmadi. Boshqa formatda yoki kichikroq qilib yuboring."
    return "⚠️ Kutilmagan xatolik. Qayta urinib ko'ring."


async def run_ai(m: Message, parts: list, mode: str):
    try:
        async with busy(m.chat.id):
            answer = await ask_ai(m.chat.id, parts, mode)
        await use_quota(m.from_user.id)
        await send_long(m, answer)
    except Exception as e:
        log.exception(e)
        await m.answer(friendly_error(e))


# ---------- Rasm yaratish (Pollinations — bepul) ----------
async def image_url(prompt: str, style: str = "", w: int = 1024, h: int = 1024) -> str:
    try:
        tr = await gemini(
            f"Translate this image description to a detailed English image prompt (max 60 words). Output only the prompt:\n{prompt}",
            None, model=FAST_MODEL, timeout=20)
        en = (tr.text or prompt).strip()
    except Exception:
        en = prompt
    if style:
        en += ", " + style
    seed = int.from_bytes(os.urandom(3), "big")
    return IMG_PROVIDERS[IMG_PROVIDER].format(p=urllib.parse.quote(en[:900]), w=w, h=h, seed=seed)


# Bepul rasm manbalari — qaysi biri ishlasa, o'shani ishlatamiz
IMG_PROVIDERS = [
    "https://image.pollinations.ai/prompt/{p}?width={w}&height={h}&nologo=true&seed={seed}",
    "https://image.pollinations.ai/prompt/{p}?width={w}&height={h}&nologo=true&model=turbo&seed={seed}",
    "https://image.pollinations.ai/prompt/{p}?width={w}&height={h}&nologo=true&model=flux&seed={seed}",
    "https://gen.pollinations.ai/image/{p}?width={w}&height={h}&nologo=true&seed={seed}",
]
IMG_PROVIDER = 0
IMG_OK = True
POLLINATIONS_KEY = os.getenv("POLLINATIONS_KEY", "")


def img_headers() -> dict:
    return {"Authorization": f"Bearer {POLLINATIONS_KEY}"} if POLLINATIONS_KEY else {}


async def pick_image_provider():
    global IMG_PROVIDER, IMG_OK
    for i, tpl in enumerate(IMG_PROVIDERS):
        url = tpl.format(p=urllib.parse.quote("red apple on a wooden table"), w=512, h=512, seed=42)
        try:
            async with http.get(url, timeout=aiohttp.ClientTimeout(total=60), headers=img_headers()) as r:
                ok = r.status == 200 and r.headers.get("content-type", "").startswith("image/")
                body = "" if ok else (await r.text())[:200]
                log.info("image provider %s: %s %s %s", i, r.status, r.headers.get("content-type"), body)
                if ok:
                    IMG_PROVIDER, IMG_OK = i, True
                    return
        except Exception as e:
            log.info("image provider %s: %s", i, e)
    IMG_OK = False


async def fetch_image(url: str) -> bytes:
    last = None
    for attempt in range(3):
        try:
            if attempt == 0:
                u = url
            else:  # boshqa manba bilan qayta urinish
                q = re.search(r"/(?:prompt|image)/([^?]+)", url)
                wh = re.search(r"width=(\d+)&height=(\d+)", url)
                tpl = IMG_PROVIDERS[(IMG_PROVIDER + attempt) % len(IMG_PROVIDERS)]
                u = tpl.format(p=q.group(1) if q else "art", w=wh.group(1) if wh else 1024,
                               h=wh.group(2) if wh else 1024, seed=int.from_bytes(os.urandom(3), "big"))
            async with http.get(u, timeout=aiohttp.ClientTimeout(total=90), headers=img_headers()) as r:
                if r.status == 200 and r.headers.get("content-type", "").startswith("image/"):
                    return await r.read()
                last = RuntimeError(f"status {r.status}")
        except Exception as e:
            last = e
        await asyncio.sleep(1)
    raise last


def redraw_kb() -> InlineKeyboardMarkup:
    return InlineKeyboardMarkup(inline_keyboard=[[InlineKeyboardButton(text="🔁 Yana chizish", callback_data="redraw")]])


last_prompt: dict[int, str] = {}


IMG_OFF_TEXT = ("🎨 Rasm chizish xizmati hozir texnik sozlanmoqda va tez orada ishga tushadi.\n"
                "Bu vaqtda rasm yuborsangiz — tahlil qilib beraman, yoki rasm uchun batafsil prompt yozib beraman.")


async def generate_image(m: Message, prompt: str, user_id: int | None = None):
    if not IMG_OK:
        return await m.answer(IMG_OFF_TEXT)
    note = await m.answer("🎨 Chizilmoqda... (10–30 soniya)")
    try:
        async with busy(m.chat.id, "upload_photo"):
            url = await image_url(prompt)
            data = await fetch_image(url)
        last_prompt[m.chat.id] = prompt
        await m.answer_photo(BufferedInputFile(data, "forward-ai.jpg"), caption=f"🎨 {prompt[:900]}",
                             reply_markup=redraw_kb())
        await use_quota(user_id or m.from_user.id)
    except Exception as e:
        log.warning("image gen: %s", e)
        await m.answer("Rasm xizmati hozir band. 1 daqiqadan keyin qayta urinib ko'ring.")
    finally:
        try:
            await note.delete()
        except Exception:
            pass


# ---------- Guruh moderatsiyasi ----------
async def violates(text: str) -> str | None:
    low = text.lower()
    if LINK_RE.search(text):
        return "reklama/havola"
    if ARABIC_RE.search(text):
        return "arabcha xabar"
    if any(w in low for w in BAD_WORDS):
        return "so'kinish"
    if AI_MODERATION:
        try:
            r = await gemini(
                model=FAST_MODEL, timeout=15,
                contents=f"Bu xabarda so'kinish, haqorat yoki reklama bormi? Faqat HA yoki YOQ deb javob ber.\n\n{text}")
            if (r.text or "").strip().upper().startswith("HA"):
                return "nomaqbul matn"
        except Exception as e:
            log.warning("moderation: %s", e)
    return None


@dp.message(F.new_chat_members | F.left_chat_member)
async def hide_join_leave(m: Message):
    try:
        await m.delete()
    except Exception:
        pass


# ---------- Buyruqlar ----------
HELP_TEXT = (
    "🤖 FORWARD AI imkoniyatlari:\n\n"
    "💬 Savol yozing — javob beraman (menyudan rejim tanlang)\n"
    "🔎 Internet — eng so'nggi ma'lumotlarni qidiraman\n"
    "🎨 Rasm yaratish — tasvirlab bering, chizib beraman (/img matn)\n"
    "🖼 Rasm yuboring — tahlil qilaman, matnini o'qiyman\n"
    "🎙 Ovozli xabar — tushunib javob beraman\n"
    "🔊 Javob ostidagi tugma — javobni ovozda eshiting\n"
    "📄 PDF, Word, Excel, TXT yuboring — xulosa va tahlil\n"
    "🎬 Video yuboring (20 MB gacha) — tahlil qilaman\n"
    "▶️ YouTube havolasi — qisqacha mazmunini aytaman\n"
    "👥 Guruhga qo'shing — spam, reklama, so'kinishni tozalayman\n\n"
    f"Bepul: kuniga {FREE_LIMIT} ta so'rov. ⭐ Premium — cheksiz.\n"
    f"/new — suhbatni tozalash\nAdmin: {ADMIN_CONTACT}"
)


file_ids: dict[str, str] = {}  # yuklangan rasm/animatsiyalar qayta yuklanmasligi uchun


def media(name: str):
    return file_ids.get(name) or FSInputFile(ASSETS / name)


def remember(name: str, msg: Message):
    if msg.animation:
        file_ids[name] = msg.animation.file_id
    elif msg.photo:
        file_ids[name] = msg.photo[-1].file_id


TOUR = [
    ("tour1.jpg", "💬 <b>1/4 · Savol bering</b>\n\nIstalgan savolni yozing — o'zbek, rus yoki ingliz tilida. "
                  "Pastdagi menyudan rejim tanlang: Biznes, Tarjimon, Kreativ, Dasturchi, O'qituvchi yoki Internet."),
    ("tour2.jpg", "🎨 <b>2/4 · Rasm yarating</b>\n\n<code>/img qor ostidagi Samarqand</code> deb yozing yoki "
                  "«🎨 Rasm yaratish» rejimini tanlang. Ilovadagi Studiyada 7 xil uslub bor."),
    ("tour3.jpg", "🎙 <b>3/4 · Ovoz, rasm, hujjat</b>\n\nOvozli xabar, rasm, PDF/Word/Excel, video yoki YouTube "
                  "havolasini yuboring — tushunib, tahlil qilib beraman. Javob ostidagi 🔊 — ovozda eshitish."),
    ("tour4.jpg", f"🚀 <b>4/4 · Ilova va Premium</b>\n\n«Open» tugmasi — Telegram ichidagi ilova. "
                  f"Kuniga {FREE_LIMIT} ta so'rov bepul, ⭐ Premium bilan cheksiz.\n\nTayyormisiz? Boshladik! 👇"),
]
SAMPLE_Q = ["Kafel do'koni uchun Instagram post yozib ber", "Bugungi dollar kursi qancha?",
            "Menga ingliz tilini o'rganish rejasini tuz"]
SAMPLE_IMG = ["Qor ostidagi Samarqand, kechki chiroqlar", "Zamonaviy kafel ko'rgazma zali", "Ko'k va qizil minimal logo"]


def tour_kb(i: int) -> InlineKeyboardMarkup:
    nav = []
    if i > 0:
        nav.append(InlineKeyboardButton(text="◀️ Orqaga", callback_data=f"tour:{i - 1}"))
    if i < len(TOUR) - 1:
        nav.append(InlineKeyboardButton(text="Keyingi ▶️", callback_data=f"tour:{i + 1}"))
    rows = [nav]
    if i == len(TOUR) - 1:
        rows.append([InlineKeyboardButton(text="✅ Boshladik!", callback_data="tour:done")])
    return InlineKeyboardMarkup(inline_keyboard=rows)


def welcome_kb() -> InlineKeyboardMarkup:
    rows = []
    if BASE_URL:
        rows.append([InlineKeyboardButton(text="🚀 Ilovani ochish", web_app=WebAppInfo(url=f"{BASE_URL}/app"))])
    rows.append([InlineKeyboardButton(text="📖 Tanishuv (30 soniya)", callback_data="tour:0")])
    rows.append([InlineKeyboardButton(text="💬 Savol berib ko'rish", callback_data="try:chat"),
                 InlineKeyboardButton(text="🎨 Rasm chizish", callback_data="try:img")])
    return InlineKeyboardMarkup(inline_keyboard=rows)


def over_limit(u: dict, tg_user) -> bool:
    return not u.get("premium") and not is_admin_user(tg_user) and u.get("used_today", 0) >= FREE_LIMIT


@dp.message(CommandStart())
async def start(m: Message):
    await get_user(m.from_user)
    if is_group(m):
        return await m.answer("Salom! Men Forward Ai 🤖 Savol berish uchun meni @mention qiling yoki xabarimga reply qiling.\n"
                              "Guruhni spam va reklamadan tozalashim uchun meni admin qiling.")
    caption = (f"👋 Salom, <b>{html.escape(m.from_user.first_name or '')}</b>!\n\n"
               "Men <b>Forward Ai</b> — FORWARD® aqlli yordamchisi.\n"
               "Savolga javob beraman, rasm chizaman, ovoz va hujjatlarni tushunaman, tarjima qilaman.\n\n"
               "Qayerdan boshlaymiz? 👇")
    try:
        msg = await m.answer_animation(media("welcome.mp4"), caption=caption, parse_mode="HTML", reply_markup=welcome_kb())
        remember("welcome.mp4", msg)
    except Exception as e:
        log.warning("welcome anim: %s", e)
        await m.answer(caption, parse_mode="HTML", reply_markup=welcome_kb())
    await m.answer("Pastdagi menyudan rejim tanlashingiz mumkin 👇", reply_markup=MENU)


@dp.callback_query(F.data.startswith("tour:"))
async def tour(c: CallbackQuery):
    arg = c.data.split(":")[1]
    if arg == "done":
        await c.answer("Omad! 🚀")
        try:
            await c.message.delete()
        except Exception:
            pass
        return await c.message.answer("Savolingizni yozing yoki menyudan rejim tanlang 👇", reply_markup=MENU)
    i = max(0, min(int(arg), len(TOUR) - 1))
    name, text = TOUR[i]
    await c.answer()
    if c.message.photo:  # tanishuv ichida — rasmni almashtiramiz
        try:
            msg = await c.message.edit_media(InputMediaPhoto(media=media(name), caption=text, parse_mode="HTML"),
                                             reply_markup=tour_kb(i))
            if isinstance(msg, Message):
                remember(name, msg)
            return
        except TelegramBadRequest as e:
            if "not modified" in str(e):
                return
    msg = await c.message.answer_photo(media(name), caption=text, parse_mode="HTML", reply_markup=tour_kb(i))
    remember(name, msg)


@dp.callback_query(F.data.startswith("try:"))
async def try_feature(c: CallbackQuery):
    await get_user(c.from_user)
    await c.answer()
    if c.data == "try:img":
        await set_mode(c.from_user.id, "image")
        kb = InlineKeyboardMarkup(inline_keyboard=[[InlineKeyboardButton(text=f"🎨 {p}", callback_data=f"img:{k}")]
                                                   for k, p in enumerate(SAMPLE_IMG)])
        return await c.message.answer("🎨 Rasm rejimi yoqildi. Qanday rasm kerak? Yozing yoki misolni bosing:", reply_markup=kb)
    await set_mode(c.from_user.id, "assistant")
    kb = InlineKeyboardMarkup(inline_keyboard=[[InlineKeyboardButton(text=f"💬 {q}", callback_data=f"ask:{k}")]
                                               for k, q in enumerate(SAMPLE_Q)])
    await c.message.answer("💬 Istalgan savolni yozing yoki misolni bosing:", reply_markup=kb)


@dp.callback_query(F.data.startswith("ask:"))
async def ask_sample(c: CallbackQuery):
    await c.answer()
    q = SAMPLE_Q[int(c.data.split(":")[1]) % len(SAMPLE_Q)]
    m = c.message
    u = await get_user(c.from_user)
    if over_limit(u, c.from_user):
        return await m.answer(f"⏳ Bugungi bepul limit ({FREE_LIMIT}) tugadi. ⭐ Premium oling yoki ertaga davom eting.")
    await m.answer(f"💬 <i>{html.escape(q)}</i>", parse_mode="HTML")
    mode = "search" if "kurs" in q else ("business" if "post" in q else "assistant")
    try:
        async with busy(m.chat.id):
            answer = await ask_ai(m.chat.id, [q], mode)
        await use_quota(c.from_user.id)
        await send_long(m, answer)
    except Exception as e:
        log.exception(e)
        await m.answer(friendly_error(e))


@dp.callback_query(F.data.startswith("img:") | (F.data == "redraw"))
async def img_sample(c: CallbackQuery):
    await c.answer("🎨 Chizyapman...")
    if c.data == "redraw":
        prompt = last_prompt.get(c.message.chat.id) or (c.message.caption or "").replace("🎨", "").strip()
    else:
        prompt = SAMPLE_IMG[int(c.data.split(":")[1]) % len(SAMPLE_IMG)]
    if not prompt:
        return
    u = await get_user(c.from_user)
    if over_limit(u, c.from_user):
        return await c.message.answer(f"⏳ Bugungi bepul limit ({FREE_LIMIT}) tugadi.")
    await generate_image(c.message, prompt, user_id=c.from_user.id)


@dp.message(Command("help"))
@dp.message(F.text == BTN_HELP)
async def help_cmd(m: Message):
    kb = InlineKeyboardMarkup(inline_keyboard=[[InlineKeyboardButton(text="📖 Tanishuv", callback_data="tour:0")]])
    await m.answer(HELP_TEXT, reply_markup=None if is_group(m) else kb)


@dp.message(Command("new"))
async def new_chat(m: Message):
    history.pop(m.chat.id, None)
    await m.answer("Suhbat tozalandi ✅")


@dp.message(F.text.in_(set(BTN_TO_MODE)))
async def choose_mode(m: Message):
    mode = BTN_TO_MODE[m.text]
    await get_user(m.from_user)
    await set_mode(m.from_user.id, mode)
    history.pop(m.chat.id, None)
    hints = {
        "image": "Qanday rasm kerak? Tasvirlab yozing (masalan: tog'lar orasida qizil mashina).",
        "search": "Nima qidiramiz? Masalan: bugungi dollar kursi.",
        "translate": "Tarjima qilinadigan matnni yuboring.",
    }
    await m.answer(f"{m.text} rejimi yoqildi.\n" + hints.get(mode, "Savolingizni yozing."))


@dp.message(Command("img"))
async def img_cmd(m: Message, command: CommandObject):
    if not command.args:
        return await m.answer("Masalan: /img qorli tog'lar orasida uy")
    if await check_access(m):
        await generate_image(m, command.args)


@dp.message(F.text == BTN_PROFILE)
@dp.message(Command("profile"))
async def profile(m: Message):
    u = await get_user(m.from_user)
    prem = "✅ " + str(u.get("premium_until", ""))[:10] if u.get("premium") else "❌ yo'q"
    mode = MODES.get(u.get("mode", "assistant"), MODES["assistant"])[0]
    await m.answer(f"👤 {m.from_user.full_name}\nID: {m.from_user.id}\nRejim: {mode}\n"
                   f"Bugun: {u.get('used_today', 0)} / {'∞' if u.get('premium') else FREE_LIMIT}\nPremium: {prem}")


# ---------- Premium (Telegram Stars) ----------
@dp.message(F.text == BTN_PREMIUM)
@dp.message(Command("premium"))
async def premium(m: Message):
    await m.answer_invoice(
        title="FORWARD AI Premium",
        description=f"{PREMIUM_DAYS} kun cheksiz foydalanish: chat, rasm yaratish, hujjat, video, internet.",
        payload=f"premium_{PREMIUM_DAYS}",
        currency="XTR",
        prices=[LabeledPrice(label="Premium", amount=PREMIUM_STARS)],
        provider_token="",
    )


@dp.pre_checkout_query()
async def pre_checkout(q: PreCheckoutQuery):
    await q.answer(ok=True)


@dp.message(F.successful_payment)
async def paid(m: Message):
    p = m.successful_payment
    until = await rpc("fai_add_premium", p_id=m.from_user.id, p_days=PREMIUM_DAYS,
                      p_stars=p.total_amount, p_charge=p.telegram_payment_charge_id)
    if until is None and m.from_user.id in local_users:
        local_users[m.from_user.id]["premium"] = True
    await m.answer(f"🎉 Rahmat! Premium faollashdi ({PREMIUM_DAYS} kun). Endi cheksiz foydalanasiz.")


# ---------- Admin buyruqlari ----------
@dp.message(Command("admin"))
async def admin_help(m: Message):
    if not is_admin_user(m.from_user):
        return
    s = await rpc("fai_stats") or {}
    await m.answer(
        "🛠 Admin panel\n\n"
        f"👥 Foydalanuvchilar: {s.get('users', '-')}\n"
        f"🆕 Bugun yangi: {s.get('today_new', '-')}\n"
        f"🔥 Bugun faol: {s.get('active_today', '-')}\n"
        f"💬 Bugungi so'rovlar: {s.get('requests_today', '-')}\n"
        f"⭐ Premium: {s.get('premium', '-')}\n"
        f"💰 Jami Stars: {s.get('stars_total', '-')}\n\n"
        "Buyruqlar:\n"
        "/broadcast — xabarga reply qilib yuboring, hammaga tarqatiladi\n"
        "/give ID KUN — premium berish\n"
        "/ban ID, /unban ID")


@dp.message(Command("broadcast"))
async def broadcast(m: Message):
    if not is_admin_user(m.from_user):
        return
    if not m.reply_to_message:
        return await m.answer("Tarqatiladigan xabarga reply qilib /broadcast yozing.")
    ids = await rpc("fai_user_ids") or []
    await m.answer(f"📤 {len(ids)} kishiga yuborilmoqda...")
    ok = 0
    for uid in ids:
        try:
            await m.reply_to_message.copy_to(uid)
            ok += 1
        except Exception:
            pass
        await asyncio.sleep(0.05)
    await m.answer(f"✅ Yuborildi: {ok} / {len(ids)}")


@dp.message(Command("give"))
async def give(m: Message, command: CommandObject):
    if not is_admin_user(m.from_user):
        return
    try:
        uid, days = (command.args or "").split()
        until = await rpc("fai_add_premium", p_id=int(uid), p_days=int(days), p_stars=0, p_charge="admin")
        await m.answer(f"✅ Premium berildi: {uid}, {str(until)[:10]} gacha")
    except Exception:
        await m.answer("Format: /give 123456789 30")


@dp.message(Command("ban", "unban"))
async def ban(m: Message, command: CommandObject):
    if not is_admin_user(m.from_user):
        return
    try:
        await rpc("fai_ban", p_id=int(command.args), p_ban=command.command == "ban")
        await m.answer("✅ Bajarildi")
    except Exception:
        await m.answer(f"Format: /{command.command} 123456789")


# ---------- Ovozda eshitish (Gemini TTS) ----------
@dp.callback_query(F.data == "tts")
async def tts(c: CallbackQuery):
    text = last_answer.get(c.message.chat.id)
    if not text:
        return await c.answer("Javob topilmadi", show_alert=True)
    await c.answer("🔊 Tayyorlanmoqda...")
    await bot.send_chat_action(c.message.chat.id, "record_voice")
    try:
        audio, _mime, ext = await tts_audio(text)
        await c.message.answer_audio(BufferedInputFile(audio, f"forward-ai.{ext}"), title="Forward Ai", performer="FORWARD")
    except Exception as e:
        log.warning("tts: %s", e)
        await c.message.answer("Ovozli javobni hozir tayyorlab bo'lmadi.")


def pick_voice(text: str) -> str:
    if len(re.findall(r"[А-Яа-яЁё]", text)) > len(text) * 0.3:
        return "ru-RU-SvetlanaNeural"
    low = f" {text.lower()} "
    uz = sum(low.count(w) for w in ("o'", "g'", "oʻ", "gʻ", " va ", " bu ", " uchun ", " bilan ", "sh", "ch", "lar", "ning"))
    en = sum(low.count(w) for w in (" the ", " and ", " is ", " you ", " to ", " of "))
    return "uz-UZ-MadinaNeural" if uz >= en else "en-US-AvaMultilingualNeural"


async def tts_audio(text: str) -> tuple[bytes, str, str]:
    """(audio, mime, fayl kengaytmasi). Avval Edge TTS, bo'lmasa Gemini TTS."""
    text = re.sub(r"[*#`_>|]", "", text)
    text = re.sub(r"https?://\S+", "", text).strip()[:2500] or "..."
    try:
        import edge_tts
        com = edge_tts.Communicate(text, pick_voice(text), rate="+5%")
        data = bytearray()

        async def run():
            async for ch in com.stream():
                if ch.get("type") == "audio":
                    data.extend(ch["data"])
        await asyncio.wait_for(run(), 60)
        if len(data) > 1000:
            return bytes(data), "audio/mpeg", "mp3"
    except Exception as e:
        log.warning("edge tts: %s", e)
    return await tts_wav(text), "audio/wav", "wav"


async def tts_wav(text: str) -> bytes:
    text = re.sub(r"[*#`_>]", "", text)
    resp = await asyncio.wait_for(ai.aio.models.generate_content(
        model=TTS_MODEL,
        contents=text[:2500],
        config=types.GenerateContentConfig(
            response_modalities=["AUDIO"],
            speech_config=types.SpeechConfig(voice_config=types.VoiceConfig(
                    prebuilt_voice_config=types.PrebuiltVoiceConfig(voice_name="Kore"))))), 90)
    pcm = resp.candidates[0].content.parts[0].inline_data.data
    if pcm[:4] == b"RIFF":  # Gemini 3.8 TTS tayyor WAV qaytaradi
        return pcm
    buf = io.BytesIO()
    with wave.open(buf, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(24000)
        w.writeframes(pcm)
    return buf.getvalue()


# ---------- Rasm ----------
@dp.message(F.photo)
async def photo(m: Message):
    if not await addressed_to_bot(m) or not (u := await check_access(m)):
        return
    data = await download(m.photo[-1].file_id)
    await run_ai(m, [m.caption or "Bu rasmda nima bor? Batafsil tahlil qil, matn bo'lsa o'qib ber.",
                     types.Part.from_bytes(data=data, mime_type="image/jpeg")], u.get("mode", "assistant"))


# ---------- Ovozli xabar ----------
@dp.message(F.voice | F.audio)
async def voice(m: Message):
    if not await addressed_to_bot(m) or not (u := await check_access(m)):
        return
    media = m.voice or m.audio
    if media.file_size and media.file_size > 20_000_000:
        return await m.answer("Fayl 20 MB dan katta.")
    data = await download(media.file_id)
    mime = "audio/ogg" if m.voice else (m.audio.mime_type or "audio/mpeg")
    await run_ai(m, ["Bu ovozli xabar. Birinchi qatorda '🎙 ' bilan nima deyilganini yoz, keyin javob ber.",
                     types.Part.from_bytes(data=data, mime_type=mime)], u.get("mode", "assistant"))


# ---------- Video ----------
@dp.message(F.video | F.video_note)
async def video(m: Message):
    if not await addressed_to_bot(m) or not (u := await check_access(m)):
        return
    media = m.video or m.video_note
    if media.file_size and media.file_size > 20_000_000:
        return await m.answer("Video 20 MB dan katta. Kichikroq video yuboring.")
    await m.answer("🎬 Video tahlil qilinmoqda...")
    data = await download(media.file_id)
    await run_ai(m, [m.caption or "Bu videoda nima bo'layapti? Qisqacha tahlil qil.",
                     types.Part.from_bytes(data=data, mime_type="video/mp4")], u.get("mode", "assistant"))


# ---------- Hujjatlar ----------
def extract_text(name: str, data: bytes) -> str | None:
    name = name.lower()
    if name.endswith(".docx"):
        import docx
        d = docx.Document(io.BytesIO(data))
        return "\n".join(p.text for p in d.paragraphs)
    if name.endswith((".xlsx", ".xlsm")):
        import openpyxl
        wb = openpyxl.load_workbook(io.BytesIO(data), read_only=True, data_only=True)
        out = []
        for ws in wb.worksheets:
            out.append(f"## {ws.title}")
            for row in ws.iter_rows(values_only=True):
                out.append(" | ".join("" if v is None else str(v) for v in row))
        return "\n".join(out)
    if name.endswith((".txt", ".md", ".csv", ".json", ".py", ".js", ".html", ".css", ".sql", ".xml", ".log")):
        return data.decode("utf-8", errors="ignore")
    return None


@dp.message(F.document)
async def document(m: Message):
    if not await addressed_to_bot(m) or not (u := await check_access(m)):
        return
    doc = m.document
    if doc.file_size and doc.file_size > 20_000_000:
        return await m.answer("Fayl 20 MB dan katta.")
    data = await download(doc.file_id)
    name = doc.file_name or "file"
    task = m.caption or "Bu hujjatni tahlil qil: qisqacha mazmuni, asosiy raqamlar va xulosa."
    mime = doc.mime_type or ""
    if name.lower().endswith(".pdf") or mime == "application/pdf":
        part = types.Part.from_bytes(data=data, mime_type="application/pdf")
    elif mime.startswith("image/"):
        part = types.Part.from_bytes(data=data, mime_type=mime)
    else:
        try:
            text = extract_text(name, data)
        except Exception as e:
            log.warning("extract: %s", e)
            text = None
        if text is None:
            return await m.answer("Bu fayl turini o'qiy olmayman. PDF, Word, Excel yoki TXT yuboring.")
        part = f"Fayl: {name}\n\n{text[:200_000]}"
    await m.answer("📄 Hujjat o'qilmoqda...")
    await run_ai(m, [task, part], u.get("mode", "assistant"))


# ---------- Matn ----------
@dp.message(F.text)
async def text_msg(m: Message):
    if is_group(m):
        reason = await violates(m.text)
        if reason:
            member = await bot.get_chat_member(m.chat.id, m.from_user.id)
            if member.status not in ("administrator", "creator"):
                try:
                    await m.delete()
                    await m.answer(f"⚠️ {m.from_user.full_name}, xabar o'chirildi: {reason}")
                except Exception:
                    log.warning("Botga 'xabarlarni o'chirish' huquqini bering")
                return
        if not await addressed_to_bot(m):
            return
    if not (u := await check_access(m)):
        return
    mode = u.get("mode", "assistant")
    if mode == "image":
        return await generate_image(m, m.text)
    yt = YT_RE.search(m.text)
    if yt:
        await m.answer("▶️ Video ko'rilmoqda...")
        rest = m.text.replace(yt.group(0), "").strip() or "Bu YouTube videoning qisqacha mazmunini va asosiy fikrlarini yoz."
        return await run_ai(m, [rest, types.Part(file_data=types.FileData(file_uri=yt.group(0)))], mode)
    await run_ai(m, [m.text], mode)



# ---------- Mini App (Telegram ichidagi ilova) API ----------
WEBAPP_HTML = pathlib.Path(__file__).with_name("webapp") / "index.html"


async def webapp_page(request):
    return web.FileResponse(WEBAPP_HTML, headers={"Cache-Control": "no-cache"})


async def api_auth(request):
    try:
        body = await request.json()
        data = safe_parse_webapp_init_data(BOT_TOKEN, body.get("initData", ""))
        return body, data.user
    except Exception:
        raise web.HTTPUnauthorized(text='{"error":"Ilovani Telegram ichida oching"}', content_type="application/json")


def jerr(msg, status=400):
    return web.json_response({"error": msg}, status=status)


async def api_quota(wu):
    u = await get_user(wu)
    if u.get("banned"):
        return u, "Siz bloklangansiz"
    if not u.get("premium") and not is_admin_user(wu) and u.get("used_today", 0) >= FREE_LIMIT:
        return u, f"Bugungi bepul limit ({FREE_LIMIT}) tugadi. ⭐ Premium oling yoki ertaga davom eting."
    return u, None


async def api_me(request):
    _, wu = await api_auth(request)
    u = await get_user(wu)
    return web.json_response({"used": u.get("used_today", 0), "limit": FREE_LIMIT, "premium": bool(u.get("premium")),
                              "premium_until": u.get("premium_until"), "premium_stars": PREMIUM_STARS})


async def api_chat(request):
    body, wu = await api_auth(request)
    u, err = await api_quota(wu)
    if err:
        return jerr(err, 429)
    mode = body.get("mode") if body.get("mode") in MODES else "assistant"
    text = (body.get("text") or "").strip()[:8000]
    hist = []
    for h in (body.get("history") or [])[-11:]:
        role = "model" if h.get("role") == "model" else "user"
        hist.append(types.Content(role=role, parts=[types.Part.from_text(text=str(h.get("text", ""))[:3000])]))
    while hist and hist[0].role != "user":
        hist.pop(0)
    parts = [text or "Tahlil qil"]
    f = body.get("file")
    if f and f.get("data"):
        data = base64.b64decode(f["data"])
        mime, name = f.get("mime", ""), f.get("name", "file")
        if mime.startswith("image/") or mime == "application/pdf":
            parts.append(types.Part.from_bytes(data=data, mime_type=mime))
        else:
            try:
                t = extract_text(name, data)
            except Exception:
                t = None
            if t is None:
                return jerr("Bu fayl turini o'qiy olmayman")
            parts.append(f"Fayl: {name}\n\n{t[:200_000]}")
    yt = YT_RE.search(text)
    if yt:
        parts.append(types.Part(file_data=types.FileData(file_uri=yt.group(0))))
    try:
        answer = await ask_ai(wu.id, parts, mode, hist=hist)
    except Exception as e:
        log.exception(e)
        if "429" in str(e) or "RESOURCE_EXHAUSTED" in str(e):
            return jerr("Hozir so'rovlar ko'p, 1 daqiqadan keyin urinib ko'ring", 503)
        return jerr("Xatolik yuz berdi, qayta urinib ko'ring", 500)
    await use_quota(wu.id)
    return web.json_response({"answer": answer})


async def api_image(request):
    body, wu = await api_auth(request)
    u, err = await api_quota(wu)
    if err:
        return jerr(err, 429)
    prompt = (body.get("prompt") or "").strip()[:1000]
    if not prompt:
        return jerr("Rasmni tasvirlab yozing")
    w = max(256, min(int(body.get("width", 1024)), 1536))
    h = max(256, min(int(body.get("height", 1024)), 1536))
    if not IMG_OK:
        return jerr("Rasm chizish xizmati tez orada ishga tushadi", 503)
    try:
        data = await fetch_image(await image_url(prompt, str(body.get("style", ""))[:200], w, h))
    except Exception as e:
        log.warning("api image: %s", e)
        return jerr("Rasm xizmati band, 1 daqiqadan keyin urinib ko'ring", 503)
    key = os.urandom(8).hex()
    IMG_CACHE[key] = data
    while len(IMG_CACHE) > 60:
        IMG_CACHE.pop(next(iter(IMG_CACHE)))
    await use_quota(wu.id)
    return web.json_response({"url": f"/img/{key}.jpg"})


IMG_CACHE: dict[str, bytes] = {}


async def img_cached(request):
    data = IMG_CACHE.get(request.match_info["key"])
    if not data:
        raise web.HTTPNotFound()
    return web.Response(body=data, content_type="image/jpeg", headers={"Cache-Control": "public, max-age=86400"})


async def api_tts(request):
    body, wu = await api_auth(request)
    try:
        audio, mime, _ext = await tts_audio((body.get("text") or "")[:2500])
        return web.Response(body=audio, content_type=mime)
    except Exception as e:
        log.warning("tts api: %s", e)
        return jerr("Ovoz tayyorlanmadi", 500)


async def api_invoice(request):
    _, wu = await api_auth(request)
    link = await bot.create_invoice_link(
        title="FORWARD AI Premium",
        description=f"{PREMIUM_DAYS} kun cheksiz foydalanish",
        payload=f"premium_{PREMIUM_DAYS}", currency="XTR",
        prices=[LabeledPrice(label="Premium", amount=PREMIUM_STARS)], provider_token="")
    return web.json_response({"link": link})

# ---------- Global xato ushlagich ----------
@dp.errors()
async def on_error(ev: ErrorEvent):
    log.exception("unhandled: %s", ev.exception)
    try:
        upd = ev.update
        chat = None
        if upd.message:
            chat = upd.message.chat
        elif upd.callback_query and upd.callback_query.message:
            chat = upd.callback_query.message.chat
        if chat:
            await bot.send_message(chat.id, "⚠️ Kichik nosozlik bo'ldi, qayta urinib ko'ring.")
    except Exception:
        pass
    return True


# ---------- O'z-o'zini tekshirish (faqat egasi uchun) ----------
async def selftest(request):
    if not SELFTEST_KEY or request.query.get("key") != SELFTEST_KEY:
        raise web.HTTPNotFound()
    return web.json_response(await run_selftest(request.query.get("only")))


async def run_selftest(which: str | None = None) -> dict:
    res = {}

    async def check(name, coro):
        t0 = time.monotonic()
        try:
            out = await coro
            res[name] = {"ok": True, "sec": round(time.monotonic() - t0, 2), "out": str(out)[:200]}
        except Exception as e:
            res[name] = {"ok": False, "sec": round(time.monotonic() - t0, 2), "err": f"{type(e).__name__}: {str(e)[:300]}"}

    async def chat():
        return await ask_ai(0, ["2+2 nechaga teng? Bitta son bilan javob ber."], "assistant", hist=[])

    async def search():
        return await ask_ai(0, ["Bugun O'zbekistonda 1 AQSh dollari necha so'm? Qisqa."], "search", hist=[])

    async def lite():
        return resp_text(await gemini("Say OK", model=FAST_MODEL, timeout=20))

    async def tts_():
        a, mime, _ = await tts_audio("Salom! Men Forward Ai, sizning aqlli yordamchingizman.")
        return f"{len(a)} bayt {mime}"

    async def image():
        return f"{len(await fetch_image(await image_url('qizil olma')))} bayt rasm"

    async def db():
        return await rpc("fai_stats")

    async def ddg():
        r = await web_search("Samarqand Registon")
        if not r:
            raise RuntimeError("natija yo'q")
        return r[:150]

    async def live():
        a, b, c = await asyncio.gather(cbu_rates(), weather("Toshkent ob-havo"), wiki("Samarqand"))
        return f"{a[:80]} | {b[:80]} | {c[:60]}"

    async def tg():
        me = await bot.get_me()
        wh = await bot.get_webhook_info()
        return f"@{me.username} webhook={wh.url} pending={wh.pending_update_count} err={wh.last_error_message}"

    checks = {"telegram": tg, "database": db, "chat": chat, "search": search, "fast_model": lite,
              "tts": tts_, "image": image, "duckduckgo": ddg, "live": live}
    await asyncio.gather(*(check(k, f()) for k, f in checks.items() if not which or k in which.split(",")))
    for f in ("welcome.mp4", "tour1.jpg", "tour2.jpg", "tour3.jpg", "tour4.jpg"):
        res[f"asset_{f}"] = {"ok": (ASSETS / f).exists()}
    return res


async def pick_models():
    """Har bir vazifa uchun ishlaydigan birinchi modelni topadi (Google model nomlarini o'zgartirsa ham bot to'xtamaydi)."""
    global CHAT_MODEL, FAST_MODEL, TTS_MODEL, THINKING_OK

    async def works(mdl, cfg=None, contents="Say OK"):
        try:
            await asyncio.wait_for(ai.aio.models.generate_content(model=mdl, contents=contents, config=cfg), 30)
            return True
        except Exception as e:
            log.info("model %s ishlamadi: %s", mdl, str(e)[:160])
            return False

    for mdl in dict.fromkeys(CHAT_CANDIDATES):
        if await works(mdl, types.GenerateContentConfig(thinking_config=types.ThinkingConfig(thinking_level="low"))):
            CHAT_MODEL = mdl
            break
        if await works(mdl):
            CHAT_MODEL, THINKING_OK = mdl, False
            break
    for mdl in dict.fromkeys(FAST_CANDIDATES):
        if await works(mdl):
            FAST_MODEL = mdl
            break
    tcfg = types.GenerateContentConfig(response_modalities=["AUDIO"], speech_config=types.SpeechConfig(
        voice_config=types.VoiceConfig(prebuilt_voice_config=types.PrebuiltVoiceConfig(voice_name="Kore"))))
    for mdl in dict.fromkeys(TTS_CANDIDATES):
        if await works(mdl, tcfg, "Salom"):
            TTS_MODEL = mdl
            break
    log.info("MODELS chat=%s fast=%s tts=%s thinking=%s", CHAT_MODEL, FAST_MODEL, TTS_MODEL, THINKING_OK)


async def selftest_on_start():
    await asyncio.sleep(1)
    try:
        r = await run_selftest()
        for k, v in r.items():
            log.info("SELFTEST %s %s", "OK " if v.get("ok") else "FAIL", f"{k} {v}")
    except Exception as e:
        log.warning("SELFTEST crash: %s", e)


# ---------- Ishga tushirish ----------
async def on_startup(*_, **__):
    global http
    http = aiohttp.ClientSession()
    await bot.set_my_commands([
        types_cmd("start", "Boshlash"), types_cmd("help", "Imkoniyatlar"),
        types_cmd("img", "Rasm yaratish"), types_cmd("new", "Suhbatni tozalash"),
        types_cmd("premium", "Premium olish"), types_cmd("profile", "Profil"),
    ])
    try:
        want = os.getenv("BOT_NAME", "Forward Ai")
        if (await bot.get_my_name()).name != want:
            await bot.set_my_name(name=want)
        sd = "FORWARD® aqlli yordamchisi: chat, rasm, ovoz, hujjat, tarjima, internet qidiruv."
        if (await bot.get_my_short_description()).short_description != sd:
            await bot.set_my_short_description(short_description=sd)
        desc = ("🤖 Forward Ai — FORWARD® aqlli yordamchisi\n\nSavol bering, rasm chizdiring, ovozli xabar, "
                "PDF/Word/Excel, video va YouTube havolasini yuboring — hammasini tushunaman.\n\nAdmin: " + ADMIN_CONTACT)
        if (await bot.get_my_description()).description != desc:
            await bot.set_my_description(description=desc)
    except Exception as e:
        log.warning("set name: %s", e)
    async def boot():
        await asyncio.gather(pick_models(), pick_image_provider())
        if os.getenv("SELFTEST_ON_START") == "1":
            await selftest_on_start()
    asyncio.create_task(boot())
    if BASE_URL:
        try:
            await bot.set_chat_menu_button(menu_button=MenuButtonWebApp(text="Open", web_app=WebAppInfo(url=f"{BASE_URL}/app")))
        except Exception as e:
            log.warning("menu button: %s", e)
        await bot.set_webhook(f"{BASE_URL}/webhook", secret_token=WEBHOOK_SECRET,
                              drop_pending_updates=False, allowed_updates=dp.resolve_used_update_types())


def types_cmd(c, d):
    from aiogram.types import BotCommand
    return BotCommand(command=c, description=d)


async def on_shutdown(*_, **__):
    if http:
        await http.close()


def main():
    if BASE_URL:  # Render: webhook rejimi (bepul tarifda uxlab qolsa ham Telegram uyg'otadi)
        dp.startup.register(on_startup)
        dp.shutdown.register(on_shutdown)
        app = web.Application(client_max_size=25 * 1024 * 1024)
        app.router.add_get("/", lambda r: web.Response(text="FORWARD AI ishlayapti"))
        app.router.add_get("/app", webapp_page)
        app.router.add_get("/app/mark.png", lambda r: web.FileResponse(WEBAPP_HTML.with_name("mark.png")))
        app.router.add_get("/selftest", selftest)
        app.router.add_get("/img/{key}.jpg", img_cached)
        for path, fn in (("me", api_me), ("chat", api_chat), ("image", api_image), ("tts", api_tts), ("invoice", api_invoice)):
            app.router.add_post(f"/api/{path}", fn)
        SimpleRequestHandler(dispatcher=dp, bot=bot, secret_token=WEBHOOK_SECRET).register(app, path="/webhook")
        setup_application(app, dp, bot=bot)
        web.run_app(app, host="0.0.0.0", port=PORT)
    else:  # Lokal: polling
        async def run():
            await on_startup()
            await bot.delete_webhook()
            await dp.start_polling(bot)
        asyncio.run(run())


if __name__ == "__main__":
    main()
