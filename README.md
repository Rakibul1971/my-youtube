# My YouTube

A Flutter (Android) app to track the **last 3 videos** from your favourite YouTube channels.

- Add a channel by **@handle**, **channel URL**, or **UC… channel ID**.
- The 3 most recent videos from every saved channel appear on the home screen.
- Tap a video to play it **inside the app** (no leaving for the browser/YouTube app).
- No API key required — it reads YouTube's public RSS feeds.
- Channels are saved on-device with `shared_preferences`.

## Run

```bash
flutter pub get
flutter run            # with an Android emulator or device connected
```

## How it works

| Concern            | Where |
|--------------------|-------|
| Resolve handle/URL → channel ID | `lib/services/youtube_service.dart` |
| Fetch latest videos (RSS)       | `lib/services/youtube_service.dart` (`feeds/videos.xml`) |
| Persist channels                | `lib/services/storage.dart` |
| UI                              | `lib/screens/home_screen.dart` |
| In-app video player             | `lib/screens/player_screen.dart` |

### In-app player note

YouTube's embedded player only allows playback inside an `<iframe>` whose parent
page is served from a real HTTP origin. Loading the player HTML from a synthetic
origin gives "Video unavailable / error 152", and pointing a WebView at the
`youtube.com/embed/...` URL top-level gives "error 153". So `PlayerScreen` starts
a tiny local HTTP server on `localhost`, serves a page hosting the IFrame Player
API, and loads that in a `webview_flutter` WebView — giving the parent page a
genuine `http://localhost` origin that YouTube accepts. Cleartext to localhost is
enabled via `android/app/src/main/res/xml/network_security_config.xml`.

(Some channels still disable embedding for their videos — those show YouTube's
"Watch on YouTube" fallback, which is expected.)
