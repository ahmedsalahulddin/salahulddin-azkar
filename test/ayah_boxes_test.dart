import 'package:flutter_test/flutter_test.dart';
import 'package:salahulddin_azkar/data/ayah_boxes.dart';
import 'package:salahulddin_azkar/data/quran_data.dart';
import 'package:salahulddin_azkar/services/bookmark_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('ayah boxes', () {
    test('every page carries boxes for exactly the ayahs it holds', () async {
      for (final page in await QuranService.pages()) {
        final boxes = await AyahBoxService.forPage(page.number);
        expect(boxes, isNotEmpty, reason: 'page ${page.number} has no boxes');

        final fromIndex = <String>{};
        for (final run in page.runs) {
          for (var a = run.first; a <= run.last; a++) {
            fromIndex.add('${run.surah}:$a');
          }
        }
        final fromBoxes = boxes.map((b) => b.key).toSet();

        expect(fromBoxes, fromIndex,
            reason: 'page ${page.number} boxes disagree with the page index');
      }
    });

    test('boxes are non-empty and stay inside the reference width', () async {
      for (final page in await QuranService.pages()) {
        for (final entry in await AyahBoxService.forPage(page.number)) {
          expect(entry.rects, isNotEmpty,
              reason: '${entry.key} on page ${page.number} has no rectangles');
          for (final r in entry.rects) {
            expect(r.width, greaterThan(0));
            expect(r.height, greaterThan(0));
            expect(r.left, greaterThanOrEqualTo(0));
            expect(r.right,
                lessThanOrEqualTo(AyahBoxService.referenceWidth));
          }
        }
      }
    });

    test('a tap inside an ayah finds that ayah', () async {
      final boxes = await AyahBoxService.forPage(1);
      final target = boxes.first;
      final rect = target.rects.first;

      expect(AyahBoxService.hitTest(boxes, rect.center)?.key, target.key);
    });

    test('a tap in the margin finds nothing', () async {
      final boxes = await AyahBoxService.forPage(1);
      // Far outside any glyph.
      expect(AyahBoxService.hitTest(boxes, const Offset(-50, -50)), isNull);
      expect(AyahBoxService.hitTest(boxes, const Offset(5000, 5000)), isNull);
    });

    test('the opening of every surah is tappable', () async {
      for (final info in await QuranService.index()) {
        final page = await QuranService.pageOfSurah(info.number);
        final boxes = await AyahBoxService.forPage(page);
        final opener =
            boxes.where((b) => b.surah == info.number && b.ayah == 1);
        expect(opener, isNotEmpty,
            reason: 'surah ${info.number} ayah 1 has no box on page $page');
      }
    });
  });

  group('bookmarks', () {
    test('marking then marking again removes the mark', () async {
      const mark = Bookmark(
          kind: BookmarkKind.reading, surah: 18, ayah: 10, page: 294);

      expect(await BookmarkService.toggle(mark), isTrue);
      expect(await BookmarkService.exists(BookmarkKind.reading, 18, 10), isTrue);

      expect(await BookmarkService.toggle(mark), isFalse);
      expect(await BookmarkService.exists(BookmarkKind.reading, 18, 10), isFalse);
    });

    test('the three kinds are tracked independently on the same ayah',
        () async {
      for (final kind in BookmarkKind.values) {
        await BookmarkService.toggle(
          Bookmark(kind: kind, surah: 2, ayah: 255, page: 42, note: 'x'),
        );
      }
      expect((await BookmarkService.all()).length, 3);
      for (final kind in BookmarkKind.values) {
        expect(await BookmarkService.exists(kind, 2, 255), isTrue);
        expect((await BookmarkService.ofKind(kind)).length, 1);
      }
    });

    test('re-saving a note updates it instead of dropping the mark', () async {
      const first = Bookmark(
          kind: BookmarkKind.note,
          surah: 36,
          ayah: 1,
          page: 440,
          note: 'first');
      const second = Bookmark(
          kind: BookmarkKind.note,
          surah: 36,
          ayah: 1,
          page: 440,
          note: 'second');

      await BookmarkService.toggle(first);
      await BookmarkService.toggle(second);

      final notes = await BookmarkService.ofKind(BookmarkKind.note);
      expect(notes.length, 1);
      expect(notes.single.note, 'second');
    });
  });
}
