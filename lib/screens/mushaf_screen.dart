import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import 'package:share_plus/share_plus.dart';
import '../constants/theme.dart';
import '../data/ayah_boxes.dart';
import '../data/quran_data.dart';
import '../l10n/strings.dart';
import '../services/bookmark_service.dart';
import '../services/app_audio.dart';
import '../services/connectivity_check.dart';
import '../services/mushaf_image_service.dart';
import '../services/playback_speed.dart';
import '../services/recitation_downloads.dart';
import '../services/recitation_service.dart';
import '../services/repeat_settings.dart';
import '../services/storage_service.dart';
import 'package:just_audio_background/just_audio_background.dart';
import '../widgets/mushaf_chrome.dart';
import '../widgets/mushaf_palettes.dart';
import '../widgets/speed_button.dart';
import '../widgets/tafsir_sheet.dart';
import 'mushaf/navigation_drawer.dart';
import 'mushaf/page_sheet.dart';
import 'mushaf/repeat_sheet.dart';

/// The Mushaf face: the printed Madinah page, turned like a paper copy.
///
/// Tapping an ayah selects it — a soft wash marks it and the action bar acts on
/// that ayah. Tapping anywhere else clears the selection and toggles the
/// surrounding chrome, so the page can stand alone.
///
/// The page itself, the drawer behind the menu, and the repetition sheet each
/// live in `screens/mushaf/`; what stays here is the reader's state — which
/// page, which ayah, and what is being recited.
class MushafScreen extends StatefulWidget {
  final int initialPage;

  const MushafScreen({super.key, this.initialPage = 1});

  @override
  State<MushafScreen> createState() => _MushafScreenState();
}

class _MushafScreenState extends State<MushafScreen> {
  late final PageController _controller = PageController(
    initialPage: widget.initialPage - 1,
  );
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _player = AppAudio.player;

  List<MushafPage>? _pages;
  List<SurahInfo>? _index;
  late int _current = widget.initialPage;

  bool _chromeVisible = true;
  AyahBoxes? _selected;
  Reciter _reciter = RecitationService.defaultReciter;
  RepeatSettings _repeat = const RepeatSettings();
  StreamSubscription<int?>? _indexSub;
  StreamSubscription<PlayerState>? _completionSub;

  /// The surah the current playlist belongs to — tracked separately from
  /// [_selected] because a per-surah reciter's single track never updates
  /// [_selected] as it plays, and reading it back at completion would still
  /// be racing whatever _indexSub last set it to.
  int? _playingSurah;

  /// Guards against the completion handler firing again while the next
  /// surah is still being loaded — the same race [ContinuousListening]
  /// guards against.
  bool _advancingSurah = false;

  StreamSubscription<PlayerException>? _errorSub;

  /// The ayah numbers of the loaded playlist, so a failure can be resumed at
  /// the ayah that failed rather than from the top.
  List<int> _playingOrder = const [];

  /// Bumped whenever the reader starts or stops recitation themselves. A
  /// recovery in progress checks it and gives way, so a retry never
  /// overrides something the reader just chose.
  int _playGen = 0;
  bool _recovering = false;

  /// True only while a finger is dragging the pages — the one kind of page
  /// change that means "the reader went elsewhere".
  bool _userSwiping = false;

  @override
  void initState() {
    super.initState();
    _load();
    // A surah finishing is not "done reading" here the way it is for a
    // read-along screen with nothing after it — the Mushaf is the whole
    // book, so recitation carries on into the next surah exactly like
    // continuous listening does, unless a repetition drill is running (that
    // has its own idea of when a page of ayat is "done").
    _completionSub = _player.playerStateStream.listen((state) {
      if (!mounted || _advancingSurah || _repeat.isActive) return;
      if (state.processingState != ProcessingState.completed) return;
      if (!AppAudio.ownsCurrent('${_reciter.id}:')) return;
      final finished = _playingSurah;
      if (finished == null) return;
      _advanceToNextSurah(finished);
    });
    // Streaming one file per ayah means hundreds of requests an hour; one
    // dropping mid-recitation used to end it silently.
    _errorSub = _player.errorStream.listen((_) => _recoverFromError());
  }

  @override
  void dispose() {
    _completionSub?.cancel();
    _errorSub?.cancel();
    _indexSub?.cancel();
    _player.stop();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _advanceToNextSurah(int finishedSurah) async {
    _advancingSurah = true;
    try {
      final next = finishedSurah >= 114 ? 1 : finishedSurah + 1;
      await _playFrom(AyahBoxes(surah: next, ayah: 1, rects: const []));
    } finally {
      _advancingSurah = false;
    }
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
    final byHand = _userSwiping;
    setState(() {
      _current = i + 1;
      if (byHand) _selected = null;
    });
    StorageService.setLastMushafPage(i + 1);
    _prefetchAround(i + 1);
    // Only a page dragged by hand stops the recitation. A flag set before
    // each automatic turn was not enough: one animation crossing several
    // pages (catching up after the screen had been off) reports each page
    // it passes, the first cleared the flag, and the next stopped playback.
    if (byHand) {
      _playGen++;
      _indexSub?.cancel();
      _indexSub = null;
      _player.stop();
    }
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
      '${t('mushaf.surah')} ${_surahInfo(a.surah).name} — ${t('mushaf.theAyah')} ${a.ayah}';

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

  /// Returns whether playback started. [quiet] is for recovery: no new
  /// generation (it continues the reader's own session) and no error toast.
  Future<bool> _playFrom(AyahBoxes start, {bool quiet = false}) async {
    if (!quiet) _playGen++;
    _playingSurah = start.surah;
    if (!_reciter.isPerAyah) {
      _playingOrder = const [];
      return _playWholeSurah(start.surah, quiet: quiet);
    }

    final surah = await QuranService.surah(start.surah);

    // With repetition on, the playlist is the drill order; otherwise it simply
    // runs from the tapped ayah to the end of the surah.
    final order = _repeat.isActive
        ? _repeat.playbackOrder(start.ayah, surah.ayahs.length)
        : [for (var n = start.ayah; n <= surah.ayahs.length; n++) n];
    _playingOrder = order;

    try {
      final sources = <AudioSource>[
        for (final ayah in order)
          AudioSource.uri(
            await RecitationDownloads.sourceFor(
              reciter: _reciter,
              surah: start.surah,
              ayah: ayah,
            ),
            // Names the track in the notification and on the lock screen,
            // and is what lets playback survive leaving the app.
            tag: MediaItem(
              id: '${_reciter.id}:${start.surah}:$ayah',
              title:
                  '${surah.name} — ${t('mushaf.theAyah')} ${QuranService.toArabicDigits(ayah)}',
              artist: _reciter.displayName,
              album: t('mushaf.theNobleQuran'),
            ),
          ),
      ];
      await _player.setAudioSources(sources, initialIndex: 0);
      await PlaybackSpeed.apply();

      // Follow the recitation: highlight the playing ayah and auto-turn the
      // page when it moves to the next one.
      _indexSub?.cancel();
      _indexSub = _player.currentIndexStream.listen((i) async {
        if (!mounted || i == null || i >= order.length) return;
        final targetAyah = order[i];
        final targetPage = await QuranService.pageOfAyah(
          start.surah,
          targetAyah,
        );

        // Navigate automatically when the recitation crosses a page boundary.
        if (targetPage != _current && mounted) {
          _controller.animateToPage(
            targetPage - 1,
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeInOut,
          );
        }

        final boxes = await AyahBoxService.forPage(targetPage);
        final match = boxes
            .where((b) => b.surah == start.surah && b.ayah == targetAyah)
            .firstOrNull;
        if (match != null && mounted) setState(() => _selected = match);
      });

      unawaited(_player.play());
      return true;
    } catch (_) {
      if (!mounted || quiet) return false;
      final online = await ConnectivityCheck.online;
      _toast(
        online
            ? t('mushaf.recitationPlaybackFailed')
            : t('mushaf.recitationNeedsInternet'),
        error: true,
      );
      return false;
    }
  }

  // Per-surah reciters (mp3quran.net): one MP3 for the whole surah, so there
  // is no ayah index to track — no highlighting, no auto page-turn.
  Future<bool> _playWholeSurah(int surah, {bool quiet = false}) async {
    try {
      _indexSub?.cancel();
      _indexSub = null;
      final surahInfo = await QuranService.surah(surah);
      await _player.setAudioSource(
        AudioSource.uri(
          await RecitationDownloads.sourceFor(reciter: _reciter, surah: surah),
          tag: MediaItem(
            id: '${_reciter.id}:$surah',
            title: surahInfo.name,
            artist: _reciter.displayName,
            album: t('mushaf.theNobleQuran'),
          ),
        ),
      );
      await PlaybackSpeed.apply();
      // play() resolves only when playback stops, so it isn't awaited.
      unawaited(_player.play());
      return true;
    } catch (_) {
      if (!mounted || quiet) return false;
      final online = await ConnectivityCheck.online;
      _toast(
        online
            ? t('mushaf.recitationPlaybackFailed')
            : t('mushaf.recitationNeedsInternet'),
        error: true,
      );
      return false;
    }
  }

  /// Keeps a recitation going through a failed load.
  ///
  /// A hiccup is retried in place; an ayah that keeps failing is skipped;
  /// and with no connection at all it waits — up to ten minutes — and picks
  /// up at the same ayah, instead of racing through the rest of the Quran
  /// failing one file after another.
  Future<void> _recoverFromError() async {
    if (!mounted || _recovering || _playingSurah == null) return;
    if (!AppAudio.ownsCurrent('${_reciter.id}:')) return;
    _recovering = true;
    final gen = _playGen;
    try {
      var surah = _playingSurah!;
      final i = _player.currentIndex ?? 0;
      var ayah = i < _playingOrder.length ? _playingOrder[i] : 1;
      var attempts = 0;
      while (mounted && gen == _playGen) {
        await Future.delayed(const Duration(seconds: 2));
        if (!mounted || gen != _playGen) return;
        if (!await ConnectivityCheck.online) {
          if (!await _waitForConnection(gen)) {
            if (mounted && gen == _playGen) {
              _toast(t('mushaf.recitationNeedsInternet'), error: true);
            }
            return;
          }
        } else if (++attempts > 3) {
          attempts = 0;
          final count = _surahInfo(surah).ayahCount;
          if (_reciter.isPerAyah && !_repeat.isActive && ayah < count) {
            ayah++;
          } else {
            surah = surah >= 114 ? 1 : surah + 1;
            ayah = 1;
          }
        }
        final ok = await _playFrom(
          AyahBoxes(surah: surah, ayah: ayah, rects: const []),
          quiet: true,
        );
        if (ok) return;
      }
    } finally {
      _recovering = false;
    }
  }

  Future<bool> _waitForConnection(int gen) async {
    final until = DateTime.now().add(const Duration(minutes: 10));
    while (DateTime.now().isBefore(until)) {
      await Future.delayed(const Duration(seconds: 5));
      if (!mounted || gen != _playGen) return false;
      if (await ConnectivityCheck.online) return true;
    }
    return false;
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
        child: RepeatSheet(initial: _repeat),
      ),
    );
    if (updated == null || !mounted) return;

    await updated.save();
    setState(() => _repeat = updated);
    _toast(
      updated.isActive ? t('mushaf.repeatEnabled') : t('mushaf.repeatDisabled'),
    );
  }

  Future<void> _copyAyah(AyahBoxes a) async {
    await Clipboard.setData(
      ClipboardData(text: '${await _ayahText(a)}\n\n[${_reference(a)}]'),
    );
    if (!mounted) return;
    HapticFeedback.lightImpact();
    _toast(t('mushaf.ayahCopied'));
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
                child: Text(
                  '${t('mushaf.bookmarkOn')} ${_reference(a)}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.gold,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const Divider(color: AppColors.goldBorder, height: 1),
              for (final kind in BookmarkKind.values)
                ListTile(
                  leading: Text(
                    kind.icon,
                    style: const TextStyle(fontSize: 20),
                  ),
                  title: Text(
                    kind.label,
                    style: const TextStyle(color: AppColors.textPrimary),
                  ),
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

    final marked = await BookmarkService.toggle(
      Bookmark(
        kind: kind,
        surah: a.surah,
        ayah: a.ayah,
        page: _current,
        note: note,
      ),
    );
    if (!mounted) return;
    _toast(
      marked
          ? '${t('mushaf.bookmarkAdded')} ${kind.label}'
          : '${t('mushaf.bookmarkRemoved')} ${kind.label}',
    );
  }

  Future<String?> _askForNote(AyahBoxes a) async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: AppColors.blackCard,
          title: Text(
            t('mushaf.noteTitle'),
            style: const TextStyle(color: AppColors.gold, fontSize: 17),
          ),
          content: TextField(
            controller: controller,
            autofocus: true,
            maxLines: 4,
            style: const TextStyle(color: AppColors.textPrimary),
            decoration: InputDecoration(
              hintText: t('mushaf.noteHint'),
              hintStyle: const TextStyle(
                color: AppColors.textMuted,
                fontSize: 13,
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(
                t('mushaf.cancel'),
                style: const TextStyle(color: AppColors.textMuted),
              ),
            ),
            TextButton(
              onPressed: () {
                final text = controller.text.trim();
                Navigator.pop(ctx, text.isEmpty ? null : text);
              },
              child: Text(
                t('mushaf.save'),
                style: const TextStyle(color: AppColors.gold),
              ),
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
      // The paper is chosen inside the drawer, so the scaffold behind the page
      // has to listen for it rather than read it once at build time.
      child: ValueListenableBuilder<MushafPalette>(
        valueListenable: MushafPalettes.current,
        builder: (context, palette, _) => Scaffold(
          key: _scaffoldKey,
          backgroundColor: palette.paper,
          drawer: pages == null
              ? null
              : MushafNavigationDrawer(
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
              ? const Center(
                  child: CircularProgressIndicator(color: AppColors.gold),
                )
              : Stack(
                  children: [
                    NotificationListener<ScrollNotification>(
                      onNotification: (n) {
                        if (n is ScrollStartNotification) {
                          _userSwiping = n.dragDetails != null;
                        } else if (n is ScrollEndNotification) {
                          _userSwiping = false;
                        }
                        return false;
                      },
                      child: PageView.builder(
                        controller: _controller,
                        itemCount: pages.length,
                        onPageChanged: _onPageChanged,
                        itemBuilder: (context, i) => MushafPageSheet(
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
                    ),
                    if (_chromeVisible) _topBar(pages[_current - 1]),
                    if (_chromeVisible) _bottomBar(),
                  ],
                ),
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
        ? '${t('mushaf.surah')} ${names.join(' · ')}'
        : '${t('mushaf.surah')} ${_surahInfo(selected.surah).name} — ${t('mushaf.ayah')} ${QuranService.toArabicDigits(selected.ayah)}';

    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      // Reports its height, so the page can be laid out to exactly clear it.
      child: MeasuredBar(
        into: MushafChrome.topHeight,
        child: Container(
          padding: EdgeInsets.fromLTRB(
            4,
            MediaQuery.viewPaddingOf(context).top + 2,
            4,
            3,
          ),
          decoration: BoxDecoration(
            color: AppColors.blackCard.withValues(alpha: 0.97),
            border: const Border(
              bottom: BorderSide(color: AppColors.goldBorder),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Where you are: surah leads, position trails it.
              Row(
                children: [
                  _barIcon(
                    Icons.menu,
                    t('mushaf.browse'),
                    () => _scaffoldKey.currentState?.openDrawer(),
                  ),
                  Flexible(
                    child: Text(
                      surahLine,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.gold,
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '${t('mushaf.juz')} ${QuranService.toArabicDigits(page.juz)} · ${t('mushaf.page')} ${QuranService.toArabicDigits(page.number)}',
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  _barIcon(
                    Icons.close,
                    t('mushaf.back'),
                    () => Navigator.pop(context),
                  ),
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
                      const SpeedButton(),
                      _barIcon(
                        Icons.repeat,
                        _reciter.isPerAyah
                            ? t('mushaf.repetition')
                            : t('mushaf.repeatUnavailablePerSurah'),
                        _reciter.isPerAyah
                            ? _openRepeatSettings
                            : () =>
                                  _toast(t('mushaf.repeatUnavailablePerSurah')),
                        label: t('mushaf.repetitionShort'),
                        active: _reciter.isPerAyah && _repeat.isActive,
                        iconSize: 23,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// A bar control. Passing [label] spells the action out beside the icon —
  /// worth the width for the ones whose symbol alone is ambiguous.
  Widget _barIcon(
    IconData icon,
    String tooltip,
    VoidCallback onTap, {
    bool active = false,
    String? label,
    double iconSize = 21,
  }) {
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
                Text(
                  label,
                  style: TextStyle(
                    color: tint,
                    fontSize: 11,
                    fontWeight: active ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
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
          _reciter.displayName,
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
      child: Icon(
        Icons.record_voice_over,
        size: 22,
        color: AppColors.textSecondary,
      ),
    ),
  );

  /// Drops the reciter list below whatever it wraps — a sheet rising from the
  /// bottom of the screen put the choices as far from the button as possible.
  Widget _reciterPopup({required Widget child}) {
    return PopupMenuButton<Reciter>(
      tooltip: t('playback.pickReciter'),
      color: AppColors.blackCard,
      position: PopupMenuPosition.under,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.goldBorder),
      ),
      padding: EdgeInsets.zero,
      // Wide enough for the longest name. Material's default cap is narrower
      // than "عبد الباسط عبد الصمد", so the list overflowed and clipped the
      // end of the very names it exists to let the reader choose between.
      constraints: const BoxConstraints(minWidth: 220, maxWidth: 340),
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
                  // Flexible as well as roomy: a name is only ever going to
                  // be trimmed here, never allowed to overflow the row it
                  // sits in and paint over what is beside it.
                  Flexible(
                    child: Text(
                      r.displayName,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: r.id == _reciter.id
                            ? AppColors.gold
                            : AppColors.textPrimary,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  // Per-surah reciters (one file per surah) can't drive the
                  // ayah-by-ayah highlighting, auto page-turn or repeat drill
                  // this screen otherwise offers — flagged so the choice is
                  // informed rather than a later surprise.
                  if (!r.isPerAyah) ...[
                    const SizedBox(width: 6),
                    Text(
                      t('mushaf.wholeSurahReciterBadge'),
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 10,
                      ),
                    ),
                  ],
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
    _indexSub?.cancel();
    _indexSub = null;
    if (!mounted) return;
    setState(() => _reciter = chosen);
    if (!chosen.isPerAyah) _toast(t('mushaf.wholeSurahReciterNote'));
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
                strokeWidth: 2,
                color: AppColors.gold,
              ),
            ),
          );
        }

        return _barIcon(
          playing ? Icons.pause : Icons.play_arrow,
          playing
              ? t('mushaf.pause')
              : (_reciter.isPerAyah
                    ? t('mushaf.playSelectedAyah')
                    : t('mushaf.playWholeSurah')),
          () {
            if (playing) {
              _player.pause();
            } else if (_selected != null) {
              _playFrom(_selected!);
            } else {
              _toast(t('mushaf.tapAyahFirst'));
            }
          },
          label: playing ? t('mushaf.pauseShort') : t('mushaf.playShort'),
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
      child: MeasuredBar(
        into: MushafChrome.bottomHeight,
        child: Container(
          // Half a line of Mushaf text lower, so the page clears it above and
          // below rather than sitting against it.
          padding: EdgeInsets.fromLTRB(
            8,
            6,
            8,
            6 + (inset > 0 ? inset : 8) - 11,
          ),
          decoration: BoxDecoration(
            color: AppColors.blackCard.withValues(alpha: 0.97),
            border: const Border(top: BorderSide(color: AppColors.goldBorder)),
          ),
          child: Row(
            children: [
              _action(
                Icons.bookmark_border,
                t('mushaf.bookmark'),
                selected == null ? null : () => _markAyah(selected),
              ),
              _action(
                Icons.menu_book,
                t('mushaf.tafsir'),
                selected == null ? null : () => _showTafsir(selected),
              ),
              _action(
                Icons.copy,
                t('mushaf.copy'),
                selected == null ? null : () => _copyAyah(selected),
              ),
              _action(
                Icons.share,
                t('mushaf.share'),
                selected == null ? null : () => _shareAyah(selected),
              ),
            ],
          ),
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
              Icon(
                icon,
                color: enabled ? AppColors.gold : AppColors.textMuted,
                size: 21,
              ),
              const SizedBox(height: 3),
              Text(
                label,
                style: TextStyle(
                  color: enabled
                      ? AppColors.textSecondary
                      : AppColors.textMuted,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
