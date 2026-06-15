import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:my_youtube/main.dart';

void main() {
  testWidgets('shows empty state with an add button', (tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const MyYoutubeApp());
    await tester.pumpAndSettle();

    expect(find.text('No channels yet'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Add a channel'), findsOneWidget);
  });
}
