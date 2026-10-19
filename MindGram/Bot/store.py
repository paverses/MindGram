"""Bot data on disk: who activated the bot and the list of MindGram builds.

data/users.json   [user_id, ...]
data/builds.json  [{"number", "telegram_version", "built_at", "whats_new", "fixed", "ipa_path", "file_id", "run_url"}, ...]
data/ipa/         the IPA files, sent through the local Bot API server by path
"""
import json
import os
from pathlib import Path

DATA_DIR = Path(os.environ.get("DATA_DIR", Path(__file__).resolve().parent / "data"))
USERS_PATH = DATA_DIR / "users.json"
BUILDS_PATH = DATA_DIR / "builds.json"
IPA_DIR = DATA_DIR / "ipa"


def _read(path: Path, default):
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except FileNotFoundError:
        return default


def _write(path: Path, value) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp = path.with_suffix(".tmp")
    tmp.write_text(json.dumps(value, ensure_ascii=False, indent=2), encoding="utf-8")
    tmp.replace(path)


def users() -> set[int]:
    return set(_read(USERS_PATH, []))


def add_user(user_id: int) -> None:
    current = users()
    current.add(user_id)
    _write(USERS_PATH, sorted(current))


def builds() -> list[dict]:
    return sorted(_read(BUILDS_PATH, []), key=lambda b: b["number"])


def build(number: int) -> dict | None:
    return next((b for b in builds() if b["number"] == number), None)


def save_builds(items: list[dict]) -> None:
    _write(BUILDS_PATH, sorted(items, key=lambda b: b["number"]))


def update_build(number: int, **fields) -> None:
    items = builds()
    for item in items:
        if item["number"] == number:
            item.update(fields)
    save_builds(items)
