import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/channel.dart';
import '../models/saved_video.dart';

/// Persists the user's saved channels and videos to device storage.
class Storage {
  static const _channelsKey = 'channels';
  static const _videosKey = 'saved_videos';

  Future<List<Channel>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_channelsKey);
    if (raw == null) return [];
    final list = jsonDecode(raw) as List<dynamic>;
    return list
        .map((e) => Channel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> save(List<Channel> channels) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _channelsKey,
      jsonEncode(channels.map((c) => c.toJson()).toList()),
    );
  }

  Future<List<SavedVideo>> loadVideos() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_videosKey);
    if (raw == null) return [];
    final list = jsonDecode(raw) as List<dynamic>;
    return list
        .map((e) => SavedVideo.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> saveVideos(List<SavedVideo> videos) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _videosKey,
      jsonEncode(videos.map((v) => v.toJson()).toList()),
    );
  }
}
