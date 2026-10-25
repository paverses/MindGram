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


BETA_PATH = DATA_DIR / "beta.json"
DOWNLOADS_PATH = DATA_DIR / "downloads.json"


def beta() -> list[dict]:
    return _read(BETA_PATH, [])


def beta_ids() -> list[int]:
    return sorted({item["id"] for item in beta()})


def set_beta(user_id: int, enabled: bool, note: str = "") -> None:
    items = [item for item in beta() if item["id"] != user_id]
    if enabled:
        items.append({"id": user_id, "note": note})
    _write(BETA_PATH, sorted(items, key=lambda item: item["id"]))


BLOCKED_PATH = DATA_DIR / "blocked.json"
MARKS_PATH = DATA_DIR / "marks.json"


def blocked() -> list[int]:
    return sorted(set(_read(BLOCKED_PATH, [])))


def set_blocked(user_id: int, value: bool) -> None:
    current = set(blocked())
    if value:
        current.add(user_id)
    else:
        current.discard(user_id)
    _write(BLOCKED_PATH, sorted(current))


def marks() -> dict[str, str]:
    return _read(MARKS_PATH, {})


def set_mark(user_id: int, mark: str | None) -> None:
    current = marks()
    if mark:
        current[str(user_id)] = mark
    else:
        current.pop(str(user_id), None)
    _write(MARKS_PATH, current)


def members() -> list[dict]:
    latest: dict[int, dict] = {}
    for item in downloads():
        latest[item["id"]] = item
    return [{"i": item["id"], "u": item.get("username"), "n": item.get("name"), "b": item.get("build"), "t": item.get("at")} for item in latest.values()]


def downloads() -> list[dict]:
    return _read(DOWNLOADS_PATH, [])


def add_download(user_id: int, username: str | None, number: int, at: str, name: str | None = None) -> None:
    items = downloads()
    items.append({"id": user_id, "username": username, "name": name, "build": number, "at": at})
    _write(DOWNLOADS_PATH, items)


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
