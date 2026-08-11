import 'package:flutter_test/flutter_test.dart';
import 'package:tema_market/main.dart';

void main() {
  testWidgets('TemasanApp smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const TemasanApp());
    expect(find.byType(TemasanApp), findsOneWidget);
  });
}
