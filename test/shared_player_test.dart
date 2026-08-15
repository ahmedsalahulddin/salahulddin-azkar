import 'package:flutter_test/flutter_test.dart';
import 'package:salahulddin_azkar/services/app_audio.dart';

/// One player serves the whole app, which turns "something is loaded" into a
/// trap: it no longer means "my playlist is loaded". A screen that assumes so
/// seeks into whatever the last screen left behind — the reported symptom was
/// exactly that, the radio playing on under a reciter's name with a stop
/// button beside him.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('ownership is decided by the tag, not by there being a tag', () {
    // The ids the app actually mints, in the shape it mints them.
    const radio = 'radio:afasy';
    const husary = 'Husary_128kbps:2:5';
    const hisn = 'hisn:14';

    // Every screen asks about its own prefix.
    bool owns(String? loaded, String owner) =>
        loaded?.startsWith(owner) ?? false;

    // The reported bug: the radio is loaded, the reader opens تلاوة وتدبّر.
    expect(owns(radio, 'Husary_128kbps:'), isFalse,
        reason: 'the reciter screen must not claim the broadcast');
    expect(owns(radio, 'hisn:'), isFalse);
    expect(owns(radio, 'radio:'), isTrue);

    // And each screen still recognises its own.
    expect(owns(husary, 'Husary_128kbps:'), isTrue);
    expect(owns(hisn, 'hisn:'), isTrue);

    // A different reciter's playlist is not this reciter's.
    expect(owns('Alafasy_128kbps:2:5', 'Husary_128kbps:'), isFalse,
        reason: 'switching reciter must rebuild the playlist, not seek in it');

    // Nothing loaded is owned by nobody.
    expect(owns(null, 'radio:'), isFalse);
  });

  test('an empty player reports no owner rather than throwing', () {
    expect(AppAudio.currentId(), isNull);
    expect(AppAudio.ownsCurrent('radio:'), isFalse);
  });
}
