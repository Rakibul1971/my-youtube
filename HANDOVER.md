# My YouTube — Handover & Ownership Guide

A complete reference for owning, building, and updating this app.

---

## 1. What the app is

A **Flutter Android app** that tracks the **last 3 videos** from YouTube channels you add.

- Add a channel by **@handle**, **channel URL**, or **UC… channel ID**.
- Home screen lists each saved channel with its 3 newest videos (thumbnail + title + "time ago").
- Tap a video → it plays **inside the app** (no browser, no YouTube app).
- **No YouTube API key** — it reads YouTube's free public RSS feeds.
- Channels are saved **on the device** (no server, no cloud account).

---

## 2. Software installed (the toolchain)

Everything was installed fresh on the Mac via **Homebrew**. Nothing pre-existed.

| Software | What it is | Where it lives |
|---|---|---|
| **Homebrew** | macOS package manager (installs everything else) | `/opt/homebrew` |
| **Flutter SDK 3.44** | The app framework + `flutter` command (includes Dart) | `/opt/homebrew/share/flutter` |
| **JDK 17** (`openjdk@17`) | Java, required by Android's Gradle build | `/opt/homebrew/opt/openjdk@17` |
| **Android command-line tools** | `sdkmanager`, `avdmanager`, `adb`, `emulator` | `/opt/homebrew/share/android-commandlinetools` |
| Android **platform-tools** | `adb` (talks to phone/emulator) | inside the SDK above |
| Android **platforms;android-36** | The Android 36 SDK to compile against | inside the SDK above |
| Android **build-tools;36.0.0** | Compiles/packages the APK | inside the SDK above |
| Android **system-image android-35** | The virtual phone image for the emulator | inside the SDK above |

> **Note:** Use the `openjdk@17` **formula**, NOT the `temurin@17` cask — the cask's `.pkg` installer needs an interactive `sudo` password and fails in scripts.

### Install commands (start from nothing → ready to build)

```bash
# 1. Homebrew (if not present)
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# 2. Flutter + Java
brew install --cask flutter
brew install openjdk@17

# 3. Android SDK command-line tools
brew install --cask android-commandlinetools

# 4. Point env vars at the SDK + JDK (add these to ~/.zshrc to make permanent)
export JAVA_HOME=/opt/homebrew/opt/openjdk@17
export ANDROID_HOME=/opt/homebrew/share/android-commandlinetools
export ANDROID_SDK_ROOT=$ANDROID_HOME
export PATH="$ANDROID_HOME/platform-tools:$ANDROID_HOME/emulator:$JAVA_HOME/bin:$PATH"

# 5. Install the Android SDK packages (pass each as a SEPARATE quoted arg — zsh
#    does not word-split, unlike bash)
sdkmanager "platform-tools" "platforms;android-36" "build-tools;36.0.0" \
           "system-images;android-35;google_apis;arm64-v8a" "emulator"
yes | sdkmanager --licenses

# 6. Tell Flutter where the SDK + JDK are
flutter config --android-sdk "$ANDROID_HOME" --jdk-dir "$JAVA_HOME"

# 7. Sanity check (everything should be green except maybe Xcode/Studio, which we don't need)
flutter doctor
```

---

## 3. Build & run commands

```bash
cd ~/Projects/my-youtube

flutter pub get          # download Dart package dependencies

# --- Run on an emulator ---
emulator -avd yt_pixel & # boot the virtual phone (created once with avdmanager)
flutter run -d emulator-5554

# --- Run on a real phone (USB, with Developer Mode + USB debugging on) ---
flutter devices          # find the device id
flutter run -d <device-id>

# --- Build an installable APK to share/sideload ---
flutter build apk --debug          # debug build, auto-signed, installs anywhere
# output: build/app/outputs/flutter-apk/app-debug.apk

adb install -r build/app/outputs/flutter-apk/app-debug.apk   # push to connected device
```

> The **release** build (`flutter build apk --release`) currently signs with the **debug key** (see `android/app/build.gradle.kts`). That's fine for sideloading to your own phones, but the Play Store needs a real signing key (see §8).

### Creating the emulator (one-time, if you ever need a new one)
```bash
avdmanager create avd -n yt_pixel -k "system-images;android-35;google_apis;arm64-v8a" -d pixel
```

---

## 4. App architecture

Plain Flutter, no state-management library. Layers: **models → services → screens**, wired up by `main.dart`.

```
lib/
├── main.dart                  App entry; MaterialApp + theme; home = HomeScreen
├── models/
│   ├── channel.dart           Channel data (channelId, title, thumbnail) + JSON
│   └── video.dart             Video data (videoId, title, channelTitle, published, thumbnail)
├── services/
│   ├── youtube_service.dart   Resolve handle/URL → channel ID; fetch RSS feed → videos
│   └── storage.dart           Save/load channels via shared_preferences
└── screens/
    ├── home_screen.dart       Main UI: list, add/remove, pull-to-refresh
    └── player_screen.dart     In-app video player (WebView + local server)
```

**Data flow when you add a channel:**
1. You type `@handle` / URL / ID in the dialog (`home_screen.dart`).
2. `YoutubeService.resolveChannelId()` turns it into a `UC…` ID (scrapes the channel page if needed).
3. `YoutubeService.fetchFeed(id)` downloads `youtube.com/feeds/videos.xml?channel_id=…` and parses the XML into `Video` objects.
4. The channel is added to the in-memory list and **saved to device** via `Storage.save()`.
5. The home screen rebuilds and shows the 3 newest videos.

**Data flow when you tap a video:**
1. `home_screen` pushes `PlayerScreen(video)`.
2. `PlayerScreen` starts a tiny **local HTTP server** on `localhost`, serving an HTML page that hosts YouTube's IFrame Player.
3. A `webview_flutter` WebView loads `http://localhost:<port>/` → the video plays.

### Key dependencies (`pubspec.yaml`)
| Package | Purpose |
|---|---|
| `http` | Download channel pages + RSS feeds |
| `xml` | Parse the RSS feed XML |
| `shared_preferences` | Save channels on the device |
| `webview_flutter` + `webview_flutter_android` | The in-app player WebView |

---

## 5. The "database" (data storage)

**There is no real database and no server.** All data is local to the phone.

- Storage engine: **`shared_preferences`** — Android's key-value store (`SharedPreferences`), backed by a small XML file in the app's private sandbox.
- **One key** is used: `"channels"`.
- Its value is a **JSON string** — a list of channels:

```json
[
  {"channelId": "UCX6OQ3DkcsbYNE6H8uQQuVA", "title": "MrBeast", "thumbnail": null}
]
```

- Videos are **NOT stored** — they're fetched fresh from YouTube's RSS feed every time the app opens or you pull-to-refresh. So the video list is always current and uses no storage.
- Uninstalling the app deletes this data. There is no backup/sync.

> If you later want history, watch-later, or sync across phones, that's when you'd add a real database (e.g. `sqflite`/SQLite locally, or Firebase/Supabase for cloud sync). Not needed today.

---

## 6. The one tricky part: the in-app player

YouTube's embedded player refuses to play unless it's inside an `<iframe>` on a page served from a **genuine HTTP origin**. We hit two dead ends first:

- Loading player HTML from a *synthetic* origin → **"Video unavailable / error 152"**.
- Pointing the WebView straight at `youtube.com/embed/<id>` → **"error 153"**.

**The fix (what's in the code now):** `PlayerScreen` runs a tiny local web server on `127.0.0.1`, serves a real page that embeds the IFrame Player API, and the WebView loads `http://localhost:<port>/`. That gives YouTube the real `http://localhost` origin it accepts. Cleartext to localhost is allowed via `android/app/src/main/res/xml/network_security_config.xml`.

> Some channels disable embedding for *their* videos — those genuinely can't play in any embed and would need a "Watch on YouTube" fallback. That's a YouTube restriction, not a bug.

---

## 7. App identity & key files

| Thing | Value | File |
|---|---|---|
| App display name | `my_youtube` | `android/app/src/main/AndroidManifest.xml` (`android:label`) |
| Package / Application ID | `com.example.my_youtube` | `android/app/build.gradle.kts` |
| Version | `1.0.0+1` (`versionName`+`versionCode`) | `pubspec.yaml` (`version:`) |
| Internet permission | granted | `AndroidManifest.xml` |
| Min Android version | minSdk 24 (Android 7.0) | Flutter defaults |
| Compiled against | SDK 36 | `build.gradle.kts` |

> **Before any public release**, change the Application ID off `com.example.*` — Google Play rejects `com.example`. Pick something like `com.shazol.myyoutube`.

---

## 8. Common future tasks (cheat sheet)

| You want to… | Do this |
|---|---|
| **Update for a new version** | Bump `version:` in `pubspec.yaml` (e.g. `1.1.0+2`), rebuild APK. Higher `versionCode` lets it install over the old one cleanly. |
| **Change "last 3" to another number** | `fetchFeed(c.channelId, limit: 3)` in `home_screen.dart` (two calls) → change `3`. |
| **Rename the app** | `android:label` in `AndroidManifest.xml`. |
| **Change the app icon** | Add the `flutter_launcher_icons` package, drop in a PNG, run it. |
| **Change package id** | `applicationId` + `namespace` in `build.gradle.kts` (and re-install fresh). |
| **Release on Play Store** | Create a keystore, add a real `signingConfig` in `build.gradle.kts`, run `flutter build appbundle --release`. |
| **Add a package** | Add to `pubspec.yaml` under `dependencies:`, run `flutter pub get`. |
| **Run tests** | `flutter test`. |

### Sharing the APK to a phone (what works)
APKs sent over Telegram show only a "Share" option (Telegram won't run them). Instead: in Telegram tap **⋮ → Save to Downloads**, open the **Files** app, tap the APK, allow "install from unknown sources". Or share via a **Google Drive** link.

---

## 9. Gotchas to remember

- **zsh ≠ bash:** zsh does not word-split unquoted variables. Always pass `sdkmanager` package names as separate quoted strings.
- **Use `openjdk@17` formula**, not the temurin cask (sudo issue).
- Flutter 3.44 defaults to **compile/target SDK 36** — that's why android-36 platform + build-tools 36 are required, even though the emulator image is API 35.
- The release build uses the **debug signing key** right now (fine for sideload, not for Play Store).
- After editing native/Android config, do a clean build if something acts stale: `flutter clean && flutter pub get && flutter build apk --debug`.
