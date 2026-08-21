import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../constants/theme.dart';
import '../services/playback_speed.dart';

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

  /// Every call into the engine goes through here.
  ///
  /// A phone with no Arabic voice installed — or none at all — throws on the
  /// first call, and this is reached from dispose(), where a throw takes the
  /// screen down with it. Silence is the right failure: the words are on the
  /// page either way.
  static Future<void> _ask(Future<void> Function() call) async {
    try {
      await call();
    } catch (_) {
      // No voice on this device.
    }
  }

  static Future<void> _configure() async {
    if (_configured) return;
    await _ask(() => _tts.setLanguage('ar'));
    _tts.setCompletionHandler(() => speaking.value = null);
    _tts.setCancelHandler(() => speaking.value = null);
    _tts.setErrorHandler((_) => speaking.value = null);
    _configured = true;
  }

  /// The reading pace is the app's one playback speed, applied before each
  /// passage: a voice already speaking cannot change its rate mid-sentence,
  /// and a reader who slowed the recitation meant the lessons too.
  static Future<void> toggle(String id, String text) async {
    // A single passage ends whatever run was going: two voices are noise.
    _run++;
    readingIndex.value = null;
    await _configure();
    // Some engines refuse a rate; they simply read at their own.
    await _ask(() => _tts.setSpeechRate(PlaybackSpeed.speechRate));
    if (speaking.value == id) {
      await _ask(_tts.stop);
      speaking.value = null;
      return;
    }
    await _ask(_tts.stop);
    speaking.value = id;
    await _ask(() => _tts.speak(text));
  }

  static Future<void> stop() async {
    _run++;
    readingIndex.value = null;
    await _ask(_tts.stop);
    speaking.value = null;
  }

  // ---- reading a list straight through -----------------------------------

  /// Which item of the current run is being read, or null when nothing is.
  static final readingIndex = ValueNotifier<int?>(null);

  /// How many items the current run holds, so a screen can say "3 of 20".
  static int total = 0;

  /// Bumped to abandon a run. The loop checks it after every passage, which
  /// is the only way to stop something that is already speaking without
  /// leaving the next passage queued behind it.
  static int _run = 0;

  /// Reads [texts] one after another, and nothing else.
  ///
  /// The recorded recitations name the chapter before the words — "دعاء
  /// الخروج من الخلاء" and then "غفرانك" — and say the short ones more than
  /// once. Read straight through a list of twenty that is mostly
  /// announcements. The device's voice reads the text and only the text, once
  /// each, which is what a reader going through their own list wants.
  static Future<void> readAll(List<String> texts) async {
    if (texts.isEmpty) return;
    await _configure();
    // Without this, speak() returns as soon as the words are handed over and
    // the whole list would be spoken at once, on top of itself.
    await _ask(() => _tts.awaitSpeakCompletion(true));

    final mine = ++_run;
    await _ask(_tts.stop);
    speaking.value = null;
    total = texts.length;

    for (var i = 0; i < texts.length; i++) {
      if (_run != mine) return;
      readingIndex.value = i;
      // A passage the engine refuses is skipped rather than ending the run.
      await _ask(() => _tts.setSpeechRate(PlaybackSpeed.speechRate));
      await _ask(() => _tts.speak(texts[i]));
    }
    if (_run == mine) readingIndex.value = null;
  }

  /// Moves to the next passage without ending the run: stopping the engine
  /// makes the waiting speak() return, and the loop carries on.
  static Future<void> skip() async {
    if (readingIndex.value == null) return;
    await _ask(_tts.stop);
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
