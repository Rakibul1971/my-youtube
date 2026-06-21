import 'package:flutter/material.dart';

import '../services/settings_controller.dart';

/// Tab for user-configurable preferences.
class SettingsScreen extends StatelessWidget {
  final SettingsController settings;
  const SettingsScreen({super.key, required this.settings});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListenableBuilder(
        listenable: settings,
        builder: (context, _) => ListView(
          padding: const EdgeInsets.symmetric(vertical: 8),
          children: [
            const _SectionHeader('Feed'),
            ListTile(
              title: const Text('Videos per channel'),
              subtitle: Text(
                'Show the latest ${settings.videosPerChannel} '
                '${settings.videosPerChannel == 1 ? 'video' : 'videos'} '
                'from each channel.',
              ),
              trailing: Text(
                '${settings.videosPerChannel}',
                style: theme.textTheme.titleLarge
                    ?.copyWith(color: theme.colorScheme.primary),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Slider(
                min: SettingsController.minVideosPerChannel.toDouble(),
                max: SettingsController.maxVideosPerChannel.toDouble(),
                divisions: SettingsController.maxVideosPerChannel -
                    SettingsController.minVideosPerChannel,
                value: settings.videosPerChannel.toDouble(),
                label: '${settings.videosPerChannel}',
                onChanged: (v) => settings.setVideosPerChannel(v.round()),
              ),
            ),
            const Divider(),
            const _SectionHeader('Appearance'),
            ListTile(
              title: const Text('Theme'),
              subtitle: Text(_themeLabel(settings.themeMode)),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: SegmentedButton<ThemeMode>(
                segments: const [
                  ButtonSegment(
                    value: ThemeMode.system,
                    label: Text('System'),
                    icon: Icon(Icons.brightness_auto),
                  ),
                  ButtonSegment(
                    value: ThemeMode.light,
                    label: Text('Light'),
                    icon: Icon(Icons.light_mode),
                  ),
                  ButtonSegment(
                    value: ThemeMode.dark,
                    label: Text('Dark'),
                    icon: Icon(Icons.dark_mode),
                  ),
                ],
                selected: {settings.themeMode},
                onSelectionChanged: (s) => settings.setThemeMode(s.first),
              ),
            ),
            const Divider(),
            const AboutListTile(
              icon: Icon(Icons.info_outline),
              applicationName: 'MyTube',
              applicationVersion: '1.0.0',
              aboutBoxChildren: [
                Text(
                  'Track the latest videos from your favourite channels and '
                  'keep a list of saved video links. Uses YouTube public '
                  'feeds — no account or API key needed.',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _themeLabel(ThemeMode mode) => switch (mode) {
        ThemeMode.system => 'Follow system setting',
        ThemeMode.light => 'Always light',
        ThemeMode.dark => 'Always dark',
      };
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Text(
        title,
        style: theme.textTheme.titleSmall
            ?.copyWith(color: theme.colorScheme.primary),
      ),
    );
  }
}
