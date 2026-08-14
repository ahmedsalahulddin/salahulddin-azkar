import 'dart:async';

import 'package:flutter/material.dart';

import '../constants/theme.dart';
import '../data/quran_data.dart';

/// A verse under the arch, changing every so often.
///
/// The text is read out of the bundled Mushaf by reference rather than typed
/// here. Arabic typed by hand does not reliably come back as the same code
/// points as the printed edition — the app has been bitten by that before —
/// and a verse on the home screen is the last place to be approximate.
class RotatingVerse extends StatefulWidget {
  const RotatingVerse({super.key});

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

  @override
  State<RotatingVerse> createState() => _RotatingVerseState();
}

class _RotatingVerseState extends State<RotatingVerse> {
  List<(String text, String citation)> _verses = const [];
  int _index = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final index = await QuranService.index();
    final loaded = <(String, String)>[];

    for (final (surahNumber, ayahNumber) in RotatingVerse.references) {
      try {
        final surah = await QuranService.surah(surahNumber);
        final ayah =
            surah.ayahs.firstWhere((a) => a.number == ayahNumber);
        final name =
            index.firstWhere((s) => s.number == surahNumber).name;
        loaded.add((
          ayah.text,
          '$name: ${QuranService.toArabicDigits(ayahNumber)}',
        ));
      } catch (_) {
        // Skip a verse we cannot read rather than showing a placeholder.
      }
    }

    if (!mounted || loaded.isEmpty) return;
    setState(() => _verses = loaded);
    _timer = Timer.periodic(RotatingVerse.interval, (_) {
      if (mounted) setState(() => _index = (_index + 1) % _verses.length);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_verses.isEmpty) return const SizedBox.shrink();
    final (text, citation) = _verses[_index];

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 700),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        // Keyed by index so the switcher knows one verse from the next.
        key: ValueKey(_index),
        children: [
          Text(
            text,
            textAlign: TextAlign.center,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontFamily: 'AmiriQuran',
              color: AppColors.textPrimary,
              fontSize: 15,
              height: 1.9,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            citation,
            style: const TextStyle(color: AppColors.textGold, fontSize: 10.5),
          ),
        ],
      ),
    );
  }
}
