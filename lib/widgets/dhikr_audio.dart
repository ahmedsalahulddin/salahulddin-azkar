import 'dart:async';

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import '../constants/theme.dart';
import '../l10n/strings.dart';
import '../services/app_audio.dart';
import '../services/playback_speed.dart';
import '../data/hisn_data.dart';

/// Plays the published recitations for a list of adhkar.
///
/// One player is shared across a screen so that starting one dhikr stops the
/// previous — two supplications talking over each other is worse than none.
class DhikrAudioController extends ChangeNotifier {
  final _player = AppAudio.player;

  StreamSubscription<PlayerState>? _stateSub;

  /// Which dhikr is sounding, by its recitation id.
  ///
  /// Not by [HisnDhikr.number], which is the item's place *within its
  /// chapter* — and every one of the 132 chapters starts at 1. That was fine
  /// while only the chapter screen used this, since numbers are unique inside
  /// one chapter. It stopped being fine the moment a screen put several
  /// chapters in front of the reader at once: the Umrah stages, where every
  /// chapter holds a single dhikr numbered 1, and the favourites tab, which
  /// gathers adhkar from wherever they were starred. The recitation id is
  /// unique across the whole book.
  int? _playingAudioId;
  bool _failed = false;

  /// Whether this controller has been thrown away.
  ///
  /// Every method here that reaches the player is async, and the reader is
  /// under no obligation to wait: tapping listen and going straight back
  /// leaves a request in flight against a controller that no longer exists.
  /// Whatever it does when it lands must not be to notify.
  bool _disposed = false;

  /// notifyListeners, unless there is no longer anyone to notify.
  void _tell() {
    if (_disposed) return;
    notifyListeners();
  }

  int? get playingAudioId => _playingAudioId;
  bool get failed => _failed;

  DhikrAudioController() {
    // A phone with no working audio still has to be able to open the chapter
    // and read it. Failing here would take the whole screen down over a
    // listener whose only job is to un-light a button.
    try {
      _watch();
    } catch (_) {
      // No player to follow; the text is the point.
    }
  }

  void _watch() {
    _stateSub = _player.playerStateStream.listen((state) {
      if (_playingAudioId == null) return;
      // Finished, or another screen took the shared player: either way this
      // controller is no longer the one sounding.
      final mine = AppAudio.ownsCurrent('hisn:');
      if (!mine || state.processingState == ProcessingState.completed) {
        _playingAudioId = null;
        _tell();
      }
    });
  }

  bool isPlaying(HisnDhikr dhikr) =>
      dhikr.audioId != null && _playingAudioId == dhikr.audioId;

  Future<void> toggle(HisnDhikr dhikr) async {
    final url = dhikr.audioUrl;
    if (url == null) return;

    if (_playingAudioId == dhikr.audioId) {
      await _player.pause();
      _playingAudioId = null;
      _tell();
      return;
    }

    _failed = false;
    _playingAudioId = dhikr.audioId;
    _tell();

    try {
      await _player.stop();
      await _player.setAudioSource(
        AudioSource.uri(
          Uri.parse(url),
          tag: MediaItem(
            id: 'hisn:${dhikr.audioId}',
            title: t(
              'adh.mediaItemTitleNumberedTemplate',
            ).replaceFirst('%s', '${dhikr.number}'),
            album: t('adh.mediaItemAlbum'),
          ),
        ),
      );
      await PlaybackSpeed.apply();
      await _player.play();
    } catch (_) {
      _failed = true;
      _playingAudioId = null;
      _tell();
    }
  }

  Future<void> stop() async {
    await _player.stop();
    _playingAudioId = null;
    _tell();
  }

  /// Stands in for the engine, which has no sound in a test.
  @visibleForTesting
  void debugSetPlaying(int? audioId) {
    _playingAudioId = audioId;
    _tell();
  }

  @override
  void dispose() {
    // Cancel before anything else. The player outlives this controller — it is
    // the app's single shared one — so a subscription left attached goes on
    // firing into a disposed notifier, which throws in debug and leaks for the
    // rest of the run in release. Every screen that shows a dhikr builds one
    // of these, so that is a subscription per visit.
    _disposed = true;
    _stateSub?.cancel();
    _stateSub = null;
    _player.stop();
    super.dispose();
  }
}

/// Listen button for one dhikr. Renders nothing when the source ships no
/// recitation for it, rather than a button that would do nothing.
class DhikrListenButton extends StatelessWidget {
  final HisnDhikr dhikr;
  final DhikrAudioController controller;

  const DhikrListenButton({
    super.key,
    required this.dhikr,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    if (!dhikr.hasAudio) return const SizedBox.shrink();

    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final playing = controller.isPlaying(dhikr);
        return GestureDetector(
          onTap: () => controller.toggle(dhikr),
          behavior: HitTestBehavior.opaque,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: playing ? AppColors.goldMuted : Colors.transparent,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: playing ? AppColors.gold : AppColors.goldBorder,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  playing ? Icons.pause : Icons.volume_up,
                  size: 14,
                  color: playing ? AppColors.gold : AppColors.textMuted,
                ),
                const SizedBox(width: 5),
                Text(
                  playing ? t('adh.pauseLabel') : t('adh.listenLabel'),
                  style: TextStyle(
                    color: playing ? AppColors.gold : AppColors.textMuted,
                    fontSize: 11,
                    fontWeight: playing ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
