import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import 'package:share_plus/share_plus.dart';
import '../constants/theme.dart';
import '../data/ayah_boxes.dart';
import '../data/quran_data.dart';
import '../data/tafsir_data.dart';
import '../data/translation_data.dart';
import '../services/bookmark_service.dart';
import '../services/mushaf_image_service.dart';
import '../services/recitation_service.dart';
import '../services/repeat_settings.dart';
import '../services/storage_service.dart';
import 'package:just_audio_background/just_audio_background.dart';
import '../widgets/mushaf_frames.dart';
import '../widgets/mushaf_palettes.dart';
import '../widgets/mushaf_page_view.dart';
import '../widgets/tafsir_sheet.dart';

/// The Mushaf face: the printed Madinah page, turned like a paper copy.
///
/// Tapping an ayah selects it — a soft wash marks it and the action bar acts on
/// that ayah. Tapping anywhere else clears the selection and toggles the
/// surrounding chrome, so the page can stand alone.
class MushafScreen extends StatefulWidget {
  final int initialPage;

  const MushafScreen({super.key, this.initialPage = 1});

  @override
  State<MushafScreen> createState() => _MushafScreenState();
}

const _ink = Color(0xFF1A1A1A);

/// The Uthmanic face the bundled text is set in.
const _mushafFont = 'AmiriQuran';

class _MushafScreenState extends State<MushafScreen> {
  late final PageController _controller =
      PageController(initialPage: widget.initialPage - 1);
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _player = AudioPlayer();

  List<MushafPage>? _pages;
  List<SurahInfo>? _index;
  late int _current = widget.initialPage;

  bool _chromeVisible = true;
  AyahBoxes? _selected;
  Reciter _reciter = RecitationService.defaultReciter;
  RepeatSettings _repeat = const RepeatSettings();
  StreamSubscription<int?>? _indexSub;

  /// Speeds offered in the picker, slowest first.
  static const _speeds = [0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0];
  double _speed = 1.0;

  /// Renders 1.0 as "١" and 0.75 as "٠٫٧٥" — trailing zeros read as noise.
  static String _arabicSpeed(double speed) {
    final text = speed == speed.roundToDouble()
        ? speed.toInt().toString()
        : speed.toString().replaceFirst('.', '٫');
    return text.split('').map((c) {
      final digit = int.tryParse(c);
      return digit == null ? c : QuranService.toArabicDigits(digit);
    }).join();
  }

  String get _speedLabel => _arabicSpeed(_speed);

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _indexSub?.cancel();
    _player.dispose();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final pages = await QuranService.pages();
    final index = await QuranService.index();
    final reciter = await RecitationService.getReciter();
    final repeat = await RepeatSettings.load();
    if (!mounted) return;
    setState(() {
      _pages = pages;
      _index = index;
      _reciter = reciter;
      _repeat = repeat;
    });
    _prefetchAround(_current);
  }

  SurahInfo _surahInfo(int number) =>
      _index!.firstWhere((s) => s.number == number);

  void _onPageChanged(int i) {
    setState(() {
      _current = i + 1;
      _selected = null;
    });
    _player.stop();
    StorageService.setLastMushafPage(i + 1);
    _prefetchAround(i + 1);
  }

  void _prefetchAround(int page) {
    for (final p in [page + 1, page - 1]) {
      if (p >= 1 && p <= QuranService.pageCount) MushafImageService.fetch(p);
    }
  }

  void _goToPage(int page) =>
      _controller.jumpToPage(page.clamp(1, QuranService.pageCount) - 1);

  Future<void> _goToSurah(SurahInfo info) async =>
      _goToPage(await QuranService.pageOfSurah(info.number));

  Future<String> _ayahText(AyahBoxes a) async {
    final surah = await QuranService.surah(a.surah);
    return surah.ayahs[a.ayah - 1].text;
  }

  String _reference(AyahBoxes a) =>
      'سورة ${_surahInfo(a.surah).name} — الآية ${a.ayah}';

  void _toast(String message, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, textDirection: TextDirection.rtl),
        backgroundColor: error ? AppColors.error : AppColors.emerald,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // ---- ayah actions ----------------------------------------------------

  Future<void> _playFrom(AyahBoxes start) async {
    final surah = await QuranService.surah(start.surah);

    // With repetition on, the playlist is the drill order; otherwise it simply
    // runs from the tapped ayah to the end of the surah.
    final order = _repeat.isActive
        ? _repeat.playbackOrder(start.ayah, surah.ayahs.length)
        : [for (var n = start.ayah; n <= surah.ayahs.length; n++) n];

    try {
      await _player.setAudioSources(
        [
          for (final ayah in order)
            AudioSource.uri(
              Uri.parse(RecitationService.urlFor(
                reciterId: _reciter.id,
                surah: start.surah,
                ayah: ayah,
              )),
              // Names the track in the notification and on the lock screen,
              // and is what lets playback survive leaving the app.
              tag: MediaItem(
                id: '${_reciter.id}:${start.surah}:$ayah',
                title: '${surah.name} — الآية ${QuranService.toArabicDigits(ayah)}',
                artist: _reciter.name,
                album: 'القرآن الكريم',
              ),
            ),
        ],
        initialIndex: 0,
      );

      // Follow the recitation with the highlight.
      _indexSub?.cancel();
      _indexSub = _player.currentIndexStream.listen((i) async {
        if (!mounted || i == null || i >= order.length) return;
        final boxes = await AyahBoxService.forPage(_current);
        final match = boxes
            .where((b) => b.surah == start.surah && b.ayah == order[i])
            .firstOrNull;
        if (match != null && mounted) setState(() => _selected = match);
      });

      await _player.play();
    } catch (_) {
      if (mounted) _toast('تعذّر تشغيل التلاوة — تحقّق من الاتصال', error: true);
    }
  }

  Future<void> _openRepeatSettings() async {
    final updated = await showModalBottomSheet<RepeatSettings>(
      context: context,
      backgroundColor: AppColors.blackCard,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: _RepeatSheet(initial: _repeat),
      ),
    );
    if (updated == null || !mounted) return;

    await updated.save();
    setState(() => _repeat = updated);
    _toast(updated.isActive ? 'تم ضبط التكرار' : 'أُلغي التكرار');
  }

  Future<void> _copyAyah(AyahBoxes a) async {
    await Clipboard.setData(
      ClipboardData(text: '${await _ayahText(a)}\n\n[${_reference(a)}]'),
    );
    if (!mounted) return;
    HapticFeedback.lightImpact();
    _toast('تم نسخ الآية');
  }

  Future<void> _shareAyah(AyahBoxes a) async {
    final text = '${await _ayahText(a)}\n\n[${_reference(a)}]';
    await SharePlus.instance.share(ShareParams(text: text));
  }

  Future<void> _markAyah(AyahBoxes a) async {
    final kind = await showModalBottomSheet<BookmarkKind>(
      context: context,
      backgroundColor: AppColors.blackCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(14),
                child: Text('علامة على ${_reference(a)}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: AppColors.gold,
                        fontSize: 15,
                        fontWeight: FontWeight.bold)),
              ),
              const Divider(color: AppColors.goldBorder, height: 1),
              for (final kind in BookmarkKind.values)
                ListTile(
                  leading: Text(kind.icon, style: const TextStyle(fontSize: 20)),
                  title: Text(kind.label,
                      style: const TextStyle(color: AppColors.textPrimary)),
                  onTap: () => Navigator.pop(ctx, kind),
                ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
    if (kind == null || !mounted) return;

    String? note;
    if (kind == BookmarkKind.note) {
      note = await _askForNote(a);
      if (note == null) return;
    }

    final marked = await BookmarkService.toggle(Bookmark(
      kind: kind,
      surah: a.surah,
      ayah: a.ayah,
      page: _current,
      note: note,
    ));
    if (!mounted) return;
    _toast(marked ? 'أُضيفت علامة ${kind.label}' : 'أُزيلت علامة ${kind.label}');
  }

  Future<String?> _askForNote(AyahBoxes a) async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: AppColors.blackCard,
          title: const Text('ملاحظة',
              style: TextStyle(color: AppColors.gold, fontSize: 17)),
          content: TextField(
            controller: controller,
            autofocus: true,
            maxLines: 4,
            style: const TextStyle(color: AppColors.textPrimary),
            decoration: const InputDecoration(
              hintText: 'اكتب ملاحظتك على هذه الآية…',
              hintStyle: TextStyle(color: AppColors.textMuted, fontSize: 13),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('إلغاء',
                  style: TextStyle(color: AppColors.textMuted)),
            ),
            TextButton(
              onPressed: () {
                final text = controller.text.trim();
                Navigator.pop(ctx, text.isEmpty ? null : text);
              },
              child: const Text('حفظ',
                  style: TextStyle(color: AppColors.gold)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showTafsir(AyahBoxes a) async {
    final ayahText = await _ayahText(a);
    if (!mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.blackCard,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: TafsirSheet(
          surah: a.surah,
          ayah: a.ayah,
          reference: _reference(a),
          ayahText: ayahText,
        ),
      ),
    );
  }

  // ---- build -----------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final pages = _pages;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        key: _scaffoldKey,
        backgroundColor: MushafPalettes.current.value.paper,
        drawer: pages == null ? null : _NavigationDrawer(
          index: _index!,
          pages: pages,
          onSurah: (info) {
            Navigator.pop(context);
            _goToSurah(info);
          },
          onPage: (page) {
            Navigator.pop(context);
            _goToPage(page);
          },
          onBookmark: (b) {
            Navigator.pop(context);
            _goToPage(b.page);
          },
        ),
        body: pages == null
            ? const Center(child: CircularProgressIndicator(color: AppColors.gold))
            : Stack(
                children: [
                  PageView.builder(
                    controller: _controller,
                    itemCount: pages.length,
                    onPageChanged: _onPageChanged,
                    itemBuilder: (context, i) => _PageSheet(
                      page: pages[i],
                      surahInfo: _surahInfo,
                      selected: i + 1 == _current ? _selected : null,
                      onAyahTapped: (a) => setState(() {
                        _selected = a;
                        _chromeVisible = true;
                      }),
                      onBackgroundTapped: () => setState(() {
                        if (_selected != null) {
                          _selected = null;
                        } else {
                          _chromeVisible = !_chromeVisible;
                        }
                      }),
                    ),
                  ),
                  if (_chromeVisible) _topBar(pages[_current - 1]),
                  if (_chromeVisible) _bottomBar(),
                ],
              ),
      ),
    );
  }

  /// Two tight rows: where you are in the Mushaf, then what to listen to.
  ///
  /// Splitting them keeps the surah name readable — packed onto one line with
  /// the controls it had to be truncated on narrow phones.
  Widget _topBar(MushafPage page) {
    final names = page.runs.map((r) => _surahInfo(r.surah).name).toSet();
    final selected = _selected;

    final surahLine = selected == null
        ? 'سورة ${names.join(' · ')}'
        : 'سورة ${_surahInfo(selected.surah).name} — آية ${QuranService.toArabicDigits(selected.ayah)}';

    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: EdgeInsets.fromLTRB(
            4, MediaQuery.viewPaddingOf(context).top + 2, 4, 3),
        decoration: BoxDecoration(
          color: AppColors.blackCard.withValues(alpha: 0.97),
          border: const Border(bottom: BorderSide(color: AppColors.goldBorder)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Where you are: surah leads, position trails it.
            Row(
              children: [
                _barIcon(Icons.menu, 'التصفّح',
                    () => _scaffoldKey.currentState?.openDrawer()),
                Flexible(
                  child: Text(
                    surahLine,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: AppColors.gold,
                        fontSize: 17,
                        fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'الجزء ${QuranService.toArabicDigits(page.juz)} · صفحة ${QuranService.toArabicDigits(page.number)}',
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: AppColors.textMuted, fontSize: 12),
                  ),
                ),
                _barIcon(Icons.close, 'رجوع', () => Navigator.pop(context)),
              ],
            ),
            // Who is reciting, then the controls.
            Padding(
              padding: const EdgeInsets.only(right: 8, bottom: 2, top: 1),
              // Fixed height so a larger icon cannot push the bar down over
              // the page. Everything inside centres within it.
              child: SizedBox(
                height: 34,
                child: Row(
                  children: [
                    // Takes whatever the controls leave. The controls set
                    // their own width, so widening a label narrows this rather
                    // than growing the row.
                    Expanded(child: _reciterChip()),
                    const SizedBox(width: 4),
                    _reciterMenu(),
                    // Play leads the controls; repeat is a setting, so it sits
                    // at the far end rather than between the two.
                    _playButton(),
                    _speedButton(),
                    _barIcon(Icons.repeat, 'التكرار', _openRepeatSettings,
                        label: 'تـكرار',
                        active: _repeat.isActive,
                        iconSize: 23),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// A bar control. Passing [label] spells the action out beside the icon —
  /// worth the width for the ones whose symbol alone is ambiguous.
  Widget _barIcon(IconData icon, String tooltip, VoidCallback onTap,
      {bool active = false, String? label, double iconSize = 21}) {
    final tint = active ? AppColors.gold : AppColors.textSecondary;
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Padding(
          // Horizontal only: the row's fixed height does the vertical work, so
          // a bigger icon cannot make the bar taller.
          padding: EdgeInsets.symmetric(horizontal: label == null ? 7 : 5),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: iconSize, color: tint),
              if (label != null) ...[
                const SizedBox(width: 3),
                Text(label,
                    style: TextStyle(
                      color: tint,
                      fontSize: 11,
                      fontWeight:
                          active ? FontWeight.bold : FontWeight.normal,
                    )),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// The reciter's name. Tapping opens the list right under it.
  Widget _reciterChip() {
    return _reciterPopup(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.blackSurface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.goldBorder),
        ),
        alignment: Alignment.center,
        child: Text(
          _reciter.name,
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
          style: const TextStyle(color: AppColors.textGold, fontSize: 12),
        ),
      ),
    );
  }

  Widget _reciterMenu() => _reciterPopup(
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 6),
          child: Icon(Icons.record_voice_over,
              size: 22, color: AppColors.textSecondary),
        ),
      );

  /// Drops the reciter list below whatever it wraps — a sheet rising from the
  /// bottom of the screen put the choices as far from the button as possible.
  Widget _reciterPopup({required Widget child}) {
    return PopupMenuButton<Reciter>(
      tooltip: 'اختر القارئ',
      color: AppColors.blackCard,
      position: PopupMenuPosition.under,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.goldBorder),
      ),
      padding: EdgeInsets.zero,
      onSelected: _applyReciter,
      itemBuilder: (context) => [
        for (final r in RecitationService.reciters)
          PopupMenuItem(
            value: r,
            height: 40,
            child: Directionality(
              textDirection: TextDirection.rtl,
              child: Row(
                children: [
                  if (r.id == _reciter.id)
                    const Icon(Icons.check, color: AppColors.gold, size: 16)
                  else
                    const SizedBox(width: 16),
                  const SizedBox(width: 8),
                  Text(r.name,
                      style: TextStyle(
                        color: r.id == _reciter.id
                            ? AppColors.gold
                            : AppColors.textPrimary,
                        fontSize: 13,
                      )),
                ],
              ),
            ),
          ),
      ],
      child: child,
    );
  }

  Future<void> _applyReciter(Reciter chosen) async {
    if (chosen.id == _reciter.id) return;
    await RecitationService.setReciter(chosen.id);
    await _player.stop();
    if (!mounted) return;
    setState(() => _reciter = chosen);
  }

  /// Speeds are picked from a list under the badge rather than cycled: seven
  /// steps meant up to six taps to reach the one you wanted.
  Widget _speedButton() {
    final changed = _speed != 1.0;
    final tint = changed ? AppColors.gold : AppColors.textSecondary;

    return PopupMenuButton<double>(
      tooltip: 'سرعة التلاوة',
      color: AppColors.blackCard,
      position: PopupMenuPosition.under,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.goldBorder),
      ),
      padding: EdgeInsets.zero,
      onSelected: _applySpeed,
      itemBuilder: (context) => [
        for (final s in _speeds)
          PopupMenuItem(
            value: s,
            height: 38,
            child: Row(
              children: [
                if (s == _speed)
                  const Icon(Icons.check, color: AppColors.gold, size: 15)
                else
                  const SizedBox(width: 15),
                const SizedBox(width: 8),
                Text(
                  s == 1.0 ? 'الطبيعية' : '${_arabicSpeed(s)}×',
                  style: TextStyle(
                    color:
                        s == _speed ? AppColors.gold : AppColors.textPrimary,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
      ],
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 5),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: changed ? AppColors.goldMuted : Colors.transparent,
                border: Border.all(color: tint, width: 2),
              ),
              child: Center(
                child: Text(
                  _speedLabel,
                  style: TextStyle(
                    color: tint,
                    fontSize: _speedLabel.length > 2 ? 9 : 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 3),
            Text('سـرعة',
                style: TextStyle(
                  color: tint,
                  fontSize: 11,
                  fontWeight: changed ? FontWeight.bold : FontWeight.normal,
                )),
          ],
        ),
      ),
    );
  }

  Future<void> _applySpeed(double speed) async {
    setState(() => _speed = speed);
    try {
      await _player.setSpeed(speed);
    } catch (_) {
      // Speed is a convenience; failing to set it must not break playback.
    }
  }

  Widget _playButton() {
    return StreamBuilder<PlayerState>(
      stream: _player.playerStateStream,
      builder: (context, snapshot) {
        final playing = snapshot.data?.playing ?? false;
        final loading =
            snapshot.data?.processingState == ProcessingState.loading ||
                snapshot.data?.processingState == ProcessingState.buffering;

        if (loading) {
          // Same padding as _barIcon, so the row keeps its height.
          return const Padding(
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: SizedBox(
              width: 19,
              height: 19,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: AppColors.gold),
            ),
          );
        }

        return _barIcon(
          playing ? Icons.pause : Icons.play_arrow,
          playing ? 'إيقاف' : 'تلاوة الآية المحددة',
          () {
            if (playing) {
              _player.pause();
            } else if (_selected != null) {
              _playFrom(_selected!);
            } else {
              _toast('اضغط على آية أولاً لتبدأ التلاوة منها');
            }
          },
          label: playing ? 'إيـقاف' : 'تـشغيل',
          iconSize: 26,
          active: true,
        );
      },
    );
  }

  Widget _bottomBar() {
    final inset = MediaQuery.viewPaddingOf(context).bottom;
    final selected = _selected;

    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: EdgeInsets.fromLTRB(
            8, 6, 8, 6 + (inset > 0 ? inset : 8)),
        decoration: BoxDecoration(
          color: AppColors.blackCard.withValues(alpha: 0.97),
          border: const Border(top: BorderSide(color: AppColors.goldBorder)),
        ),
        child: Row(
          children: [
            _action(Icons.bookmark_border, 'علامة',
                selected == null ? null : () => _markAyah(selected)),
            _action(Icons.menu_book, 'التفسير',
                selected == null ? null : () => _showTafsir(selected)),
            _action(Icons.copy, 'نسخ',
                selected == null ? null : () => _copyAyah(selected)),
            _action(Icons.share, 'مشاركة',
                selected == null ? null : () => _shareAyah(selected)),
          ],
        ),
      ),
    );
  }

  Widget _action(IconData icon, String label, VoidCallback? onTap) {
    final enabled = onTap != null;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon,
                  color: enabled ? AppColors.gold : AppColors.textMuted,
                  size: 21),
              const SizedBox(height: 3),
              Text(label,
                  style: TextStyle(
                      color: enabled
                          ? AppColors.textSecondary
                          : AppColors.textMuted,
                      fontSize: 10)),
            ],
          ),
        ),
      ),
    );
  }
}

// ---- repeat -------------------------------------------------------------

/// Sets up a memorisation drill: how many times each ayah repeats, how many
/// ayahs the drill covers, and how many times the whole passage is replayed.
class _RepeatSheet extends StatefulWidget {
  final RepeatSettings initial;

  const _RepeatSheet({required this.initial});

  @override
  State<_RepeatSheet> createState() => _RepeatSheetState();
}

class _RepeatSheetState extends State<_RepeatSheet> {
  late RepeatSettings _value = widget.initial;

  @override
  Widget build(BuildContext context) {
    final total = _value.perAyah * _value.rangeLength * _value.wholeRange;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('التكرار للحفظ',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: AppColors.gold,
                    fontSize: 17,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            const Text('تبدأ من الآية التي تحددها',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
            const SizedBox(height: 16),

            _counter(
              label: 'عدد الآيات',
              hint: 'كم آية يشملها التكرار',
              value: _value.rangeLength,
              min: 1,
              max: 20,
              onChanged: (v) =>
                  setState(() => _value = _value.copyWith(rangeLength: v)),
            ),
            _counter(
              label: 'تكرار كل آية',
              hint: 'كم مرة تُعاد الآية الواحدة',
              value: _value.perAyah,
              min: 1,
              max: 20,
              onChanged: (v) =>
                  setState(() => _value = _value.copyWith(perAyah: v)),
            ),
            _counter(
              label: 'تكرار المقطع',
              hint: 'كم مرة يُعاد المقطع كاملاً',
              value: _value.wholeRange,
              min: 1,
              max: 20,
              onChanged: (v) =>
                  setState(() => _value = _value.copyWith(wholeRange: v)),
            ),

            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.goldMuted,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.goldBorder),
              ),
              child: Text(
                _value.isActive
                    ? 'إجمالاً: $total تلاوة'
                    : 'التكرار مُطفأ — تُقرأ السورة من الآية المحددة',
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: AppColors.textGold, fontSize: 13),
              ),
            ),
            const SizedBox(height: 14),

            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(
                        context, const RepeatSettings()),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.goldBorder),
                    ),
                    child: const Text('إيقاف التكرار',
                        style: TextStyle(color: AppColors.textMuted)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context, _value),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.emerald,
                      foregroundColor: AppColors.white,
                    ),
                    child: const Text('حفظ'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _counter({
    required String label,
    required String hint,
    required int value,
    required int min,
    required int max,
    required ValueChanged<int> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        color: AppColors.textPrimary, fontSize: 14)),
                Text(hint,
                    style: const TextStyle(
                        color: AppColors.textMuted, fontSize: 11)),
              ],
            ),
          ),
          _stepper(Icons.remove,
              value > min ? () => onChanged(value - 1) : null),
          SizedBox(
            width: 40,
            child: Text(QuranService.toArabicDigits(value),
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: AppColors.gold,
                    fontSize: 17,
                    fontWeight: FontWeight.bold)),
          ),
          _stepper(Icons.add, value < max ? () => onChanged(value + 1) : null),
        ],
      ),
    );
  }

  Widget _stepper(IconData icon, VoidCallback? onTap) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: AppColors.blackSurface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.goldBorder),
        ),
        child: Icon(icon,
            size: 17,
            color: onTap == null ? AppColors.textMuted : AppColors.gold),
      ),
    );
  }
}

// ---- page ---------------------------------------------------------------

class _PageSheet extends StatefulWidget {
  final MushafPage page;
  final SurahInfo Function(int) surahInfo;
  final AyahBoxes? selected;
  final ValueChanged<AyahBoxes?> onAyahTapped;
  final VoidCallback onBackgroundTapped;

  const _PageSheet({
    required this.page,
    required this.surahInfo,
    required this.selected,
    required this.onAyahTapped,
    required this.onBackgroundTapped,
  });

  @override
  State<_PageSheet> createState() => _PageSheetState();
}

class _PageSheetState extends State<_PageSheet> {
  late Future<File?> _image;
  List<AyahBoxes> _boxes = const [];

  @override
  void initState() {
    super.initState();
    _image = MushafImageService.fetch(widget.page.number);
    AyahBoxService.forPage(widget.page.number).then((b) {
      if (mounted) setState(() => _boxes = b);
    });
  }

  @override
  Widget build(BuildContext context) {
    // The page sits inside the reader's chosen border, drawn in the app's own
    // colour so changing the theme carries the ornament with it. The page
    // images are text on a transparent ground with no printed border of their
    // own, so nothing is being drawn over.
    return ValueListenableBuilder<MushafPalette>(
      valueListenable: MushafPalettes.current,
      builder: (context, palette, _) => Container(
        margin: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: palette.paper,
          borderRadius: BorderRadius.circular(6),
        ),
        clipBehavior: Clip.antiAlias,
        child: ValueListenableBuilder<MushafFrame>(
          valueListenable: MushafFrames.current,
          builder: (context, frame, child) => MushafFrameBox(
            frame: frame,
            color: palette.ink,
            child: child!,
          ),
          child: FutureBuilder<File?>(
            future: _image,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return Center(
                  child: CircularProgressIndicator(
                      color: palette.ink, strokeWidth: 2),
                );
              }
              final file = snapshot.data;
              if (file == null) return _textFallback(palette);

              return InvertedInk(
                active: palette.invert,
                child: MushafPageImage(
                  file: file,
                  boxes: _boxes,
                  selected: widget.selected,
                  onAyahTapped: widget.onAyahTapped,
                  onBackgroundTapped: widget.onBackgroundTapped,
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  /// Same page from the bundled text — used offline and on web.
  Widget _textFallback(MushafPalette palette) {
    final view = MediaQuery.viewPaddingOf(context);
    return GestureDetector(
      onTap: widget.onBackgroundTapped,
      child: SingleChildScrollView(
        // Clears the two-row bar above and the action bar below, plus the
        // system bars.
        padding: EdgeInsets.fromLTRB(16, 80 + view.top, 16, 62 + view.bottom),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final run in widget.page.runs) ..._runWidgets(run),
            const SizedBox(height: 8),
            Text('صفحة ${QuranService.toArabicDigits(widget.page.number)}',
                textAlign: TextAlign.center,
                style: TextStyle(color: palette.onPaperMuted, fontSize: 12)),
          ],
        ),
      ),
    );
  }

  List<Widget> _runWidgets(AyahRun run) {
    final info = widget.surahInfo(run.surah);
    return [
      if (run.startsSurah) ...[
        Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFFE8DCC0),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFC9B37E)),
          ),
          child: Text('سورة ${info.name}',
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: Color(0xFF6B5A2E),
                  fontSize: 18,
                  fontWeight: FontWeight.bold)),
        ),
        if (info.hasBasmala)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(QuranService.basmala,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: _mushafFont,
                  color: Color(0xFF6B5A2E),
                  fontSize: 20,
                  height: 1.9,
                )),
          ),
      ],
      FutureBuilder<Surah>(
        future: QuranService.surah(run.surah),
        builder: (context, snapshot) {
          final surah = snapshot.data;
          if (surah == null) return const SizedBox(height: 40);
          return Text.rich(
            TextSpan(children: [
              for (var n = run.first; n <= run.last; n++) ...[
                TextSpan(text: surah.ayahs[n - 1].text),
                TextSpan(
                  text: ' ﴿${QuranService.toArabicDigits(n)}﴾ ',
                  style: const TextStyle(color: Color(0xFF9A7B2E), fontSize: 15),
                ),
              ],
            ]),
            textAlign: TextAlign.justify,
            style: const TextStyle(
              fontFamily: _mushafFont,
              color: _ink,
              fontSize: 21,
              height: 2.2,
            ),
          );
        },
      ),
      const SizedBox(height: 6),
    ];
  }
}

// ---- drawer -------------------------------------------------------------

class _NavigationDrawer extends StatelessWidget {
  final List<SurahInfo> index;
  final List<MushafPage> pages;
  final ValueChanged<SurahInfo> onSurah;
  final ValueChanged<int> onPage;
  final ValueChanged<Bookmark> onBookmark;

  const _NavigationDrawer({
    required this.index,
    required this.pages,
    required this.onSurah,
    required this.onPage,
    required this.onBookmark,
  });

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: AppColors.black,
      width: MediaQuery.sizeOf(context).width * 0.92,
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: SafeArea(
          child: _DrawerBody(
            index: index,
            pages: pages,
            onSurah: onSurah,
            onPage: onPage,
            onBookmark: onBookmark,
          ),
        ),
      ),
    );
  }
}

/// Tabs run down the side rather than across the top: five Arabic labels do
/// not fit on one line on a phone, and a scrolling tab strip hides whichever
/// ones happen to be off-screen.
class _DrawerBody extends StatefulWidget {
  final List<SurahInfo> index;
  final List<MushafPage> pages;
  final ValueChanged<SurahInfo> onSurah;
  final ValueChanged<int> onPage;
  final ValueChanged<Bookmark> onBookmark;

  const _DrawerBody({
    required this.index,
    required this.pages,
    required this.onSurah,
    required this.onPage,
    required this.onBookmark,
  });

  @override
  State<_DrawerBody> createState() => _DrawerBodyState();
}

class _DrawerBodyState extends State<_DrawerBody> {
  int _tab = 0;

  static const _tabs = [
    (icon: Icons.menu_book, label: 'السور'),
    (icon: Icons.auto_stories, label: 'الأجزاء'),
    (icon: Icons.search, label: 'الكلمات'),
    (icon: Icons.bookmark, label: 'العلامات'),
    (icon: Icons.download, label: 'التنزيل'),
    (icon: Icons.filter_frames, label: 'الإطار'),
    (icon: Icons.palette, label: 'اللون'),
  ];

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _rail(),
        const VerticalDivider(width: 1, color: AppColors.goldBorder),
        Expanded(
          child: IndexedStack(
            index: _tab,
            children: [
              _SurahTab(index: widget.index, onSurah: widget.onSurah),
              _JuzTab(pages: widget.pages, onPage: widget.onPage),
              _WordSearchTab(onGoTo: widget.onSurah, index: widget.index),
              _BookmarksTab(
                  index: widget.index, onBookmark: widget.onBookmark),
              const _DownloadsTab(),
              const _FrameTab(),
              const _PaletteTab(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _rail() {
    return Container(
      width: 78,
      color: AppColors.blackCard,
      child: Column(
        children: [
          const SizedBox(height: 10),
          const Text('التصفّح',
              style: TextStyle(
                  color: AppColors.gold,
                  fontSize: 13,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          for (var i = 0; i < _tabs.length; i++) _railItem(i),
        ],
      ),
    );
  }

  Widget _railItem(int i) {
    final active = _tab == i;
    return GestureDetector(
      onTap: () => setState(() => _tab = i),
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: active ? AppColors.goldMuted : Colors.transparent,
          border: Border(
            right: BorderSide(
              color: active ? AppColors.gold : Colors.transparent,
              width: 3,
            ),
          ),
        ),
        child: Column(
          children: [
            Icon(_tabs[i].icon,
                size: 20,
                color: active ? AppColors.gold : AppColors.textMuted),
            const SizedBox(height: 4),
            Text(_tabs[i].label,
                style: TextStyle(
                  color: active ? AppColors.gold : AppColors.textMuted,
                  fontSize: 11,
                  fontWeight: active ? FontWeight.bold : FontWeight.normal,
                )),
          ],
        ),
      ),
    );
  }
}

/// Picks the border drawn around the page. Every swatch is the real painter at
/// preview size, so what the reader taps is exactly what the page becomes.
class _FrameTab extends StatelessWidget {
  const _FrameTab();

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<MushafFrame>(
      valueListenable: MushafFrames.current,
      builder: (context, chosen, _) => ListView(
        padding: const EdgeInsets.all(12),
        children: [
          const Text('إطار الصفحة',
              style: TextStyle(
                  color: AppColors.gold,
                  fontSize: 15,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          const Text(
            'زخارف مرسومة داخل التطبيق، تأخذ لون السمة وتتغيّر معه.',
            style: TextStyle(color: AppColors.textMuted, fontSize: 11),
          ),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 0.66,
            children: [
              for (final frame in MushafFrame.values)
                _swatch(frame, frame == chosen),
            ],
          ),
        ],
      ),
    );
  }

  Widget _swatch(MushafFrame frame, bool active) {
    return GestureDetector(
      onTap: () => MushafFrames.choose(frame),
      behavior: HitTestBehavior.opaque,
      child: Column(
        children: [
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: MushafPalettes.current.value.paper,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: active ? AppColors.gold : Colors.transparent,
                  width: 2,
                ),
              ),
              clipBehavior: Clip.antiAlias,
              child: MushafFrameBox(
                frame: frame,
                color: MushafPalettes.current.value.ink,
                // Stand-in for the text, so the swatch shows how much room the
                // ornament leaves the page.
                child: const _PreviewLines(),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            frame.label,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: active ? AppColors.gold : AppColors.textMuted,
              fontSize: 10,
              fontWeight: active ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}

/// Picks the paper. Each swatch is that paper with that ornament on it, so
/// the choice is made by looking rather than by reading a colour name.
class _PaletteTab extends StatelessWidget {
  const _PaletteTab();

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<MushafPalette>(
      valueListenable: MushafPalettes.current,
      builder: (context, chosen, _) => ValueListenableBuilder<MushafFrame>(
        valueListenable: MushafFrames.current,
        builder: (context, frame, _) => ListView(
          padding: const EdgeInsets.all(12),
          children: [
            const Text('لون الصفحة',
                style: TextStyle(
                    color: AppColors.gold,
                    fontSize: 15,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            const Text(
              'الإطار وأرقام الآيات تأخذ لون الورقة. الأوراق الداكنة تقلب لون '
              'الخط ليبقى مقروءاً.',
              style: TextStyle(color: AppColors.textMuted, fontSize: 11),
            ),
            const SizedBox(height: 12),
            GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 0.66,
              children: [
                for (final palette in MushafPalette.values)
                  _swatch(palette, frame, palette == chosen),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _swatch(MushafPalette palette, MushafFrame frame, bool active) {
    return GestureDetector(
      onTap: () => MushafPalettes.choose(palette),
      behavior: HitTestBehavior.opaque,
      child: Column(
        children: [
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: palette.paper,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: active ? AppColors.gold : Colors.transparent,
                  width: 2,
                ),
              ),
              clipBehavior: Clip.antiAlias,
              child: MushafFrameBox(
                frame: frame,
                color: palette.ink,
                child: _PreviewLines(color: palette.onPaperMuted),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            palette.label,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: active ? AppColors.gold : AppColors.textMuted,
              fontSize: 10,
              fontWeight: active ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}

class _PreviewLines extends StatelessWidget {
  const _PreviewLines({this.color = const Color(0xFF6B6250)});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(2),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 0; i < 4; i++)
            Container(
              height: 2,
              margin: const EdgeInsets.symmetric(vertical: 2),
              width: i.isEven ? double.infinity : null,
              constraints: const BoxConstraints(minWidth: 14),
              color: color,
            ),
        ],
      ),
    );
  }
}

class _SurahTab extends StatefulWidget {
  final List<SurahInfo> index;
  final ValueChanged<SurahInfo> onSurah;

  const _SurahTab({required this.index, required this.onSurah});

  @override
  State<_SurahTab> createState() => _SurahTabState();
}

class _SurahTabState extends State<_SurahTab> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final q = _query.trim();
    final filtered = q.isEmpty
        ? widget.index
        : widget.index
            .where((s) => QuranService.surahMatches(s, q))
            .toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(10),
          child: TextField(
            onChanged: (v) => setState(() => _query = v),
            textAlign: TextAlign.right,
            style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
            decoration: InputDecoration(
              hintText: 'ابحث عن سورة…',
              hintStyle:
                  const TextStyle(color: AppColors.textMuted, fontSize: 13),
              filled: true,
              fillColor: AppColors.blackSurface,
              isDense: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppColors.goldBorder),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppColors.goldBorder),
              ),
              suffixIcon:
                  const Icon(Icons.search, color: AppColors.textMuted, size: 18),
            ),
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: filtered.length,
            itemBuilder: (context, i) => ListTile(
              dense: true,
              leading: Text(QuranService.toArabicDigits(filtered[i].number),
                  style: const TextStyle(color: AppColors.gold, fontSize: 13)),
              title: Text(filtered[i].name,
                  style: const TextStyle(
                      color: AppColors.textPrimary, fontSize: 14)),
              subtitle: Text(
                  '${filtered[i].type} • ${filtered[i].ayahCount} آية',
                  style: const TextStyle(
                      color: AppColors.textMuted, fontSize: 11)),
              onTap: () => widget.onSurah(filtered[i]),
            ),
          ),
        ),
      ],
    );
  }
}

class _JuzTab extends StatelessWidget {
  final List<MushafPage> pages;
  final ValueChanged<int> onPage;

  const _JuzTab({required this.pages, required this.onPage});

  @override
  Widget build(BuildContext context) {
    final firstPage = <int, int>{};
    for (final p in pages) {
      firstPage.putIfAbsent(p.juz, () => p.number);
    }
    final juz = firstPage.keys.toList()..sort();

    return ListView.builder(
      itemCount: juz.length,
      itemBuilder: (context, i) => ListTile(
        dense: true,
        leading: Text(QuranService.toArabicDigits(juz[i]),
            style: const TextStyle(color: AppColors.gold, fontSize: 13)),
        title: Text('الجزء ${QuranService.toArabicDigits(juz[i])}',
            style:
                const TextStyle(color: AppColors.textPrimary, fontSize: 14)),
        subtitle: Text(
            'يبدأ في صفحة ${QuranService.toArabicDigits(firstPage[juz[i]]!)}',
            style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
        onTap: () => onPage(firstPage[juz[i]]!),
      ),
    );
  }
}

/// Finds a word anywhere in the Mushaf and lists where it occurs, in order.
///
/// Matching ignores diacritics: nobody types the Mushaf's tashkeel, so a plain
/// query has to reach the marked-up text.
class _WordSearchTab extends StatefulWidget {
  final List<SurahInfo> index;
  final ValueChanged<SurahInfo> onGoTo;

  const _WordSearchTab({required this.index, required this.onGoTo});

  @override
  State<_WordSearchTab> createState() => _WordSearchTabState();
}

class _WordSearchTabState extends State<_WordSearchTab> {
  final _controller = TextEditingController();
  List<AyahHit> _hits = const [];
  int _occurrences = 0;
  bool _searching = false;
  String _lastQuery = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _run(String query) async {
    final trimmed = query.trim();
    if (trimmed == _lastQuery) return;
    _lastQuery = trimmed;

    if (trimmed.isEmpty) {
      setState(() {
        _hits = const [];
        _occurrences = 0;
      });
      return;
    }

    setState(() => _searching = true);
    final hits = await QuranService.search(trimmed);
    final count = await QuranService.countOccurrences(trimmed);
    if (!mounted || _lastQuery != trimmed) return;
    setState(() {
      _hits = hits;
      _occurrences = count;
      _searching = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(10),
          child: TextField(
            controller: _controller,
            onChanged: _run,
            textAlign: TextAlign.right,
            style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
            decoration: InputDecoration(
              hintText: 'اكتب كلمة…',
              hintStyle:
                  const TextStyle(color: AppColors.textMuted, fontSize: 13),
              filled: true,
              fillColor: AppColors.blackSurface,
              isDense: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppColors.goldBorder),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppColors.goldBorder),
              ),
              suffixIcon:
                  const Icon(Icons.search, color: AppColors.textMuted, size: 18),
            ),
          ),
        ),
        if (_searching)
          const Padding(
            padding: EdgeInsets.all(8),
            child: SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: AppColors.gold),
            ),
          )
        else if (_lastQuery.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              children: [
                Text(
                  _hits.isEmpty
                      ? 'لا نتائج'
                      : 'وردت ${QuranService.toArabicDigits(_occurrences)} مرة '
                          'في ${QuranService.toArabicDigits(_hits.length)} آية',
                  style: const TextStyle(
                      color: AppColors.textGold, fontSize: 12),
                ),
              ],
            ),
          ),
        Expanded(
          child: _lastQuery.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'ابحث عن أي كلمة في المصحف.\nلا حاجة لكتابة التشكيل.',
                      textAlign: TextAlign.center,
                      style:
                          TextStyle(color: AppColors.textMuted, fontSize: 13),
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(10, 8, 10, 16),
                  itemCount: _hits.length,
                  itemBuilder: (context, i) => _hitCard(_hits[i]),
                ),
        ),
      ],
    );
  }

  Widget _hitCard(AyahHit hit) {
    return GestureDetector(
      onTap: () {
        final info =
            widget.index.where((s) => s.number == hit.surah).firstOrNull;
        if (info != null) widget.onGoTo(info);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(11),
        decoration: BoxDecoration(
          color: AppColors.blackCard,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.goldBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              hit.text,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontFamily: _mushafFont,
                color: AppColors.textPrimary,
                fontSize: 16,
                height: 1.9,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '${hit.surahName} — آية ${QuranService.toArabicDigits(hit.ayah)}',
              style:
                  const TextStyle(color: AppColors.textMuted, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}

class _BookmarksTab extends StatefulWidget {
  final List<SurahInfo> index;
  final ValueChanged<Bookmark> onBookmark;

  const _BookmarksTab({required this.index, required this.onBookmark});

  @override
  State<_BookmarksTab> createState() => _BookmarksTabState();
}

class _BookmarksTabState extends State<_BookmarksTab> {
  List<Bookmark>? _marks;

  @override
  void initState() {
    super.initState();
    BookmarkService.all().then((m) {
      if (mounted) setState(() => _marks = m);
    });
  }

  String _name(int surah) =>
      widget.index.firstWhere((s) => s.number == surah).name;

  @override
  Widget build(BuildContext context) {
    final marks = _marks;
    if (marks == null) {
      return const Center(
          child: CircularProgressIndicator(color: AppColors.gold));
    }
    if (marks.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'لا توجد علامات بعد.\nاضغط على آية ثم «علامة».',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textMuted, fontSize: 13),
          ),
        ),
      );
    }

    return ListView.builder(
      itemCount: marks.length,
      itemBuilder: (context, i) {
        final b = marks[i];
        return ListTile(
          dense: true,
          leading: Text(b.kind.icon, style: const TextStyle(fontSize: 18)),
          title: Text('${_name(b.surah)} — آية ${b.ayah}',
              style:
                  const TextStyle(color: AppColors.textPrimary, fontSize: 14)),
          subtitle: Text(
              b.note ??
                  '${b.kind.label} • صفحة ${QuranService.toArabicDigits(b.page)}',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
          trailing: IconButton(
            icon: const Icon(Icons.delete_outline,
                color: AppColors.textMuted, size: 18),
            onPressed: () async {
              await BookmarkService.remove(b.kind, b.surah, b.ayah);
              final refreshed = await BookmarkService.all();
              if (mounted) setState(() => _marks = refreshed);
            },
          ),
          onTap: () => widget.onBookmark(b),
        );
      },
    );
  }
}

/// Pulls the whole Mushaf down so it reads with no connection at all.
class _DownloadsTab extends StatefulWidget {
  const _DownloadsTab();

  @override
  State<_DownloadsTab> createState() => _DownloadsTabState();
}

class _DownloadsTabState extends State<_DownloadsTab> {
  int _cached = 0;
  bool _running = false;
  int _done = 0;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final count = await MushafImageService.cachedCount();
    if (mounted) setState(() => _cached = count);
  }

  Future<void> _start() async {
    setState(() {
      _running = true;
      _done = 0;
    });

    final failed = await MushafImageService.downloadAll(
      onProgress: (done, _) {
        if (mounted) setState(() => _done = done);
      },
    );

    if (!mounted) return;
    setState(() => _running = false);
    await _refresh();
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          failed == 0
              ? 'اكتمل تنزيل المصحف — يعمل الآن بلا إنترنت'
              : 'تعذّر تنزيل $failed صفحة — أعد المحاولة لإكمالها',
          textDirection: TextDirection.rtl,
        ),
        backgroundColor: failed == 0 ? AppColors.emerald : AppColors.error,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const total = QuranService.pageCount;
    final complete = _cached >= total;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('تنزيل الملحقات',
            style: TextStyle(
                color: AppColors.gold,
                fontSize: 15,
                fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        const Text(
          'نزّل صفحات المصحف مرة واحدة لتقرأها بلا إنترنت. '
          'الصفحة التي تفتحها تُحفظ تلقائياً على أي حال.',
          style: TextStyle(color: AppColors.textMuted, fontSize: 12, height: 1.6),
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.blackCard,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.goldBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('الصفحات',
                      style: TextStyle(
                          color: AppColors.textPrimary, fontSize: 14)),
                  Text(
                    _running
                        ? '$_done / $total'
                        : '$_cached / $total',
                    style: const TextStyle(
                        color: AppColors.textGold, fontSize: 13),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: (_running ? _done : _cached) / total,
                  backgroundColor: AppColors.blackSurface,
                  valueColor: const AlwaysStoppedAnimation(AppColors.gold),
                  minHeight: 5,
                ),
              ),
              const SizedBox(height: 12),
              if (_running)
                OutlinedButton(
                  onPressed: MushafImageService.cancelDownloadAll,
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.goldBorder),
                  ),
                  child: const Text('إيقاف',
                      style: TextStyle(color: AppColors.textMuted)),
                )
              else
                ElevatedButton(
                  onPressed: complete ? null : _start,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.emerald,
                    disabledBackgroundColor: AppColors.blackSurface,
                  ),
                  child: Text(
                    complete ? '✓ مكتمل' : 'نزّل المصحف كاملاً (~٥٩ م.ب)',
                    style: const TextStyle(color: AppColors.white),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        const Text('التفاسير والتراجم',
            style: TextStyle(
                color: AppColors.gold,
                fontSize: 15,
                fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        const Text(
          'الميسّر والمختصر مضمّنان أصلاً. نزّل البقية لتعمل بلا إنترنت.',
          style: TextStyle(color: AppColors.textMuted, fontSize: 12, height: 1.6),
        ),
        const SizedBox(height: 10),
        for (final edition in TafsirService.editions.where((e) => !e.isBundled))
          _RemoteItem(
            title: edition.name,
            subtitle: '${edition.author} · ${edition.downloadSize}',
            isDownloaded: () => TafsirService.isDownloaded(edition),
            download: (onProgress) async {
              final failed = await TafsirService.download(edition,
                  onProgress: (done, total) => onProgress(done, total));
              return failed == 0;
            },
          ),
        for (final translation in TranslationService.available)
          _RemoteItem(
            title: translation.language,
            subtitle: translation.translator,
            isDownloaded: () => TranslationService.isDownloaded(translation),
            download: (onProgress) async {
              final failed = await TranslationService.download(translation,
                  onProgress: (done, total) => onProgress(done, total));
              return failed == 0;
            },
          ),

        const SizedBox(height: 18),
        const Text('التلاوات',
            style: TextStyle(
                color: AppColors.gold,
                fontSize: 15,
                fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        const Text(
          'تُبَث عند التشغيل ولا تُنزَّل بعد — تلاوة قارئ واحد للمصحف كامل '
          'تقارب ٣٠٠ م.ب، وتنزيلها يحتاج إدارة مساحة لم تُبنَ.',
          style: TextStyle(color: AppColors.textMuted, fontSize: 12, height: 1.6),
        ),
      ],
    );
  }
}

/// A downloadable extra: shows whether it is already on the device, and its
/// progress while it arrives.
class _RemoteItem extends StatefulWidget {
  final String title;
  final String subtitle;
  final Future<bool> Function() isDownloaded;
  final Future<bool> Function(void Function(int done, int total)) download;

  const _RemoteItem({
    required this.title,
    required this.subtitle,
    required this.isDownloaded,
    required this.download,
  });

  @override
  State<_RemoteItem> createState() => _RemoteItemState();
}

class _RemoteItemState extends State<_RemoteItem> {
  bool? _ready;
  bool _busy = false;
  double _progress = 0;

  @override
  void initState() {
    super.initState();
    widget.isDownloaded().then((v) {
      if (mounted) setState(() => _ready = v);
    });
  }

  Future<void> _start() async {
    setState(() {
      _busy = true;
      _progress = 0;
    });

    final ok = await widget.download((done, total) {
      if (mounted && total > 0) setState(() => _progress = done / total);
    });

    if (!mounted) return;
    setState(() {
      _busy = false;
      _ready = ok;
    });

    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('لم يكتمل التنزيل — أعد المحاولة',
              textDirection: TextDirection.rtl),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.blackCard,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.goldBorder),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.title,
                        style: const TextStyle(
                            color: AppColors.textPrimary, fontSize: 14)),
                    Text(widget.subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: AppColors.textMuted, fontSize: 11)),
                  ],
                ),
              ),
              if (_busy)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: AppColors.gold),
                )
              else if (_ready == true)
                const Icon(Icons.offline_pin,
                    color: AppColors.emeraldLight, size: 20)
              else
                GestureDetector(
                  onTap: _start,
                  behavior: HitTestBehavior.opaque,
                  child: const Padding(
                    padding: EdgeInsets.all(4),
                    child: Icon(Icons.download,
                        color: AppColors.gold, size: 20),
                  ),
                ),
            ],
          ),
          if (_busy) ...[
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: _progress == 0 ? null : _progress,
                backgroundColor: AppColors.blackSurface,
                valueColor: const AlwaysStoppedAnimation(AppColors.gold),
                minHeight: 4,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
