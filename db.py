"""Foydalanuvchilar, statistika va sozlamalar uchun ma'lumotlar bazasi (Neon Postgres).
DATABASE_URL berilmasa, bot bazasiz ham ishlayveradi — hech narsa buzilmaydi."""
import logging
import os

log = logging.getLogger("probot.db")
DATABASE_URL = os.getenv("DATABASE_URL", "")
pool = None


async def init() -> None:
    global pool
    if not DATABASE_URL:
        log.info("DATABASE_URL yo'q — statistika o'chiq")
        return
    try:
        import asyncpg

        pool = await asyncpg.create_pool(DATABASE_URL, min_size=0, max_size=3, command_timeout=15)
        async with pool.acquire() as c:
            await c.execute(
                "CREATE TABLE IF NOT EXISTS users (user_id BIGINT PRIMARY KEY, first_name TEXT, username TEXT,"
                " lang TEXT, joined_at TIMESTAMPTZ DEFAULT now(), last_seen TIMESTAMPTZ DEFAULT now(),"
                " blocked BOOLEAN DEFAULT false)"
            )
            await c.execute(
                "CREATE TABLE IF NOT EXISTS downloads (id BIGSERIAL PRIMARY KEY, user_id BIGINT, chat_type TEXT,"
                " site TEXT, kind TEXT, ok BOOLEAN, seconds REAL, created_at TIMESTAMPTZ DEFAULT now())"
            )
            await c.execute("CREATE INDEX IF NOT EXISTS downloads_created_idx ON downloads(created_at)")
            await c.execute("CREATE TABLE IF NOT EXISTS settings (key TEXT PRIMARY KEY, value TEXT)")
        log.info("Baza ulandi ✅")
    except Exception as e:  # noqa: BLE001
        pool = None
        log.warning("Bazaga ulanib bo'lmadi: %s", e)


async def _exec(sql: str, *args) -> None:
    if not pool:
        return
    try:
        async with pool.acquire() as c:
            await c.execute(sql, *args)
    except Exception as e:  # noqa: BLE001
        log.warning("DB yozish xatosi: %s", e)


async def _fetch(sql: str, *args) -> list:
    if not pool:
        return []
    try:
        async with pool.acquire() as c:
            return await c.fetch(sql, *args)
    except Exception as e:  # noqa: BLE001
        log.warning("DB o'qish xatosi: %s", e)
        return []


async def touch_user(user) -> None:
    await _exec(
        "INSERT INTO users (user_id, first_name, username, lang) VALUES ($1,$2,$3,$4)"
        " ON CONFLICT (user_id) DO UPDATE SET first_name=EXCLUDED.first_name, username=EXCLUDED.username,"
        " last_seen=now(), blocked=false",
        user.id, user.first_name, user.username, user.language_code,
    )


async def log_download(user_id: int, chat_type: str, site: str, kind: str, ok: bool, seconds: float) -> None:
    await _exec(
        "INSERT INTO downloads (user_id, chat_type, site, kind, ok, seconds) VALUES ($1,$2,$3,$4,$5,$6)",
        user_id, chat_type, site, kind, ok, seconds,
    )


async def mark_blocked(user_id: int) -> None:
    await _exec("UPDATE users SET blocked=true WHERE user_id=$1", user_id)


async def active_user_ids() -> list[int]:
    return [r["user_id"] for r in await _fetch("SELECT user_id FROM users WHERE blocked=false")]


async def get_setting(key: str) -> str | None:
    rows = await _fetch("SELECT value FROM settings WHERE key=$1", key)
    return rows[0]["value"] if rows else None


async def set_setting(key: str, value: str | None) -> None:
    if value is None:
        await _exec("DELETE FROM settings WHERE key=$1", key)
    else:
        await _exec(
            "INSERT INTO settings (key, value) VALUES ($1,$2) ON CONFLICT (key) DO UPDATE SET value=EXCLUDED.value",
            key, value,
        )


async def stats() -> dict | None:
    if not pool:
        return None
    one = await _fetch(
        "SELECT"
        " (SELECT count(*) FROM users) AS users,"
        " (SELECT count(*) FROM users WHERE blocked) AS blocked,"
        " (SELECT count(*) FROM users WHERE joined_at > now() - interval '1 day') AS new_day,"
        " (SELECT count(*) FROM users WHERE joined_at > now() - interval '7 day') AS new_week,"
        " (SELECT count(*) FROM users WHERE last_seen > now() - interval '1 day') AS active_day,"
        " (SELECT count(*) FROM downloads) AS dl_total,"
        " (SELECT count(*) FROM downloads WHERE created_at > now() - interval '1 day') AS dl_day,"
        " (SELECT count(*) FROM downloads WHERE ok AND created_at > now() - interval '1 day') AS dl_day_ok,"
        " (SELECT round(avg(seconds)::numeric,1) FROM downloads WHERE ok AND created_at > now() - interval '1 day') AS avg_sec"
    )
    sites = await _fetch(
        "SELECT site, count(*) AS n FROM downloads WHERE created_at > now() - interval '7 day'"
        " GROUP BY site ORDER BY n DESC LIMIT 8"
    )
    kinds = await _fetch(
        "SELECT kind, count(*) AS n FROM downloads WHERE created_at > now() - interval '7 day'"
        " GROUP BY kind ORDER BY n DESC"
    )
    return {"main": dict(one[0]) if one else {}, "sites": sites, "kinds": kinds}


# ---------- Kanal uchun rejalashtirilgan postlar ----------
async def init_posts() -> None:
    await _exec(
        "CREATE TABLE IF NOT EXISTS scheduled_posts (id BIGSERIAL PRIMARY KEY, admin_chat BIGINT, src_chat BIGINT,"
        " src_msg BIGINT, kind TEXT, html TEXT, buttons BOOLEAN, pin BOOLEAN, run_at TIMESTAMPTZ,"
        " done BOOLEAN DEFAULT false, created_at TIMESTAMPTZ DEFAULT now())"
    )


async def add_post(admin_chat, src_chat, src_msg, kind, html_text, buttons, pin, run_at) -> int | None:
    rows = await _fetch(
        "INSERT INTO scheduled_posts (admin_chat, src_chat, src_msg, kind, html, buttons, pin, run_at)"
        " VALUES ($1,$2,$3,$4,$5,$6,$7,$8) RETURNING id",
        admin_chat, src_chat, src_msg, kind, html_text, buttons, pin, run_at,
    )
    return rows[0]["id"] if rows else None


async def due_posts() -> list:
    return await _fetch("SELECT * FROM scheduled_posts WHERE NOT done AND run_at <= now() ORDER BY run_at LIMIT 10")


async def upcoming_posts() -> list:
    return await _fetch("SELECT * FROM scheduled_posts WHERE NOT done ORDER BY run_at LIMIT 20")


async def finish_post(post_id: int) -> None:
    await _exec("UPDATE scheduled_posts SET done=true WHERE id=$1", post_id)
