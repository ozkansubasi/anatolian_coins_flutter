// Uygulamanın açılışta çökmediğini doğrulayan temel smoke test.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:anatolian_coins/main.dart';
import 'package:anatolian_coins/src/features/settings/settings_provider.dart';

void main() {
  testWidgets('App builds without crashing', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
        child: const AnatolianCoinsApp(),
      ),
    );

    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
