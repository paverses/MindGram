# MindGram builds bot

Private bot that hands out MindGram IPA builds. It stays silent until a user sends `/aftreen`
(reply: "Запомнил"); after that `/start` shows the builds: **IPA** → grid of builds (2 per row,
8 per page, "Следующая"/"Назад") → build card (version, date, "Что нового", "Что исправил") → **IPA** sends the file.

| File | What it does |
|---|---|
| `bot.py` | The bot (aiogram 3, long polling through the local Bot API server). |
| `store.py` | `data/users.json`, `data/builds.json`, `data/ipa/`. |
| `add_build.py` | `add` / `edit` / `list` builds. |
| `deploy/bot-api.sh` | Local Bot API server in Docker on `127.0.0.1:8111` (sends files up to 2000 MB; the regular API caps them at 50 MB). |
| `deploy/mindgram-bot.service` | systemd unit. |

Server: `/opt/mindgram-bot` on 2.27.200.223, service `mindgram-bot`, container `mindgram-bot-api`.

Add a build after a successful GitHub run:

```sh
ssh root@2.27.200.223 'cd /opt/mindgram-bot && .venv/bin/python add_build.py add \
  --ipa-url https://github.com/paverses/MindGram/releases/download/build-NNNN/MindGram.ipa \
  --built-at 2026-10-19T17:05:00+03:00 --telegram 13.0 \
  --whats-new-file new.txt --fixed-file fixed.txt'
```

The bot reads `builds.json` on every request, so no restart is needed.
