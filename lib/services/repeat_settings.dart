import 'package:shared_preferences/shared_preferences.dart';

/// How a passage is repeated while memorising.
///
/// Two counters stack: each ayah is heard [perAyah] times before the recitation
/// moves on, and the whole selected range is then replayed [wholeRange] times.
/// That mirrors how memorisation is actually done — drill a verse, then join it
/// back to its neighbours.
class RepeatSettings {
  /// Times each ayah is repeated before advancing. 1 means no repetition.
  final int perAyah;

  /// Times the whole range is replayed. 1 means play it once.
  final int wholeRange;

  /// How many ayahs the range covers, starting at the selected one.
  final int rangeLength;

  /// Pause between repeats, giving time to say the verse back.
  final Duration gap;

  const RepeatSettings({
    this.perAyah = 1,
    this.wholeRange = 1,
    this.rangeLength = 1,
    this.gap = Duration.zero,
  });

  bool get isActive => perAyah > 1 || wholeRange > 1 || rangeLength > 1;

  /// The playback order for a range starting at [firstAyah], as ayah numbers.
  ///
  /// Capped at [lastAyahInSurah] so a range near the end of a surah stops there
  /// instead of running past it.
  List<int> playbackOrder(int firstAyah, int lastAyahInSurah) {
    final end = (firstAyah + rangeLength - 1).clamp(firstAyah, lastAyahInSurah);
    final order = <int>[];
    for (var pass = 0; pass < wholeRange; pass++) {
      for (var ayah = firstAyah; ayah <= end; ayah++) {
        for (var time = 0; time < perAyah; time++) {
          order.add(ayah);
        }
      }
    }
    return order;
  }

  RepeatSettings copyWith({
    int? perAyah,
    int? wholeRange,
    int? rangeLength,
    Duration? gap,
  }) =>
      RepeatSettings(
        perAyah: perAyah ?? this.perAyah,
        wholeRange: wholeRange ?? this.wholeRange,
        rangeLength: rangeLength ?? this.rangeLength,
        gap: gap ?? this.gap,
      );

  static const _perAyahKey = '@noor_repeat_per_ayah';
  static const _wholeKey = '@noor_repeat_whole';
  static const _rangeKey = '@noor_repeat_range';
  static const _gapKey = '@noor_repeat_gap';

  static Future<RepeatSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    return RepeatSettings(
      perAyah: prefs.getInt(_perAyahKey) ?? 1,
      wholeRange: prefs.getInt(_wholeKey) ?? 1,
      rangeLength: prefs.getInt(_rangeKey) ?? 1,
      gap: Duration(milliseconds: prefs.getInt(_gapKey) ?? 0),
    );
  }

  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_perAyahKey, perAyah);
    await prefs.setInt(_wholeKey, wholeRange);
    await prefs.setInt(_rangeKey, rangeLength);
    await prefs.setInt(_gapKey, gap.inMilliseconds);
  }
}
