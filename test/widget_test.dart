import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tema_market/pages/auth_page.dart';
import 'package:tema_market/pages/splash_screen_page.dart';
import 'package:tema_market/services/feature_flags_service.dart';

void main() {
  test('feature flag values safely parse booleans, numbers and strings', () {
    final flags = FeatureFlags.fromJson({
      'sanal_market': 'false',
      'bayi_stok': 0,
      'temapuan': 1,
      'soft_pos': 'true',
    });

    expect(flags.sanalMarket, isFalse);
    expect(flags.bayiStok, isFalse);
    expect(flags.temapuan, isTrue);
    expect(flags.softPos, isTrue);
    expect(flags.sanalPos, isFalse);
  });

  testWidgets('login form does not prefill phone or consent', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: AuthPage(defaultRole: 'Customer')),
    );
    await tester.pump();

    final phoneField = tester.widget<TextField>(find.byType(TextField).first);
    expect(phoneField.controller?.text, isEmpty);

    final checkboxes =
        tester.widgetList<Checkbox>(find.byType(Checkbox)).toList();
    expect(checkboxes, isNotEmpty);
    expect(checkboxes.every((checkbox) => checkbox.value == false), isTrue);
    expect(find.textContaining('123987'), findsNothing);
  });

  testWidgets('splash disposal cancels its fallback timer', (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: SplashScreenPage(onFinish: () {})),
    );
    await tester.pump();
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}
