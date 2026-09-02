import 'package:flutter_test/flutter_test.dart';
import 'package:hastakala/main.dart';

void main() {
  testWidgets('App boots to landing', (WidgetTester tester) async {
    await tester.pumpWidget(const HastakalaApp());
    expect(find.text('Building Tomorrow.'), findsOneWidget);
  });
}
