import 'package:http/http.dart' as http;
import 'package:xml/xml.dart';

import '../models/channel.dart';
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
