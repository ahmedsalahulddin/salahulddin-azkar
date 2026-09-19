import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import '../constants/theme.dart';
import '../services/app_audio.dart';
import '../data/quran_data.dart';
import '../data/tafsir_data.dart';
import '../l10n/strings.dart';
import '../services/connectivity_check.dart';
import '../services/playback_speed.dart';
import '../services/recitation_downloads.dart';
import '../services/recitation_service.dart';
import '../services/storage_service.dart';
import '../widgets/speed_button.dart';

class SurahScreen extends StatefulWidget {
  final SurahInfo info;

  const SurahScreen({super.key, required this.info});

  @override
  State<SurahScreen> createState() => _SurahScreenState();
}

/// Bundled Mushaf face. The KFGQPC text uses Arabic Extended-A marks that most
/// system fonts have no glyphs for, so scripture must not fall back to them.
const _mushafFont = 'AmiriQuran';

class _SurahScreenState extends State<SurahScreen> {
  Surah? _surah;
  double _fontSize = 24;

  final _player = AppAudio.player;
  final _itemKeys = <int, GlobalKey>{};
  Reciter _reciter = RecitationService.defaultReciter;
  StreamSubscription<int?>? _indexSub;
  int? _playingAyah;
  bool _audioFailed = false;

  @override
  void initState() {
    super.initState();
    _load();
    // Any audio playing when this screen opens belongs to another screen. Stop
    // it now rather than letting it bleed into the reader's session — the
    // ownership check in _play() would catch it on the first tap, but the
    // reader should not hear the previous audio while they are choosing a ayah.
    if (_player.playing && !AppAudio.ownsCurrent('${_reciter.id}:')) {
      _player.stop();
    }

    // Keep the highlight and scroll position in step with the playlist.
    _indexSub = _player.currentIndexStream.listen((i) {
      if (!mounted || i == null || !_player.playing) return;
      // Only when the player is on this surah's playlist: the shared player
      // reports the radio's track changes here too.
      if (!AppAudio.ownsCurrent('${_reciter.id}:')) return;
      // Per-surah reciters load one file — index 0 is not an ayah position.
      if (!_reciter.isPerAyah) return;
      final ayah = i + 1;
      setState(() => _playingAyah = ayah);
      _scrollTo(ayah);
    });
  }

  @override
  void dispose() {
    _indexSub?.cancel();
    _player.stop();
    super.dispose();
  }

  Future<void> _load() async {
    final s = await QuranService.surah(widget.info.number);
    final stored = await StorageService.getFontSize();
    final reciter = await RecitationService.getReciter();
    if (!mounted) return;
    setState(() {
      _surah = s;
      _reciter = reciter;
      _fontSize = switch (stored) {
        'small' => 20.0,
        'large' => 30.0,
        _ => 24.0,
      };
    });
  }

  void _adjustFont(double delta) {
    setState(() => _fontSize = (_fontSize + delta).clamp(16.0, 40.0));
  }

  void _scrollTo(int ayah) {
    final ctx = _itemKeys[ayah]?.currentContext;
    if (ctx == null) return; // off-screen and not built — nothing to scroll to
    Scrollable.ensureVisible(
      ctx,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
      alignment: 0.3,
    );
  }

  /// Streams the surah as a playlist so playback rolls on to the next ayah.
  /// For per-surah reciters (mp3quran.net), loads a single file instead.
  Future<void> _play({int fromAyah = 1}) async {
    final surah = _surah;
    if (surah == null) return;

    setState(() => _audioFailed = false);

    if (_reciter.isPerAyah) {
      await _playPerAyah(surah: surah, fromAyah: fromAyah);
    } else {
      await _playPerSurah(surah: surah);
    }
  }

  Future<void> _playPerAyah({
    required dynamic surah,
    required int fromAyah,
  }) async {
    // Whose playlist is loaded, not merely whether one is: the radio leaves
    // its own source in place, and seeking into that plays the broadcast
    // under this screen's reciter name.
    final mine = '${_reciter.id}:${surah.number}:';
    try {
      if (!AppAudio.ownsCurrent(mine)) {
        await _player.stop();
        final sources = <AudioSource>[
          for (final a in surah.ayahs)
            AudioSource.uri(
              await RecitationDownloads.sourceFor(
                reciter: _reciter,
                surah: surah.number,
                ayah: a.number,
              ),
              tag: MediaItem(
                id: '${_reciter.id}:${surah.number}:${a.number}',
                title:
                    '${surah.name} — ${t('qs.ayahWord')} ${QuranService.toArabicDigits(a.number)}',
                artist: _reciter.displayName,
                album: t('qs.quranTitle'),
              ),
            ),
        ];
        await _player.setAudioSources(sources, initialIndex: fromAyah - 1);
      } else {
        await _player.seek(Duration.zero, index: fromAyah - 1);
      }
      setState(() => _playingAyah = fromAyah);
      await PlaybackSpeed.apply();
      await _player.play();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _audioFailed = true;
        _playingAyah = null;
      });
      _toast(await _playbackFailureMessage());
    }
  }

  /// Distinguishes "not downloaded and no internet" from an ordinary
  /// playback failure, so the reader is told the actual reason rather than a
  /// generic "check your connection" when a network check would show there
  /// plainly is none.
  Future<String> _playbackFailureMessage() async =>
      (await ConnectivityCheck.online)
      ? t('qs.recitationPlaybackFailed')
      : t('qs.recitationNeedsInternet');

  // Per-surah reciters (mp3quran.net): one MP3 for the whole surah.
  // Ayah highlighting is unavailable; _playingAyah stays null.
  Future<void> _playPerSurah({required dynamic surah}) async {
    final mine = '${_reciter.id}:${surah.number}';
    try {
      if (!AppAudio.ownsCurrent(mine)) {
        await _player.stop();
        await _player.setAudioSource(
          AudioSource.uri(
            await RecitationDownloads.sourceFor(
              reciter: _reciter,
              surah: surah.number,
            ),
            tag: MediaItem(
              id: mine,
              title: surah.name,
              artist: _reciter.displayName,
              album: t('qs.quranTitle'),
            ),
          ),
        );
      }
      setState(() => _playingAyah = null);
      await PlaybackSpeed.apply();
      await _player.play();
    } catch (_) {
      if (!mounted) return;
      setState(() => _audioFailed = true);
      _toast(await _playbackFailureMessage());
    }
  }

  Future<void> _pause() async {
    await _player.pause();
    if (mounted) setState(() {});
  }

  Future<void> _pickReciter() async {
    final chosen = await showModalBottomSheet<Reciter>(
      context: context,
      backgroundColor: AppColors.blackCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.55,
          minChildSize: 0.35,
          maxChildSize: 0.85,
          builder: (ctx, scroll) => Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  t('playback.pickReciter'),
                  style: const TextStyle(
                    color: AppColors.gold,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Expanded(
                child: ListView(
                  controller: scroll,
                  children: [
                    for (final r in RecitationService.reciters)
                      ListTile(
                        title: Text(
                          r.displayName,
                          style: const TextStyle(color: AppColors.textPrimary),
                        ),
                        trailing: r.id == _reciter.id
                            ? const Icon(Icons.check, color: AppColors.gold)
                            : null,
                        onTap: () => Navigator.pop(ctx, r),
                      ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (chosen == null || chosen.id == _reciter.id) return;
    await RecitationService.setReciter(chosen.id);
    await _player.stop();
    // Drop the old playlist so the new reciter's audio is used.
    await _player.setAudioSources([]);
    if (!mounted) return;
    setState(() {
      _reciter = chosen;
      _playingAyah = null;
    });
  }

  /// Stops playback and clears the highlight.
  Future<void> _stop() async {
    await _player.stop();
    if (mounted) setState(() => _playingAyah = null);
  }

  Widget _ayahAction({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool active = false,
  }) {
    final tint = active ? AppColors.gold : AppColors.textMuted;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: active ? AppColors.goldMuted : AppColors.blackSurface,
            borderRadius: BorderRadius.circular(8),
            border: active ? Border.all(color: AppColors.goldBorder) : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: tint, size: 14),
              const SizedBox(width: 5),
              Text(label, style: TextStyle(color: tint, fontSize: 11)),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showTafsir(Ayah a) async {
    Map<int, String> tafsir;
    try {
      tafsir = await TafsirService.forSurah(widget.info.number);
    } catch (_) {
      if (mounted) _toast(t('qs.tafsirOpenFailed'));
      return;
    }
    if (!mounted) return;

    final text = tafsir[a.number];
    await showModalBottomSheet<void>(
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
          initialChildSize: 0.6,
          minChildSize: 0.3,
          maxChildSize: 0.92,
          builder: (ctx, scrollController) => Column(
            children: [
              // Grab handle
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.textMuted,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Text(
                '${TafsirService.name} — ${t('qs.ayahWord')} ${QuranService.toArabicDigits(a.number)}',
                style: const TextStyle(
                  color: AppColors.gold,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              const Divider(color: AppColors.goldBorder, height: 1),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(18, 16, 18, 24),
                  children: [
                    // The ayah itself, for context
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.navy,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.goldBorder),
                      ),
                      child: Text(
                        a.text,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: _mushafFont,
                          color: AppColors.textGold,
                          fontSize: _fontSize * 0.85,
                          height: 2.0,
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      text ?? t('qs.noTafsirAvailable'),
                      textAlign: TextAlign.justify,
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: _fontSize * 0.62,
                        height: 1.9,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      TafsirService.publisher,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, textDirection: TextDirection.rtl),
        backgroundColor: AppColors.error,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _copyAyah(Ayah a) async {
    await Clipboard.setData(
      ClipboardData(
        text:
            '${a.text}\n\n[${t('qs.surahPrefix')} ${widget.info.name} — ${t('qs.ayahWord')} ${a.number}]',
      ),
    );
    if (!mounted) return;
    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(t('qs.ayahCopied'), textDirection: TextDirection.rtl),
        backgroundColor: AppColors.emerald,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final info = widget.info;
    final surah = _surah;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.black,
        appBar: AppBar(
          title: Text('${t('qs.surahPrefix')} ${info.name}'),
          backgroundColor: AppColors.black,
          foregroundColor: AppColors.gold,
          actions: [
            IconButton(
              icon: const Icon(Icons.record_voice_over, size: 20),
              onPressed: _pickReciter,
              tooltip: t('playback.pickReciter'),
            ),
            IconButton(
              icon: const Icon(Icons.text_decrease, size: 20),
              onPressed: () => _adjustFont(-2),
              tooltip: t('playback.decreaseFont'),
            ),
            IconButton(
              icon: const Icon(Icons.text_increase, size: 20),
              onPressed: () => _adjustFont(2),
              tooltip: t('playback.increaseFont'),
            ),
          ],
        ),
        body: surah == null
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.gold),
              )
            : Column(
                children: [
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
                      // +1 for the surah header
                      itemCount: surah.ayahs.length + 1,
                      itemBuilder: (context, i) {
                        if (i == 0) return _header(info);
                        return _ayahTile(surah.ayahs[i - 1]);
                      },
                    ),
                  ),
                  _playerBar(),
                ],
              ),
      ),
    );
  }

  Widget _playerBar() {
    return StreamBuilder<PlayerState>(
      stream: _player.playerStateStream,
      builder: (context, snapshot) {
        final state = snapshot.data;
        // Playing *this* surah, not merely playing: otherwise the bar offers
        // to pause a broadcast it does not own, under this reciter's name.
        final playing =
            (state?.playing ?? false) &&
            AppAudio.ownsCurrent('${_reciter.id}:');
        final loading =
            state?.processingState == ProcessingState.loading ||
            state?.processingState == ProcessingState.buffering;

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: const BoxDecoration(
            color: AppColors.blackCard,
            border: Border(top: BorderSide(color: AppColors.goldBorder)),
          ),
          child: Row(
            children: [
              GestureDetector(
                onTap: _pickReciter,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      t('qs.reciterLabel'),
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 10,
                      ),
                    ),
                    Text(
                      _reciter.displayName,
                      style: const TextStyle(
                        color: AppColors.textGold,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              const SpeedButton(showLabel: false),
              if (_audioFailed)
                const Padding(
                  padding: EdgeInsets.only(left: 8),
                  child: Icon(Icons.wifi_off, color: AppColors.error, size: 18),
                ),
              if (_playingAyah != null)
                Padding(
                  padding: const EdgeInsets.only(left: 10),
                  child: Text(
                    '${t('qs.ayahWord')} ${QuranService.toArabicDigits(_playingAyah!)}',
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 12,
                    ),
                  ),
                ),
              IconButton(
                icon: loading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.gold,
                        ),
                      )
                    : Icon(
                        playing
                            ? Icons.pause_circle_filled
                            : Icons.play_circle_fill,
                        color: AppColors.gold,
                        size: 40,
                      ),
                onPressed: loading
                    ? null
                    : () => playing
                          ? _pause()
                          : _play(fromAyah: _playingAyah ?? 1),
                tooltip: playing ? t('qs.stopLabel') : t('qs.playSurahLabel'),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _header(SurahInfo info) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.navyLight, AppColors.navy],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.goldBorder),
      ),
      child: Column(
        children: [
          Text(
            '${t('qs.surahPrefix')} ${info.name}',
            style: const TextStyle(
              color: AppColors.gold,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${info.type} • ${info.ayahCount} ${t('qs.ayahUnit')}',
            style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
          ),
          if (info.hasBasmala) ...[
            const SizedBox(height: 14),
            const Divider(
              color: AppColors.goldBorder,
              height: 1,
              indent: 30,
              endIndent: 30,
            ),
            const SizedBox(height: 14),
            Text(
              QuranService.basmala,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: _mushafFont,
                color: AppColors.textGold,
                fontSize: _fontSize * 0.92,
                height: 1.9,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _ayahTile(Ayah a) {
    final isPlaying = _playingAyah == a.number;
    final key = _itemKeys.putIfAbsent(a.number, GlobalKey.new);

    return GestureDetector(
      key: key,
      onLongPress: () => _copyAyah(a),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: isPlaying ? AppColors.navyLight : AppColors.blackCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isPlaying
                ? AppColors.gold
                : a.isSajda
                ? AppColors.emerald
                : AppColors.goldBorder,
            width: isPlaying ? 1.5 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Ayah text with the number ornament trailing it
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(text: a.text),
                  const TextSpan(text: '  '),
                  TextSpan(
                    text: '﴿${QuranService.toArabicDigits(a.number)}﴾',
                    style: TextStyle(
                      color: AppColors.gold,
                      fontSize: _fontSize * 0.7,
                    ),
                  ),
                ],
              ),
              textAlign: TextAlign.justify,
              style: TextStyle(
                fontFamily: _mushafFont,
                color: AppColors.textPrimary,
                fontSize: _fontSize,
                height: 2.1,
              ),
            ),
            if (a.isSajda) ...[
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.star,
                    color: AppColors.emeraldLight,
                    size: 13,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    t('qs.sajdaPosition'),
                    style: TextStyle(
                      color: AppColors.emeraldLight,
                      fontSize: _fontSize * 0.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],

            const SizedBox(height: 6),
            Row(
              children: [
                _ayahAction(
                  icon: Icons.menu_book,
                  label: t('qs.tafsirLabel'),
                  onTap: () => _showTafsir(a),
                ),
                const SizedBox(width: 6),
                // The same button stops what it started — there was no other
                // way to silence a verse once it began.
                _ayahAction(
                  icon: isPlaying ? Icons.stop : Icons.play_arrow,
                  label: isPlaying ? t('qs.stopLabel') : t('qs.listenLabel'),
                  active: isPlaying,
                  onTap: () => isPlaying ? _stop() : _play(fromAyah: a.number),
                ),
                const SizedBox(width: 6),
                _ayahAction(
                  icon: Icons.copy,
                  label: t('qs.copyLabel'),
                  onTap: () => _copyAyah(a),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
