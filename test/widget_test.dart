import 'package:flutter_test/flutter_test.dart';
import 'package:salahulddin_azkar/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const NoorAzkarApp());
    // The home header carries the app's name.
    expect(find.textContaining('الأذكار'), findsWidgets);
  });
}
