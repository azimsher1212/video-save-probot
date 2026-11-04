# 📥 Video Save ProBot

Instagram, YouTube, TikTok, Snapchat, Facebook dan rasm/videolarni musiqasi bilan yuklab beruvchi Telegram bot.
👨‍💻 @Forward_admin1

## Imkoniyatlar
- Havola yuborilsa — video (ovozi bilan) yoki rasmlar keladi
- Karusel postlar (bir nechta rasm/video) albom qilib yuboriladi
- 🎵 "Musiqasini yuklash" tugmasi — videodagi musiqani MP3 qilib beradi
- Bir vaqtda bir nechta foydalanuvchiga xizmat qiladi

## 1. Botni BotFather'da yaratish
1. Telegram'da **@BotFather** ga kiring → `/newbot` → nom: `Video Save ProBot`, username: masalan `VideoSaveProBot`
2. Berilgan **TOKEN**ni saqlab qo'ying
3. `/setuserpic` → logotip rasmini yuboring
4. `/setdescription` → quyidagini yozing:
   ```
   Insta, YouTube, TikTok, SnapChat, Facebook tarmoqlaridan rasm/videolarni musiqasi bilan yuklab beraman📥

   👨‍💻:@Forward_admin1
   ```
5. `/setabouttext` → `Rasm/videolarni musiqasi bilan yuklab beraman📥 👨‍💻:@Forward_admin1`
6. `/setcommands` → 
   ```
   start - Botni ishga tushirish
   help - Yordam
   ```

## 2. Kompyuterda ishga tushirish
FFmpeg o'rnatilgan bo'lishi kerak (https://ffmpeg.org).
```bash
pip install -r requirements.txt
export BOT_TOKEN="123456:ABC..."      # Windows: set BOT_TOKEN=123456:ABC...
python bot.py
```

## 3. Serverga joylash (Render.com, 24/7)
1. Papkani GitHub'ga yuklang
2. Render → **New → Web Service** → reponi tanlang → Runtime: **Docker**
3. Environment: `BOT_TOKEN` = tokeningiz
4. Deploy. Tayyor ✅

> Render'ning bepul tarifi faoliyatsiz qolganda "uxlaydi". Doimiy ishlashi uchun pullik tarif yoki VPS (Hetzner, Timeweb, va h.k.) tavsiya qilinadi.

## Sozlamalar (environment)
| O'zgaruvchi | Vazifasi | Standart |
|---|---|---|
| `BOT_TOKEN` | BotFather tokeni | — (majburiy) |
| `ADMIN_USERNAME` | Xabarlarda ko'rinadigan admin | `@Forward_admin1` |
| `COOKIES_FILE` | cookies.txt yo'li | yo'q |
| `MAX_PARALLEL` | Bir vaqtdagi yuklashlar soni | `3` |

## Muhim eslatmalar
- **50 MB limiti:** Telegram oddiy botlarga 50 MB gacha fayl yuborishga ruxsat beradi. Shuning uchun YouTube videolar 720p gacha yuklanadi. 2 GB gacha kerak bo'lsa — o'zingizning *Local Bot API Server*ingizni ko'tarish kerak.
- **Instagram / YouTube bloklasa:** serverlardan kelgan so'rovlarni ba'zan "login qiling" deb to'xtatadi. Yechim — brauzerdan `cookies.txt` eksport qilib (masalan "Get cookies.txt LOCALLY" kengaytmasi), serverga qo'yib, `COOKIES_FILE` ga yo'lini yozish. Alohida (asosiy bo'lmagan) akkaunt ishlating.
- **yt-dlp yangilab turing:** saytlar tez-tez o'zgaradi. Muammo chiqsa: `pip install -U yt-dlp gallery-dl` va qayta deploy.
- Faqat ochiq (public) postlar yuklanadi.
