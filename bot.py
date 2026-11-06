"""FORWARD AI — Telegram bot + Google Gemini (bepul): chat, rasm, ovoz, guruh moderatsiyasi."""
import asyncio
import io
import logging
import os
import re
from collections import defaultdict, deque

from aiogram import Bot, Dispatcher, F
from aiogram.client.default import DefaultBotProperties
from aiogram.enums import ChatType
from aiogram.filters import Command, CommandStart
from aiogram.types import Message
from aiohttp import web
from google import genai
from google.genai import types

logging.basicConfig(level=logging.INFO)

BOT_TOKEN = os.environ["BOT_TOKEN"]
GEMINI_API_KEY = os.environ["GEMINI_API_KEY"]
CHAT_MODEL = os.getenv("CHAT_MODEL", "gemini-2.5-flash")
# Guruhdagi har bir xabarni AI bilan tekshirish (bepul limitni tez sarflaydi) — 1 qilsangiz yoqiladi
AI_MODERATION = os.getenv("AI_MODERATION", "0") == "1"
ADMIN_CONTACT = os.getenv("ADMIN_CONTACT", "@Forward_admin1")
PORT = int(os.getenv("PORT", "10000"))

SYSTEM_PROMPT = (
    "Sen FORWARD AI — FORWARD® brendining yordamchisisan. "
    "Foydalanuvchi qaysi tilda yozsa, o'sha tilda (asosan o'zbekcha) qisqa va aniq javob ber."
)

# O'zingiz to'ldiring: guruhda o'chiriladigan so'zlar (kichik harfda)
BAD_WORDS = {w.strip() for w in os.getenv("BAD_WORDS", "").lower().split(",") if w.strip()}
LINK_RE = re.compile(r"(https?://|t\.me/|www\.|@\w+bot\b)", re.I)
ARABIC_RE = re.compile(r"[؀-ۿ]")

bot = Bot(BOT_TOKEN, default=DefaultBotProperties(parse_mode=None))
dp = Dispatcher()
ai = genai.Client(api_key=GEMINI_API_KEY)

# Har bir chat uchun oxirgi 10 ta xabar (suhbat xotirasi)
history: dict[int, deque] = defaultdict(lambda: deque(maxlen=10))


async def ask_ai(chat_id: int, parts: list) -> str:
    """parts: matn (str) yoki types.Part ro'yxati."""
    parts = [types.Part.from_text(text=p) if isinstance(p, str) else p for p in parts]
    contents = list(history[chat_id]) + [types.Content(role="user", parts=parts)]
    resp = await ai.aio.models.generate_content(
        model=CHAT_MODEL,
        contents=contents,
        config=types.GenerateContentConfig(system_instruction=SYSTEM_PROMPT),
    )
    answer = (resp.text or "Javob topilmadi.").strip()
    # Xotirada faqat matn saqlaymiz (rasm/ovoz joy egallamasin)
    user_text = " ".join(p.text for p in parts if p.text) or "[media]"
    history[chat_id].append(types.Content(role="user", parts=[types.Part.from_text(text=user_text)]))
    history[chat_id].append(types.Content(role="model", parts=[types.Part.from_text(text=answer)]))
    return answer


async def send_long(message: Message, text: str):
    for i in range(0, len(text), 4000):
        await message.answer(text[i:i + 4000])


async def download(file_id: str) -> bytes:
    f = await bot.get_file(file_id)
    buf = io.BytesIO()
    await bot.download_file(f.file_path, buf)
    return buf.getvalue()


def is_group(m: Message) -> bool:
    return m.chat.type in (ChatType.GROUP, ChatType.SUPERGROUP)


async def addressed_to_bot(m: Message) -> bool:
    """Guruhda bot faqat @mention yoki reply qilinganda javob beradi."""
    if not is_group(m):
        return True
    me = await bot.me()
    text = (m.text or m.caption or "")
    if f"@{me.username}".lower() in text.lower():
        return True
    return bool(m.reply_to_message and m.reply_to_message.from_user
                and m.reply_to_message.from_user.id == me.id)


# ---------- Guruh moderatsiyasi ----------
async def is_admin(m: Message) -> bool:
    member = await bot.get_chat_member(m.chat.id, m.from_user.id)
    return member.status in ("administrator", "creator")


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
                contents=f"Bu xabarda so'kinish, haqorat yoki reklama bormi? Faqat HA yoki YOQ deb javob ber.\n\n{text}",
            )
            if (r.text or "").strip().upper().startswith("HA"):
                return "nomaqbul matn"
        except Exception as e:
            logging.warning("moderation error: %s", e)
    return None


@dp.message(F.new_chat_members | F.left_chat_member)
async def hide_join_leave(m: Message):
    try:
        await m.delete()
    except Exception:
        pass


# ---------- Buyruqlar ----------
@dp.message(CommandStart())
async def start(m: Message):
    await m.answer(
        "Salom! Men FORWARD AI 🤖\n\n"
        "• Savol yozing — javob beraman\n"
        "• Rasm yuboring — tahlil qilaman\n"
        "• Ovozli xabar yuboring — tushunib javob beraman\n\n"
        f"/new — suhbatni yangidan boshlash\nAdmin: {ADMIN_CONTACT}"
    )


@dp.message(Command("new"))
async def new_chat(m: Message):
    history.pop(m.chat.id, None)
    await m.answer("Suhbat tozalandi ✅")


# ---------- Rasm ----------
@dp.message(F.photo)
async def photo(m: Message):
    if is_group(m) and not await addressed_to_bot(m):
        return
    await bot.send_chat_action(m.chat.id, "typing")
    data = await download(m.photo[-1].file_id)
    content = [
        m.caption or "Bu rasmda nima bor? Tahlil qilib ber.",
        types.Part.from_bytes(data=data, mime_type="image/jpeg"),
    ]
    try:
        await send_long(m, await ask_ai(m.chat.id, content))
    except Exception as e:
        logging.exception(e)
        await m.answer("Xatolik yuz berdi, keyinroq urinib ko'ring.")


# ---------- Ovozli xabar ----------
@dp.message(F.voice | F.audio)
async def voice(m: Message):
    if is_group(m) and not await addressed_to_bot(m):
        return
    await bot.send_chat_action(m.chat.id, "typing")
    media = m.voice or m.audio
    data = await download(media.file_id)
    try:
        mime = "audio/ogg" if m.voice else (m.audio.mime_type or "audio/mpeg")
        content = [
            "Bu ovozli xabar. Avval birinchi qatorda '🎙 ' bilan nima deyilganini yoz, keyin javob ber.",
            types.Part.from_bytes(data=data, mime_type=mime),
        ]
        await send_long(m, await ask_ai(m.chat.id, content))
    except Exception as e:
        logging.exception(e)
        await m.answer("Ovozni tushuna olmadim, qayta yuboring.")


# ---------- Matn ----------
@dp.message(F.text)
async def text_msg(m: Message):
    if is_group(m):
        reason = await violates(m.text)
        if reason and not await is_admin(m):
            try:
                await m.delete()
                await m.answer(f"⚠️ {m.from_user.full_name}, xabar o'chirildi: {reason}")
            except Exception:
                logging.warning("Botga 'xabarlarni o'chirish' huquqini bering")
            return
        if not await addressed_to_bot(m):
            return
    await bot.send_chat_action(m.chat.id, "typing")
    try:
        await send_long(m, await ask_ai(m.chat.id, [m.text]))
    except Exception as e:
        logging.exception(e)
        await m.answer("Xatolik yuz berdi, keyinroq urinib ko'ring.")


# ---------- Render bepul tarifi uchun kichik web-server ----------
async def run_web():
    app = web.Application()
    app.router.add_get("/", lambda r: web.Response(text="FORWARD AI ishlayapti"))
    runner = web.AppRunner(app)
    await runner.setup()
    await web.TCPSite(runner, "0.0.0.0", PORT).start()


async def main():
    await run_web()
    await dp.start_polling(bot)


if __name__ == "__main__":
    asyncio.run(main())
