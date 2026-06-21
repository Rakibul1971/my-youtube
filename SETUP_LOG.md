# Environment Setup Log — my_youtube Flutter app

Goal: install SDK + emulator and run the app on this Mac (Apple Silicon, arm64, macOS Darwin 25.3).

## Starting state (what was missing)
- Flutter / Dart: not installed
- Java (JDK): not installed
- Android SDK / emulator / adb: not installed
- Xcode: only Command Line Tools (no iOS simulator)
- Homebrew: present ✅

## Downloads / installs
| # | What | Command | Status |
|---|------|---------|--------|
| 1 | Flutter SDK (+Dart) | `brew install --cask flutter temurin android-commandlinetools` | ✅ Flutter 3.44.2 / Dart 3.12.2 |
| 1b | Temurin JDK (in same cmd) | (same) | ❌ failed — .pkg needs sudo password (non-interactive) |
| 1c | android-commandlinetools (aborted by 1b failure, reinstalled) | `brew install --cask android-commandlinetools` | ✅ |
| 2 | JDK 17 (sudo-free alternative to Temurin) | `brew install openjdk@17` | running |

SDK root: `/opt/homebrew/share/android-commandlinetools`

## JDK
- `brew install openjdk@17` → ✅ OpenJDK 17.0.19 at `/opt/homebrew/opt/openjdk@17`

## Environment (appended to `~/.zshrc`)
```
export JAVA_HOME="/opt/homebrew/opt/openjdk@17"
export ANDROID_HOME="/opt/homebrew/share/android-commandlinetools"
export ANDROID_SDK_ROOT="$ANDROID_HOME"
export PATH="$JAVA_HOME/bin:$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools:$ANDROID_HOME/emulator:$PATH"
```
- `flutter config --jdk-dir=$JAVA_HOME --android-sdk=$ANDROID_HOME`

## Android SDK packages (via sdkmanager)
- `yes | sdkmanager --licenses`  (accept all licenses)
- `sdkmanager "platform-tools" "emulator" "platforms;android-36" "build-tools;36.0.0" "system-images;android-36;google_apis;arm64-v8a"`
- Flutter defaults: compileSdk 36 / targetSdk 36 / minSdk 24

## Project deps
- `flutter pub get` → ✅

## AVD / emulator
- `avdmanager create avd -n flutter_pixel -k "system-images;android-36;google_apis;arm64-v8a" -d pixel_7 --force`
- Boot: `emulator -avd flutter_pixel -no-snapshot -no-boot-anim -gpu swiftshader_indirect`
- `flutter doctor`: Flutter ✓ / Android toolchain SDK 36 ✓ / Chrome ✓ (Xcode incomplete = N/A; "Network resources" check timed out — harmless)

## Run command
- `flutter run -d emulator-5554` → ✅ built, installed `com.example.
`, launched MainActivity
- Verified: app shows "My YouTube" / "No channels yet" empty state on the emulator
- Note: first build is slow (Gradle + deps download); the app only appears in the launcher after it completes.

## Feature work (channels / saved links / settings tabs)
- Added bottom-nav tabs: **Channels**, **Saved**, **Settings** (`lib/screens/root_screen.dart`)
- Settings (persisted): videos-per-channel (1–10) + theme mode (`lib/services/settings_controller.dart`, `settings_screen.dart`)
- Saved videos by link via keyless oEmbed metadata (`lib/models/saved_video.dart`, `saved_videos_screen.dart`, `youtube_service.resolveVideo`)
- `flutter analyze` clean; `flutter test` 2/2 pass
