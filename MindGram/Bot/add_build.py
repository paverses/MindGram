"""Adds a MindGram build to the bot, or edits one.

  python add_build.py add --ipa-url URL --built-at 2026-10-19T15:40:00+03:00 --telegram 13.0 \
      --whats-new-file new.txt --fixed-file fixed.txt [--run-url URL]
  python add_build.py edit 2 [--whats-new-file F] [--fixed-file F]
  python add_build.py list

Builds are numbered in order: MindGram (1), (2), ... The IPA is downloaded into data/ipa/, where the
local Bot API server reads it when someone presses IPA.
"""
import argparse
import sys
import urllib.request
from datetime import datetime
from pathlib import Path

import store


def read_text(path: str | None) -> str:
    if not path:
        return ""
    return sys.stdin.read() if path == "-" else Path(path).read_text(encoding="utf-8")


def add(args: argparse.Namespace) -> None:
    items = store.builds()
    number = (items[-1]["number"] + 1) if items else 1
    store.IPA_DIR.mkdir(parents=True, exist_ok=True)
    ipa_path = store.IPA_DIR / f"MindGram-{number}.ipa"
    print(f"Downloading {args.ipa_url} -> {ipa_path}")
    urllib.request.urlretrieve(args.ipa_url, ipa_path)
    items.append({
        "number": number,
        "telegram_version": args.telegram,
        "built_at": int(datetime.fromisoformat(args.built_at).timestamp()),
        "whats_new": read_text(args.whats_new_file),
        "fixed": read_text(args.fixed_file),
        "ipa_path": str(ipa_path.resolve()),
        "file_id": None,
        "run_url": args.run_url,
    })
    store.save_builds(items)
    print(f"Added MindGram ({number}), {ipa_path.stat().st_size // (1024 * 1024)} MB")


def edit(args: argparse.Namespace) -> None:
    fields = {}
    if args.whats_new_file:
        fields["whats_new"] = read_text(args.whats_new_file)
    if args.fixed_file:
        fields["fixed"] = read_text(args.fixed_file)
    store.update_build(args.number, **fields)
    print(f"Updated MindGram ({args.number})")


def list_builds(_: argparse.Namespace) -> None:
    for item in store.builds():
        built_at = datetime.fromtimestamp(item["built_at"]).isoformat(timespec="minutes")
        print(f"({item['number']}) Telegram {item['telegram_version']}  {built_at}  {item['ipa_path']}")


def main() -> None:
    parser = argparse.ArgumentParser()
    commands = parser.add_subparsers(dest="command", required=True)

    add_parser = commands.add_parser("add")
    add_parser.add_argument("--ipa-url", required=True)
    add_parser.add_argument("--built-at", required=True, help="ISO 8601 with time zone")
    add_parser.add_argument("--telegram", required=True, help="Telegram version, from versions.json")
    add_parser.add_argument("--whats-new-file")
    add_parser.add_argument("--fixed-file")
    add_parser.add_argument("--run-url")
    add_parser.set_defaults(handler=add)

    edit_parser = commands.add_parser("edit")
    edit_parser.add_argument("number", type=int)
    edit_parser.add_argument("--whats-new-file")
    edit_parser.add_argument("--fixed-file")
    edit_parser.set_defaults(handler=edit)

    commands.add_parser("list").set_defaults(handler=list_builds)

    args = parser.parse_args()
    args.handler(args)


if __name__ == "__main__":
    main()
