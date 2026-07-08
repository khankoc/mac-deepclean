# Knowledge Base — What Things Are

Interpretation accelerator. The scan is NOT limited to this list; anything big
and unrecognized goes through the investigation flow in SKILL.md instead.
Tiers here are defaults — context (git state, running services, user answers)
can move an item to a stricter tier, never to a looser one.

Sizes marked "regen" mean: deleting costs only a re-download/rebuild.

## Developer

| Path / pattern | What it is | Default tier |
|---|---|---|
| `**/node_modules` | npm packages; `npm install` regenerates | 🟢 (repo must not be 🔴-blocked for full-repo deletes; artifact itself regen) |
| `**/.next`, `**/dist`, `**/build`, `**/out`, `**/target` | build output; rebuilt on demand | 🟢 |
| `**/.dart_tool`, Flutter `build/` | Flutter/Dart build cache; `flutter clean` territory | 🟢 |
| `**/venv`, `**/.venv` | Python virtualenv; `pip install -r requirements.txt` regenerates | 🟢 |
| `~/.npm/_cacache`, `~/.npm/_npx` | npm download cache | 🟢 |
| `~/.gradle/caches`, `~/.gradle/wrapper` | Android/Gradle deps; re-downloaded on next build | 🟢 |
| `~/.pub-cache` | Flutter packages; `pub get` regenerates | 🟢 |
| `~/.cache/uv`, `~/Library/Caches/pip` | Python package caches | 🟢 |
| `~/Library/Caches/Homebrew` | brew download cache (`brew cleanup`) | 🟢 |
| `~/Library/Caches/CocoaPods` | iOS dependency cache | 🟢 |
| `~/Library/Developer/Xcode/DerivedData` | Xcode intermediate builds | 🟢 |
| `~/Library/Developer/CoreSimulator/Devices` | simulator devices with installed apps | 🟡 (user may be mid-testing) |
| `/Library/Developer/CoreSimulator/Volumes` | iOS runtime images (~8 GB each); re-downloadable | 🟡 + old versions 🟢 |
| `/Library/Developer/CoreSimulator/Caches` | simulator dyld caches; regenerate on boot | 🟢 (sudo — hand to user) |
| `~/Library/Android/sdk` | Android SDK/NDK; needed for Android builds | 🟡 |
| `~/Library/Containers/com.docker.docker` | Docker Desktop VM disk (images+volumes) | 🔴 if used; 🟡 if not running/stale |
| `~/.colima` | Colima (Docker alternative) VM disk | 🟡 — check active docker context |
| `~/.dartServer` | Dart analysis cache | 🟢 |
| `~/Library/Caches/ms-playwright*` | Playwright browser binaries | 🟢 |
| `*.xcarchive`, `~/Library/Developer/Xcode/Archives` | app archives — may hold unreleased builds | 🟡 |
| `~/Library/Developer/Xcode/iOS DeviceSupport` | per-iOS-version debug symbols; regen on device connect | 🟢 |

## Video / Photo

| Path / pattern | What it is | Default tier |
|---|---|---|
| Final Cut `*.fcpbundle/**/Render Files` | render cache; FCP re-renders | 🟢 |
| `~/Movies/**/Optimized Media`, `Proxy Media` | FCP optimized/proxy copies of originals | 🟡 (large re-encode time) |
| Premiere `~/Documents/Adobe/Premiere Pro/**/Media Cache*` | media cache; regenerates | 🟢 |
| After Effects `Disk Cache` | preview cache | 🟢 |
| `~/Pictures/Photos Library.photoslibrary` | THE photo library | 🔴 |
| Lightroom `*.lrcat-data`, previews `*.lrdata` | previews regen; catalog itself 🔴 | previews 🟢, catalog 🔴 |

## Music / Audio

| Path / pattern | What it is | Default tier |
|---|---|---|
| Logic `~/Music/Audio Music Apps`, sampler instruments | user instruments/patches | 🔴 |
| `/Library/Application Support/GarageBand`, `Logic/*.pkg` sound libraries | Apple loops/sounds; re-downloadable in-app | 🟡 |
| Ableton `~/Music/Ableton/**/Cache` | decoding/analysis cache | 🟢 |
| `~/Music/iTunes`, `~/Music/Music` | THE music library | 🔴 |

## Everyday

| Path / pattern | What it is | Default tier |
|---|---|---|
| `~/Library/Caches/ru.keepcoder.Telegram` | Telegram media cache; re-downloads from cloud | 🟢 |
| WhatsApp `~/Library/Group Containers/*.WhatsApp*/Media` | may be the ONLY copy of received media | 🟡 |
| `~/Library/Caches/Google`, browser caches | web caches | 🟢 |
| `~/Library/Application Support/MobileSync/Backup` | old iPhone/iPad backups | 🟡 (check device + date) |
| Mail `~/Library/Mail` | local mail store | 🔴 (offer Mail.app attachment cleanup instead) |
| `~/Library/Application Support/com.apple.wallpaper` | aerial wallpaper videos; switch to static to shrink | 🟡 |
| `*.ShipIt`, `*-updater` caches | app auto-update leftovers | 🟢 |
| `~/Downloads` old `.dmg`/`.zip` installers | installers already installed | 🟡 (list, let user pick) |
| `/private/var/folders` | macOS-managed temp; do NOT rm blindly | 🔴 (reboot shrinks it) |

## Orphan pattern (any category)

Data dir whose owning app/CLI is gone (scanner: `cli_installed:false`, or no
matching app in /Applications) → verify absence, then 🟢. Examples seen in the
wild: `~/Library/pnpm` with no pnpm, `~/.codex` with no codex.
