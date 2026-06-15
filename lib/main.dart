import 'package:flutter/material.dart';

import 'screens/home_screen.dart';

void main() => runApp(const MyYoutubeApp());

class MyYoutubeApp extends StatelessWidget {
  const MyYoutubeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'My YouTube',
      debugShowCheckedModeBanner: false,
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
      home: const HomeScreen(),
    );
  }
}
