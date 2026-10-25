"""Private MindGram builds bot.

Silent for everyone until they send /aftreen. After that /start shows the builds:
IPA -> grid of builds (2 per row, 8 per page) -> build card -> IPA file.
"""
import asyncio
import base64
import html
import json
import logging
import os
from datetime import datetime
from zoneinfo import ZoneInfo

import aiohttp
from aiogram import Bot, Dispatcher, F
from aiogram.client.default import DefaultBotProperties
from aiogram.client.session.aiohttp import AiohttpSession
from aiogram.client.telegram import TelegramAPIServer
from aiogram.enums import ChatAction, ChatType
from aiogram.exceptions import TelegramBadRequest
from aiogram.filters import Command
from aiogram.types import CallbackQuery, ChatMemberUpdated, InlineKeyboardButton, InlineKeyboardMarkup, Message, ReplyParameters

import store

BOT_TOKEN = os.environ["BOT_TOKEN"]
API_SERVER = os.environ.get("API_SERVER", "http://127.0.0.1:8111")
ACTIVATE_COMMAND = os.environ.get("ACTIVATE_COMMAND", "aftreen")
TIMEZONE = ZoneInfo(os.environ.get("TIMEZONE", "Europe/Moscow"))

ADMIN_IDS = {int(x) for x in os.environ.get("ADMIN_IDS", "8690187164,1318539187").split(",") if x.strip()}
GITHUB_TOKEN = os.environ.get("GITHUB_TOKEN", "")
GITHUB_REPO = os.environ.get("GITHUB_REPO", "paverses/MindGram")
GITHUB_PATH = os.environ.get("GITHUB_PATH", "MindGram/Bot/palette.json")
PAID_CHANNEL_ID = int(os.environ.get("PAID_CHANNEL_ID", "0"))

PAGE_SIZE = 8
START_TEXT = "Тут ниже твои сборки MindGram"
WEEKDAYS = ["пн", "вт", "ср", "чт", "пт", "сб", "вс"]

dp = Dispatcher()
dp.message.filter(F.chat.type == ChatType.PRIVATE)


def allowed(user_id: int | None) -> bool:
    return user_id is not None and user_id in store.users()


def button(text: str, data: str) -> InlineKeyboardButton:
    return InlineKeyboardButton(text=text, callback_data=data)


def start_keyboard() -> InlineKeyboardMarkup:
    return InlineKeyboardMarkup(inline_keyboard=[[button("IPA", "l:0")]])


def list_keyboard(page: int) -> InlineKeyboardMarkup:
    items = store.builds()
    pages = max(1, -(-len(items) // PAGE_SIZE))
    page = min(max(page, 0), pages - 1)
    chunk = items[page * PAGE_SIZE:(page + 1) * PAGE_SIZE]
    rows = [
        [button(f"MindGram ({b['number']})", f"b:{b['number']}:{page}") for b in chunk[i:i + 2]]
        for i in range(0, len(chunk), 2)
    ]
    nav = [button("Назад", f"l:{page - 1}" if page > 0 else "s")]
    if page < pages - 1:
        nav.append(button("Следующая", f"l:{page + 1}"))
    rows.append(nav)
    return InlineKeyboardMarkup(inline_keyboard=rows)


def build_keyboard(number: int, page: int) -> InlineKeyboardMarkup:
    return InlineKeyboardMarkup(inline_keyboard=[
        [button("IPA", f"f:{number}")],
        [button("Назад", f"l:{page}")],
    ])


def date_html(unix_time: int) -> str:
    # A Bot API date-time entity with an empty format: the text below is shown as written
    # (short weekday, as wanted), and Telegram still knows the exact moment.
    moment = datetime.fromtimestamp(unix_time, TIMEZONE)
    text = f"{WEEKDAYS[moment.weekday()]}, {moment:%d.%m.%Y}, {moment:%H:%M}"
    return f'<tg-time unix="{unix_time}">{text}</tg-time>'


def quote_html(text: str) -> str:
    return f"<blockquote expandable>{html.escape(text.strip())}</blockquote>"


def build_text(item: dict) -> str:
    parts = [
        f"<b>MindGram ({item['number']})</b> · Telegram {html.escape(item['telegram_version'])}",
        date_html(item["built_at"]),
    ]
    if item.get("whats_new", "").strip():
        parts += ["", "<b>Что нового</b>", quote_html(item["whats_new"])]
    if item.get("fixed", "").strip():
        parts += ["", "<b>Что исправил</b>", quote_html(item["fixed"])]
    return "\n".join(parts)


async def show(callback: CallbackQuery, text: str, keyboard: InlineKeyboardMarkup) -> None:
    try:
        await callback.message.edit_text(text, reply_markup=keyboard)
    except TelegramBadRequest as error:
        if "message is not modified" not in str(error):
            raise


@dp.message(Command(ACTIVATE_COMMAND))
async def activate(message: Message) -> None:
    store.add_user(message.from_user.id)
    await message.answer("Запомнил")


@dp.message(Command("start"))
async def start(message: Message) -> None:
    if not allowed(message.from_user.id):
        return
    await message.answer(START_TEXT, reply_markup=start_keyboard())


@dp.callback_query()
async def on_callback(callback: CallbackQuery) -> None:
    if not allowed(callback.from_user.id):
        await callback.answer()
        return

    kind, *args = (callback.data or "").split(":")
    if kind == "s":
        await show(callback, START_TEXT, start_keyboard())
    elif kind == "l":
        await show(callback, START_TEXT, list_keyboard(int(args[0])))
    elif kind == "b":
        item = store.build(int(args[0]))
        if item is not None:
            await show(callback, build_text(item), build_keyboard(item["number"], int(args[1])))
    elif kind == "f":
        await callback.answer()
        await send_ipa(callback, int(args[0]))
        return
    await callback.answer()


async def send_ipa(callback: CallbackQuery, number: int) -> None:
    item = store.build(number)
    if item is None:
        return
    bot = callback.bot
    chat_id = callback.message.chat.id
    await bot.send_chat_action(chat_id, ChatAction.UPLOAD_DOCUMENT)
    # The local Bot API server reads the file straight from disk (up to 2000 MB); after the first
    # upload Telegram's file_id is reused.
    document = item.get("file_id") or f"file://{item['ipa_path']}"
    sent = await bot.send_document(
        chat_id,
        document,
        caption=f"MindGram ({number}) · Telegram {html.escape(item['telegram_version'])}",
        reply_parameters=ReplyParameters(message_id=callback.message.message_id),
    )
    if not item.get("file_id") and sent.document:
        store.update_build(number, file_id=sent.document.file_id)
    store.add_download(callback.from_user.id, callback.from_user.username, number, datetime.now(TIMEZONE).isoformat(timespec="seconds"), callback.from_user.full_name)
    await publish_beta()


async def publish_beta() -> str:
    if not GITHUB_TOKEN:
        return "GITHUB_TOKEN не задан, список сохранён только на сервере"
    url = f"https://api.github.com/repos/{GITHUB_REPO}/contents/{GITHUB_PATH}"
    headers = {"Authorization": f"Bearer {GITHUB_TOKEN}", "Accept": "application/vnd.github+json"}
    body = json.dumps({"rev": int(datetime.now().timestamp()), "tones": store.beta_ids(), "muted": store.blocked(), "accents": store.marks(), "swatches": store.members()}, ensure_ascii=False, indent=2) + "\n"
    async with aiohttp.ClientSession(headers=headers) as session:
        async with session.get(url) as response:
            sha = (await response.json()).get("sha") if response.status == 200 else None
        payload = {"message": "palette", "content": base64.b64encode(body.encode()).decode()}
        if sha:
            payload["sha"] = sha
        async with session.put(url, json=payload) as response:
            if response.status not in (200, 201):
                return f"GitHub ответил {response.status}"
    return "Опубликовано"


def parse_id(message: Message) -> tuple[int | None, str]:
    parts = (message.text or "").split(maxsplit=2)
    if len(parts) < 2 or not parts[1].lstrip("-").isdigit():
        return None, ""
    return int(parts[1]), parts[2] if len(parts) > 2 else ""


@dp.message(Command("addbeta"))
async def add_beta(message: Message) -> None:
    if message.from_user.id not in ADMIN_IDS:
        return
    user_id, note = parse_id(message)
    if user_id is None:
        await message.answer("/addbeta &lt;id&gt; [заметка]")
        return
    store.set_beta(user_id, True, note)
    await message.answer(f"Бета-тестер <code>{user_id}</code> добавлен. {await publish_beta()}")


@dp.message(Command("removebeta"))
async def remove_beta(message: Message) -> None:
    if message.from_user.id not in ADMIN_IDS:
        return
    user_id, _ = parse_id(message)
    if user_id is None:
        await message.answer("/removebeta &lt;id&gt;")
        return
    store.set_beta(user_id, False)
    await message.answer(f"<code>{user_id}</code> убран из бета-тестеров. {await publish_beta()}")


@dp.chat_member()
async def paid_channel_member(update: ChatMemberUpdated) -> None:
    if PAID_CHANNEL_ID and update.chat.id != PAID_CHANNEL_ID:
        return
    user = update.new_chat_member.user
    if user.is_bot:
        return
    joined = update.new_chat_member.status in ("member", "administrator", "creator", "restricted")
    was_member = update.old_chat_member.status in ("member", "administrator", "creator", "restricted")
    if joined == was_member:
        return
    note = f"@{user.username}" if user.username else user.full_name
    store.set_beta(user.id, joined, note)
    result = await publish_beta()
    for admin_id in ADMIN_IDS:
        try:
            await update.bot.send_message(admin_id, f"{'Купил бету' if joined else 'Подписка закончилась'}: <code>{user.id}</code> {html.escape(note)}. {result}")
        except Exception:
            pass


@dp.message(Command("block"))
async def block_user(message: Message) -> None:
    if message.from_user.id not in ADMIN_IDS:
        return
    user_id, _ = parse_id(message)
    if user_id is None:
        return
    store.set_blocked(user_id, True)
    await message.answer(f"<code>{user_id}</code> заблокирован. {await publish_beta()}")


@dp.message(Command("unblock"))
async def unblock_user(message: Message) -> None:
    if message.from_user.id not in ADMIN_IDS:
        return
    user_id, _ = parse_id(message)
    if user_id is None:
        return
    store.set_blocked(user_id, False)
    await message.answer(f"<code>{user_id}</code> разблокирован. {await publish_beta()}")


@dp.message(Command("mark"))
async def mark_user(message: Message) -> None:
    if message.from_user.id not in ADMIN_IDS:
        return
    user_id, value = parse_id(message)
    value = value.strip().lower()
    if user_id is None or value not in ("hold", "major", "none"):
        await message.answer("/mark &lt;id&gt; hold|major|none")
        return
    store.set_mark(user_id, None if value == "none" else value)
    await message.answer(f"Метка <code>{user_id}</code>: {value}. {await publish_beta()}")


@dp.message(Command("betas"))
async def list_betas(message: Message) -> None:
    if message.from_user.id not in ADMIN_IDS:
        return
    items = store.beta()
    lines = [f"<code>{item['id']}</code> {html.escape(item.get('note', ''))}" for item in items] or ["Пусто"]
    await message.answer("Бета-тестеры:\n" + "\n".join(lines))


@dp.message(Command("downloads"))
async def list_downloads(message: Message) -> None:
    if message.from_user.id not in ADMIN_IDS:
        return
    items = store.downloads()[-30:]
    lines = [f"<code>{item['id']}</code> @{html.escape(item.get('username') or '-')} · ({item['build']}) · {item['at']}" for item in items] or ["Пусто"]
    await message.answer("Последние скачивания:\n" + "\n".join(lines))


@dp.message()
async def ignore(_: Message) -> None:
    # Private bot: no replies, no hints.
    return


async def main() -> None:
    logging.basicConfig(level=logging.INFO)
    session = AiohttpSession(api=TelegramAPIServer.from_base(API_SERVER, is_local=True), timeout=900)
    bot = Bot(BOT_TOKEN, session=session, default=DefaultBotProperties(parse_mode="HTML"))
    await bot.delete_my_commands()
    await dp.start_polling(bot, allowed_updates=["message", "callback_query", "chat_member"])


if __name__ == "__main__":
    asyncio.run(main())
