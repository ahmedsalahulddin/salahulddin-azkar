import 'package:shared_preferences/shared_preferences.dart';
import 'app_locale.dart';

class Reciter {
  final String id;
  final String name;
  final String nameEn;

  /// Non-null for reciters hosted on mp3quran.net.
  /// Format: 'serverN/slug', e.g. 'server11/hawashi'.
  /// These serve one MP3 per surah rather than one per ayah, so playback
  /// works differently: a single file is loaded and the player seeks within
  /// it rather than stepping through a playlist of ayahs.
  final String? mp3quranPath;

  const Reciter({
    required this.id,
    required this.name,
    required this.nameEn,
    this.mp3quranPath,
  });

  bool get isPerAyah => mp3quranPath == null;

  /// What the reader actually sees — the one to use in UI text.
  String get displayName => AppLocale.isEn ? nameEn : name;
}

/// Recitation streamed through audio.salahulddin.com, which proxies both
/// everyayah.com (per-ayah) and mp3quran.net (per-surah) with CORS headers.
class RecitationService {
  static const _reciterKey = '@noor_reciter';

  static const reciters = <Reciter>[
    Reciter(
      id: 'Husary_128kbps',
      name: 'محمود خليل الحصري',
      nameEn: 'Mahmoud Khalil Al-Husary',
    ),
    Reciter(
      id: 'Minshawy_Murattal_128kbps',
      name: 'محمد صديق المنشاوي',
      nameEn: 'Muhammad Siddiq Al-Minshawi',
    ),
    Reciter(
      id: 'Abdul_Basit_Murattal_192kbps',
      name: 'عبد الباسط عبد الصمد',
      nameEn: 'Abdul Basit Abdul Samad',
    ),
    Reciter(
      id: 'Alafasy_128kbps',
      name: 'مشاري العفاسي',
      nameEn: 'Mishary Alafasy',
    ),
    Reciter(
      id: 'Abdurrahmaan_As-Sudais_192kbps',
      name: 'عبد الرحمن السديس',
      nameEn: 'Abdul Rahman Al-Sudais',
    ),
    Reciter(
      id: 'Saood_ash-Shuraym_128kbps',
      name: 'سعود الشريم',
      nameEn: 'Saud Al-Shuraim',
    ),
    Reciter(
      id: 'Ahmed_Neana_128kbps',
      name: 'أحمد نعينع',
      nameEn: 'Ahmed Neana',
    ),
    Reciter(
      id: 'Ahmed_ibn_Ali_al-Ajamy_128kbps_ketaballah.net',
      name: 'أحمد بن علي العجمي',
      nameEn: 'Ahmed ibn Ali Al-Ajamy',
    ),
    Reciter(
      id: 'hawashi',
      name: 'أحمد الحواشي',
      nameEn: 'Ahmed Al-Hawashi',
      mp3quranPath: 'server11/hawashi',
    ),
    Reciter(
      id: 'banna',
      name: 'محمود علي البنا',
      nameEn: 'Mahmoud Ali Al-Banna',
      mp3quranPath: 'server8/bna',
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
  static String? surahUrlFor({required Reciter reciter, required int surah}) {
    final path = reciter.mp3quranPath;
    if (path == null) return null;
    final s = surah.toString().padLeft(3, '0');
    return '$_proxy/mp3quran/$path/$s.mp3';
  }

  static Future<Reciter> getReciter() async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getString(_reciterKey);
    return reciters.firstWhere((r) => r.id == id, orElse: () => defaultReciter);
  }

  static Future<void> setReciter(String id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_reciterKey, id);
  }
}
