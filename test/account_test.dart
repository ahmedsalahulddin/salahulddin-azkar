import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salahulddin_azkar/screens/account_screen.dart';
import 'package:salahulddin_azkar/services/auth_service.dart';
import 'package:salahulddin_azkar/widgets/sign_in_buttons.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AuthService.user.value = null;
    AuthService.availableProviders.value = {};
  });

  group('guest', () {
    test('nobody is signed in until they choose to be', () {
      expect(AuthService.user.value, isNull);
    });

    test('no provider is offered until the project reports one', () {
      // Offering a provider the project has not enabled can only fail.
      expect(AuthService.availableProviders.value, isEmpty);
      expect(AuthService.googleAvailable, isFalse);
    });

    test('every provider maps to a distinct Supabase provider and label', () {
      final keys = SignInProvider.values.map((p) => p.key).toList();
      expect(keys.toSet().length, keys.length);
      for (final p in SignInProvider.values) {
        expect(p.label.trim(), isNotEmpty);
        // The brand name must appear in the button text, as their terms require.
        expect(p.label, contains(p.brand));
      }
    });

    test('signing out of nothing is harmless', () async {
      await AuthService.signOut();
      expect(AuthService.user.value, isNull);
    });
  });

  group('display of a signed-in reader', () {
    test('falls back through name, then email, then a placeholder', () {
      expect(
        const AppUser(id: '1', name: 'أحمد صلاح', email: 'a@b.com')
            .displayName,
        'أحمد صلاح',
      );
      // A blank name must not produce a blank label.
      expect(
        const AppUser(id: '2', name: '   ', email: 'ahmed@b.com').displayName,
        'ahmed',
      );
      expect(const AppUser(id: '3').displayName, 'مستخدم');
    });

    test('initials come from the first two words', () {
      expect(const AppUser(id: '1', name: 'أحمد صلاح').initials, 'أص');
      expect(const AppUser(id: '2', name: 'أحمد').initials, 'أ');
      expect(const AppUser(id: '3', name: 'Ahmed Salah').initials, 'AS');
    });
  });

  testWidgets('the account screen offers settings and never blocks a guest',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(home: AccountScreen()));
    await tester.pump();

    expect(find.text('تقرأ كضيف'), findsOneWidget);
    expect(find.textContaining('حجم الخط والتذكيرات'), findsOneWidget);
    // While no provider is on, the buttons are replaced by an honest note.
    expect(find.textContaining('قريباً'), findsOneWidget);
    expect(find.byType(SignInButton), findsNothing);

    // Switching providers on surfaces their buttons with no rebuild of the app.
    AuthService.availableProviders.value = {
      SignInProvider.google,
      SignInProvider.facebook,
    };
    await tester.pump();

    expect(find.byType(SignInButton), findsNWidgets(2));
    expect(find.text(SignInProvider.google.label), findsOneWidget);
    expect(find.text(SignInProvider.facebook.label), findsOneWidget);
    expect(find.textContaining('قريباً'), findsNothing);
    // Apple was not enabled, so it must not appear.
    expect(find.text(SignInProvider.apple.label), findsNothing);
  });

  testWidgets('the avatar shows a guest mark, then the reader once known',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: UserAvatar(user: null)),
    ));
    expect(find.byIcon(Icons.person_outline), findsOneWidget);

    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: UserAvatar(user: AppUser(id: '1', name: 'أحمد صلاح')),
      ),
    ));
    expect(find.text('أص'), findsOneWidget);
  });
}
