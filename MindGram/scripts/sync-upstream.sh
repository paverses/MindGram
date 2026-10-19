#!/bin/sh
# Brings a newer Telegram-iOS release into MindGram.
#
#   sh MindGram/scripts/sync-upstream.sh               # latest upstream master
#   sh MindGram/scripts/sync-upstream.sh release-13.1  # a specific tag or branch
#
# MindGram's history starts from a snapshot of Telegram-iOS, not from Telegram's history, so the update
# is applied as a patch: the difference between the Telegram version recorded in MindGram/UPSTREAM and
# the new one, merged three-way into our files. Files MindGram never touched update cleanly; where both
# changed the same lines git leaves <<<<<<< conflict markers. MindGram/README.md lists every hook.
set -e

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

if [ -n "$(git status --porcelain)" ]; then
    echo "Commit or stash your changes first."
    exit 1
fi

BASE="$(cat MindGram/UPSTREAM)"
TARGET_REF="${1:-master}"

git remote get-url upstream >/dev/null 2>&1 || git remote add upstream https://github.com/TelegramMessenger/Telegram-iOS.git
git fetch --depth=1 upstream "$BASE"
git fetch --depth=1 upstream "$TARGET_REF"
TARGET="$(git rev-parse FETCH_HEAD)"

if [ "$TARGET" = "$BASE" ]; then
    echo "Already on $TARGET_REF ($TARGET)."
    exit 0
fi

PATCH="$(mktemp)"
git diff --binary "$BASE" "$TARGET" > "$PATCH"

echo "Applying Telegram changes $BASE -> $TARGET ($TARGET_REF)"
if git apply --3way --index "$PATCH"; then
    STATUS="clean"
else
    STATUS="conflicts"
fi
rm -f "$PATCH"

git submodule update --init --recursive
echo "$TARGET" > MindGram/UPSTREAM
git add MindGram/UPSTREAM

# An update can bring Telegram's icon and intro images back.
sh MindGram/scripts/apply-branding.sh
git add -A Telegram/Telegram-iOS/Telegram.icon Telegram/Telegram-iOS/Resources/intro submodules/RMIntro/Sources/platform/ios/Resources

if [ "$STATUS" = "conflicts" ]; then
    echo
    echo "Some MindGram hooks conflict with Telegram's changes. Fix the files git lists as 'both modified',"
    echo "keeping Telegram's new code plus the MindGram lines (see MindGram/README.md), then commit."
    git status --short | grep '^UU\|^AA\|^DU\|^UD' || true
    exit 2
fi

echo "Done. Review with 'git diff --cached --stat', then commit: git commit -m \"Update Telegram to $TARGET_REF\""
