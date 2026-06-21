import 'package:flutter/material.dart';

import 'screens/root_screen.dart';
import 'services/settings_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final settings = SettingsController();
  await settings.load();
  runApp(MyYoutubeApp(settings: settings));
}

class MyYoutubeApp extends StatelessWidget {
  final SettingsController settings;
  const MyYoutubeApp({super.key, required this.settings});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) => MaterialApp(
        title: 'My YouTube',
        debugShowCheckedModeBanner: false,
        themeMode: settings.themeMode,
        theme: ThemeData(
          useMaterial3: true,
          colorSchemeSeed: const Color(0xFFFF0000),
          brightness: Brightness.light,
        ),
        darkTheme: ThemeData(
          useMaterial3: true,
          colorSchemeSeed: const Color(0xFFFF0000),
          brightness: Brightness.dark,
        ),
        home: RootScreen(settings: settings),
      ),
    );
  }
}
