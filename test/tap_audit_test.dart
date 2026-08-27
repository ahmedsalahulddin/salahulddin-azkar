import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salahulddin_azkar/widgets/rotating_verse.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:salahulddin_azkar/screens/account_screen.dart';
import 'package:salahulddin_azkar/screens/admin_screen.dart';
import 'package:salahulddin_azkar/screens/adhkar_home_screen.dart';
import 'package:salahulddin_azkar/screens/books_screen.dart';
import 'package:salahulddin_azkar/data/adhkar_data.dart';
import 'package:salahulddin_azkar/data/greeting_cards.dart';
import 'package:salahulddin_azkar/data/hisn_data.dart';
import 'package:salahulddin_azkar/data/library_data.dart';
import 'package:salahulddin_azkar/data/quran_data.dart';
import 'package:salahulddin_azkar/screens/book_reader_screen.dart';
import 'package:salahulddin_azkar/screens/category_screen.dart';
import 'package:salahulddin_azkar/screens/hisn_chapter_screen.dart';
import 'package:salahulddin_azkar/screens/surah_screen.dart';
import 'package:salahulddin_azkar/screens/cards_screen.dart';
import 'package:salahulddin_azkar/screens/deceased_screen.dart';
import 'package:salahulddin_azkar/screens/favorites_screen.dart';
import 'package:salahulddin_azkar/screens/my_cards_screen.dart';
import 'package:salahulddin_azkar/screens/quran_screen.dart';
import 'package:salahulddin_azkar/screens/radio_screen.dart';
import 'package:salahulddin_azkar/screens/sahih_adhkar_screen.dart';
import 'package:salahulddin_azkar/screens/search_screen.dart';
import 'package:salahulddin_azkar/screens/settings_screen.dart';
import 'package:salahulddin_azkar/screens/umrah_screen.dart';
import 'package:salahulddin_azkar/screens/home_screen.dart';
import 'package:salahulddin_azkar/data/lessons.dart';
import 'package:salahulddin_azkar/screens/lesson_screen.dart';
import 'package:salahulddin_azkar/screens/lessons_screen.dart';
import 'package:salahulddin_azkar/screens/memorisation_test_screen.dart';
import 'package:salahulddin_azkar/screens/mushaf_screen.dart';
import 'package:salahulddin_azkar/screens/listening_screen.dart';
import 'package:salahulddin_azkar/screens/prayer_alerts_screen.dart';
import 'package:salahulddin_azkar/screens/quran_home_screen.dart';
import 'package:salahulddin_azkar/screens/sources_screen.dart';

/// Every control on a screen, pressed, one at a time.
///
/// The app has around two hundred and fifty things a reader can touch and,
/// before this, eight tests that touched any of them. Everything else checked
/// logic — which is how a notification system with no receiver declared passed
/// four hundred tests while not one reminder ever arrived.
///
/// A control is rebuilt from scratch before it is pressed, because pressing
/// one often replaces the screen the next one lives on.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  // Loaded out here, deliberately. Awaiting an asset inside testWidgets waits
  // on a message loop the test clock never turns, so the test does not fail —
  // it stops, past its own timeout, and looks exactly like the screen under
  // test hanging. Two screens were written off as untestable on that evidence
  // before it turned out to be these two lines.
  late final List<HisnChapter> chapters;
  late final List<SurahInfo> surahs;
  setUpAll(() async {
    chapters = await HisnService.chapters();
    surahs = await QuranService.index();
  });

  /// Everything on screen that claims to respond to a touch.
  Finder tappables() => find.byWidgetPredicate((w) =>
      (w is GestureDetector && w.onTap != null) ||
      (w is InkWell && w.onTap != null) ||
      (w is IconButton && w.onPressed != null) ||
      (w is TextButton && w.onPressed != null) ||
      (w is ElevatedButton && w.onPressed != null) ||
      (w is OutlinedButton && w.onPressed != null) ||
      (w is ListTile && w.onTap != null) ||
      w is Switch ||
      w is Radio);

  /// What the reader can currently see, as one string. Two of these differing
  /// is the evidence that a press did something.
  ///
  /// The whole tree, not just its words. A great many controls in this app
  /// answer by changing a colour or a border — every alert mode, every chip,
  /// every chosen reciter — and a text-only comparison called all of them
  /// dead. That was the harness being wrong about the app, which is worse
  /// than useless: it buries the real findings in noise.
  String visible(WidgetTester tester) {
    final root = find.byType(MaterialApp).evaluate();
    if (root.isEmpty) return '';
    return root.first.toStringDeep();
  }

  /// Puts the last screen down and lets what it started finish.
  ///
  /// Every press but the final one is cleaned up by the next one tearing the
  /// tree down. The last one is not, so whatever it left running — the timer
  /// behind a message that is still on screen, most often — was still pending
  /// when the test ended, and the binding reports that as a leak. It reads
  /// exactly like a screen that forgot to cancel something.
  Future<void> settle(WidgetTester tester) async {
    // The rotating verse is deliberately app-lifetime: one timer, started by
    // the first screen that shows a verse and shared by all of them. It
    // belongs to no widget, so disposing the tree does not stop it, and the
    // invariant check runs before tearDown — which is why it surfaced against
    // whichever screen happened to be swept last rather than the one that
    // started it.
    VerseRotation.debugStop();
    // Supabase's auth client starts a token refresh on a ten-second period
    // the moment it is initialised, and keeps it for the life of the app —
    // correct in the app, and a pending timer here. The admin screen loads
    // its config in initState, which is enough to bring it up.
    try {
      Supabase.instance.client.auth.stopAutoRefresh();
    } catch (_) {
      // Never initialised, which is the usual case.
    }
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    // Fake time, so this is free: long enough for the longest message in the
    // app to take itself away.
    await tester.pump(const Duration(seconds: 12));
  }

  /// Presses control [index] on a freshly built [screen] and says what came
  /// of it. Null means there is no control with that index.
  Future<String?> press(
    WidgetTester tester,
    Widget Function() screen,
    int index,
  ) async {
    // Torn down first, deliberately. Pumping the same const widget again
    // does not rebuild anything: Flutter sees an identical tree and updates
    // it in place, so whatever the previous press pushed onto the Navigator
    // was still there. Control 43 of a ten-control screen was the giveaway —
    // the sweep had wandered three screens deep and was reporting its
    // findings against the screen it started on.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();

    await tester.pumpWidget(MaterialApp(home: screen()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    // Drained before the press, not after. Building the screen raises its own
    // errors in a test — absent assets, no network — and left in the queue
    // they surface on whichever control is pressed next and get reported as
    // its fault. That misattribution cost a round of chasing two innocent
    // buttons.
    tester.takeException();

    final found = tappables().evaluate().toList();
    if (index >= found.length) return null;

    final target = found[index];
    final label = _label(target);
    final before = visible(tester);

    // Errors are collected as they are raised rather than read back
    // afterwards. takeException() hands back one aggregated object whose text
    // does not reliably carry the reason, and two rounds were spent reading
    // "Multiple exceptions (2)" and guessing which two.
    final raised = <String>[];
    final previousHandler = FlutterError.onError;
    FlutterError.onError = (details) {
      raised.add(details.exception.toString());
      if (const bool.fromEnvironment('AUDIT_VERBOSE')) {
        debugPrint('--- $label ---\n$details');
      }
    };
    try {
      // Deliberately not warnIfMissed: false. A control the touch cannot
      // reach — behind something, off the edge, sized to nothing — is a
      // finding in itself, and silencing the warning turns it into the same
      // "nothing changed" a dead handler produces.
      await tester.tap(find.byWidget(target.widget));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
    } catch (e) {
      raised.add(e.toString());
    } finally {
      FlutterError.onError = previousHandler;
    }
    tester.takeException();

    if (raised.any((e) => e.contains('would not hit test'))) {
      return 'NOT REACHABLE BY TOUCH — $label';
    }
    if (raised.isNotEmpty) {
      return 'THREW — $label — ${raised.first.split('\n').first}';
    }
    return visible(tester) == before ? 'nothing changed — $label' : 'ok';
  }


  /// Presses every control on [screen] and returns the ones that did nothing
  /// or threw, described well enough to go and look.
  Future<List<String>> sweep(
    WidgetTester tester,
    Widget Function() screen,
  ) async {
    tester.view.physicalSize = const Size(1200, 5000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final trouble = <String>[];
    for (var i = 0; i < 60; i++) {
      final outcome = await press(tester, screen, i);
      if (outcome == null) break;
      if (const bool.fromEnvironment('AUDIT_VERBOSE')) {
        debugPrint('AUDIT [$i] $outcome');
      }
      if (outcome != 'ok') trouble.add('[$i] $outcome');
    }
    await settle(tester);
    return trouble;
  }

  final screens = <String, Widget Function()>{
    'الرئيسية': () => const HomeScreen(),
    'الأذكار': () => const AdhkarHomeScreen(),
    'القرآن': () => const QuranHomeScreen(),
    'تنبيهات الصلاة': () => const PrayerAlertsScreen(),
    'الدروس': () => const LessonsScreen(),
    'المصادر': () => const SourcesScreen(),
    'حسابي': () => const AccountScreen(),
    'الكتب': () => const BooksScreen(),
    'كروت يومية': () => const CardsScreen(shelf: CardShelf.daily),
    'المتوفّون': () => const DeceasedScreen(),
    'المفضلة': () => const FavoritesScreen(),
    'كروتي': () => const MyCardsScreen(),
    'السور': () => const QuranScreen(),
    'الإذاعة': () => const RadioScreen(),
    'صحيح الأذكار': () => const SahihAdhkarScreen(),
    'البحث': () => const SearchScreen(),
    'الإعدادات': () => const SettingsScreen(),
    'العمرة': () => const UmrahScreen(),
    'الإدارة': () => const AdminScreen(),
  };

  /// The screens that cannot be built without something to show.
  ///
  /// Each is handed real data out of the app's own files rather than a
  /// hand-made stand-in, so what is pressed is what the reader presses. One
  /// test each: a screen that reaches the audio engine does not fail here, it
  /// stops dead — past its own timeout, because the harness is blocked on a
  /// channel the test clock cannot turn — and sharing a test would take the
  /// others down with it.
  Future<void> sweepOne(
    WidgetTester tester,
    String name,
    Widget Function() screen,
  ) async {
    tester.view.physicalSize = const Size(1200, 5000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final trouble = <String>[];
    for (var i = 0; i < 60; i++) {
      final outcome = await press(tester, screen, i);
      if (outcome == null) break;
      if (outcome != 'ok') trouble.add('$name [$i] $outcome');
    }
    await settle(tester);
    expect(trouble, isEmpty, reason: trouble.join('\n'));
  }

  testWidgets('every control in a chapter of حصن المسلم answers a press',
      (tester) async {
    await sweepOne(tester, 'حصن المسلم',
        () => HisnChapterScreen(chapter: chapters.first));
  });

  testWidgets('every control in a section of the adhkar answers a press',
      (tester) async {
    final categories = getCategoriesWithCount();
    await sweepOne(
        tester, 'قسم الأذكار', () => CategoryScreen(category: categories.first));
  });

  testWidgets('every control in a book answers a press', (tester) async {
    await sweepOne(tester, 'كتاب',
        () => BookReaderScreen(book: LibraryService.books.first));
  });

  testWidgets('every control in a surah answers a press', (tester) async {
    await sweepOne(tester, 'سورة', () => SurahScreen(info: surahs.first));
  });

  testWidgets('every control in the Mushaf answers a press', (tester) async {
    await sweepOne(tester, 'المصحف', () => const MushafScreen());
  });

  testWidgets('every control in the memorisation test answers a press',
      (tester) async {
    await sweepOne(
        tester, 'اختبار الحفظ', () => MemorisationTestScreen(info: surahs.first));
  });

  testWidgets('every control in a lesson answers a press', (tester) async {
    await sweepOne(tester, 'درس', () => LessonScreen(lesson: Lessons.all.first));
  });

  testWidgets('every control on الاستماع answers a press', (tester) async {
    await sweepOne(tester, 'الاستماع', () => const ListeningScreen());
  });

  // Nothing is left out. ListeningScreen was written off here as unsweepable
  // — every route into it reaches the audio engine, so it hung — and that was
  // wrong twice over: the hang was an await in the test, not the engine, and
  // the note would have kept a screen out of the sweep for good on the
  // strength of a guess nobody would have gone back to check.

  for (final entry in screens.entries) {
    testWidgets('every control on ${entry.key} answers a press',
        (tester) async {
      final trouble = await sweep(tester, entry.value);
      expect(trouble, isEmpty,
          reason: 'on ${entry.key}, these did nothing visible or threw:\n'
              '${trouble.join('\n')}');
    });
  }
}

/// The nearest words inside a control, so a finding names something the
/// reader would recognise instead of an index.
String _label(Element element) {
  final words = <String>[];
  void walk(Element e) {
    if (words.length >= 3) return;
    final w = e.widget;
    if (w is Text && w.data != null && w.data!.trim().isNotEmpty) {
      words.add(w.data!.trim());
    }
    if (w is Icon && w.icon != null) words.add('icon:${w.icon!.codePoint}');
    e.visitChildren(walk);
  }

  element.visitChildren(walk);
  return words.isEmpty ? '(no label)' : words.take(3).join(' / ');
}
