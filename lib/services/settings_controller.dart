import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// App-wide, user-configurable preferences, persisted to device storage.
class SettingsController extends ChangeNotifier {
  static const _videosKey = 'videos_per_channel';
  static const _themeKey = 'theme_mode';

  static const int minVideosPerChannel = 1;
  static const int maxVideosPerChannel = 10;

  int _videosPerChannel = 3;
  ThemeMode _themeMode = ThemeMode.system;

  int get videosPerChannel => _videosPerChannel;
  ThemeMode get themeMode => _themeMode;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _videosPerChannel = (prefs.getInt(_videosKey) ?? 3)
        .clamp(minVideosPerChannel, maxVideosPerChannel);
    _themeMode = ThemeMode.values[
        (prefs.getInt(_themeKey) ?? ThemeMode.system.index)
            .clamp(0, ThemeMode.values.length - 1)];
    notifyListeners();
  }

  Future<void> setVideosPerChannel(int value) async {
    final clamped = value.clamp(minVideosPerChannel, maxVideosPerChannel);
    if (clamped == _videosPerChannel) return;
    _videosPerChannel = clamped;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_videosKey, clamped);
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    if (mode == _themeMode) return;
    _themeMode = mode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_themeKey, mode.index);
  }
}
