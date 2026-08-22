import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salahulddin_azkar/data/adhkar_data.dart';
import 'package:salahulddin_azkar/data/library_data.dart';
import 'package:salahulddin_azkar/data/sources.dart';
import 'package:salahulddin_azkar/data/tafsir_data.dart';
import 'package:salahulddin_azkar/screens/sources_screen.dart';

/// The app carries other people's work. Naming each one is the least that
/// owes them, and the list has to stay true as the app grows — a source added
/// to the code and not to this page is exactly the kind of thing nobody
/// notices until someone asks.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('the list', () {
    test('every source names a holder and says where it stands', () {
      expect(Sources.all, isNotEmpty);
      for (final source in Sources.all) {
        expect(source.title.trim(), isNotEmpty);
        expect(source.holder.trim(), isNotEmpty,
            reason: '${source.title} names nobody');
      }
    });

    test('each kind has something under it', () {
      for (final kind in SourceKind.values) {
        expect(Sources.of(kind), isNotEmpty, reason: kind.label);
      }
    });

    test('the four standings are distinct, and each explains itself', () {
      final labels = Standing.values.map((s) => s.label).toSet();
      expect(labels.length, Standing.values.length);
      for (final standing in Standing.values) {
        expect(standing.note.trim(), isNotEmpty);
      }
    });
  });

  group('what the app actually carries is on the list', () {
    test('the two bundled tafsir editions are both named', () {
      // These are the modern ones — the two that rest on their owners' say-so
      // rather than on age. They are the last that should go unnamed.
      final bundled =
          TafsirService.editions.where((e) => e.isBundled).toList();
      expect(bundled, hasLength(2));

      final page = Sources.all.map((s) => s.title).join(' ');
      for (final edition in bundled) {
        expect(page, contains(edition.name));
      }
    });

    test('Hisn al-Muslim is named, since the adhkar lean on it', () {
      expect(Sources.all.any((s) => s.title.contains('حصن المسلم')), isTrue);
      expect(adhkar, isNotEmpty);
    });

    test('the bundled hadith books are covered', () {
      final bundled = LibraryService.books.where((b) => b.isBundled);
      expect(bundled, isNotEmpty);
      expect(
        Sources.all.any((s) => s.title.contains('الأربعون')),
        isTrue,
        reason: 'three forty-hadith collections ship inside the app',
      );
    });

    test('the recitations say the recording belongs to whoever made it', () {
      // The Qur\'an is nobody\'s to own; a recording of it is. The page has to
      // say so rather than implying the app may hand the audio around.
      final recitations =
          Sources.all.firstWhere((s) => s.title.contains('تلاوات'));
      expect(recitations.standing, Standing.hosted);
      expect(recitations.detail, isNotNull);
    });
  });

  testWidgets('the page shows every source it holds', (tester) async {
    // Tall enough to hold the whole list: a ListView never builds what is
    // below the fold, so on a normal test screen most of the page would be
    // absent rather than merely off-view.
    tester.view.physicalSize = const Size(1200, 6000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const MaterialApp(home: SourcesScreen()));
    await tester.pump();

    for (final kind in SourceKind.values) {
      expect(find.text(kind.label), findsOneWidget, reason: kind.label);
    }
    for (final source in Sources.all) {
      expect(find.text(source.title), findsOneWidget,
          reason: '${source.title} is on the list but not on the page');
      expect(find.text(source.holder), findsWidgets,
          reason: '${source.title} is shown without naming its holder');
    }

    // And it says the app takes nothing for this.
    expect(find.textContaining('لا إعلان فيه ولا بيع'), findsOneWidget);
  });
}
