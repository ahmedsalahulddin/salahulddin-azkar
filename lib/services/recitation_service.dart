import 'package:shared_preferences/shared_preferences.dart';

class Reciter {
  final String id;
  final String name;

  /// Non-null for reciters hosted on mp3quran.net.
  /// Format: 'serverN/slug', e.g. 'server11/hawashi'.
  /// These serve one MP3 per surah rather than one per ayah, so playback
  /// works differently: a single file is loaded and the player seeks within
  /// it rather than stepping through a playlist of ayahs.
  final String? mp3quranPath;

  const Reciter({required this.id, required this.name, this.mp3quranPath});

  bool get isPerAyah => mp3quranPath == null;
}

/// Recitation streamed through audio.salahulddin.com, which proxies both
/// everyayah.com (per-ayah) and mp3quran.net (per-surah) with CORS headers.
class RecitationService {
  static const _reciterKey = '@noor_reciter';

  static const reciters = <Reciter>[
    Reciter(id: 'Husary_128kbps',                              name: 'محمود خليل الحصري'),
    Reciter(id: 'Minshawy_Murattal_128kbps',                   name: 'محمد صديق المنشاوي'),
    Reciter(id: 'Abdul_Basit_Murattal_192kbps',                name: 'عبد الباسط عبد الصمد'),
    Reciter(id: 'Alafasy_128kbps',                             name: 'مشاري العفاسي'),
    Reciter(id: 'Abdurrahmaan_As-Sudais_192kbps',              name: 'عبد الرحمن السديس'),
    Reciter(id: 'Saood_ash-Shuraym_128kbps',                   name: 'سعود الشريم'),
    Reciter(id: 'Ahmed_Neana_128kbps',                         name: 'أحمد نعينع'),
    Reciter(id: 'Ahmed_ibn_Ali_al-Ajamy_128kbps_ketaballah.net', name: 'أحمد بن علي العجمي'),
    Reciter(
      id: 'hawashi',
      name: 'أحمد الحواشي',
      mp3quranPath: 'server11/hawashi',
    ),
  ];

  static Reciter get defaultReciter => reciters.first;

  static const _proxy = 'https://audioazkar.salahulddin.com';

  /// Per-ayah URL for everyayah.com reciters.
  /// e.g. surah 2, ayah 255 → `…/everyayah/{reciter}/002255.mp3`
  static String urlFor({
    required String reciterId,
    required int surah,
    required int ayah,
  }) {
    final s = surah.toString().padLeft(3, '0');
    final a = ayah.toString().padLeft(3, '0');
    return '$_proxy/everyayah/$reciterId/$s$a.mp3';
  }

  /// Per-surah URL for mp3quran.net reciters.
  /// Returns null for per-ayah reciters.
  static String? surahUrlFor({
    required Reciter reciter,
    required int surah,
  }) {
    final path = reciter.mp3quranPath;
    if (path == null) return null;
    final s = surah.toString().padLeft(3, '0');
    return '$_proxy/mp3quran/$path/$s.mp3';
  }

  static Future<Reciter> getReciter() async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getString(_reciterKey);
    return reciters.firstWhere(
      (r) => r.id == id,
      orElse: () => defaultReciter,
    );
  }

  static Future<void> setReciter(String id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_reciterKey, id);
  }
}
