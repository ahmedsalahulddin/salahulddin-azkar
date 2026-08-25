import 'package:flutter_test/flutter_test.dart';
import 'package:salahulddin_azkar/data/hizb_data.dart';
import 'package:salahulddin_azkar/data/quran_data.dart';

/// The Mushaf marks every quarter of every hizb down its margin, and the
/// reader who recites a fixed portion finds their place by them. These page
/// images carry the text block alone — the margins are cropped away — so the
/// marks are drawn back on, and this holds the reference they are drawn from.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('sixty ahzab, four parts each, and not one missing', () async {
    final marks = await HizbService.all();
    expect(marks, hasLength(240));

    for (var hizb = 1; hizb <= 60; hizb++) {
      final parts = marks.where((m) => m.hizb == hizb).map((m) => m.quarter);
      expect(parts, [0, 1, 2, 3], reason: 'الحزب $hizb');
    }
  });

  test('it opens where the Mushaf opens', () async {
    final marks = await HizbService.all();
    expect(marks.first.surah, 1);
    expect(marks.first.ayah, 1);
    expect(marks.first.startsHizb, isTrue);
  });

  test('every mark points at an ayah that exists', () async {
    final index = await QuranService.index();
    final counts = {for (final s in index) s.number: s.ayahCount};

    for (final mark in await HizbService.all()) {
      expect(counts.containsKey(mark.surah), isTrue,
          reason: 'سورة ${mark.surah}');
      expect(mark.ayah, inInclusiveRange(1, counts[mark.surah]!),
          reason: 'الحزب ${mark.hizb} الربع ${mark.quarter}');
    }
  });

  test('they run in Mushaf order, never backwards', () async {
    final marks = await HizbService.all();
    for (var i = 1; i < marks.length; i++) {
      final before = marks[i - 1];
      final now = marks[i];
      final forward = now.surah > before.surah ||
          (now.surah == before.surah && now.ayah > before.ayah);
      expect(forward, isTrue,
          reason: '${now.surah}:${now.ayah} came after '
              '${before.surah}:${before.ayah}');
    }
  });

  test('a hizb opening is told apart from its quarters', () async {
    final marks = await HizbService.all();
    final opening = marks.firstWhere((m) => m.quarter == 0);
    final quarter = marks.firstWhere((m) => m.quarter == 1);

    expect(opening.startsHizb, isTrue);
    expect(quarter.startsHizb, isFalse);
    expect(opening.label, isNot(quarter.label));
    expect(quarter.longLabel, contains('ربع'));
  });

  group('what lands on a page', () {
    test('the opening page carries the first mark', () async {
      final found =
          await HizbService.onPage([(surah: 1, first: 1, last: 7)]);
      expect(found, hasLength(1));
      expect(found.single.hizb, 1);
    });

    test('most pages carry none, and that is not a fault', () async {
      // Two hundred and forty marks across six hundred and four pages.
      final found =
          await HizbService.onPage([(surah: 2, first: 6, last: 16)]);
      expect(found, isEmpty);
    });
  });
}
