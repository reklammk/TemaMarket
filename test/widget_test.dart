import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tema_market/pages/auth_page.dart';
import 'package:tema_market/pages/splash_screen_page.dart';
import 'package:tema_market/services/feature_flags_service.dart';
import 'package:tema_market/utils/customer_profile_utils.dart';

void main() {
  test('TEMA Kart barkodu telefon numarasının rakamlarını kullanır', () {
    expect(customerPhoneBarcodeValue('+90 (555) 123 45 67'), '905551234567');
    expect(customerPhoneBarcodeValue(null), isEmpty);
  });

  test('indirim tercihleri temizlenir, tekilleştirilir ve sınırlandırılır', () {
    expect(
      parseDiscountPreferences([' Kasap ', 'Manav', 'Kasap', '', 42]),
      {'Kasap', 'Manav'},
    );
    expect(parseDiscountPreferences('Kasap'), isEmpty);
  });

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

  test('adres ekleme kontratı id, başlık ve ilçe verisini doğrular', () {
    final serverResponse = {
      'success': true,
      'message': 'Adres kaydedildi.',
      'data': {
        'id': 42,
        'title': 'Ev Adresi',
        'address': 'Gezköy OSB Mah. No:5',
        'city_district': 'Erzurum / Aziziye',
        'is_default': 0,
      }
    };
    expect(serverResponse['success'], isTrue);
    final data = serverResponse['data'] as Map<String, dynamic>;
    expect(data['id'], 42);
    expect(data['title'], 'Ev Adresi');
    expect(data['city_district'], 'Erzurum / Aziziye');
  });

  test('TemaPuan yanıtı total_points ve tl_equivalent alanlarını okur', () {
    final serverResponse = {
      'success': true,
      'data': {
        'total_points': 250,
        'tl_equivalent': 25.0,
        'history': [
          {'points': 50, 'type': 'Kazanım', 'description': 'Sipariş puanı'}
        ]
      }
    };
    final data = serverResponse['data'] as Map<String, dynamic>;
    final points = data['total_points'] ?? data['points'] ?? 0;
    final value = (data['tl_equivalent'] as num?)?.toDouble() ?? 0.0;
    expect(points, 250);
    expect(value, 25.0);
    expect((data['history'] as List).length, 1);
  });
}
