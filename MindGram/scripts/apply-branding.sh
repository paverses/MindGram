#!/bin/sh
# Copies MindGram's branding over Telegram's files. Run it after every upstream update
# (sync-upstream.sh does), because an update can bring Telegram's icon and intro images back.
set -e

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BRANDING="$ROOT/MindGram/Branding"

# App icon: Telegram/BUILD builds the icon from Telegram-iOS/Telegram.icon, so ours goes there.
rm -rf "$ROOT/Telegram/Telegram-iOS/Telegram.icon"
cp -R "$BRANDING/AppIcon.icon" "$ROOT/Telegram/Telegram-iOS/Telegram.icon"

# Intro screen logo (both copies are bundled).
for dir in "$ROOT/Telegram/Telegram-iOS/Resources/intro" "$ROOT/submodules/RMIntro/Sources/platform/ios/Resources"; do
    cp "$BRANDING/intro/telegram_sphere@2x.png" "$dir/telegram_sphere@2x.png"
    cp "$BRANDING/intro/telegram_plane1@2x.png" "$dir/telegram_plane1@2x.png"
done

# Alternate app icons (Settings > Appearance > App Icon): regular and inverted.
for icon in "$BRANDING"/AlternateIcons/*.alticon; do
    rm -rf "$ROOT/Telegram/Telegram-iOS/$(basename "$icon")"
    cp -R "$icon" "$ROOT/Telegram/Telegram-iOS/$(basename "$icon")"
done

# The badge Telegram shows at the top centre, under the notch.
cp "$BRANDING/AppBadge@3x.png" "$ROOT/submodules/TelegramUI/Images.xcassets/Components/AppBadge.imageset/AppBadge@3x.png"

echo "MindGram branding applied."
