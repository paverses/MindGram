#!/bin/sh
# Local Telegram Bot API server for the MindGram bot: files up to 2000 MB, read straight from disk.
# Needs MindGram's api_id/api_hash in /opt/mindgram-bot/bot-api.env (TELEGRAM_API_ID=, TELEGRAM_API_HASH=).
set -e
docker rm -f mindgram-bot-api >/dev/null 2>&1 || true
docker run -d --name mindgram-bot-api --restart unless-stopped \
    --env-file /opt/mindgram-bot/bot-api.env \
    -e TELEGRAM_LOCAL=1 \
    -p 127.0.0.1:8111:8081 \
    -v /opt/mindgram-bot/bot-api-data:/var/lib/telegram-bot-api \
    -v /opt/mindgram-bot/data/ipa:/opt/mindgram-bot/data/ipa:ro \
    aiogram/telegram-bot-api:latest
