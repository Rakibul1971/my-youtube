import 'package:flutter/material.dart';

import '../services/settings_controller.dart';
import 'channels_screen.dart';
import 'saved_videos_screen.dart';
import 'settings_screen.dart';

/// Hosts the three top-level tabs behind a Material 3 navigation bar.
class RootScreen extends StatefulWidget {
  final SettingsController settings;
  const RootScreen({super.key, required this.settings});

  @override
  State<RootScreen> createState() => _RootScreenState();
}

class _RootScreenState extends State<RootScreen> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      ChannelsScreen(settings: widget.settings),
      const SavedVideosScreen(),
      SettingsScreen(settings: widget.settings),
    ];

    return Scaffold(
      body: IndexedStack(index: _index, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.subscriptions_outlined),
            selectedIcon: Icon(Icons.subscriptions),
            label: 'Channels',
          ),
          NavigationDestination(
            icon: Icon(Icons.bookmark_border),
            selectedIcon: Icon(Icons.bookmark),
            label: 'Saved',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}
