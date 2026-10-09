import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salahulddin_azkar/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const NoorAzkarApp());
    // The home header carries the app's name.
    expect(find.textContaining('الأذكار'), findsWidgets);
    // The home screen starts one-shot timers (tours, the verse rotation);
    // let them run out after the tree is gone so none is left pending.
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(minutes: 1));
  });
}
