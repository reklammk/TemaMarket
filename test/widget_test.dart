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

  test('sanal market fails closed when the server value is missing', () {
    expect(const FeatureFlags().sanalMarket, isFalse);
    expect(FeatureFlags.fromJson(const {}).sanalMarket, isFalse);
  });

  testWidgets('login form does not prefill phone or consent', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: AuthPage(defaultRole: 'Customer')),
    );
    await tester.pump();

    final phoneField = tester.widget<TextField>(find.byType(TextField).first);
    expect(phoneField.controller?.text, isEmpty);
    expect(find.text('Giriş Yapılacak Rol'), findsNothing);

    final checkboxes =
        tester.widgetList<Checkbox>(find.byType(Checkbox)).toList();
    expect(checkboxes, isNotEmpty);
    expect(checkboxes.every((checkbox) => checkbox.value == false), isTrue);
    expect(find.textContaining('123987'), findsNothing);
  });

  testWidgets('login navbar opens the selected storefront tab', (tester) async {
    int? selectedTab;
    await tester.pumpWidget(
      MaterialApp(
        home: AuthPage(
          defaultRole: 'Customer',
          onNavigate: (tab) => selectedTab = tab,
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.byIcon(Icons.store_rounded));
    expect(selectedTab, 1);

    await tester.tap(find.byIcon(Icons.shopping_bag_outlined));
    expect(selectedTab, 2);

    await tester.tap(find.byIcon(Icons.auto_awesome_rounded));
    expect(selectedTab, 3);
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
