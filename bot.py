"""
Forward Save bot (Video Save ProBot)
Instagram, YouTube, TikTok, Pinterest, Snapchat, Facebook dan rasm/videolarni
musiqasi bilan yuklab beruvchi Telegram bot.
👨‍💻 @Forward_admin1
"""
import asyncio
import html
import logging
import os
import re
import shutil
import time
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
    BotCommand,
    InputProfilePhotoStatic,
    ReactionTypeEmoji,
)
from aiogram.utils.media_group import MediaGroupBuilder

logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")
log = logging.getLogger("probot")

# ---------- Sozlamalar ----------
BOT_TOKEN = os.getenv("BOT_TOKEN", "")
ADMIN = os.getenv("ADMIN_USERNAME", "@Forward_admin1")
COOKIES = os.getenv("COOKIES_FILE")  # ixtiyoriy: cookies.txt yo'li
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
    "pinterest.com": "Pinterest",
    "pin.it": "Pinterest",
    "snapchat.com": "Snapchat",
    "facebook.com": "Facebook",
    "fb.watch": "Facebook",
    "fb.com": "Facebook",
}
SITE_EMOJI = {
    "Instagram": "📸",
    "YouTube": "▶️",
    "TikTok": "🎵",
    "Pinterest": "📌",
    "Snapchat": "👻",
    "Facebook": "📘",
}
# Bu saytlarda ko'pincha rasm bo'ladi — avval rasm yuklovchini ishlatamiz (tezroq)
GALLERY_FIRST = {"Pinterest"}

URL_RE = re.compile(r"https?://[^\s]+")
VIDEO_EXT = {".mp4", ".mov", ".mkv", ".webm"}
IMAGE_EXT = {".jpg", ".jpeg", ".png", ".webp"}
AUDIO_EXT = {".mp3", ".m4a", ".opus", ".ogg", ".aac"}

links: dict[str, str] = {}  # callback kaliti -> havola
cache: dict[str, dict] = {}  # havola -> {"items": [(tur, file_id)], "cap": str}
sem = asyncio.Semaphore(MAX_PARALLEL)
dp = Dispatcher()
WELCOME_IMG = Path(__file__).parent / "assets" / "welcome.jpg"
WELCOME_ID: str | None = None  # bir marta yuklangach Telegram file_id qayta ishlatiladi


# ---------- Matnlar ----------
def start_text(name: str) -> str:
    return (
        f"👋 <b>Salom, {html.escape(name)}!</b>\n\n"
        "Men — <b>FORWARD SAVE</b> 🔴🔵 ⚡\n"
        "Rasm va videolarni <b>musiqasi bilan</b> bir zumda yuklab beraman 📥\n\n"
        "📸 Instagram  ▶️ YouTube  🎵 TikTok\n"
        "📌 Pinterest  👻 Snapchat  📘 Facebook\n\n"
        "🔗 <b>Havolani yuboring — qolganini o'zim qilaman!</b>\n"
        "🎶 Video ostidagi tugma — musiqasini MP3 qilib beradi\n"
        "🖼 Rasmlarni <b>original sifatda</b> fayl qilib ham olasiz\n"
        "💎 Videolar — 1080p gacha eng yuqori sifatda\n\n"
        f"👨‍💻 {ADMIN}"
    )


def bot_link(username: str) -> str:
    return f"https://t.me/{username}?startgroup=true"


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


def cache_key(url: str) -> str:
    # Instagram/TikTok havolalaridagi ?igsh=... kabi qo'shimchalarni olib tashlaymiz
    if "youtube.com/watch" in url:
        return url
    return url.split("?")[0].rstrip("/")


def ydl_opts(folder: Path, audio: bool, low: bool = False) -> dict:
    opts = {
        "outtmpl": str(folder / "%(id)s.%(ext)s"),
        "noplaylist": True,
        "quiet": True,
        "no_warnings": True,
        "restrictfilenames": True,
        "socket_timeout": 20,
        "retries": 2,
        "extractor_retries": 1,
        "concurrent_fragment_downloads": 4,
    }
    if COOKIES and Path(COOKIES).exists():
        opts["cookiefile"] = COOKIES
    if audio:
        opts["format"] = "bestaudio/best"
        opts["postprocessors"] = [
            {"key": "FFmpegExtractAudio", "preferredcodec": "mp3", "preferredquality": "192"}
        ]
    else:
        if low:
            # Zaxira: fayl 50 MB dan oshsa, 720p
            opts["format"] = "bv*[height<=720][filesize<?44M]+ba/b[height<=720]/bv*[height<=480]+ba/b"
        else:
            # Eng yuqori sifat (1080p gacha), 50 MB ga sig'adigan
            opts["format"] = (
                "bv*[height<=1080][filesize<?44M]+ba/"
                "b[height<=1080][filesize<?48M]/"
                "bv*[height<=720]+ba/b[height<=720]/b"
            )
        # Bir xil sifatda Telegram'da hamma joyda ochiladigan H.264 + AAC ni afzal ko'ramiz
        opts["format_sort"] = ["res", "vcodec:h264", "acodec:aac", "ext:mp4:m4a"]
        opts["merge_output_format"] = "mp4"
    return opts


def collect(folder: Path) -> tuple[list[Path], list[Path], list[Path]]:
    files = sorted(f for f in folder.rglob("*") if f.is_file())
    videos = [f for f in files if f.suffix.lower() in VIDEO_EXT]
    images = [f for f in files if f.suffix.lower() in IMAGE_EXT]
    audios = [f for f in files if f.suffix.lower() in AUDIO_EXT]
    return videos, images, audios


def has_files(folder: Path) -> bool:
    return any(collect(folder))


async def run_gallery_dl(url: str, folder: Path) -> None:
    cmd = ["gallery-dl", "-D", str(folder), "--quiet"]
    if COOKIES and Path(COOKIES).exists():
        cmd += ["--cookies", COOKIES]
    cmd.append(url)
    proc = await asyncio.create_subprocess_exec(
        *cmd, stdout=asyncio.subprocess.DEVNULL, stderr=asyncio.subprocess.PIPE
    )
    try:
        _, err = await asyncio.wait_for(proc.communicate(), timeout=120)
        if proc.returncode:
            log.warning("gallery-dl: %s", err.decode(errors="ignore")[:300])
    except asyncio.TimeoutError:
        proc.kill()


async def run_ytdlp(url: str, folder: Path, audio: bool, low: bool = False) -> dict:
    def _yt():
        with yt_dlp.YoutubeDL(ydl_opts(folder, audio, low)) as ydl:
            return ydl.extract_info(url, download=True) or {}

    try:
        return await asyncio.wait_for(asyncio.to_thread(_yt), timeout=240)
    except Exception as e:  # noqa: BLE001
        log.warning("yt-dlp xatosi (%s): %s", url, str(e)[:200])
        return {}


async def download(url: str, site: str, audio: bool = False) -> tuple[Path, dict]:
    folder = DL_ROOT / uuid.uuid4().hex
    folder.mkdir()
    info: dict = {}

    if not audio and site in GALLERY_FIRST:
        await run_gallery_dl(url, folder)
        if has_files(folder):
            return folder, info

    info = await run_ytdlp(url, folder, audio)
    # Video 50 MB dan katta chiqsa — 720p da qayta yuklaymiz
    vids, imgs, _ = collect(folder)
    if not audio and vids and not imgs and all(v.stat().st_size > MAX_BYTES for v in vids):
        shutil.rmtree(folder, ignore_errors=True)
        folder.mkdir()
        info = await run_ytdlp(url, folder, audio, low=True) or info
    if not audio and not has_files(folder) and site not in GALLERY_FIRST:
        await run_gallery_dl(url, folder)
    return folder, info


def build_caption(site: str, info: dict, username: str, seconds: float | None) -> str:
    lines = []
    title = (info.get("title") or info.get("description") or "").strip().split("\n")[0]
    if title and title.lower() not in {"video", "pin", "instagram", "tiktok"}:
        lines.append(f"🎬 <b>{html.escape(title[:120])}</b>")
    author = info.get("uploader") or info.get("channel") or info.get("creator")
    if author:
        lines.append(f"👤 {html.escape(str(author)[:60])}")
    meta = f"{SITE_EMOJI.get(site, '🌐')} {site}"
    if seconds is not None:
        meta += f"  •  ⚡ {seconds:.1f} soniyada"
    lines.append(meta)
    lines.append("")
    lines.append(f"🔵🔴 <b>FORWARD SAVE</b> · @{username}")
    return "\n".join(lines)


def action_kb(url: str, username: str, has_video: bool, has_photo: bool) -> InlineKeyboardMarkup:
    rows = []
    if has_video or has_photo:
        if len(links) > 5000:
            links.clear()
        key = uuid.uuid4().hex[:12]
        links[key] = url
        if has_video:
            rows.append([InlineKeyboardButton(text="🎶 Musiqasini yuklash (MP3)", callback_data=f"mp3:{key}")])
        if has_photo:
            rows.append([InlineKeyboardButton(text="🖼 Original sifatda (fayl)", callback_data=f"hd:{key}")])
    rows.append([InlineKeyboardButton(text="➕ Botni guruhga qo'shish", url=bot_link(username))])
    return InlineKeyboardMarkup(inline_keyboard=rows)


async def react(m: Message, emoji: str) -> None:
    try:
        await m.react([ReactionTypeEmoji(emoji=emoji)])
    except Exception:  # noqa: BLE001
        pass


async def set_status(status: Message, text: str) -> None:
    try:
        await status.edit_text(text)
    except Exception:  # noqa: BLE001
        pass


async def keep_action(bot: Bot, chat_id: int, action: ChatAction, stop: asyncio.Event) -> None:
    """Yuklash davomida 'video yuborilmoqda...' belgisini ko'rsatib turadi."""
    while not stop.is_set():
        try:
            await bot.send_chat_action(chat_id, action)
        except Exception:  # noqa: BLE001
            pass
        try:
            await asyncio.wait_for(stop.wait(), timeout=4.5)
        except asyncio.TimeoutError:
            pass


async def send_items(m: Message, items: list[tuple[str, object]], cap: str, kb) -> list[tuple[str, str]]:
    """items: [(tur, FSInputFile yoki file_id)] — yuborib, file_id larni qaytaradi."""
    out: list[tuple[str, str]] = []
    visual = [it for it in items if it[0] in ("video", "photo")]
    audios = [it for it in items if it[0] == "audio"]

    async def one(kind, media, c, markup):
        if kind == "video":
            r = await m.reply_video(media, caption=c, reply_markup=markup, supports_streaming=True)
            out.append(("video", r.video.file_id))
        else:
            r = await m.reply_photo(media, caption=c, reply_markup=markup)
            out.append(("photo", r.photo[-1].file_id))

    if len(visual) == 1:
        await one(*visual[0], cap, kb)
    elif visual:
        for i in range(0, len(visual), 10):
            chunk = visual[i : i + 10]
            if len(chunk) == 1:
                await one(*chunk[0], cap if i == 0 else None, None)
                continue
            group = MediaGroupBuilder(caption=cap if i == 0 else None)
            for kind, media in chunk:
                if kind == "video":
                    group.add_video(media=media, supports_streaming=True)
                else:
                    group.add_photo(media=media)
            msgs = await m.reply_media_group(group.build())
            for r in msgs:
                out.append(("video", r.video.file_id) if r.video else ("photo", r.photo[-1].file_id))
        await m.answer("👆 Tayyor! Yana nima qilamiz?", reply_markup=kb)

    for _, media in audios:
        r = await m.reply_audio(media, caption=cap)
        out.append(("audio", r.audio.file_id))
    return out


# ---------- Handlerlar ----------
@dp.message(CommandStart())
async def on_start(m: Message):
    me = await m.bot.me()
    kb = InlineKeyboardMarkup(
        inline_keyboard=[
            [InlineKeyboardButton(text="➕ Guruhga qo'shish", url=bot_link(me.username))],
            [InlineKeyboardButton(text="👨‍💻 Admin bilan bog'lanish", url=f"https://t.me/{ADMIN.lstrip('@')}")],
        ]
    )
    text = start_text(m.from_user.first_name if m.from_user else "do'stim")
    global WELCOME_ID
    try:
        r = await m.answer_photo(WELCOME_ID or FSInputFile(WELCOME_IMG), caption=text, reply_markup=kb)
        WELCOME_ID = r.photo[-1].file_id
    except Exception as e:  # noqa: BLE001
        log.warning("Banner yuborilmadi: %s", e)
        await m.answer(text, reply_markup=kb)


@dp.message(Command("help"))
async def on_help(m: Message):
    await m.answer(
        "📖 <b>Qanday ishlatiladi?</b>\n\n"
        "1️⃣ Ilovada postni oching → <b>Ulashish</b> → <b>Havolani nusxalash</b>\n"
        "2️⃣ Havolani shu yerga yuboring\n"
        "3️⃣ Bir necha soniyada video yoki rasm tayyor ✅\n"
        "4️⃣ 🎶 tugma bilan musiqasini MP3 qilib oling\n\n"
        "👥 Guruhlarda ham ishlayman — meni guruhga qo'shing!\n\n"
        f"❓ Savollar: {ADMIN}"
    )


@dp.message(F.text.regexp(URL_RE))
async def on_link(m: Message):
    url = URL_RE.search(m.text).group(0)
    site = detect_site(url)
    if not site:
        if m.chat.type != "private":
            return  # guruhlarda boshqa havolalarga jim turamiz
        await m.answer(
            "🤔 Bu saytni hali tanimayman.\n\n"
            "Men bilan ishlaydiganlar:\n📸 Instagram  ▶️ YouTube  🎵 TikTok\n📌 Pinterest  👻 Snapchat  📘 Facebook"
        )
        return

    me = await m.bot.me()
    key = cache_key(url)
    await react(m, "👀")

    # ⚡ Avval yuklangan bo'lsa — darhol yuboramiz
    if key in cache:
        c = cache[key]
        kinds = {k for k, _ in c["items"]}
        try:
            await send_items(m, c["items"], c["cap"], action_kb(url, me.username, "video" in kinds, "photo" in kinds))
            await react(m, "⚡")
            return
        except Exception as e:  # noqa: BLE001
            log.warning("Keshdan yuborib bo'lmadi: %s", e)
            cache.pop(key, None)

    emoji = SITE_EMOJI.get(site, "🌐")
    status = await m.reply(f"{emoji} <b>{site}</b> havolasi qabul qilindi\n⏳ Yuklanmoqda...")
    stop = asyncio.Event()
    typing = asyncio.create_task(keep_action(m.bot, m.chat.id, ChatAction.UPLOAD_VIDEO, stop))
    folder = None
    t0 = time.monotonic()
    try:
        async with sem:
            folder, info = await download(url, site)
            videos, images, audios = collect(folder)
            files = [f for f in videos + images + audios if f.stat().st_size <= MAX_BYTES]
            too_big = len(videos + images + audios) - len(files)

            if not files:
                stop.set()
                await react(m, "😢")
                if too_big:
                    await m.reply("📦 Fayl juda katta (50 MB dan ortiq) — Telegram buni botlarga ruxsat bermaydi.")
                else:
                    await m.reply(
                        "😔 <b>Yuklab bo'lmadi.</b>\n\n"
                        "Ehtimol:\n• post yopiq (private) yoki o'chirilgan\n• havola noto'g'ri\n\n"
                        "Boshqa havola bilan urinib ko'ring 🔁"
                    )
                return

            await set_status(status, f"{emoji} <b>{site}</b>\n📤 Yuborilmoqda...")
            items = []
            for f in files:
                ext = f.suffix.lower()
                kind = "video" if ext in VIDEO_EXT else "photo" if ext in IMAGE_EXT else "audio"
                items.append((kind, FSInputFile(f)))
            cap = build_caption(site, info, me.username, time.monotonic() - t0)
            kinds = {k for k, _ in items}
            sent = await send_items(m, items, cap, action_kb(url, me.username, "video" in kinds, "photo" in kinds))

        if len(cache) > 3000:
            cache.clear()
        cache[key] = {"items": sent, "cap": build_caption(site, info, me.username, None)}
        await react(m, "🔥")
    except Exception as e:  # noqa: BLE001
        log.exception("Yuborishda xato: %s", e)
        await react(m, "😢")
        await m.reply("⚠️ Kutilmagan xatolik. Birozdan so'ng qayta urinib ko'ring 🔁")
    finally:
        stop.set()
        typing.cancel()
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
        await c.answer("⌛ Havola eskirgan, qaytadan yuboring.", show_alert=True)
        return
    me = await c.bot.me()
    site = detect_site(url) or "Video"
    key = "mp3:" + cache_key(url)

    if key in cache:
        await c.answer("⚡ Tayyor!")
        await c.message.answer_audio(cache[key]["file_id"], caption=f"🎶 Musiqa\n\n📥 @{me.username}")
        return

    await c.answer("🎶 Musiqa ajratilmoqda...")
    stop = asyncio.Event()
    typing = asyncio.create_task(keep_action(c.bot, c.message.chat.id, ChatAction.UPLOAD_VOICE, stop))
    folder = None
    try:
        async with sem:
            folder, info = await download(url, site, audio=True)
        _, _, audios = collect(folder)
        audios = [a for a in audios if a.stat().st_size <= MAX_BYTES]
        if audios:
            title = html.escape((info.get("title") or "Musiqa")[:100])
            r = await c.message.answer_audio(
                FSInputFile(audios[0]),
                title=info.get("title"),
                performer=info.get("uploader"),
                caption=f"🎶 <b>{title}</b>\n\n📥 @{me.username}",
            )
            cache[key] = {"file_id": r.audio.file_id}
        else:
            await c.message.answer("😔 Bu videodan musiqani ajratib bo'lmadi.")
    except Exception as e:  # noqa: BLE001
        log.exception("MP3 xato: %s", e)
        await c.message.answer("⚠️ Xatolik yuz berdi, qayta urinib ko'ring 🔁")
    finally:
        stop.set()
        typing.cancel()
        if folder:
            shutil.rmtree(folder, ignore_errors=True)


@dp.callback_query(F.data.startswith("hd:"))
async def on_hd(c: CallbackQuery):
    url = links.get(c.data[3:])
    if not url:
        await c.answer("⌛ Havola eskirgan, qaytadan yuboring.", show_alert=True)
        return
    me = await c.bot.me()
    site = detect_site(url) or "Rasm"
    key = "hd:" + cache_key(url)

    if key in cache:
        await c.answer("⚡ Tayyor!")
        for fid in cache[key]["file_ids"]:
            await c.message.answer_document(fid)
        return

    await c.answer("🖼 Original sifat tayyorlanmoqda...")
    stop = asyncio.Event()
    typing = asyncio.create_task(keep_action(c.bot, c.message.chat.id, ChatAction.UPLOAD_DOCUMENT, stop))
    folder = None
    try:
        async with sem:
            folder, _ = await download(url, site)
        _, images, _ = collect(folder)
        images = [i for i in images if i.stat().st_size <= MAX_BYTES]
        if not images:
            await c.message.answer("😔 Original rasmni olib bo'lmadi.")
            return
        ids = []
        for n, img in enumerate(images[:10]):
            r = await c.message.answer_document(
                FSInputFile(img),
                caption=f"🖼 Original sifat • {SITE_EMOJI.get(site, '🌐')} {site}\n\n📥 @{me.username}" if n == 0 else None,
            )
            ids.append(r.document.file_id)
        cache[key] = {"file_ids": ids}
    except Exception as e:  # noqa: BLE001
        log.exception("HD xato: %s", e)
        await c.message.answer("⚠️ Xatolik yuz berdi, qayta urinib ko'ring 🔁")
    finally:
        stop.set()
        typing.cancel()
        if folder:
            shutil.rmtree(folder, ignore_errors=True)


@dp.message(F.chat.type == "private")
async def on_other(m: Message):
    await m.answer("🔗 Menga video yoki rasm <b>havolasini</b> yuboring — bir zumda yuklab beraman ⚡")


# ---------- Bot profilini avtomatik sozlash ----------
BOT_NAME = "Forward Save"
BOT_ABOUT = "Rasm/videolarni musiqasi bilan yuklab beraman 📥 Insta · YouTube · TikTok · Pinterest 👨‍💻 " + ADMIN
BOT_DESCRIPTION = (
    "Insta, YouTube, TikTok, Pinterest, SnapChat, Facebook tarmoqlaridan "
    "rasm/videolarni musiqasi bilan yuklab beraman📥\n\n"
    "⚡ Tez  💎 1080p HD  🎶 MP3  🆓 Bepul\n\n"
    f"👨‍💻: {ADMIN}"
)
AVATAR_IMG = Path(__file__).parent / "assets" / "avatar.jpg"


async def setup_profile(bot: Bot) -> None:
    try:
        await bot.set_my_commands([
            BotCommand(command="start", description="🚀 Botni ishga tushirish"),
            BotCommand(command="help", description="📖 Qanday ishlatiladi"),
        ])
        await bot.set_my_description(description=BOT_DESCRIPTION)
        await bot.set_my_short_description(short_description=BOT_ABOUT[:120])
        current = await bot.get_my_name()
        if current.name != BOT_NAME:
            await bot.set_my_name(name=BOT_NAME)
            if AVATAR_IMG.exists():
                await bot.set_my_profile_photo(photo=InputProfilePhotoStatic(photo=FSInputFile(AVATAR_IMG)))
            log.info("Bot profili yangilandi: nom, rasm, tavsif")
    except Exception as e:  # noqa: BLE001
        log.warning("Profilni sozlab bo'lmadi: %s", e)


# ---------- Ishga tushirish ----------
async def health(_request):
    return web.Response(text="Forward Save bot ishlayapti ✅")


async def main():
    if not BOT_TOKEN:
        raise SystemExit("BOT_TOKEN o'rnatilmagan!")
    bot = Bot(BOT_TOKEN, default=DefaultBotProperties(parse_mode=ParseMode.HTML))

    app = web.Application()
    app.router.add_get("/", health)
    runner = web.AppRunner(app)
    await runner.setup()
    await web.TCPSite(runner, "0.0.0.0", PORT).start()

    await bot.delete_webhook(drop_pending_updates=True)
    asyncio.create_task(setup_profile(bot))
    log.info("Bot ishga tushdi")
    await dp.start_polling(bot)


if __name__ == "__main__":
    asyncio.run(main())
