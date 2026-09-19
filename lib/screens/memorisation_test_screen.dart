import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../constants/theme.dart';
import '../data/memorisation.dart';
import '../data/quran_data.dart';
import '../l10n/strings.dart';
import '../services/auth_service.dart';
import '../services/tahfeez_service.dart';
import 'tahfeez/tahfeez_widgets.dart' show gradeLabel, gradeColor;
import 'memtest_history_screen.dart';

const _mushafFont = 'AmiriQuran';

/// Asks which surah to drill, then opens the test.
///
/// Lives here rather than in one caller's screen because both the Quran shelf
/// and the Quran home reach the drill, and a picker that differed between them
/// would be a second thing to keep in step.
Future<void> openMemorisationPicker(BuildContext context) async {
  final index = await QuranService.index();
  if (!context.mounted) return;

  final chosen = await showModalBottomSheet<SurahInfo>(
    context: context,
    backgroundColor: AppColors.blackCard,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => Directionality(
      textDirection: TextDirection.rtl,
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.75,
        builder: (ctx, controller) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(14),
              child: Text(
                t('misc.chooseSurahToTest'),
                style: const TextStyle(
                  color: AppColors.gold,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const Divider(color: AppColors.goldBorder, height: 1),
            Expanded(
              child: ListView.builder(
                controller: controller,
                itemCount: index.length,
                itemBuilder: (ctx, i) => ListTile(
                  dense: true,
                  leading: Text(
                    QuranService.toArabicDigits(index[i].number),
                    style: const TextStyle(color: AppColors.gold, fontSize: 13),
                  ),
                  title: Text(
                    index[i].name,
                    style: const TextStyle(color: AppColors.textPrimary),
                  ),
                  subtitle: Text(
                    t(
                      'misc.ayahCount',
                    ).replaceAll('{count}', '${index[i].ayahCount}'),
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 11,
                    ),
                  ),
                  onTap: () => Navigator.pop(ctx, index[i]),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );

  if (chosen == null || !context.mounted) return;
  await Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => MemorisationTestScreen(info: chosen)),
  );
}

/// Drills one surah, four different ways.
class MemorisationTestScreen extends StatefulWidget {
  final SurahInfo info;

  const MemorisationTestScreen({super.key, required this.info});

  @override
  State<MemorisationTestScreen> createState() => _MemorisationTestScreenState();
}

class _MemorisationTestScreenState extends State<MemorisationTestScreen> {
  QuestionBank? _bank;
  TestMode _mode = TestMode.complete;
  TestDifficulty _difficulty = TestDifficulty.medium;

  /// Whether the setup step (question count) has been confirmed and the run
  /// is under way. Reset to false whenever the mode changes, since each mode
  /// has its own number of available questions.
  bool _started = false;

  /// How many questions this run asked for, and how many the bank had —
  /// picked once in setup, then fixed for the run.
  int _requestedCount = 0;

  /// Where in the surah this run's block of questions begins — randomised
  /// per run so repeated attempts do not always drill the same opening
  /// ayahs.
  int _runStart = 0;

  int _position = 0;
  int _correct = 0;
  int _missed = 0;
  bool _saving = false;
  bool _saved = false;

  /// complete — whether the withheld words are showing.
  bool _revealed = false;

  /// order — words placed so far, and whether the reader has slipped.
  final List<int> _placed = [];
  int _slips = 0;

  /// missing and next — which option was tapped, if any.
  int? _chosen;

  @override
  void initState() {
    super.initState();
    QuranService.surah(widget.info.number).then((s) {
      if (mounted) {
        setState(() {
          _bank = QuestionBank(s);
          _requestedCount = _defaultCount(_bank!.length(_mode));
        });
      }
    });
  }

  int _defaultCount(int available) => min(10, available);

  /// The fewest questions worth offering a picker for — below this, the run
  /// always covers everything available rather than asking the reader to
  /// choose among two or three questions.
  int _minCount(int available) => min(3, available);

  int get _total => _started ? _requestedCount : _bank!.length(_mode);
  bool get _finished => _started && _position >= _total;
  Question get _question =>
      _bank!.build(_mode, _runStart + _position, _difficulty);

  void _switchMode(TestMode mode) {
    setState(() {
      _mode = mode;
      _started = false;
      _requestedCount = _defaultCount(_bank!.length(mode));
      _restart();
    });
  }

  void _beginRun() {
    final available = _bank!.length(_mode);
    final maxStart = available - _requestedCount;
    setState(() {
      _started = true;
      _runStart = maxStart <= 0 ? 0 : Random().nextInt(maxStart + 1);
      _restart();
    });
  }

  void _restart() {
    _position = 0;
    _correct = 0;
    _missed = 0;
    _saved = false;
    _clearQuestionState();
  }

  /// Retakes the same question count from a freshly randomised start, rather
  /// than sending the reader back through setup.
  void _retake() {
    setState(() {
      final available = _bank!.length(_mode);
      final maxStart = available - _requestedCount;
      _runStart = maxStart <= 0 ? 0 : Random().nextInt(maxStart + 1);
      _restart();
    });
  }

  void _clearQuestionState() {
    _revealed = false;
    _placed.clear();
    _slips = 0;
    _chosen = null;
  }

  void _answer({required bool remembered}) {
    HapticFeedback.lightImpact();
    setState(() {
      remembered ? _correct++ : _missed++;
      _position++;
      _clearQuestionState();
    });
  }

  @override
  Widget build(BuildContext context) {
    final bank = _bank;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.black,
        appBar: AppBar(
          backgroundColor: AppColors.black,
          foregroundColor: AppColors.gold,
          title: Text(
            t(
              'misc.memorisationTestTitle',
            ).replaceAll('{name}', widget.info.name),
            style: const TextStyle(fontSize: 16),
          ),
        ),
        body: bank == null
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.gold),
              )
            : Column(
                children: [
                  _modeBar(bank),
                  if (_started && !_finished) _progress(),
                  Expanded(
                    child: _finished
                        ? _results()
                        : !bank.supports(_mode)
                        ? _tooShort()
                        : !_started
                        ? _setupPanel(bank)
                        : _body(_question),
                  ),
                ],
              ),
      ),
    );
  }

  // ---- chrome ------------------------------------------------------------

  Widget _modeBar(QuestionBank bank) {
    return SizedBox(
      height: 62,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        children: [
          for (final mode in TestMode.values)
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: GestureDetector(
                onTap: () => _switchMode(mode),
                behavior: HitTestBehavior.opaque,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: mode == _mode
                        ? AppColors.goldMuted
                        : AppColors.blackCard,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: mode == _mode
                          ? AppColors.gold
                          : AppColors.goldBorder,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      mode.label,
                      style: TextStyle(
                        color: mode == _mode
                            ? AppColors.gold
                            : AppColors.textMuted,
                        fontSize: 13,
                        fontWeight: mode == _mode
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _progress() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 2, 16, 8),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                t('misc.questionProgress')
                    .replaceAll(
                      '{current}',
                      QuranService.toArabicDigits(_position + 1),
                    )
                    .replaceAll('{total}', QuranService.toArabicDigits(_total)),
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 12,
                ),
              ),
              Text(
                '✓ ${QuranService.toArabicDigits(_correct)}   ✗ ${QuranService.toArabicDigits(_missed)}',
                style: const TextStyle(color: AppColors.textGold, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: _total == 0 ? 0 : _position / _total,
              backgroundColor: AppColors.blackSurface,
              valueColor: const AlwaysStoppedAnimation(AppColors.gold),
              minHeight: 5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _tooShort() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Text(
          t('misc.surahTooShort').replaceAll('{name}', widget.info.name),
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: AppColors.textMuted,
            fontSize: 14,
            height: 1.7,
          ),
        ),
      ),
    );
  }

  /// Asked once per run, before the first question: how many of the
  /// available questions to be tested on. A short surah with only a
  /// handful skips the picker and simply says so.
  Widget _setupPanel(QuestionBank bank) {
    final available = bank.length(_mode);
    final minCount = _minCount(available);
    final fixedCount = minCount >= available;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: _card(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                t(
                  'misc.questionsAvailable',
                ).replaceAll('{count}', QuranService.toArabicDigits(available)),
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 18),
              if (fixedCount)
                Text(
                  t('misc.allAvailableQuestions').replaceAll(
                    '{count}',
                    QuranService.toArabicDigits(available),
                  ),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 13,
                  ),
                )
              else ...[
                Text(
                  t('misc.questionCountLabel'),
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _countStepButton(
                      Icons.remove,
                      _requestedCount > minCount
                          ? () => setState(() => _requestedCount--)
                          : null,
                    ),
                    SizedBox(
                      width: 64,
                      child: Text(
                        QuranService.toArabicDigits(_requestedCount),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: AppColors.gold,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    _countStepButton(
                      Icons.add,
                      _requestedCount < available
                          ? () => setState(() => _requestedCount++)
                          : null,
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                SliderTheme(
                  // The default overlay reaches ~24px past the track in
                  // every direction — with the +/- buttons this close
                  // above, that halo was swallowing taps meant for them.
                  data: SliderTheme.of(
                    context,
                  ).copyWith(overlayShape: SliderComponentShape.noOverlay),
                  child: Slider(
                    value: _requestedCount.toDouble(),
                    min: minCount.toDouble(),
                    max: available.toDouble(),
                    divisions: (available - minCount) == 0
                        ? null
                        : available - minCount,
                    activeColor: AppColors.gold,
                    inactiveColor: AppColors.goldBorder,
                    onChanged: (v) =>
                        setState(() => _requestedCount = v.round()),
                  ),
                ),
              ],
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _beginRun,
                  icon: const Icon(Icons.play_arrow, size: 18),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.goldDark,
                    foregroundColor: AppColors.white,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                  ),
                  label: Text(t('misc.startTest')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _countStepButton(IconData icon, VoidCallback? onTap) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 40,
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: onTap == null ? AppColors.blackSurface : AppColors.gold,
          ),
        ),
        child: Icon(
          icon,
          size: 18,
          color: onTap == null ? AppColors.textMuted : AppColors.gold,
        ),
      ),
    );
  }

  Widget _card({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.navyLight, AppColors.navy],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.goldBorder),
      ),
      child: child,
    );
  }

  Widget _body(Question q) => switch (q.mode) {
    TestMode.complete => _complete(q),
    TestMode.order => _order(q),
    TestMode.missing => _missing(q),
    TestMode.next => _nextAyah(q),
  };

  // ---- إكمال الآية --------------------------------------------------------

  Widget _complete(Question q) {
    return Column(
      children: [
        _difficultyPicker(),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: _card(
              child: Column(
                children: [
                  // A blank per withheld word, so the reader can see how much
                  // is missing. Painting them in the background colour — which
                  // is what this did before — left the card looking empty.
                  Wrap(
                    alignment: WrapAlignment.center,
                    textDirection: TextDirection.rtl,
                    spacing: 6,
                    runSpacing: 8,
                    children: [
                      for (final word in q.shown)
                        Text(
                          word,
                          style: const TextStyle(
                            fontFamily: _mushafFont,
                            fontSize: 23,
                            height: 1.9,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      for (final word in q.hidden)
                        _revealed ? _revealedWord(word) : _blank(word),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(
                    _revealed
                        ? t('misc.ayahNumber').replaceAll(
                            '{number}',
                            QuranService.toArabicDigits(q.ayah.number),
                          )
                        : q.shown.isEmpty
                        ? t('misc.recallFullAyahThenReveal')
                        : t('misc.completeAyahThenReveal'),
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
          child: _revealed
              ? _judgeRow()
              : SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => setState(() => _revealed = true),
                    icon: const Icon(Icons.visibility, size: 18),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.goldDark,
                      foregroundColor: AppColors.white,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                    ),
                    label: Text(t('misc.reveal')),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _blank(String word) {
    // Wide enough to hint at the word's length without spelling it out.
    final width = (QuranService.searchKey(word).runes.length * 11.0).clamp(
      34.0,
      110.0,
    );
    return Container(
      width: width,
      height: 30,
      decoration: BoxDecoration(
        color: AppColors.goldMuted,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.gold),
      ),
      child: Center(
        child: Text(
          t('misc.blankPlaceholder'),
          style: const TextStyle(color: AppColors.gold, fontSize: 15),
        ),
      ),
    );
  }

  Widget _revealedWord(String word) => Text(
    word,
    style: const TextStyle(
      fontFamily: _mushafFont,
      fontSize: 23,
      height: 1.9,
      color: AppColors.gold,
    ),
  );

  Widget _difficultyPicker() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          for (final d in TestDifficulty.values)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: GestureDetector(
                  onTap: () => setState(() {
                    _difficulty = d;
                    _revealed = false;
                  }),
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 7),
                    decoration: BoxDecoration(
                      color: d == _difficulty
                          ? AppColors.goldMuted
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: d == _difficulty
                            ? AppColors.gold
                            : AppColors.goldBorder,
                      ),
                    ),
                    child: Column(
                      children: [
                        Text(
                          d.label,
                          style: TextStyle(
                            color: d == _difficulty
                                ? AppColors.gold
                                : AppColors.textMuted,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          d.hint,
                          style: const TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 9,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _judgeRow() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => _answer(remembered: false),
            icon: const Icon(Icons.close, size: 18),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.error,
              side: const BorderSide(color: AppColors.error),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            label: Text(t('misc.didNotRemember')),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () => _answer(remembered: true),
            icon: const Icon(Icons.check, size: 18),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.emerald,
              foregroundColor: AppColors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            label: Text(t('misc.rememberedIt')),
          ),
        ),
      ],
    );
  }

  // ---- ترتيب الكلمات ------------------------------------------------------

  Widget _order(Question q) {
    final done = _placed.length == q.scrambled.length;

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _card(
                  child: _placed.isEmpty
                      ? Text(
                          t('misc.tapWordsInOrder'),
                          style: const TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 13,
                          ),
                        )
                      : Wrap(
                          alignment: WrapAlignment.center,
                          textDirection: TextDirection.rtl,
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final slot in _placed)
                              Text(
                                q.scrambled[slot],
                                style: const TextStyle(
                                  fontFamily: _mushafFont,
                                  fontSize: 22,
                                  height: 1.8,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                          ],
                        ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  alignment: WrapAlignment.center,
                  textDirection: TextDirection.rtl,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (var slot = 0; slot < q.scrambled.length; slot++)
                      if (!_placed.contains(slot))
                        GestureDetector(
                          onTap: () => _placeWord(q, slot),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.blackCard,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: AppColors.goldBorder),
                            ),
                            child: Text(
                              q.scrambled[slot],
                              style: const TextStyle(
                                fontFamily: _mushafFont,
                                fontSize: 20,
                                color: AppColors.textGold,
                              ),
                            ),
                          ),
                        ),
                  ],
                ),
                if (_slips > 0) ...[
                  const SizedBox(height: 14),
                  Text(
                    t('misc.mistakesCount').replaceAll(
                      '{count}',
                      QuranService.toArabicDigits(_slips),
                    ),
                    style: const TextStyle(
                      color: AppColors.error,
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: done ? () => _answer(remembered: _slips == 0) : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: _slips == 0
                    ? AppColors.emerald
                    : AppColors.goldDark,
                foregroundColor: AppColors.white,
                disabledBackgroundColor: AppColors.blackSurface,
                disabledForegroundColor: AppColors.textMuted,
                padding: const EdgeInsets.symmetric(vertical: 13),
              ),
              child: Text(done ? t('misc.next') : t('misc.arrangeAllWords')),
            ),
          ),
        ),
      ],
    );
  }

  void _placeWord(Question q, int slot) {
    final expected = q.solution[_placed.length];
    setState(() {
      if (slot == expected) {
        _placed.add(slot);
        HapticFeedback.selectionClick();
      } else {
        _slips++;
        HapticFeedback.heavyImpact();
      }
    });
  }

  // ---- الكلمة الناقصة ----------------------------------------------------

  Widget _missing(Question q) {
    return _choiceLayout(
      q: q,
      prompt: Wrap(
        alignment: WrapAlignment.center,
        textDirection: TextDirection.rtl,
        spacing: 6,
        runSpacing: 8,
        children: [
          for (final word in q.before)
            Text(
              word,
              style: const TextStyle(
                fontFamily: _mushafFont,
                fontSize: 22,
                height: 1.9,
                color: AppColors.textPrimary,
              ),
            ),
          Container(
            width: 70,
            height: 28,
            decoration: BoxDecoration(
              color: AppColors.goldMuted,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: AppColors.gold),
            ),
            child: Center(
              child: Text(
                t('misc.blankPlaceholder'),
                style: const TextStyle(color: AppColors.gold, fontSize: 15),
              ),
            ),
          ),
          for (final word in q.after)
            Text(
              word,
              style: const TextStyle(
                fontFamily: _mushafFont,
                fontSize: 22,
                height: 1.9,
                color: AppColors.textPrimary,
              ),
            ),
        ],
      ),
      optionText: (option) => option,
      optionFont: _mushafFont,
    );
  }

  // ---- الآية التالية ------------------------------------------------------

  Widget _nextAyah(Question q) {
    return _choiceLayout(
      q: q,
      prompt: Column(
        children: [
          Text(
            q.ayah.text,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: _mushafFont,
              fontSize: 22,
              height: 2.0,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            t('misc.whichAyahFollows'),
            style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
          ),
        ],
      ),
      // The whole ayah would give the game away by its length alone.
      optionText: (option) {
        final words = option.split(' ');
        return words.length <= 7 ? option : '${words.take(7).join(' ')} …';
      },
      optionFont: _mushafFont,
    );
  }

  Widget _choiceLayout({
    required Question q,
    required Widget prompt,
    required String Function(String) optionText,
    required String optionFont,
  }) {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _card(child: prompt),
                const SizedBox(height: 16),
                for (var i = 0; i < q.options.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _option(q, i, optionText(q.options[i]), optionFont),
                  ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _chosen == null
                  ? null
                  : () => _answer(remembered: _chosen == q.answer),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.goldDark,
                foregroundColor: AppColors.white,
                disabledBackgroundColor: AppColors.blackSurface,
                disabledForegroundColor: AppColors.textMuted,
                padding: const EdgeInsets.symmetric(vertical: 13),
              ),
              child: Text(
                _chosen == null ? t('misc.chooseAnAnswer') : t('misc.next'),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _option(Question q, int index, String label, String font) {
    final answered = _chosen != null;
    final isAnswer = index == q.answer;
    final picked = index == _chosen;

    // Once answered, the right one is always marked — being told only that you
    // were wrong teaches nothing.
    final border = !answered
        ? AppColors.goldBorder
        : isAnswer
        ? AppColors.success
        : picked
        ? AppColors.error
        : AppColors.goldBorder;

    return GestureDetector(
      onTap: answered ? null : () => setState(() => _chosen = index),
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.blackCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: border,
            width: answered && (isAnswer || picked) ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontFamily: font,
                  fontSize: 19,
                  height: 1.7,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            if (answered && isAnswer)
              const Icon(
                Icons.check_circle,
                color: AppColors.success,
                size: 20,
              ),
            if (answered && picked && !isAnswer)
              const Icon(Icons.cancel, color: AppColors.error, size: 20),
          ],
        ),
      ),
    );
  }

  // ---- results -----------------------------------------------------------

  /// Ties the run's percentage to the same four-tier vocabulary a teacher's
  /// evaluation uses, so a reader who does both sees one consistent scale.
  EvalGrade _gradeOf(int score) {
    if (score >= 90) return EvalGrade.excellent;
    if (score >= 75) return EvalGrade.veryGood;
    if (score >= 60) return EvalGrade.good;
    return EvalGrade.redo;
  }

  Future<void> _saveResult(int score, int total) async {
    setState(() => _saving = true);
    try {
      await TahfeezService.saveMemtestResult(
        surahNumber: widget.info.number,
        surahName: widget.info.name,
        mode: _mode.name,
        questionCount: total,
        correctCount: _correct,
        scorePercent: score,
      );
      if (!mounted) return;
      setState(() {
        _saving = false;
        _saved = true;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(t('misc.resultSaved'))));
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(t('misc.resultSaveFailed'))));
    }
  }

  Widget _results() {
    final total = _correct + _missed;
    final score = total == 0 ? 0 : (_correct * 100 / total).round();
    final grade = _gradeOf(score);
    final signedIn = AuthService.user.value != null;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '%${QuranService.toArabicDigits(score)}',
              style: const TextStyle(
                color: AppColors.gold,
                fontSize: 46,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: gradeColor(grade).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: gradeColor(grade)),
              ),
              child: Text(
                gradeLabel(grade),
                style: TextStyle(
                  color: gradeColor(grade),
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              '${_mode.label} — ${t('misc.surahPrefix')} ${widget.info.name}',
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              t('misc.rememberedCountOf')
                  .replaceAll(
                    '{correct}',
                    QuranService.toArabicDigits(_correct),
                  )
                  .replaceAll('{total}', QuranService.toArabicDigits(total)),
              style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
            ),
            const SizedBox(height: 22),
            if (signedIn) ...[
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _saving || _saved
                      ? null
                      : () => _saveResult(score, total),
                  icon: Icon(
                    _saved ? Icons.check : Icons.save_outlined,
                    size: 18,
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.gold,
                    side: const BorderSide(color: AppColors.gold),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  label: Text(
                    _saved ? t('misc.resultSaved') : t('misc.saveResult'),
                  ),
                ),
              ),
              const SizedBox(height: 10),
            ] else
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text(
                  t('misc.signInToSaveResults'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 12,
                  ),
                ),
              ),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _retake,
                icon: const Icon(Icons.refresh, size: 18),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.goldDark,
                  foregroundColor: AppColors.white,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                ),
                label: Text(t('misc.retakeTest')),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              t('misc.orChooseAnotherMethod'),
              style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
            ),
            if (signedIn) ...[
              const SizedBox(height: 14),
              TextButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const MemtestHistoryScreen(),
                  ),
                ),
                icon: const Icon(Icons.history, size: 18),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.textGold,
                ),
                label: Text(t('misc.viewMemtestHistory')),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
