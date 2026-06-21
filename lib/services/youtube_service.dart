import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:xml/xml.dart';

import '../models/channel.dart';
import '../models/saved_video.dart';
import '../models/video.dart';

/// Reads YouTube's public RSS feeds — no API key required.
class YoutubeService {
  static final _channelIdRe = RegExp(r'^UC[\w-]{22}$');
  static final _channelUrlRe = RegExp(r'channel/(UC[\w-]{22})');
  // The page's own channel — prefer the canonical link / metadata owner over
  // the first "channelId" in the HTML, which may be a linked/featured channel.
  static final _canonicalRe =
      RegExp(r'<link rel="canonical" href="https://www\.youtube\.com/channel/(UC[\w-]{22})"');
  static final _externalIdRe = RegExp(r'"externalId":"(UC[\w-]{22})"');
  static final _channelIdJsonRe = RegExp(r'"channelId":"(UC[\w-]{22})"');

  // Channel avatar: the channel page exposes it as og:image; the embedded
  // ytInitialData JSON carries it as an "avatar" thumbnail as a fallback.
  static final _ogImageRe =
      RegExp(r'<meta property="og:image" content="([^"]+)"');
  static final _avatarJsonRe =
      RegExp(r'"avatar":\{"thumbnails":\[\{"url":"(https://[^"]+?)"');

  static final _bareVideoIdRe = RegExp(r'^[\w-]{11}$');
  static final _videoUrlRe = RegExp(
      r'(?:youtu\.be/|/shorts/|/embed/|[?&]v=)([\w-]{11})');

  static const _headers = {
    'User-Agent':
        'Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120 Mobile Safari/537.36',
    'Accept-Language': 'en-US,en;q=0.9',
  };

  /// Turns a raw user input (channel id, full URL, or @handle) into a UC… id.
  Future<String> resolveChannelId(String input) async {
    final raw = input.trim();
    if (raw.isEmpty) throw 'Enter a channel link or ID.';

    if (_channelIdRe.hasMatch(raw)) return raw;

    final urlMatch = _channelUrlRe.firstMatch(raw);
    if (urlMatch != null) return urlMatch.group(1)!;

    final Uri pageUrl;
    if (raw.startsWith('http')) {
      pageUrl = Uri.parse(raw);
    } else if (raw.startsWith('@')) {
      pageUrl = Uri.parse('https://www.youtube.com/$raw');
    } else {
      pageUrl = Uri.parse('https://www.youtube.com/@$raw');
    }

    final res = await http.get(pageUrl, headers: _headers);
    if (res.statusCode != 200) {
      throw 'Could not load that channel (HTTP ${res.statusCode}).';
    }
    final match = _canonicalRe.firstMatch(res.body) ??
        _externalIdRe.firstMatch(res.body) ??
        _channelIdJsonRe.firstMatch(res.body) ??
        _channelUrlRe.firstMatch(res.body);
    if (match == null) throw 'Could not find a channel ID for that input.';
    return match.group(1)!;
  }

  /// Fetches a channel's avatar image URL by scraping its public page.
  /// Returns null if it can't be found (network error, markup change, etc.).
  Future<String?> fetchChannelAvatar(String channelId) async {
    final url = Uri.parse('https://www.youtube.com/channel/$channelId');
    try {
      final res = await http.get(url, headers: _headers);
      if (res.statusCode != 200) return null;
      final match = _ogImageRe.firstMatch(res.body) ??
          _avatarJsonRe.firstMatch(res.body);
      // ytInitialData escapes slashes as \/; normalise before use.
      return match?.group(1)?.replaceAll(r'\/', '/');
    } catch (_) {
      return null;
    }
  }

  /// Extracts an 11-character video id from a watch/share/shorts/embed URL or
  /// a bare id. Returns null when nothing looks like a video id.
  String? parseVideoId(String input) {
    final raw = input.trim();
    if (raw.isEmpty) return null;
    if (_bareVideoIdRe.hasMatch(raw)) return raw;
    return _videoUrlRe.firstMatch(raw)?.group(1);
  }

  /// Resolves a video link into a [SavedVideo], pulling its title, channel and
  /// thumbnail from YouTube's keyless oEmbed endpoint.
  Future<SavedVideo> resolveVideo(String input) async {
    final id = parseVideoId(input);
    if (id == null) throw 'Could not find a video link or ID in that input.';

    final now = DateTime.now();
    final oembed = Uri.parse(
        'https://www.youtube.com/oembed?url=https://www.youtube.com/watch?v=$id&format=json');
    try {
      final res = await http.get(oembed, headers: _headers);
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        return SavedVideo(
          videoId: id,
          title: (data['title'] as String?)?.trim() ?? 'Video $id',
          channelTitle: (data['author_name'] as String?)?.trim() ?? '',
          thumbnail: data['thumbnail_url'] as String?,
          addedAt: now,
        );
      }
      if (res.statusCode == 401 || res.statusCode == 404) {
        throw 'That video is private, removed, or unavailable.';
      }
    } on FormatException {
      // Fall through to a minimal entry below.
    }
    // Network/format hiccup: still save the id so playback can be attempted.
    return SavedVideo(
      videoId: id,
      title: 'Video $id',
      channelTitle: '',
      thumbnail: null,
      addedAt: now,
    );
  }

  /// Fetches the channel's feed and returns up to [limit] most recent videos
  /// plus the channel metadata.
  Future<(Channel, List<Video>)> fetchFeed(String channelId,
      {int limit = 3}) async {
    final url = Uri.parse(
        'https://www.youtube.com/feeds/videos.xml?channel_id=$channelId');
    final res = await http.get(url, headers: _headers);
    if (res.statusCode != 200) {
      throw 'Feed request failed (HTTP ${res.statusCode}).';
    }

    final doc = XmlDocument.parse(res.body);
    final feed = doc.rootElement;

    final channelTitle = feed
            .getElement('title')
            ?.innerText
            .trim() ??
        channelId;

    final entries = feed.findElements('entry').take(limit);
    final videos = <Video>[];
    for (final e in entries) {
      final videoId =
          e.getElement('yt:videoId')?.innerText.trim() ?? '';
      if (videoId.isEmpty) continue;
      final publishedStr = e.getElement('published')?.innerText.trim();
      final thumb = e
          .getElement('media:group')
          ?.getElement('media:thumbnail')
          ?.getAttribute('url');
      videos.add(Video(
        videoId: videoId,
        title: e.getElement('title')?.innerText.trim() ?? '(untitled)',
        channelTitle: channelTitle,
        published:
            publishedStr != null ? DateTime.tryParse(publishedStr) : null,
        thumbnail: thumb,
      ));
    }

    final channel = Channel(channelId: channelId, title: channelTitle);
    return (channel, videos);
  }
}
