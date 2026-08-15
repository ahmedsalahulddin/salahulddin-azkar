import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../constants/theme.dart';

/// Reads a passage aloud with the device's own Arabic voice.
///
/// This is for explanations, lessons and hadith — never for the Qur'an. A
/// synthetic voice cannot carry tajwīd, and the app already has real
/// recitations for every ayah; offering a robot instead would be a
/// disservice dressed as a feature.
class Tts {
  static final FlutterTts _tts = FlutterTts();

  /// Which speak button is talking now, so a second tap anywhere stops the
  /// first — two voices at once is noise.
  static final speaking = ValueNotifier<String?>(null);

  static bool _configured = false;

  static Future<void> _configure() async {
    if (_configured) return;
    await _tts.setLanguage('ar');
    await _tts.setSpeechRate(0.45);
    _tts.setCompletionHandler(() => speaking.value = null);
    _tts.setCancelHandler(() => speaking.value = null);
    _tts.setErrorHandler((_) => speaking.value = null);
    _configured = true;
  }

  static Future<void> toggle(String id, String text) async {
    await _configure();
    if (speaking.value == id) {
      await _tts.stop();
      speaking.value = null;
      return;
    }
    await _tts.stop();
    speaking.value = id;
    await _tts.speak(text);
  }

  static Future<void> stop() async {
    await _tts.stop();
    speaking.value = null;
  }
}

/// The small speaker that reads [text] aloud, lit while it is the one talking.
class SpeakButton extends StatelessWidget {
  /// Distinguishes this button from every other on screen.
  final String id;
  final String text;
  final double size;

  const SpeakButton(
      {super.key, required this.id, required this.text, this.size = 18});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String?>(
      valueListenable: Tts.speaking,
      builder: (context, speakingId, _) {
        final active = speakingId == id;
        return GestureDetector(
          onTap: () => Tts.toggle(id, text),
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: Icon(
              active ? Icons.stop_circle_outlined : Icons.volume_up_outlined,
              size: size,
              color: active ? AppColors.gold : AppColors.textMuted,
            ),
          ),
        );
      },
    );
  }
}
