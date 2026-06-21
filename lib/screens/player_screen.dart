import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

import '../models/video.dart';

/// Plays a YouTube video inside the app.
///
/// YouTube's embedded player only allows playback when it lives inside an
/// `<iframe>` whose parent page is served from a real HTTP origin. Loading the
/// player HTML from a synthetic origin (error 152) or pointing the WebView at
/// the embed URL top-level (error 153) both fail. So we spin up a tiny local
/// HTTP server on localhost, serve a page that hosts the IFrame Player API,
/// and load that — giving the parent page a genuine `http://localhost` origin
/// that YouTube accepts.
class PlayerScreen extends StatefulWidget {
  final Video video;
  const PlayerScreen({super.key, required this.video});

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  WebViewController? _controller;
  HttpServer? _server;
  bool _loading = true;
  bool _fullscreen = false;
  bool _embedBlocked = false;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    _server = server;
    final html = _playerHtml(widget.video.videoId);
    server.listen((req) {
      req.response
        ..headers.contentType = ContentType.html
        ..write(html);
      req.response.close();
    });

    const params = PlatformWebViewControllerCreationParams();
    final controller = WebViewController.fromPlatformCreationParams(params)
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.black)
      ..addJavaScriptChannel(
        'PlayerChannel',
        onMessageReceived: (msg) {
          // The IFrame player reports an error code when a video can't be
          // embedded (e.g. 101/150 = embedding disabled by the owner).
          if (msg.message == 'error' && mounted) {
            setState(() => _embedBlocked = true);
          }
        },
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) {
            if (mounted) setState(() => _loading = false);
          },
        ),
      )
      ..loadRequest(Uri.parse('http://localhost:${server.port}/'));

    if (controller.platform is AndroidWebViewController) {
      (controller.platform as AndroidWebViewController)
          .setMediaPlaybackRequiresUserGesture(false);
    }

    if (mounted) setState(() => _controller = controller);
  }

  String _playerHtml(String videoId) => '''
<!DOCTYPE html>
<html>
<head>
<meta name="viewport" content="width=device-width, initial-scale=1, user-scalable=no">
<style>
  html, body { margin: 0; padding: 0; background: #000; height: 100%; overflow: hidden; }
  #player { width: 100%; height: 100%; }
</style>
</head>
<body>
<div id="player"></div>
<script src="https://www.youtube.com/iframe_api"></script>
<script>
  var player;
  function onYouTubeIframeAPIReady() {
    player = new YT.Player('player', {
      videoId: '$videoId',
      playerVars: { autoplay: 1, playsinline: 1, rel: 0, modestbranding: 1 },
      events: {
        'onError': function(e) {
          if (window.PlayerChannel) PlayerChannel.postMessage('error');
        }
      }
    });
  }
</script>
</body>
</html>
''';

  Future<void> _openInYouTube() async {
    final messenger = ScaffoldMessenger.of(context);
    final uri = Uri.parse(widget.video.watchUrl);
    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok) throw 'No app available to open the link.';
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text("Couldn't open YouTube.")),
      );
    }
  }

  void _enterFullscreen() {
    setState(() => _fullscreen = true);
    SystemChrome.setPreferredOrientations(
        [DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  void _exitFullscreen() {
    setState(() => _fullscreen = false);
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }

  @override
  void dispose() {
    // Restore normal orientation/system UI if we left while in fullscreen.
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _server?.close(force: true);
    super.dispose();
  }

  Widget _videoSurface() {
    final controller = _controller;
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(color: Colors.black),
        if (controller != null) WebViewWidget(controller: controller),
        if (_loading)
          const Center(child: CircularProgressIndicator(color: Colors.white)),
        if (_embedBlocked) _EmbedBlockedOverlay(onOpen: _openInYouTube),
        Positioned(
          right: 4,
          bottom: 4,
          child: IconButton(
            tooltip: _fullscreen ? 'Exit fullscreen' : 'Fullscreen',
            icon: Icon(
              _fullscreen ? Icons.fullscreen_exit : Icons.fullscreen,
              color: Colors.white,
            ),
            onPressed: _fullscreen ? _exitFullscreen : _enterFullscreen,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_fullscreen) {
      return PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) _exitFullscreen();
        },
        child: Scaffold(
          backgroundColor: Colors.black,
          body: Center(
            child: AspectRatio(aspectRatio: 16 / 9, child: _videoSurface()),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.video.channelTitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            tooltip: 'Open in YouTube',
            icon: const Icon(Icons.open_in_new),
            onPressed: _openInYouTube,
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(aspectRatio: 16 / 9, child: _videoSurface()),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              widget.video.title,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
        ],
      ),
    );
  }
}

/// Shown over the player when YouTube refuses to embed a video.
class _EmbedBlockedOverlay extends StatelessWidget {
  final VoidCallback onOpen;
  const _EmbedBlockedOverlay({required this.onOpen});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black87,
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.lock_outline, color: Colors.white70, size: 40),
          const SizedBox(height: 12),
          const Text(
            "This video can't be played here.",
            style: TextStyle(color: Colors.white),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          const Text(
            'The owner disabled embedded playback.',
            style: TextStyle(color: Colors.white70, fontSize: 12),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: onOpen,
            icon: const Icon(Icons.open_in_new),
            label: const Text('Open in YouTube'),
          ),
        ],
      ),
    );
  }
}
