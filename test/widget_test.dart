import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:my_youtube/main.dart';
import 'package:my_youtube/services/settings_controller.dart';

void main() {
  testWidgets('shows channels empty state with an add button', (tester) async {
    SharedPreferences.setMockInitialValues({});

    final settings = SettingsController();
    await settings.load();

    await tester.pumpWidget(MyYoutubeApp(settings: settings));
    await tester.pumpAndSettle();

    expect(find.text('No channels yet'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Add a channel'), findsOneWidget);
  });

  testWidgets('can switch to the Saved tab', (tester) async {
    SharedPreferences.setMockInitialValues({});

    final settings = SettingsController();
    await settings.load();

    await tester.pumpWidget(MyYoutubeApp(settings: settings));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Saved'));
    await tester.pumpAndSettle();

    expect(find.text('No saved videos'), findsOneWidget);
  });
}
