"""Private MindGram builds bot.

Silent for everyone until they send /aftreen. After that /start shows the builds:
IPA -> grid of builds (2 per row, 8 per page) -> build card -> IPA file.
"""
import asyncio
import html
import logging
import os
from datetime import datetime
from zoneinfo import ZoneInfo

from aiogram import Bot, Dispatcher, F
from aiogram.client.default import DefaultBotProperties
from aiogram.client.session.aiohttp import AiohttpSession
from aiogram.client.telegram import TelegramAPIServer
from aiogram.enums import ChatAction, ChatType
from aiogram.exceptions import TelegramBadRequest
from aiogram.filters import Command
from aiogram.types import CallbackQuery, InlineKeyboardButton, InlineKeyboardMarkup, Message, ReplyParameters

import store

BOT_TOKEN = os.environ["BOT_TOKEN"]
API_SERVER = os.environ.get("API_SERVER", "http://127.0.0.1:8111")
ACTIVATE_COMMAND = os.environ.get("ACTIVATE_COMMAND", "aftreen")
TIMEZONE = ZoneInfo(os.environ.get("TIMEZONE", "Europe/Moscow"))

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
        [button(f"IPA ({b['number']})", f"b:{b['number']}:{page}") for b in chunk[i:i + 2]]
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


@dp.message()
async def ignore(_: Message) -> None:
    # Private bot: no replies, no hints.
    return


async def main() -> None:
    logging.basicConfig(level=logging.INFO)
    session = AiohttpSession(api=TelegramAPIServer.from_base(API_SERVER, is_local=True), timeout=900)
    bot = Bot(BOT_TOKEN, session=session, default=DefaultBotProperties(parse_mode="HTML"))
    await bot.delete_my_commands()
    await dp.start_polling(bot, allowed_updates=["message", "callback_query"])


if __name__ == "__main__":
    asyncio.run(main())
