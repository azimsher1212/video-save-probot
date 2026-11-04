"""
Video Save ProBot
Instagram, YouTube, TikTok, Snapchat, Facebook dan rasm/videolarni
musiqasi bilan yuklab beruvchi Telegram bot.
👨‍💻 @azimsher
"""
import asyncio
import logging
import os
import re
import shutil
import uuid
from pathlib import Path

import yt_dlp
from aiohttp import web
from aiogram import Bot, Dispatcher, F
from aiogram.client.default import DefaultBotProperties
from aiogram.enums import ChatAction, ParseMode
from aiogram.filters import Command, CommandStart
from aiogram.types import (
    CallbackQuery,
    FSInputFile,
    InlineKeyboardButton,
    InlineKeyboardMarkup,
    Message,
)
from aiogram.utils.media_group import MediaGroupBuilder

logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")
log = logging.getLogger("probot")

# ---------- Sozlamalar ----------
BOT_TOKEN = os.getenv("BOT_TOKEN", "")
ADMIN = os.getenv("ADMIN_USERNAME", "@azimsher")
COOKIES = os.getenv("COOKIES_FILE")  # ixtiyoriy: cookies.txt yo'li (Instagram/YouTube uchun)
PORT = int(os.getenv("PORT", "8080"))
MAX_PARALLEL = int(os.getenv("MAX_PARALLEL", "3"))
MAX_BYTES = 49 * 1024 * 1024  # Telegram Bot API limiti ~50 MB

DL_ROOT = Path("downloads")
DL_ROOT.mkdir(exist_ok=True)

SITES = {
    "instagram.com": "Instagram",
    "youtube.com": "YouTube",
    "youtu.be": "YouTube",
    "tiktok.com": "TikTok",
    "snapchat.com": "Snapchat",
    "facebook.com": "Facebook",
    "fb.watch": "Facebook",
    "fb.com": "Facebook",
    "pinterest.com": "Pinterest",
    "pin.it": "Pinterest",
}
URL_RE = re.compile(r"https?://[^\s]+")
VIDEO_EXT = {".mp4", ".mov", ".mkv", ".webm"}
IMAGE_EXT = {".jpg", ".jpeg", ".png", ".webp"}
AUDIO_EXT = {".mp3", ".m4a", ".opus", ".ogg", ".aac"}

links: dict[str, str] = {}  # callback uchun qisqa kalit -> havola
sem = asyncio.Semaphore(MAX_PARALLEL)
dp = Dispatcher()

START_TEXT = (
    "👋 <b>Assalomu alaykum!</b>\n\n"
    "Men <b>Instagram, YouTube, TikTok, Pinterest, Snapchat, Facebook</b> tarmoqlaridan "
    "rasm/videolarni musiqasi bilan yuklab beraman 📥\n\n"
    "🔗 Menga havolani yuboring — qolganini o'zim qilaman.\n"
    "🎵 Video ostidagi tugma orqali musiqasini MP3 qilib olasiz.\n\n"
    f"👨‍💻: {ADMIN}"
)


# ---------- Yordamchi funksiyalar ----------
def detect_site(url: str) -> str | None:
    try:
        host = url.split("/")[2].lower().split(":")[0]
    except IndexError:
        return None
    for domain, name in SITES.items():
        if host == domain or host.endswith("." + domain):
            return name
    return None


def ydl_opts(folder: Path, audio: bool) -> dict:
    opts = {
        "outtmpl": str(folder / "%(id)s.%(ext)s"),
        "noplaylist": True,
        "quiet": True,
        "no_warnings": True,
        "restrictfilenames": True,
        "socket_timeout": 30,
        "retries": 3,
    }
    if COOKIES and Path(COOKIES).exists():
        opts["cookiefile"] = COOKIES
    if audio:
        opts["format"] = "bestaudio/best"
        opts["postprocessors"] = [
            {"key": "FFmpegExtractAudio", "preferredcodec": "mp3", "preferredquality": "192"}
        ]
    else:
        # 720p gacha, ovozi bilan birga (Telegram limitiga sig'ishi uchun)
        opts["format"] = (
            "bv*[height<=720][ext=mp4]+ba[ext=m4a]/b[height<=720][ext=mp4]/"
            "bv*[height<=720]+ba/b[height<=720]/b"
        )
        opts["merge_output_format"] = "mp4"
    return opts


async def run_gallery_dl(url: str, folder: Path) -> None:
    """Rasmli postlar (Instagram karusel, TikTok slayd) uchun zaxira yuklovchi."""
    cmd = ["gallery-dl", "-D", str(folder), "--quiet"]
    if COOKIES and Path(COOKIES).exists():
        cmd += ["--cookies", COOKIES]
    cmd.append(url)
    proc = await asyncio.create_subprocess_exec(
        *cmd, stdout=asyncio.subprocess.DEVNULL, stderr=asyncio.subprocess.PIPE
    )
    try:
        _, err = await asyncio.wait_for(proc.communicate(), timeout=180)
        if proc.returncode:
            log.warning("gallery-dl: %s", err.decode(errors="ignore")[:300])
    except asyncio.TimeoutError:
        proc.kill()


async def download(url: str, audio: bool = False) -> Path:
    folder = DL_ROOT / uuid.uuid4().hex
    folder.mkdir()

    def _yt():
        with yt_dlp.YoutubeDL(ydl_opts(folder, audio)) as ydl:
            ydl.download([url])

    try:
        await asyncio.wait_for(asyncio.to_thread(_yt), timeout=300)
    except Exception as e:  # noqa: BLE001
        log.warning("yt-dlp xatosi (%s): %s", url, e)

    if not audio and not any(collect(folder)):
        await run_gallery_dl(url, folder)
    return folder


def collect(folder: Path) -> tuple[list[Path], list[Path], list[Path]]:
    files = sorted(f for f in folder.rglob("*") if f.is_file())
    videos = [f for f in files if f.suffix.lower() in VIDEO_EXT]
    images = [f for f in files if f.suffix.lower() in IMAGE_EXT]
    audios = [f for f in files if f.suffix.lower() in AUDIO_EXT]
    return videos, images, audios


def music_kb(url: str) -> InlineKeyboardMarkup:
    if len(links) > 5000:
        links.clear()
    key = uuid.uuid4().hex[:12]
    links[key] = url
    return InlineKeyboardMarkup(
        inline_keyboard=[[InlineKeyboardButton(text="🎵 Musiqasini yuklash", callback_data=f"mp3:{key}")]]
    )


async def caption(bot: Bot) -> str:
    me = await bot.me()
    return f"📥 @{me.username} orqali yuklandi"


async def send_media(m: Message, folder: Path, url: str) -> bool:
    videos, images, audios = collect(folder)
    too_big = [f for f in videos + images + audios if f.stat().st_size > MAX_BYTES]
    videos = [f for f in videos if f not in too_big]
    images = [f for f in images if f not in too_big]
    audios = [f for f in audios if f not in too_big]

    if too_big and not (videos or images or audios):
        await m.answer("⚠️ Fayl hajmi 50 MB dan katta — Telegram bunday faylni botga yuborishga ruxsat bermaydi.")
        return True

    cap = await caption(m.bot)
    kb = music_kb(url) if videos else None
    media = videos + images
    if not media and not audios:
        return False

    await m.bot.send_chat_action(m.chat.id, ChatAction.UPLOAD_VIDEO if videos else ChatAction.UPLOAD_PHOTO)

    async def send_one(f: Path, with_cap: bool, markup=None):
        c = cap if with_cap else None
        if f.suffix.lower() in VIDEO_EXT:
            await m.answer_video(FSInputFile(f), caption=c, reply_markup=markup, supports_streaming=True)
        else:
            await m.answer_photo(FSInputFile(f), caption=c, reply_markup=markup)

    if len(media) == 1:
        await send_one(media[0], True, kb)
    elif media:
        for i in range(0, len(media), 10):
            chunk = media[i : i + 10]
            if len(chunk) == 1:
                await send_one(chunk[0], i == 0)
                continue
            group = MediaGroupBuilder(caption=cap if i == 0 else None)
            for f in chunk:
                if f.suffix.lower() in VIDEO_EXT:
                    group.add_video(media=FSInputFile(f), supports_streaming=True)
                else:
                    group.add_photo(media=FSInputFile(f))
            await m.answer_media_group(group.build())
        if kb:
            await m.answer("🎵 Musiqasini ham yuklab olasizmi?", reply_markup=kb)

    for a in audios:
        await m.answer_audio(FSInputFile(a), caption=cap)
    return True


# ---------- Handlerlar ----------
@dp.message(CommandStart())
async def on_start(m: Message):
    await m.answer(START_TEXT)


@dp.message(Command("help"))
async def on_help(m: Message):
    await m.answer(
        "📌 <b>Qanday ishlatiladi:</b>\n"
        "1. Instagram / YouTube / TikTok / Pinterest / Snapchat / Facebook dan havolani nusxalang\n"
        "2. Shu yerga yuboring\n"
        "3. Video yoki rasmlarni oling, xohlasangiz 🎵 tugma bilan MP3 ham\n\n"
        f"Savollar bo'yicha: {ADMIN}"
    )


@dp.message(F.text.regexp(URL_RE))
async def on_link(m: Message):
    url = URL_RE.search(m.text).group(0)
    site = detect_site(url)
    if not site:
        if m.chat.type != "private":
            return  # guruhlarda boshqa havolalarga jim turamiz
        await m.answer("❌ Bu sayt qo'llab-quvvatlanmaydi.\nInstagram, YouTube, TikTok, Pinterest, Snapchat yoki Facebook havolasini yuboring.")
        return

    status = await m.answer(f"⏳ {site} dan yuklanmoqda, biroz kuting...")
    folder = None
    try:
        async with sem:
            folder = await download(url)
            ok = await send_media(m, folder, url)
        if not ok:
            await m.answer(
                "😔 Yuklab bo'lmadi. Sabablari bo'lishi mumkin:\n"
                "• post yopiq (private) yoki o'chirilgan\n"
                "• havola noto'g'ri\n"
                "Boshqa havola bilan urinib ko'ring."
            )
    except Exception as e:  # noqa: BLE001
        log.exception("Yuborishda xato: %s", e)
        await m.answer("⚠️ Xatolik yuz berdi, birozdan so'ng qayta urinib ko'ring.")
    finally:
        if folder:
            shutil.rmtree(folder, ignore_errors=True)
        try:
            await status.delete()
        except Exception:  # noqa: BLE001
            pass


@dp.callback_query(F.data.startswith("mp3:"))
async def on_mp3(c: CallbackQuery):
    url = links.get(c.data[4:])
    if not url:
        await c.answer("Havola eskirgan, iltimos qaytadan yuboring.", show_alert=True)
        return
    await c.answer("🎵 Musiqa tayyorlanmoqda...")
    await c.bot.send_chat_action(c.message.chat.id, ChatAction.UPLOAD_VOICE)
    folder = None
    try:
        async with sem:
            folder = await download(url, audio=True)
        _, _, audios = collect(folder)
        audios = [a for a in audios if a.stat().st_size <= MAX_BYTES]
        if audios:
            await c.message.answer_audio(FSInputFile(audios[0]), caption=await caption(c.bot))
        else:
            await c.message.answer("😔 Musiqani ajratib bo'lmadi.")
    except Exception as e:  # noqa: BLE001
        log.exception("MP3 xato: %s", e)
        await c.message.answer("⚠️ Xatolik yuz berdi, qayta urinib ko'ring.")
    finally:
        if folder:
            shutil.rmtree(folder, ignore_errors=True)


@dp.message(F.chat.type == "private")
async def on_other(m: Message):
    await m.answer("🔗 Menga video yoki rasm havolasini yuboring.")


# ---------- Ishga tushirish ----------
async def health(_request):
    return web.Response(text="Video Save ProBot ishlayapti ✅")


async def main():
    if not BOT_TOKEN:
        raise SystemExit("BOT_TOKEN o'rnatilmagan!")
    bot = Bot(BOT_TOKEN, default=DefaultBotProperties(parse_mode=ParseMode.HTML))

    # Hosting (Render va h.k.) uchun kichik veb-server
    app = web.Application()
    app.router.add_get("/", health)
    runner = web.AppRunner(app)
    await runner.setup()
    await web.TCPSite(runner, "0.0.0.0", PORT).start()

    await bot.delete_webhook(drop_pending_updates=True)
    log.info("Bot ishga tushdi")
    await dp.start_polling(bot)


if __name__ == "__main__":
    asyncio.run(main())
