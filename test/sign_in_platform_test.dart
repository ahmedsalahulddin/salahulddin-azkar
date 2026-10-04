import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salahulddin_azkar/services/auth_service.dart';

void main() {
  const google = SignInProvider.google;
  const apple = SignInProvider.apple;

  test('Android offers whatever the project has switched on', () {
    expect(AuthService.offeredOn(TargetPlatform.android, {google}), {google});
  });

  test('iPhone hides Google while Sign in with Apple is off', () {
    expect(AuthService.offeredOn(TargetPlatform.iOS, {google}), isEmpty);
  });

  test('iPhone offers both once Apple is switched on', () {
    expect(AuthService.offeredOn(TargetPlatform.iOS, {google, apple}), {
      google,
      apple,
    });
  });
}
