"""FORWARD AI — Telegram bot + Google Gemini (bepul).

Imkoniyatlar: chat (rejimlar), internetdan qidiruv, rasm tahlili, rasm yaratish,
ovozli xabar, ovozda javob, hujjat (PDF/DOCX/XLSX/TXT), video, YouTube xulosasi,
guruh moderatsiyasi, kunlik limit, Telegram Stars premium, admin buyruqlari.
"""
import asyncio
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
from aiogram.types import MenuButtonWebApp, WebAppInfo
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
CHAT_MODEL = os.getenv("CHAT_MODEL", "gemini-2.5-flash")
TTS_MODEL = os.getenv("TTS_MODEL", "gemini-2.5-flash-preview-tts")
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
               "Telegram uchun oddiy matn yoz, markdown jadval ishlatma.")
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


async def send_long(m: Message, text: str, tts: bool = True):
    chunks = [text[i:i + 4000] for i in range(0, len(text), 4000)] or ["..."]
    for i, c in enumerate(chunks):
        last = i == len(chunks) - 1
        await m.answer(c, reply_markup=TTS_KB if (tts and last and not is_group(m)) else None)


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


async def ask_ai(chat_id: int, parts: list, mode: str = "assistant", hist: list | None = None) -> str:
    parts = [types.Part.from_text(text=p) if isinstance(p, str) else p for p in parts]
    base = hist if hist is not None else list(history[chat_id])
    contents = base + [types.Content(role="user", parts=parts)]
    config = types.GenerateContentConfig(system_instruction=BASE_PROMPT + " " + MODES.get(mode, MODES["assistant"])[1])
    if mode == "search":
        config.tools = [types.Tool(google_search=types.GoogleSearch())]
    resp = await ai.aio.models.generate_content(model=CHAT_MODEL, contents=contents, config=config)
    answer = (resp.text or "Javob topilmadi.").strip()
    if hist is not None:
        return answer
    user_text = " ".join(p.text for p in parts if p.text) or "[media]"
    history[chat_id].append(types.Content(role="user", parts=[types.Part.from_text(text=user_text[:3000])]))
    history[chat_id].append(types.Content(role="model", parts=[types.Part.from_text(text=answer[:3000])]))
    last_answer[chat_id] = answer
    return answer


async def run_ai(m: Message, parts: list, mode: str):
    await bot.send_chat_action(m.chat.id, "typing")
    try:
        answer = await ask_ai(m.chat.id, parts, mode)
        await use_quota(m.from_user.id)
        await send_long(m, answer)
    except Exception as e:
        log.exception(e)
        msg = str(e)
        if "429" in msg or "RESOURCE_EXHAUSTED" in msg:
            await m.answer("⏳ Hozir so'rovlar ko'p. 1 daqiqadan keyin qayta urinib ko'ring.")
        else:
            await m.answer("Xatolik yuz berdi, keyinroq urinib ko'ring.")


# ---------- Rasm yaratish (Pollinations — bepul) ----------
async def image_url(prompt: str, style: str = "", w: int = 1024, h: int = 1024) -> str:
    try:
        tr = await ai.aio.models.generate_content(
            model=CHAT_MODEL,
            contents=f"Translate this image description to a detailed English image prompt. Output only the prompt:\n{prompt}")
        en = (tr.text or prompt).strip()
    except Exception:
        en = prompt
    if style:
        en += ", " + style
    seed = int.from_bytes(os.urandom(3), "big")
    return (f"https://image.pollinations.ai/prompt/{urllib.parse.quote(en[:900])}"
            f"?width={w}&height={h}&nologo=true&model=flux&seed={seed}")


async def generate_image(m: Message, prompt: str):
    await bot.send_chat_action(m.chat.id, "upload_photo")
    url = await image_url(prompt)
    try:
        async with http.get(url, timeout=aiohttp.ClientTimeout(total=120)) as r:
            if r.status != 200:
                raise RuntimeError(f"status {r.status}")
            data = await r.read()
        await m.answer_photo(BufferedInputFile(data, "forward-ai.jpg"), caption=f"🎨 {prompt[:900]}")
        await use_quota(m.from_user.id)
    except Exception as e:
        log.warning("image gen: %s", e)
        await m.answer("Rasm yaratib bo'lmadi, birozdan keyin qayta urinib ko'ring.")


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
            r = await ai.aio.models.generate_content(
                model=CHAT_MODEL,
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


@dp.message(CommandStart())
async def start(m: Message):
    await get_user(m.from_user)
    await m.answer(f"Salom, {m.from_user.first_name}! Men FORWARD AI 🤖\n\n" + HELP_TEXT,
                   reply_markup=None if is_group(m) else MENU)
    if BASE_URL and not is_group(m):
        kb = InlineKeyboardMarkup(inline_keyboard=[[InlineKeyboardButton(
            text="🚀 Ilovani ochish", web_app=WebAppInfo(url=f"{BASE_URL}/app"))]])
        await m.answer("📱 Forward Ai ilovasi — chat, rasm studiyasi va profil bir joyda:", reply_markup=kb)


@dp.message(Command("help"))
@dp.message(F.text == BTN_HELP)
async def help_cmd(m: Message):
    await m.answer(HELP_TEXT)


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
        wav = await tts_wav(text)
        await c.message.answer_audio(BufferedInputFile(wav, "forward-ai.wav"), title="FORWARD AI")
    except Exception as e:
        log.warning("tts: %s", e)
        await c.message.answer("Ovozli javobni hozir tayyorlab bo'lmadi.")


async def tts_wav(text: str) -> bytes:
    resp = await ai.aio.models.generate_content(
        model=TTS_MODEL,
        contents=text[:2500],
        config=types.GenerateContentConfig(
            response_modalities=["AUDIO"],
            speech_config=types.SpeechConfig(voice_config=types.VoiceConfig(
                prebuilt_voice_config=types.PrebuiltVoiceConfig(voice_name="Kore")))))
    pcm = resp.candidates[0].content.parts[0].inline_data.data
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
    url = await image_url(prompt, str(body.get("style", ""))[:200], w, h)
    await use_quota(wu.id)
    return web.json_response({"url": url})


async def api_tts(request):
    body, wu = await api_auth(request)
    try:
        wav = await tts_wav((body.get("text") or "")[:2500])
        return web.Response(body=wav, content_type="audio/wav")
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
        await bot.set_my_name(name=os.getenv("BOT_NAME", "FORWARD AI Assistant"))
        await bot.set_my_short_description(short_description="FORWARD® aqlli yordamchisi: chat, rasm, ovoz, hujjat, video, internet qidiruv.")
        await bot.set_my_description(description="🤖 FORWARD AI Assistant\n\nSavol bering, rasm chizdiring, ovozli xabar, PDF/Word/Excel, video va YouTube havolasini yuboring — hammasini tushunaman.\n\nAdmin: " + ADMIN_CONTACT)
    except Exception as e:
        log.warning("set name: %s", e)
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
