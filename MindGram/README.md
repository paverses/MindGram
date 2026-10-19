# MindGram

MindGram is a client built on the open-source [Telegram-iOS](https://github.com/TelegramMessenger/Telegram-iOS).
All of MindGram's own code lives in this folder. Telegram's files only contain short hooks (listed
below), so updating to a new Telegram version stays simple.

## Folder structure

| Folder | What's in it |
|---|---|
| `Core/` | `MindGramCore` module: the `MindGramDesign` (classic design) and `MindGramBranding` switches, and the `MindGramLogo` drawn in code. Display re-exports it, so the switches are visible in every Telegram module. |
| `Settings/` | The **MindGram** row in Settings, the section menu, and the texts (`MindGramStrings`). |
| `Appearance/` | **Оформление** (Appearance): the "Старый дизайн Telegram" (Classic Telegram Design) switch and the restart toast. |
| `Tabs/` | **Вкладки** (Tabs): which tabs the bottom bar shows. |
| `Profile/` | **Профиль** (Profile): profile features (empty for now). |
| `Branding/` | Logo (`logo.svg`), app icon (`AppIcon.icon`), intro screen images (`intro/`). |
| `Bot/` | Private Telegram bot that hands out the builds (`@updateIPA_rabot`, server `/opt/mindgram-bot`). See `Bot/README.md`. |
| `scripts/` | `apply-branding.sh`, `sync-upstream.sh`, `render-logo.ps1`. |
| `UPSTREAM` | The Telegram-iOS commit MindGram is currently based on. |

`Settings/`, `Appearance/`, `Tabs/` and `Profile/` build into one module, `MindGramUI` (see `BUILD`).
A new screen gets its own folder, added to the `glob` in `BUILD`.

To add a feature with a switch: add a row with `ItemListSwitchItem(title:text:value:…)` to the matching
screen (`text` is the short gray description under the name). If Telegram code has to check the switch,
put the switch in `Core/` and the check behind one `if` in Telegram's file, and list it below.

## Hooks in Telegram's files

Classic design (`MindGramDesign.isClassic`, read once at launch):

| File | What it does |
|---|---|
| `submodules/Display/BUILD`, `submodules/Display/Source/MindGramExports.swift` | Links and re-exports `MindGramCore`. |
| `submodules/Display/Source/NavigationBar.swift` | `NavigationBarTheme` forces the `.legacy` style (flat bar with separator). |
| `submodules/TelegramPresentationData/Sources/ComponentsThemes.swift` | Same for theme-based bars (button colors). |
| `submodules/TabBarUI/Sources/TabBarContollerNode.swift` | The classic full-width `TabBarNode` instead of the floating capsule (`updateClassicImpl`). |
| `submodules/TelegramUI/Components/GlassBackgroundComponent/Sources/GlassBackgroundComponent.swift` | Glass becomes a flat panel: no system `UIGlassEffect`, no rim light, no shadow (`generateClassicPanelImage`). |
| `submodules/TelegramUI/Components/GlassBackgroundComponent/Sources/LegacyGlassView.swift` | Plain blur without refraction. |
| `submodules/TelegramUI/Sources/SharedAccountContext.swift` | Keeps the custom (non-system) glass in classic mode. |
| 62 list item files (`self.systemStyle = MindGramDesign.isClassic ? .legacy : systemStyle`) | List rows in the old style: 44pt height, small corner radius. Find them all with `grep -rn "MindGramDesign.isClassic ? .legacy" submodules`. |

Settings and branding:

| File | What it does |
|---|---|
| `submodules/TelegramUI/Components/PeerInfo/PeerInfoScreen/BUILD` | Depends on `//MindGram:MindGramUI`. |
| `.../PeerInfoScreen/Sources/PeerInfoScreen.swift` | `PeerInfoSettingsSection.mindgram`. |
| `.../PeerInfoScreen/Sources/PeerInfoSettingsItems.swift` | The **MindGram** row under "My Profile". |
| `.../PeerInfoScreen/Sources/PeerInfoScreenSettingsActions.swift` | Opens `mindGramSettingsController`. |
| `submodules/TelegramUI/Sources/AppDelegate.swift` | Hides Telegram's alternate app icons (`MindGramBranding`). |
| `Telegram/BUILD` | App and extension names (`CFBundleDisplayName`, `CFBundleName`): `MindGram`. |
| `Telegram/Telegram-iOS/*/InfoPlist.strings`, `en.lproj/Localizable.strings` | Localized name, intro title. |
| `submodules/MtProtoKit/Sources/MTApiEnvironment.m` | App version shown on the server in "Devices": `MindGram 13.0 (…)`. |
| `Telegram/Telegram-iOS/Telegram.icon`, intro `telegram_*@2x.png` | Overwritten by `scripts/apply-branding.sh` from `Branding/`. |
| `.github/workflows/mindgram.yml`, `.gitignore` | GitHub Actions build. |
| `.gitmodules` | `rlottie` and `tgcalls` point at TelegramMessenger directly (upstream uses relative URLs that only work in Telegram's own repo). |

## Build

GitHub Actions (`.github/workflows/mindgram.yml`) builds an IPA on every push to `main`, or by hand from
Actions → MindGram iOS → Run workflow. The IPA lands in the run's artifacts and in Releases.
`api_id` and `api_hash` come from the repository secrets `TELEGRAM_API_ID` and `TELEGRAM_API_HASH`;
they are not stored in the code.

The build is signed with Telegram's fake profiles (`build-system/fake-codesigning`). To install on
iPhone, re-sign the IPA with your Apple ID in Sideloadly or AltStore.

Bazel cache: every run, including failed or timed-out ones, saves `~/telegram-bazel-cache` to the
GitHub cache, and the next run starts from it, so a repeat build only compiles what changed or was left
unbuilt.

## Updating Telegram

```sh
sh MindGram/scripts/sync-upstream.sh               # latest master
sh MindGram/scripts/sync-upstream.sh release-13.1  # a specific release
```

The script applies the difference between Telegram's old and new versions (`UPSTREAM`) as a three-way
patch. Files without hooks update automatically. If Telegram changed a line with a hook, git marks a
conflict: keep Telegram's new code and add the MindGram line back (using the table above). Then:
`git commit -m "Update Telegram to …"` and `git push`.
