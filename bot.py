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
from aiogram import BaseMiddleware, Bot, Dispatcher, F
from aiogram.exceptions import TelegramForbiddenError, TelegramRetryAfter

import db
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
ADMIN_USERNAMES = {u.strip().lstrip("@").lower() for u in os.getenv("ADMINS", "Forward_admin1,azimsher").split(",") if u.strip()}
ADMIN_IDS = {int(x) for x in os.getenv("ADMIN_IDS", "").replace(" ", "").split(",") if x.isdigit()}
broadcast_wait: set[int] = set()
pending_broadcast: dict[int, tuple[int, int]] = {}


def is_admin(user) -> bool:
    return bool(user) and (user.id in ADMIN_IDS or (user.username or "").lower() in ADMIN_USERNAMES)


def track(user_id: int, chat_type: str, site: str, kind: str, ok: bool, seconds: float) -> None:
    asyncio.create_task(db.log_download(user_id, chat_type, site, kind, ok, seconds))


class Gate(BaseMiddleware):
    """Har bir xabarda foydalanuvchini statistika uchun bazaga yozadi. Hech narsani cheklamaydi."""

    async def __call__(self, handler, event, data):
        user = getattr(event, "from_user", None)
        if user and not user.is_bot and isinstance(event, Message) and event.chat.type == "private":
            asyncio.create_task(db.touch_user(user))
        return await handler(event, data)


dp.message.outer_middleware(Gate())
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
        "🎧 Faqat musiqa kerakmi? <code>/mp3 havola</code> yoki havola + <b>mp3</b>\n"
        "🔎 Qo'shiq nomini yozing — topib, MP3 qilib beraman\n"
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
    lines.append(f'🌐 <a href="{BRAND_TG}">FORWARD® | Premium Brand</a>')
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
# ---------- FORWARD brendi ----------
BRAND_IG = "https://www.instagram.com/forward.uzbekistan"
BRAND_TG = "https://t.me/forwardtowardsdreams"
BRAND_YT = "https://www.youtube.com/@FORWARD-9707"
BRAND_TEXT = (
    "🌐 <b>FORWARD® | Premium Brand</b>\n\n"
    "✨ Premium sifatdagi mahsulot\n"
    "🌫️ Kafel • Qurilish materiallari\n"
    "🛠️ Professional uskunalar\n"
    "💎 Ishonchli tanlov\n"
    "💸 Eng maqbul narxlar\n"
    "🚚 🇺🇿 bo‘ylab yetkazib berish\n\n"
    "📱 +998945650779\n"
    "📱 +998934069707\n\n"
    f'📸 <a href="{BRAND_IG}">Instagram</a>  |  ✈️ <a href="{BRAND_TG}">Telegram</a>  |  ▶️ <a href="{BRAND_YT}">YouTube</a>'
)

# Kanal postlariga avtomatik imzo
BRAND_CHANNELS = {c.strip().lstrip("@").lower() for c in os.getenv("BRAND_CHANNELS", "forwardtowardsdreams").split(",") if c.strip()}
SIGN_MARK = "FORWARD® | Premium Brand"
SIGNATURE = (
    "\n\n━━━━━━━━━━━━━━━\n"
    f"🌐 <b>{SIGN_MARK}</b>\n"
    "📱 +998945650779\n"
    "📱 +998934069707\n"
    f'📸 <a href="{BRAND_IG}">Instagram</a>  |  ✈️ <a href="{BRAND_TG}">Telegram</a>  |  ▶️ <a href="{BRAND_YT}">YouTube</a>'
)


@dp.channel_post()
async def on_channel_post(post: Message):
    """Brend kanalidagi har bir yangi post ostiga imzo qo'shadi (bot kanalda admin bo'lishi kerak)."""
    if (post.chat.username or "").lower() not in BRAND_CHANNELS:
        return
    try:
        if post.text is not None:
            body = post.html_text
            if SIGN_MARK in (post.text or "") or len(post.text) + 220 > 4096:
                return
            await post.edit_text(body + SIGNATURE, disable_web_page_preview=True)
        elif post.caption is not None or (post.photo or post.video or post.document or post.audio or post.animation):
            if post.media_group_id and not post.caption:
                return  # albomda imzo faqat matnli birinchi rasmga qo'yiladi
            body = post.html_text if post.caption else ""
            if SIGN_MARK in (post.caption or "") or len(post.caption or "") + 220 > 1024:
                return
            await post.edit_caption(caption=(body + SIGNATURE).lstrip("\n"))
    except Exception as e:  # noqa: BLE001
        log.warning("Kanal postiga imzo qo'yib bo'lmadi: %s", e)


def brand_kb() -> InlineKeyboardMarkup:
    return InlineKeyboardMarkup(inline_keyboard=[
        [InlineKeyboardButton(text="📸 Instagram", url=BRAND_IG),
         InlineKeyboardButton(text="✈️ Telegram", url=BRAND_TG)],
        [InlineKeyboardButton(text="▶️ YouTube", url=BRAND_YT)],
    ])


# ---------- Kanalni boshqarish (faqat admin) ----------
from datetime import datetime, timedelta, timezone

UZ_TZ = timezone(timedelta(hours=5))  # O'zbekiston vaqti (yozgi vaqt yo'q)
POST_CHANNEL = "@" + sorted(BRAND_CHANNELS)[0] if BRAND_CHANNELS else None
post_wait: set[int] = set()
sched_wait: set[int] = set()
drafts: dict[int, dict] = {}
SHORT_SIGN = f'\n\n🌐 <b>{SIGN_MARK}</b> · <a href="{BRAND_IG}">Instagram</a> | <a href="{BRAND_TG}">Telegram</a>'


def channel_buttons() -> InlineKeyboardMarkup:
    return InlineKeyboardMarkup(inline_keyboard=[
        [InlineKeyboardButton(text="💬 Buyurtma berish", url=f"https://t.me/{ADMIN.lstrip('@')}")],
        [InlineKeyboardButton(text="📸 Instagram", url=BRAND_IG),
         InlineKeyboardButton(text="▶️ YouTube", url=BRAND_YT)],
    ])


def signed(html_text: str, kind: str) -> str:
    if SIGN_MARK in html_text:
        return html_text
    limit = 4096 if kind == "text" else 1024
    for sig in (SIGNATURE, SHORT_SIGN):
        if len(html_text) + len(sig) <= limit:
            return (html_text + sig).lstrip("\n")
    return html_text


def draft_kb(d: dict) -> InlineKeyboardMarkup:
    on = lambda v: "✅" if v else "❌"  # noqa: E731
    return InlineKeyboardMarkup(inline_keyboard=[
        [InlineKeyboardButton(text="📤 Hozir chiqarish", callback_data="pst:now"),
         InlineKeyboardButton(text="⏰ Rejalashtirish", callback_data="pst:sched")],
        [InlineKeyboardButton(text=f"🔘 Tugmalar {on(d['buttons'])}", callback_data="pst:btn"),
         InlineKeyboardButton(text=f"📌 Pin {on(d['pin'])}", callback_data="pst:pin")],
        [InlineKeyboardButton(text="❌ Bekor qilish", callback_data="pst:cancel")],
    ])


async def publish(bot: Bot, src_chat: int, src_msg: int, kind: str, html_text: str, buttons: bool, pin: bool):
    kb = channel_buttons() if buttons else None
    body = signed(html_text or "", kind)
    if kind == "text":
        sent = await bot.send_message(POST_CHANNEL, body, reply_markup=kb, disable_web_page_preview=True)
        msg_id = sent.message_id
    else:
        sent = await bot.copy_message(POST_CHANNEL, src_chat, src_msg, caption=body, reply_markup=kb)
        msg_id = sent.message_id
    if pin:
        try:
            await bot.pin_chat_message(POST_CHANNEL, msg_id, disable_notification=False)
        except Exception as e:  # noqa: BLE001
            log.warning("Pin qilib bo'lmadi: %s", e)
    return msg_id


def post_link(msg_id: int) -> str:
    return f"https://t.me/{POST_CHANNEL.lstrip('@')}/{msg_id}"


def parse_when(text: str) -> datetime | None:
    t = text.strip().lower().replace("ertaga", "+1").replace("bugun", "")
    now = datetime.now(UZ_TZ)
    m = re.match(r"^\s*(\+1)?\s*(\d{1,2})[:.](\d{2})\s*$", t)
    if m:
        h, mi = int(m.group(2)), int(m.group(3))
        if h > 23 or mi > 59:
            return None
        dt = now.replace(hour=h, minute=mi, second=0, microsecond=0)
        if m.group(1):
            dt += timedelta(days=1)
        elif dt <= now:
            dt += timedelta(days=1)
        return dt
    m = re.match(r"^\s*(\d{1,2})[./](\d{1,2})(?:[./](\d{2,4}))?\s+(\d{1,2})[:.](\d{2})\s*$", t)
    if m:
        d, mo = int(m.group(1)), int(m.group(2))
        y = int(m.group(3)) if m.group(3) else now.year
        if y < 100:
            y += 2000
        try:
            dt = datetime(y, mo, d, int(m.group(4)), int(m.group(5)), tzinfo=UZ_TZ)
        except ValueError:
            return None
        return dt if dt > now else None
    return None


async def show_draft(m: Message, d: dict) -> None:
    """Postning kanalda qanday ko'rinishini ko'rsatadi + boshqaruv tugmalari."""
    kb = channel_buttons() if d["buttons"] else None
    body = signed(d["html"] or "", d["kind"])
    try:
        if d["kind"] == "text":
            await m.answer(body, reply_markup=kb, disable_web_page_preview=True)
        else:
            await m.bot.copy_message(m.chat.id, d["src_chat"], d["src_msg"], caption=body, reply_markup=kb)
    except Exception as e:  # noqa: BLE001
        await m.answer(f"⚠️ Ko'rinishni chiqarib bo'lmadi: {html.escape(str(e)[:150])}")
    await m.answer(f"👆 <b>Kanalda shunday chiqadi</b> ({POST_CHANNEL})\nNima qilamiz?", reply_markup=draft_kb(d))


@dp.message(Command("post"), F.func(lambda m: is_admin(m.from_user)))
async def on_post_cmd(m: Message):
    if not POST_CHANNEL:
        await m.answer("Kanal sozlanmagan.")
        return
    post_wait.add(m.from_user.id)
    sched_wait.discard(m.from_user.id)
    await m.answer(
        f"✍️ <b>{POST_CHANNEL} uchun yangi post</b>\n\n"
        "Menga yuboring:\n"
        "• matn, rasm yoki video (izohi bilan)\n"
        "• yoki <b>Instagram/TikTok/YouTube havolasi</b> — o'zim yuklab, post tayyorlayman\n\n"
        "Bekor qilish: /cancel"
    )


@dp.message(Command("posts"), F.func(lambda m: is_admin(m.from_user)))
async def on_posts_list(m: Message):
    rows = await db.upcoming_posts()
    if not rows:
        await m.answer("⏰ Rejalashtirilgan post yo'q.")
        return
    lines = ["⏰ <b>Rejalashtirilgan postlar</b>\n"]
    kb = []
    for r in rows:
        when = r["run_at"].astimezone(UZ_TZ).strftime("%d.%m %H:%M")
        preview = re.sub(r"<[^>]+>", "", r["html"] or "")[:40] or ("🖼 media" if r["kind"] != "text" else "")
        lines.append(f"<b>#{r['id']}</b> · {when} · {html.escape(preview)}")
        kb.append([InlineKeyboardButton(text=f"🗑 #{r['id']} ni bekor qilish", callback_data=f"pst:del:{r['id']}")])
    await m.answer("\n".join(lines), reply_markup=InlineKeyboardMarkup(inline_keyboard=kb))


@dp.message(F.func(lambda m: m.from_user and m.from_user.id in sched_wait and m.text and not m.text.startswith("/")))
async def on_sched_time(m: Message):
    d = drafts.get(m.from_user.id)
    when = parse_when(m.text)
    if not d or not when:
        await m.answer("🕐 Vaqtni tushunmadim. Masalan: <code>21:30</code>, <code>ertaga 09:00</code> yoki <code>05.11 18:00</code>")
        return
    sched_wait.discard(m.from_user.id)
    pid = await db.add_post(m.chat.id, d["src_chat"], d["src_msg"], d["kind"], d["html"], d["buttons"], d["pin"],
                            when.astimezone(timezone.utc))
    drafts.pop(m.from_user.id, None)
    if pid:
        await m.answer(f"✅ Post <b>#{pid}</b> rejalashtirildi: <b>{when.strftime('%d.%m.%Y %H:%M')}</b>\nRo'yxat: /posts")
    else:
        await m.answer("⚠️ Saqlab bo'lmadi (baza ulanmagan).")


@dp.message(F.func(lambda m: m.from_user and m.from_user.id in post_wait and not (m.text or "").startswith("/")))
async def on_post_content(m: Message):
    post_wait.discard(m.from_user.id)
    d = {"buttons": True, "pin": False}
    url_m = URL_RE.fullmatch((m.text or "").strip())
    if url_m and detect_site(url_m.group(0)):
        url = url_m.group(0)
        site = detect_site(url)
        status = await m.answer(f"{SITE_EMOJI.get(site, '🌐')} {site} dan post tayyorlanmoqda...")
        folder = None
        try:
            async with sem:
                folder, info = await download(url, site)
            videos, images, _ = collect(folder)
            files = [f for f in videos + images if f.stat().st_size <= MAX_BYTES]
            if not files:
                await m.answer("😔 Bu havoladan media olib bo'lmadi. Boshqa havola yoki faylni o'zingiz yuboring: /post")
                return
            cap = (info.get("description") or info.get("title") or "").strip()
            cap_html = html.escape(cap[:700])
            f = files[0]
            if f.suffix.lower() in VIDEO_EXT:
                src = await m.answer_video(FSInputFile(f), caption=cap_html or None, supports_streaming=True)
            else:
                src = await m.answer_photo(FSInputFile(f), caption=cap_html or None)
            d.update(src_chat=src.chat.id, src_msg=src.message_id, kind="media", html=cap_html)
        finally:
            if folder:
                shutil.rmtree(folder, ignore_errors=True)
            try:
                await status.delete()
            except Exception:  # noqa: BLE001
                pass
    elif m.text:
        d.update(src_chat=m.chat.id, src_msg=m.message_id, kind="text", html=m.html_text)
    elif m.photo or m.video or m.animation or m.document or m.audio:
        d.update(src_chat=m.chat.id, src_msg=m.message_id, kind="media", html=m.html_text if m.caption else "")
    else:
        await m.answer("Bu turdagi xabarni post qilib bo'lmaydi. Matn, rasm yoki video yuboring: /post")
        return
    drafts[m.from_user.id] = d
    await show_draft(m, d)


@dp.callback_query(F.data.startswith("pst:"), F.func(lambda c: is_admin(c.from_user)))
async def on_post_cb(c: CallbackQuery):
    act = c.data[4:]
    if act.startswith("del:"):
        pid = int(act[4:])
        await db.finish_post(pid)
        await c.answer(f"#{pid} bekor qilindi")
        await c.message.edit_reply_markup(reply_markup=None)
        return
    d = drafts.get(c.from_user.id)
    if not d:
        await c.answer("Qoralama topilmadi. /post bilan qaytadan boshlang", show_alert=True)
        return
    if act in ("btn", "pin"):
        key = "buttons" if act == "btn" else "pin"
        d[key] = not d[key]
        await c.answer("✅ Yoqildi" if d[key] else "❌ O'chirildi")
        await c.message.edit_reply_markup(reply_markup=draft_kb(d))
    elif act == "now":
        await c.answer("📤 Chiqarilmoqda...")
        try:
            mid = await publish(c.bot, d["src_chat"], d["src_msg"], d["kind"], d["html"], d["buttons"], d["pin"])
            drafts.pop(c.from_user.id, None)
            await c.message.edit_text(f'✅ Post kanalga chiqdi: <a href="{post_link(mid)}">ko\'rish</a>')
        except Exception as e:  # noqa: BLE001
            await c.message.answer(
                "⚠️ Kanalga chiqarib bo'lmadi. Botni kanalda <b>admin</b> qilib, "
                "<b>post qilish</b>, <b>tahrirlash</b> va <b>pin</b> ruxsatlarini bering.\n"
                f"<i>{html.escape(str(e)[:150])}</i>"
            )
    elif act == "sched":
        sched_wait.add(c.from_user.id)
        await c.answer()
        await c.message.answer(
            "🕐 Qachon chiqarilsin? (O'zbekiston vaqti)\n\n"
            "Masalan:\n<code>21:30</code> — bugun (o'tgan bo'lsa ertaga)\n"
            "<code>ertaga 09:00</code>\n<code>05.11 18:00</code>"
        )
    elif act == "cancel":
        drafts.pop(c.from_user.id, None)
        sched_wait.discard(c.from_user.id)
        await c.answer("Bekor qilindi")
        await c.message.edit_text("❌ Post bekor qilindi.")


async def scheduler(bot: Bot) -> None:
    """Har 30 soniyada vaqti kelgan postlarni kanalga chiqaradi."""
    await db.init_posts()
    while True:
        try:
            for r in await db.due_posts():
                await db.finish_post(r["id"])
                try:
                    mid = await publish(bot, r["src_chat"], r["src_msg"], r["kind"], r["html"] or "", r["buttons"], r["pin"])
                    await bot.send_message(r["admin_chat"], f'✅ Rejalashtirilgan post <b>#{r["id"]}</b> chiqdi: <a href="{post_link(mid)}">ko\'rish</a>')
                except Exception as e:  # noqa: BLE001
                    log.warning("Rejali post xatosi: %s", e)
                    await bot.send_message(r["admin_chat"], f"⚠️ Post #{r['id']} chiqmadi: {html.escape(str(e)[:150])}")
        except Exception as e:  # noqa: BLE001
            log.warning("Scheduler xatosi: %s", e)
        await asyncio.sleep(30)


@dp.message(Command("about", "forward"))
async def on_about(m: Message):
    await m.answer(BRAND_TEXT, reply_markup=brand_kb(), disable_web_page_preview=True)


@dp.callback_query(F.data == "brand")
async def on_brand_cb(c: CallbackQuery):
    await c.answer()
    await c.message.answer(BRAND_TEXT, reply_markup=brand_kb(), disable_web_page_preview=True)


@dp.message(CommandStart())
async def on_start(m: Message):
    me = await m.bot.me()
    kb = InlineKeyboardMarkup(
        inline_keyboard=[
            [InlineKeyboardButton(text="➕ Guruhga qo'shish", url=bot_link(me.username))],
            [InlineKeyboardButton(text="🌐 FORWARD® haqida", callback_data="brand"),
             InlineKeyboardButton(text="👨‍💻 Admin", url=f"https://t.me/{ADMIN.lstrip('@')}")],
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
        "🔎 <b>Qo'shiq qidirish:</b> shunchaki nomini yozing\n"
        "masalan: <i>Shoxrux Yurak</i>\n\n"
        "🎧 <b>Faqat MP3 (videosiz):</b>\n"
        "• <code>/mp3 havola</code>\n"
        "• yoki havola yonida <b>mp3</b> deb yozing\n"
        "• yoki havolaga javob qilib <code>/mp3</code> yozing\n\n"
        "👥 Guruhlarda ham ishlayman — meni guruhga qo'shing!\n\n"
        f"❓ Savollar: {ADMIN}"
    )


# ---------- Admin panel ----------
def fmt_stats(st: dict | None) -> str:
    if not st:
        return "📊 Statistika uchun baza ulanmagan."
    m = st["main"]
    rows = [
        ("Jami foydalanuvchi", m.get("users", 0)),
        ("Bugun qo'shilgan", m.get("new_day", 0)),
        ("7 kunda qo'shilgan", m.get("new_week", 0)),
        ("24 soatda faol", m.get("active_day", 0)),
        ("Botni bloklagan", m.get("blocked", 0)),
        ("Bugun yuklash", m.get("dl_day", 0)),
        ("Bugun muvaffaqiyatli", m.get("dl_day_ok", 0)),
        ("Jami yuklash", m.get("dl_total", 0)),
        ("O'rtacha tezlik, s", m.get("avg_sec") or "-"),
    ]
    w = max(len(r[0]) for r in rows)
    table = "\n".join(f"{k.ljust(w)}  {v}" for k, v in rows)
    sites = "\n".join(f"{(r['site'] or '-').ljust(10)} {r['n']}" for r in st["sites"]) or "-"
    kinds = "\n".join(f"{(r['kind'] or '-').ljust(10)} {r['n']}" for r in st["kinds"]) or "-"
    return (
        "📊 <b>FORWARD SAVE — statistika</b>\n\n"
        f"<pre>{html.escape(table)}</pre>\n"
        f"<b>Tarmoqlar (7 kun):</b>\n<pre>{html.escape(sites)}</pre>\n"
        f"<b>Turlar (7 kun):</b>\n<pre>{html.escape(kinds)}</pre>"
    )


def admin_kb() -> InlineKeyboardMarkup:
    return InlineKeyboardMarkup(inline_keyboard=[
        [InlineKeyboardButton(text="🔄 Yangilash", callback_data="adm:stat"),
         InlineKeyboardButton(text="📨 Xabar yuborish", callback_data="adm:send")],
        [InlineKeyboardButton(text="✍️ Kanalga post", callback_data="adm:post"),
         InlineKeyboardButton(text="⏰ Rejadagi postlar", callback_data="adm:posts")],
    ])


@dp.message(Command("admin", "stat"), F.func(lambda m: is_admin(m.from_user)))
async def on_admin(m: Message):
    await m.answer(fmt_stats(await db.stats()), reply_markup=admin_kb())


@dp.callback_query(F.data.startswith("adm:"), F.func(lambda c: is_admin(c.from_user)))
async def on_admin_cb(c: CallbackQuery):
    act = c.data[4:]
    if act == "stat":
        await c.answer("🔄")
        try:
            await c.message.edit_text(fmt_stats(await db.stats()), reply_markup=admin_kb())
        except Exception:  # noqa: BLE001
            pass
    elif act == "send":
        await c.answer()
        broadcast_wait.add(c.from_user.id)
        await c.message.answer("📨 Hammaga yuboriladigan xabarni yuboring (matn, rasm, video — istalgani).\nBekor qilish: /cancel")
    elif act == "post":
        await c.answer()
        await on_post_cmd(c.message.model_copy(update={"from_user": c.from_user}))
    elif act == "posts":
        await c.answer()
        await on_posts_list(c.message)
    elif act == "go":
        pend = pending_broadcast.pop(c.from_user.id, None)
        if not pend:
            await c.answer("Xabar topilmadi", show_alert=True)
            return
        await c.answer("🚀 Boshlandi")
        await c.message.edit_reply_markup(reply_markup=None)
        asyncio.create_task(run_broadcast(c.bot, c.message.chat.id, *pend))
    elif act == "no":
        pending_broadcast.pop(c.from_user.id, None)
        await c.answer("Bekor qilindi")
        await c.message.edit_text("❌ Yuborish bekor qilindi.")


@dp.message(Command("cancel"), F.func(lambda m: is_admin(m.from_user)))
async def on_cancel(m: Message):
    broadcast_wait.discard(m.from_user.id)
    pending_broadcast.pop(m.from_user.id, None)
    post_wait.discard(m.from_user.id)
    sched_wait.discard(m.from_user.id)
    drafts.pop(m.from_user.id, None)
    await m.answer("❌ Bekor qilindi.")


@dp.message(F.func(lambda m: m.from_user and m.from_user.id in broadcast_wait))
async def on_broadcast_content(m: Message):
    broadcast_wait.discard(m.from_user.id)
    pending_broadcast[m.from_user.id] = (m.chat.id, m.message_id)
    n = len(await db.active_user_ids())
    await m.answer(
        f"👆 Shu xabar <b>{n}</b> ta foydalanuvchiga yuboriladi. Tasdiqlaysizmi?",
        reply_markup=InlineKeyboardMarkup(inline_keyboard=[[
            InlineKeyboardButton(text="✅ Yuborish", callback_data="adm:go"),
            InlineKeyboardButton(text="❌ Bekor", callback_data="adm:no"),
        ]]),
    )


async def run_broadcast(bot: Bot, report_chat: int, from_chat: int, msg_id: int) -> None:
    ids = await db.active_user_ids()
    ok = blocked = failed = 0
    status = await bot.send_message(report_chat, f"📨 Yuborilmoqda... 0/{len(ids)}")
    for i, uid in enumerate(ids, 1):
        for _ in range(2):
            try:
                await bot.copy_message(uid, from_chat, msg_id)
                ok += 1
                break
            except TelegramRetryAfter as e:
                await asyncio.sleep(e.retry_after + 1)
            except TelegramForbiddenError:
                blocked += 1
                await db.mark_blocked(uid)
                break
            except Exception:  # noqa: BLE001
                failed += 1
                break
        await asyncio.sleep(0.05)  # Telegram limiti: sekundiga ~20 ta
        if i % 100 == 0:
            try:
                await status.edit_text(f"📨 Yuborilmoqda... {i}/{len(ids)}")
            except Exception:  # noqa: BLE001
                pass
    await status.edit_text(
        "✅ <b>Yuborish tugadi</b>\n\n"
        f"<pre>Yetkazildi   {ok}\nBloklagan    {blocked}\nXato         {failed}\nJami         {len(ids)}</pre>"
    )


MP3_WORD = re.compile(r"(^|\s)/?(mp3|musiqa|audio)(@\w+)?(\s|$)", re.IGNORECASE)


@dp.message(Command("mp3"))
async def on_mp3_command(m: Message):
    found = URL_RE.search(m.text or "")
    if not found and m.reply_to_message:
        found = URL_RE.search(m.reply_to_message.text or m.reply_to_message.caption or "")
    if not found:
        await m.answer(
            "🎶 <b>Faqat musiqa olish:</b>\n\n"
            "<code>/mp3 havola</code> deb yozing\n"
            "yoki havolaning oldiga/ortiga <b>mp3</b> so'zini qo'shing.\n\n"
            "Masalan:\n<code>/mp3 https://www.tiktok.com/@.../video/...</code>"
        )
        return
    url = found.group(0)
    if not detect_site(url):
        await m.answer("🤔 Bu saytni hali tanimayman.")
        return
    await react(m, "👌")
    await deliver_mp3(m, url, reply=True, user_id=m.from_user.id if m.from_user else 0)


@dp.message(F.text.regexp(URL_RE) & F.text.regexp(MP3_WORD))
async def on_link_mp3(m: Message):
    url = URL_RE.search(m.text).group(0)
    if not detect_site(url):
        return
    await react(m, "👌")
    await deliver_mp3(m, url, reply=True, user_id=m.from_user.id if m.from_user else 0)


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
            track(m.from_user.id if m.from_user else 0, m.chat.type, site, "kesh", True, 0)
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
                track(m.from_user.id if m.from_user else 0, m.chat.type, site, "media", False, time.monotonic() - t0)
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
        track(m.from_user.id if m.from_user else 0, m.chat.type, site,
              "video" if "video" in kinds else "rasm", True, time.monotonic() - t0)
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
    await c.answer("🎶 Musiqa ajratilmoqda...")
    await deliver_mp3(c.message, url, user_id=c.from_user.id)


async def deliver_mp3(target: Message, url: str, reply: bool = False, user_id: int = 0) -> None:
    """Havoladan faqat musiqani (MP3) ajratib yuboradi."""
    bot = target.bot
    me = await bot.me()
    site = detect_site(url) or "Video"
    key = "mp3:" + cache_key(url)
    send = target.reply_audio if reply else target.answer_audio

    if key in cache:
        await send(cache[key]["file_id"], caption=cache[key].get("cap") or f"🎶 Musiqa\n\n📥 @{me.username}")
        return

    stop = asyncio.Event()
    typing = asyncio.create_task(keep_action(bot, target.chat.id, ChatAction.UPLOAD_VOICE, stop))
    folder = None
    t0 = time.monotonic()
    try:
        async with sem:
            folder, info = await download(url, site, audio=True)
        _, _, audios = collect(folder)
        audios = [a for a in audios if a.stat().st_size <= MAX_BYTES]
        if audios:
            title = html.escape((info.get("title") or "Musiqa")[:100])
            author = info.get("uploader") or info.get("channel")
            cap = f"🎶 <b>{title}</b>\n"
            if author:
                cap += f"👤 {html.escape(str(author)[:60])}\n"
            cap += f"{SITE_EMOJI.get(site, '🌐')} {site}  •  ⚡ {time.monotonic() - t0:.1f} soniyada\n\n🔵🔴 <b>FORWARD SAVE</b> · @{me.username}"
            r = await send(
                FSInputFile(audios[0]),
                title=info.get("title"),
                performer=author,
                caption=cap,
            )
            track(user_id, target.chat.type, site, "mp3", True, time.monotonic() - t0)
            cache[key] = {"file_id": r.audio.file_id, "cap": cap.split("  •  ⚡")[0] + f"\n\n🔵🔴 <b>FORWARD SAVE</b> · @{me.username}"}
        else:
            track(user_id, target.chat.type, site, "mp3", False, time.monotonic() - t0)
            await target.answer("😔 Bu havoladan musiqani ajratib bo'lmadi.")
    except Exception as e:  # noqa: BLE001
        log.exception("MP3 xato: %s", e)
        await target.answer("⚠️ Xatolik yuz berdi, qayta urinib ko'ring 🔁")
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


# ---------- Qo'shiq qidirish ----------
async def search_songs(query: str) -> list[tuple[str, str, int | None, str]]:
    def _s(prefix):
        opts = {"quiet": True, "no_warnings": True, "extract_flat": True, "skip_download": True}
        with yt_dlp.YoutubeDL(opts) as y:
            r = y.extract_info(f"{prefix}8:{query}", download=False) or {}
            return r.get("entries") or []

    out = []
    for prefix in ("ytsearch", "scsearch"):  # YouTube, topilmasa SoundCloud
        try:
            ents = await asyncio.wait_for(asyncio.to_thread(_s, prefix), timeout=25)
        except Exception as e:  # noqa: BLE001
            log.warning("Qidiruv xatosi (%s): %s", prefix, str(e)[:150])
            ents = []
        for e in ents:
            if not e:
                continue
            url = e.get("url") or e.get("webpage_url")
            if prefix == "ytsearch" and e.get("id"):
                url = f"https://www.youtube.com/watch?v={e['id']}"
            dur = e.get("duration")
            if url and (not dur or dur <= 900):  # 15 daqiqadan uzunlari — qo'shiq emas
                out.append((e.get("title") or "?", e.get("channel") or e.get("uploader") or "", dur, url))
        if out:
            break
    return out[:6]


def fmt_dur(sec) -> str:
    if not sec:
        return ""
    sec = int(sec)
    return f"{sec // 60}:{sec % 60:02d}"


@dp.message(F.chat.type == "private", F.text, ~F.text.startswith("/"))
async def on_search(m: Message):
    q = m.text.strip()
    if len(q) < 2 or len(q) > 100:
        await m.answer("🔗 Havola yuboring yoki 🔎 qo'shiq nomini yozing (masalan: <i>Shoxrux Yurak</i>)")
        return
    status = await m.reply(f"🔎 <b>{html.escape(q)}</b> qidirilmoqda...")
    results = await search_songs(q)
    try:
        await status.delete()
    except Exception:  # noqa: BLE001
        pass
    if not results:
        await m.reply("😔 Hech narsa topilmadi. Boshqacha yozib ko'ring yoki havola yuboring 🔗")
        return
    lines = [f"🎵 <b>{html.escape(q)}</b> bo'yicha topildi:\n"]
    buttons = []
    for i, (title, author, dur, url) in enumerate(results, 1):
        meta = " · ".join(x for x in (author[:30], fmt_dur(dur)) if x)
        lines.append(f"<b>{i}.</b> {html.escape(title[:70])}" + (f"\n     <i>{html.escape(meta)}</i>" if meta else ""))
        key = uuid.uuid4().hex[:12]
        links[key] = url
        buttons.append(InlineKeyboardButton(text=f"{i} 🎶", callback_data=f"mp3:{key}"))
    lines.append("\n👇 Raqamni bosing — MP3 darhol keladi")
    rows = [buttons[i:i + 3] for i in range(0, len(buttons), 3)]
    await m.reply("\n".join(lines), reply_markup=InlineKeyboardMarkup(inline_keyboard=rows))


@dp.message(F.chat.type == "private")
async def on_other(m: Message):
    await m.answer("🔗 Menga video yoki rasm <b>havolasini</b> yuboring yoki 🔎 qo'shiq nomini yozing ⚡")


# ---------- Bot profilini avtomatik sozlash ----------
BOT_NAME = "Forward Save"
BOT_ABOUT = "Rasm/videolarni musiqasi bilan yuklab beraman 📥 Insta · YouTube · TikTok · Pinterest 👨‍💻 " + ADMIN
BOT_DESCRIPTION = (
    "Insta, YouTube, TikTok, Pinterest, SnapChat, Facebook tarmoqlaridan "
    "rasm/videolarni musiqasi bilan yuklab beraman📥\n\n"
    "⚡ Tez  💎 1080p HD  🎶 MP3  🆓 Bepul\n\n"
    "🌐 FORWARD® | Premium Brand — kafel, qurilish materiallari, professional uskunalar\n"
    "📱 +998 94 565 07 79 · +998 93 406 97 07\n\n"
    f"👨‍💻: {ADMIN}"
)
AVATAR_IMG = Path(__file__).parent / "assets" / "avatar.jpg"


async def setup_profile(bot: Bot) -> None:
    try:
        await bot.set_my_commands([
            BotCommand(command="start", description="🚀 Botni ishga tushirish"),
            BotCommand(command="mp3", description="🎧 Faqat musiqa (MP3) olish"),
            BotCommand(command="help", description="📖 Qanday ishlatiladi"),
            BotCommand(command="about", description="🌐 FORWARD® haqida"),
        ])
        await bot.set_my_description(description=BOT_DESCRIPTION)
        await bot.set_my_short_description(short_description=BOT_ABOUT[:120])
        current = await bot.get_my_name()
        if current.name != BOT_NAME:
            await bot.set_my_name(name=BOT_NAME)
        if AVATAR_IMG.exists():
            # eski rasm tarixda to'planib qolmasligi uchun avval o'chiramiz
            try:
                await bot.remove_my_profile_photo()
            except Exception:  # noqa: BLE001
                pass
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

    await db.init()
    await bot.delete_webhook(drop_pending_updates=True)
    asyncio.create_task(setup_profile(bot))
    asyncio.create_task(scheduler(bot))
    log.info("Bot ishga tushdi")
    await dp.start_polling(bot)


if __name__ == "__main__":
    asyncio.run(main())
