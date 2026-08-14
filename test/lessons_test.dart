import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salahulddin_azkar/data/lessons.dart';
import 'package:salahulddin_azkar/data/library_data.dart';
import 'package:salahulddin_azkar/data/quran_data.dart';
import 'package:salahulddin_azkar/screens/lesson_screen.dart';

/// A lesson is only worth as much as what it rests on. Every source it cites
/// has to exist, come from something already shipped with the app, and be read
/// from there rather than copied into the lesson file.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('ids and titles are unique, and each lesson has points', () {
    expect(Lessons.all.map((l) => l.id).toSet().length, Lessons.all.length);
    expect(Lessons.all.map((l) => l.title).toSet().length, Lessons.all.length);
    for (final lesson in Lessons.all) {
      expect(lesson.points, isNotEmpty, reason: '${lesson.id} teaches nothing');
      for (final point in lesson.points) {
        expect(point.title.trim(), isNotEmpty);
        expect(point.body.trim().length, greaterThan(20),
            reason: '${lesson.id}/${point.title} says too little');
      }
    }
  });

  test('the five pillars are five, and the six of faith are six', () {
    expect(Lessons.byId('pillars-islam').points.length, 5);
    expect(Lessons.byId('pillars-faith').points.length, 6);
  });

  test('every cited verse exists in the Mushaf', () async {
    final index = await QuranService.index();
    final counts = {for (final s in index) s.number: s.ayahCount};

    for (final lesson in Lessons.all) {
      for (final source in [
        if (lesson.opening != null) lesson.opening!,
        for (final p in lesson.points)
          if (p.source != null) p.source!,
      ]) {
        if (source is! VerseSource) continue;
        expect(counts.containsKey(source.surah), isTrue,
            reason: '${lesson.id} cites surah ${source.surah}');
        expect(source.ayah, inInclusiveRange(1, counts[source.surah]!),
            reason: '${lesson.id} cites ${source.surah}:${source.ayah}');
      }
    }
  });

  test('every cited hadith is in a book the app already carries', () async {
    for (final lesson in Lessons.all) {
      for (final source in [
        if (lesson.opening != null) lesson.opening!,
        for (final p in lesson.points)
          if (p.source != null) p.source!,
      ]) {
        if (source is! HadithSource) continue;
        final book = LibraryService.books
            .where((b) => b.id == source.bookId)
            .firstOrNull;
        expect(book, isNotNull, reason: '${lesson.id} cites an unknown book');
        // Bundled, so the lesson works with no network and no download.
        expect(book!.isBundled, isTrue,
            reason: '${book.title} is not shipped with the app');
        final hadiths = await LibraryService.hadiths(book);
        expect(hadiths.any((h) => h.number == source.number), isTrue,
            reason: '${book.title} has no hadith ${source.number}');
      }
    }
  });

  test('every source resolves to real text, read from the bundle', () async {
    for (final lesson in Lessons.all) {
      for (final source in [
        if (lesson.opening != null) lesson.opening!,
        for (final p in lesson.points)
          if (p.source != null) p.source!,
      ]) {
        final resolved = await Lessons.resolve(source);
        expect(resolved, isNotNull, reason: '${lesson.id} has a dead source');
        expect(resolved!.text.trim().length, greaterThan(10));
        expect(resolved.citation.trim(), isNotEmpty);
      }
    }
  });

  test('the pillars rest on the hadith that lists them', () async {
    // "بني الإسلام على خمس" is Nawawi 3; the lesson opens on it.
    final opening = Lessons.byId('pillars-islam').opening;
    expect(opening, isA<HadithSource>());
    expect((opening as HadithSource).number, 3);

    // And faith on the hadith of Jibril, which is Nawawi 2.
    expect((Lessons.byId('pillars-faith').opening as HadithSource).number, 2);
    // Ihsan comes from the same hadith.
    expect((Lessons.byId('ihsan').opening as HadithSource).number, 2);
    // Wudu on the verse of wudu.
    final wudu = Lessons.byId('wudu').opening as VerseSource;
    expect((wudu.surah, wudu.ayah), (5, 6));
  });

  testWidgets('a lesson renders its points and its sources', (tester) async {
    tester.view.physicalSize = const Size(420, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final lesson = Lessons.byId('pillars-islam');
    await tester.pumpWidget(MaterialApp(home: LessonScreen(lesson: lesson)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    for (final point in lesson.points) {
      expect(find.text(point.title), findsOneWidget,
          reason: '${point.title} is missing');
    }
    expect(tester.takeException(), isNull);
  });
}
