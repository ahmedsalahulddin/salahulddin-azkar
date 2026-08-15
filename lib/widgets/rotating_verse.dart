import 'dart:async';

import 'package:flutter/material.dart';

import '../constants/theme.dart';
import '../data/quran_data.dart';

/// The rotation itself, shared so the verse and its citation can live in two
/// different places — the verse under the sky panel, the citation inside it —
/// and still change together.
///
/// The text is read out of the bundled Mushaf by reference rather than typed
/// here. Arabic typed by hand does not reliably come back as the same code
/// points as the printed edition — the app has been bitten by that before —
/// and a verse on the home screen is the last place to be approximate.
class VerseRotation {
  /// Surah and ayah of each verse in the rotation.
  static const references = [
    (33, 41),
    (2, 152),
    (87, 15),
    (13, 28),
    (20, 14),
    (94, 5),
  ];

  static const interval = Duration(seconds: 9);

  /// The verse on show now, with its citation. Null until the bundle loads.
  static final current = ValueNotifier<(String text, String citation)?>(null);

  static List<(String, String)> _verses = const [];
  static int _index = 0;
  static Timer? _timer;

  /// Idempotent: the first caller starts the rotation, later calls join it.
  static Future<void> start() async {
    if (_timer != null || _verses.isNotEmpty) return;

    final index = await QuranService.index();
    final loaded = <(String, String)>[];
    for (final (surahNumber, ayahNumber) in references) {
      try {
        final surah = await QuranService.surah(surahNumber);
        final ayah = surah.ayahs.firstWhere((a) => a.number == ayahNumber);
        final name = index.firstWhere((s) => s.number == surahNumber).name;
        loaded.add((
          ayah.text,
          '$name: ${QuranService.toArabicDigits(ayahNumber)}',
        ));
      } catch (_) {
        // Skip a verse we cannot read rather than showing a placeholder.
      }
    }
    if (loaded.isEmpty) return;

    _verses = loaded;
    current.value = loaded.first;
    _timer = Timer.periodic(interval, (_) {
      _index = (_index + 1) % _verses.length;
      current.value = _verses[_index];
    });
  }
}

/// The verse alone. Its citation is [VerseCitation], shown elsewhere.
class RotatingVerse extends StatefulWidget {
  /// Set when the verse floats in the sky panel, where the room is tighter
  /// than under it.
  final bool dense;

  const RotatingVerse({super.key, this.dense = false});

  @override
  State<RotatingVerse> createState() => _RotatingVerseState();
}

class _RotatingVerseState extends State<RotatingVerse> {
  @override
  void initState() {
    super.initState();
    VerseRotation.start();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<(String, String)?>(
      valueListenable: VerseRotation.current,
      builder: (context, verse, _) {
        if (verse == null) return const SizedBox.shrink();
        final text = Text(
          verse.$1,
          key: ValueKey(verse.$1),
          textAlign: TextAlign.center,
          maxLines: widget.dense ? 1 : 3,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontFamily: 'AmiriQuran',
            color: AppColors.textPrimary,
            fontSize: widget.dense ? 17 : 15,
            height: widget.dense ? 1.6 : 1.9,
          ),
        );
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 700),
          // One line always: a short verse shows at full size, a long one
          // scales down until it spans the panel instead of wrapping.
          child: widget.dense
              ? FittedBox(
                  key: ValueKey(verse.$1), fit: BoxFit.scaleDown, child: text)
              : text,
        );
      },
    );
  }
}

/// The surah and ayah of whatever [RotatingVerse] is showing, kept in step by
/// the shared rotation.
class VerseCitation extends StatelessWidget {
  const VerseCitation({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<(String, String)?>(
      valueListenable: VerseRotation.current,
      builder: (context, verse, _) {
        if (verse == null) return const SizedBox.shrink();
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 700),
          child: Text(
            verse.$2,
            key: ValueKey(verse.$2),
            style: const TextStyle(color: AppColors.textGold, fontSize: 10.5),
          ),
        );
      },
    );
  }
}
