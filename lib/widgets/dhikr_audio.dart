import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import '../constants/theme.dart';
import '../data/hisn_data.dart';

/// Plays the published recitations for a list of adhkar.
///
/// One player is shared across a screen so that starting one dhikr stops the
/// previous — two supplications talking over each other is worse than none.
class DhikrAudioController extends ChangeNotifier {
  final _player = AudioPlayer();

  int? _playingNumber;
  bool _failed = false;

  /// Which dhikr is sounding, by its number within the chapter.
  int? get playingNumber => _playingNumber;
  bool get failed => _failed;

  DhikrAudioController() {
    _player.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed) {
        _playingNumber = null;
        notifyListeners();
      }
    });
  }

  bool isPlaying(HisnDhikr dhikr) => _playingNumber == dhikr.number;

  Future<void> toggle(HisnDhikr dhikr) async {
    final url = dhikr.audioUrl;
    if (url == null) return;

    if (_playingNumber == dhikr.number) {
      await _player.pause();
      _playingNumber = null;
      notifyListeners();
      return;
    }

    _failed = false;
    _playingNumber = dhikr.number;
    notifyListeners();

    try {
      await _player.setUrl(url);
      await _player.play();
    } catch (_) {
      _failed = true;
      _playingNumber = null;
      notifyListeners();
    }
  }

  Future<void> stop() async {
    await _player.stop();
    _playingNumber = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _player.dispose();
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
                  playing ? 'إيقاف' : 'استمع',
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
