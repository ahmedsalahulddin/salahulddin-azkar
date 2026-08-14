import 'dart:math';

import 'quran_data.dart';

/// The ways the drill can ask about an ayah.
///
/// One shape of question only ever tests one thing. Completing a tail checks
/// that the next words are on the tongue; ordering scrambled words checks the
/// sentence is held whole; a gap in the middle checks the reader is not just
/// running a memorised rhythm; and naming what comes next checks the joins
/// between ayahs, which is where recitation actually breaks.
enum TestMode {
  complete('إكمال الآية', 'يُخفى آخر الآية وتسترجعه'),
  order('ترتيب الكلمات', 'رتّب كلمات الآية بالضغط عليها'),
  missing('الكلمة الناقصة', 'اختر الكلمة الساقطة من موضعها'),
  next('الآية التالية', 'اختر ما يأتي بعد الآية المعروضة');

  const TestMode(this.label, this.hint);

  final String label;
  final String hint;
}

/// How much is withheld in [TestMode.complete].
enum TestDifficulty {
  easy('سهل', 'كلمة واحدة', 1),
  medium('متوسط', 'ثلاث كلمات', 3),
  hard('صعب', 'الآية كاملة', -1);

  const TestDifficulty(this.label, this.hint, this.hiddenWords);

  final String label;
  final String hint;

  /// Words withheld from the end, or -1 for the whole ayah.
  final int hiddenWords;
}

/// One question, already resolved. Built once per position so that rebuilding
/// the screen never reshuffles the answer under the reader's finger.
class Question {
  final TestMode mode;
  final Ayah ayah;

  /// [TestMode.complete] — the words left showing, then the ones to recall.
  final List<String> shown;
  final List<String> hidden;

  /// [TestMode.order] — the ayah's words, shuffled.
  final List<String> scrambled;

  /// The order [scrambled] has to be tapped in.
  final List<int> solution;

  /// [TestMode.missing] and [TestMode.next] — the choices, and which is right.
  final List<String> options;
  final int answer;

  /// [TestMode.missing] — the ayah with the gap left in place.
  final List<String> before;
  final List<String> after;

  const Question({
    required this.mode,
    required this.ayah,
    this.shown = const [],
    this.hidden = const [],
    this.scrambled = const [],
    this.solution = const [],
    this.options = const [],
    this.answer = 0,
    this.before = const [],
    this.after = const [],
  });
}

/// Builds the questions for one surah.
class QuestionBank {
  QuestionBank(this.surah);

  final Surah surah;

  /// How many questions [mode] can ask.
  ///
  /// "What comes next" cannot ask about the last ayah, and the choice modes
  /// need something to offer besides the right answer — a surah of three
  /// ayahs simply has fewer questions in it.
  int length(TestMode mode) => switch (mode) {
        TestMode.next => surah.ayahs.length - 1,
        _ => surah.ayahs.length,
      };

  bool supports(TestMode mode) => length(mode) > 0;

  /// The question at [position]. Deterministic: the same position always
  /// produces the same shuffle, so a rebuild does not move the answer.
  Question build(TestMode mode, int position, TestDifficulty difficulty) {
    final ayah = surah.ayahs[position];
    final random = Random(surah.number * 10007 + position * 31 + mode.index);
    final words = _words(ayah.text);

    switch (mode) {
      case TestMode.complete:
        if (difficulty.hiddenWords < 0 || words.length <= 1) {
          return Question(mode: mode, ayah: ayah, hidden: words);
        }
        final hide = difficulty.hiddenWords.clamp(1, words.length - 1);
        return Question(
          mode: mode,
          ayah: ayah,
          shown: words.sublist(0, words.length - hide),
          hidden: words.sublist(words.length - hide),
        );

      case TestMode.order:
        // Shuffle indices, not words: an ayah can repeat a word, and the
        // reader must still be able to place either copy.
        final order = List.generate(words.length, (i) => i)..shuffle(random);
        final scrambled = [for (final i in order) words[i]];
        // Where each original position now sits in the scrambled list.
        final solution = List.filled(words.length, 0);
        for (var slot = 0; slot < order.length; slot++) {
          solution[order[slot]] = slot;
        }
        return Question(
          mode: mode,
          ayah: ayah,
          scrambled: scrambled,
          solution: solution,
        );

      case TestMode.missing:
        final gap = words.length == 1 ? 0 : random.nextInt(words.length);
        final answer = words[gap];
        final distractors = _distractors(answer, random, exclude: {answer});
        final options = [answer, ...distractors]..shuffle(random);
        return Question(
          mode: mode,
          ayah: ayah,
          before: words.sublist(0, gap),
          after: words.sublist(gap + 1),
          options: options,
          answer: options.indexOf(answer),
        );

      case TestMode.next:
        final correct = surah.ayahs[position + 1].text;
        final others = surah.ayahs
            .where((a) => a.text != correct && a.number != ayah.number)
            .map((a) => a.text)
            .toList()
          ..shuffle(random);
        final options = [correct, ...others.take(3)]..shuffle(random);
        return Question(
          mode: mode,
          ayah: ayah,
          options: options,
          answer: options.indexOf(correct),
        );
    }
  }

  /// Wrong answers for the gap question, taken from the surah itself so they
  /// look like they belong — a distractor from another book would give the
  /// answer away.
  List<String> _distractors(String answer, Random random,
      {required Set<String> exclude}) {
    final pool = <String>{};
    for (final ayah in surah.ayahs) {
      for (final word in _words(ayah.text)) {
        if (!exclude.contains(word) && word.letterCount > 1) pool.add(word);
      }
    }
    final list = pool.toList()..shuffle(random);
    return list.take(3).toList();
  }

  static List<String> _words(String text) =>
      text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
}

extension on String {
  /// Letters once the diacritics are folded away, so a one-letter particle is
  /// not mistaken for a real word because of its marks.
  int get letterCount => QuranService.searchKey(this).runes.length;
}
