import 'dart:convert';
import 'package:flutter/services.dart';

/// One of the 240 marks the Mushaf carries down its margin.
///
/// The Qur'an is divided into sixty ahzab, and each hizb into four. The
/// printed page marks every one of those quarters — the reader who recites a
/// fixed portion each day finds their place by them, not by the page number.
class HizbMark {
  /// 1..60.
  final int hizb;

  /// 0 for the hizb itself, then the quarter, the half, the three quarters.
  final int quarter;

  final int surah;
  final int ayah;

  const HizbMark({
    required this.hizb,
    required this.quarter,
    required this.surah,
    required this.ayah,
  });

  factory HizbMark.fromJson(Map<String, dynamic> j) => HizbMark(
        hizb: j['h'],
        quarter: j['q'],
        surah: j['s'],
        ayah: j['a'],
      );

  /// What the margin says: the hizb by number, or which part of it this is.
  String get label => switch (quarter) {
        0 => 'الحزب',
        1 => '¼',
        2 => '½',
        _ => '¾',
      };

  /// Spelled out, for the places with room for it.
  String get longLabel => switch (quarter) {
        0 => 'الحزب $hizb',
        1 => 'ربع الحزب $hizb',
        2 => 'نصف الحزب $hizb',
        _ => 'ثلاثة أرباع الحزب $hizb',
      };

  /// The hizb's own opening is the mark the eye should catch first.
  bool get startsHizb => quarter == 0;
}

class HizbService {
  static List<HizbMark>? _marks;

  /// All 240, in Mushaf order. Loaded once — the file is under seven
  /// kilobytes and every page turn asks for it.
  static Future<List<HizbMark>> all() async {
    final cached = _marks;
    if (cached != null) return cached;

    final raw = await rootBundle.loadString('assets/quran/hizb.json');
    return _marks = (jsonDecode(raw) as List)
        .map((e) => HizbMark.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// The marks that begin somewhere inside [runs] — the stretches of surah
  /// printed on one page. A page usually carries none; some carry two.
  static Future<List<HizbMark>> onPage(
      Iterable<({int surah, int first, int last})> runs) async {
    final marks = await all();
    return [
      for (final mark in marks)
        if (runs.any((r) =>
            r.surah == mark.surah &&
            mark.ayah >= r.first &&
            mark.ayah <= r.last))
          mark,
    ];
  }
}
