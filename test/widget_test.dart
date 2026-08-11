import 'package:flutter_test/flutter_test.dart';
import 'package:temasan_mobile_app/main.dart';

void main() {
  testWidgets('TemasanApp smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const TemasanApp());
    expect(find.byType(TemasanApp), findsOneWidget);
  });
}
