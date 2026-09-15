import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/quran_data.dart';
import 'app_audio.dart';
import 'playback_speed.dart';
import 'recitation_service.dart';

/// Recitation that does not stop at the end of a surah.
///
/// The other players in the app are for reading along: they run to the end of
/// what is on the page and stop. This one is for listening — in the car, while
/// working, falling asleep — so when a surah ends the next one begins, and the
/// Mushaf plays through to An-Nas and starts again at Al-Fatiha.
///
/// Where the listener reached is remembered, which is the whole point of
/// coming back: the reader who left off at Yusuf resumes at Yusuf, not at the
/// beginning.
///
/// The playlist is laid down one surah at a time rather than all 6,236 ayat at
/// once: a playlist that long takes seconds to build, holds far more in memory
/// than a phone should give a background player, and would have to be rebuilt
/// from scratch every time the listener jumps.
class ContinuousListening {
  ContinuousListening._();

  static const _surahKey = '@noor_listen_surah';
  static const _ayahKey = '@noor_listen_ayah';

  /// Distinguishes this playlist from the ones the Mushaf and the surah screen
  /// load, which are tagged with the reciter's own id.
  static const owner = 'listen:';

  static final surah = ValueNotifier<int>(1);
  static final ayah = ValueNotifier<int>(1);

  /// True while this screen's playlist is the one loaded, whether or not it is
  /// sounding — the buttons belong to it either way.
  static final active = ValueNotifier<bool>(false);

  static final reciter = ValueNotifier<Reciter>(RecitationService.defaultReciter);

  static List<SurahInfo> _index = const [];
  static bool _wired = false;
  static StreamSubscription<int?>? _indexSub;
  static StreamSubscription<PlayerState>? _stateSub;

  /// The surah whose playlist is currently loaded. Set to 0 while a new
  /// playlist is being loaded so that stale currentIndexStream events from the
  /// previous surah are ignored rather than overwriting ayah.value.
  static int _loadedSurah = 0;

  /// Guards against the completion handler firing while the next surah is
  /// still being loaded, which would skip a surah for every ayah left in the
  /// stream's queue.
  static bool _advancing = false;

  static SurahInfo? infoFor(int number) =>
      _index.where((s) => s.number == number).firstOrNull;

  static String nameFor(int number) => infoFor(number)?.name ?? '';

  static Future<void> load() async {
    _index = await QuranService.index();
    reciter.value = await RecitationService.getReciter();
    try {
      final prefs = await SharedPreferences.getInstance();
      final at = prefs.getInt(_surahKey) ?? 1;
      surah.value = at.clamp(1, 114);
      // An ayah beyond the surah — a store written by an older build, or a
      // surah that changed hands — starts the surah rather than failing.
      final count = infoFor(surah.value)?.ayahCount ?? 1;
      ayah.value = (prefs.getInt(_ayahKey) ?? 1).clamp(1, count);
    } catch (_) {
      // Al-Fatiha from its first ayah is a safe place to begin.
    }
  }

  static Future<void> _remember() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_surahKey, surah.value);
      await prefs.setInt(_ayahKey, ayah.value);
    } catch (_) {
      // The position still holds for this session.
    }
  }

  static Future<void> setReciter(Reciter chosen) async {
    reciter.value = chosen;
    await RecitationService.setReciter(chosen.id);
    // Reload in the new voice from where the listener is, rather than making
    // them find their place again.
    if (active.value) await play(surah.value, fromAyah: ayah.value);
  }

  /// Loads [number] and plays it, continuing into what follows.
  static Future<void> play(int number, {int fromAyah = 1}) async {
    final info = infoFor(number);
    if (info == null) return;

    _wire();
    surah.value = number;
    await _remember();

    if (reciter.value.isPerAyah) {
      await _playPerAyah(number: number, info: info, fromAyah: fromAyah);
    } else {
      await _playPerSurah(number: number, info: info);
    }
  }

  static Future<void> _playPerAyah({
    required int number,
    required SurahInfo info,
    required int fromAyah,
  }) async {
    // Capture the start index as a local variable BEFORE any awaits.
    // _indexSub can fire during AppAudio.player.stop() and overwrite
    // ayah.value with a stale index from the old surah; reading ayah.value
    // again at the setAudioSources call would then start the new surah at
    // the wrong ayah. The local variable is immune to that race.
    final startIndex = fromAyah.clamp(1, info.ayahCount) - 1;
    ayah.value = startIndex + 1;
    await _remember();
    try {
      _loadedSurah = 0;
      await AppAudio.player.stop();
      await AppAudio.player.setAudioSources(
        [
          for (var n = 1; n <= info.ayahCount; n++)
            AudioSource.uri(
              Uri.parse(RecitationService.urlFor(
                reciterId: reciter.value.id,
                surah: number,
                ayah: n,
              )),
              tag: MediaItem(
                id: '$owner$number:$n',
                title:
                    '${info.name} — الآية ${QuranService.toArabicDigits(n)}',
                artist: reciter.value.name,
                album: 'الاستماع الدائم',
              ),
            ),
        ],
        initialIndex: startIndex,
      );
      // just_audio_background sometimes settles on index 0 for a moment after
      // setAudioSources before honouring initialIndex — the background
      // session's own restore can race the one just requested. An explicit
      // seek forces the position rather than trusting that race, and without
      // it a jump to any ayah but the first would silently reopen at ayah 1.
      if (startIndex != 0) {
        await AppAudio.player.seek(Duration.zero, index: startIndex);
      }
      _loadedSurah = number;
      // Only now. Claiming it before the playlist is loaded left a window —
      // across the awaits above — where the listener saw the previous owner's
      // tag still on the player (the Mushaf's, the radio's, or none at all on
      // a first run), read that as "somebody else took it", and switched this
      // off again. The first surah still played, and then nothing followed it,
      // which is the one thing this file exists to prevent.
      active.value = true;
      await PlaybackSpeed.apply();
      await AppAudio.player.play();
    } catch (_) {
      active.value = false;
    }
  }

  // Per-surah reciters (mp3quran.net): one file per surah.
  // Ayah tracking is unavailable; the completion handler still advances.
  static Future<void> _playPerSurah({
    required int number,
    required SurahInfo info,
  }) async {
    final url = RecitationService.surahUrlFor(reciter: reciter.value, surah: number);
    if (url == null) { active.value = false; return; }
    ayah.value = 1;
    await _remember();
    try {
      _loadedSurah = 0;
      await AppAudio.player.stop();
      await AppAudio.player.setAudioSource(
        AudioSource.uri(
          Uri.parse(url),
          tag: MediaItem(
            id: '$owner$number:1',
            title: info.name,
            artist: reciter.value.name,
            album: 'الاستماع الدائم',
          ),
        ),
      );
      _loadedSurah = number;
      active.value = true;
      await PlaybackSpeed.apply();
      await AppAudio.player.play();
    } catch (_) {
      active.value = false;
    }
  }

  /// Al-Fatiha follows An-Nas: the Mushaf is read in a circle, not to an end.
  static int nextSurah(int number) => number >= 114 ? 1 : number + 1;

  static int previousSurah(int number) => number <= 1 ? 114 : number - 1;

  static Future<void> skipNext() => play(nextSurah(surah.value));

  static Future<void> skipPrevious() => play(previousSurah(surah.value));

  static Future<void> skipNextAyah() async {
    if (!reciter.value.isPerAyah) return;
    if (!AppAudio.ownsCurrent(owner)) return;
    final info = infoFor(surah.value);
    if (info == null) return;
    if (ayah.value >= info.ayahCount) {
      await play(nextSurah(surah.value));
    } else {
      // seek to the start of the next ayah (index = current 0-based index + 1)
      await AppAudio.player.seek(Duration.zero, index: ayah.value);
    }
  }

  static Future<void> skipPreviousAyah() async {
    if (!reciter.value.isPerAyah) return;
    if (!AppAudio.ownsCurrent(owner)) return;
    if (ayah.value <= 1) {
      await play(previousSurah(surah.value));
    } else {
      await AppAudio.player.seek(Duration.zero, index: ayah.value - 2);
    }
  }

  static Future<void> toggle() async {
    if (!active.value || !AppAudio.ownsCurrent(owner)) {
      await play(surah.value, fromAyah: ayah.value);
      return;
    }
    if (AppAudio.player.playing) {
      await AppAudio.player.pause();
    } else {
      await AppAudio.player.play();
    }
  }

  static Future<void> stop() async {
    active.value = false;
    await AppAudio.player.stop();
  }

  /// Attached once. Another screen taking the shared player simply clears the
  /// flag; nothing here fights it for the sound.
  static void _wire() {
    if (_wired) return;
    _wired = true;

    _indexSub = AppAudio.player.currentIndexStream.listen((i) {
      if (i == null || !AppAudio.ownsCurrent(owner)) return;
      if (surah.value != _loadedSurah) return;
      ayah.value = i + 1;
      _remember();
    });

    _stateSub = AppAudio.player.playerStateStream.listen((state) async {
      if (!active.value) return;
      if (!AppAudio.ownsCurrent(owner)) {
        active.value = false;
        return;
      }
      if (state.processingState != ProcessingState.completed) return;
      if (_advancing) return;

      _advancing = true;
      try {
        await play(nextSurah(surah.value));
      } finally {
        _advancing = false;
      }
    });
  }

  @visibleForTesting
  static Future<void> debugReset() async {
    await _indexSub?.cancel();
    await _stateSub?.cancel();
    _indexSub = null;
    _stateSub = null;
    _wired = false;
    _advancing = false;
    _loadedSurah = 0;
    active.value = false;
    surah.value = 1;
    ayah.value = 1;
    _index = const [];
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
