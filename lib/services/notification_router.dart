import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../data/adhkar_data.dart';
import '../data/quran_data.dart';
import '../screens/category_screen.dart';
import '../screens/deceased_screen.dart';
import '../screens/mushaf_screen.dart';
import 'adhan_downloads.dart';

/// Opens what a tapped notification points at. The payload is the reminder's
/// own ("surah:18", "adhkar:morning"); anything else is ignored, so older
/// notifications without one still just open the app.
class NotificationRouter {
  NotificationRouter._();

  /// Given to MaterialApp, so a tap can navigate from outside any widget.
  static final navigatorKey = GlobalKey<NavigatorState>();

  /// A tap that launched the app, held until the first screen is up.
  static String? _pending;

  static void open(String? payload) {
    if (payload == null || payload.isEmpty) return;
    final nav = navigatorKey.currentState;
    if (nav == null) {
      _pending = payload;
      return;
    }
    _go(nav, payload);
  }

  /// Called once the home screen exists. True when a tapped reminder was
  /// waiting and is now being opened.
  static bool flushPending() {
    final p = _pending;
    _pending = null;
    if (p != null) open(p);
    return p != null;
  }

  static Future<void> _go(NavigatorState nav, String payload) async {
    final i = payload.indexOf(':');
    if (i == -1) return;
    final kind = payload.substring(0, i);
    final value = payload.substring(i + 1);
    switch (kind) {
      case 'surah':
        final surah = int.tryParse(value);
        if (surah == null || surah < 1 || surah > 114) return;
        final page = await QuranService.pageOfSurah(surah);
        nav.push(
          MaterialPageRoute(builder: (_) => MushafScreen(initialPage: page)),
        );
      case 'prayer':
        // "<ms>:adhan" — the call to prayer itself, with its sound. iOS
        // played only its first 30 seconds, so the whole adhan follows when
        // the tap comes while it is still the time of the call.
        final parts = value.split(':');
        final ms = int.tryParse(parts.first);
        if (ms == null || !parts.contains('adhan')) return;
        if (defaultTargetPlatform != TargetPlatform.iOS) return;
        final late = DateTime.now().millisecondsSinceEpoch - ms;
        if (late < -60000 || late > 15 * 60000) return;
        await AdhanDownloads.playFull();
      case 'adhkar':
        final cat = categories.where((c) => c.id == value).firstOrNull;
        if (cat == null) return;
        nav.push(
          MaterialPageRoute(
            builder: (_) => cat.id == 'deceased'
                ? const DeceasedScreen()
                : CategoryScreen(category: cat),
          ),
        );
    }
  }
}
