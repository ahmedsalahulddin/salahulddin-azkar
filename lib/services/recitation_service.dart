import 'package:shared_preferences/shared_preferences.dart';
import 'app_locale.dart';

class Reciter {
  final String id;
  final String name;
  final String nameEn;

  /// The name in each of the app's 8 extra languages (fr, ur, id, ms, hi,
  /// tr, bn, ha), keyed by AppLocale code — kept separate from [name]/
  /// [nameEn] so every existing single-language call site (media-notification
  /// metadata, the compact "now playing" chip) is unaffected.
  final Map<String, String> otherNames;

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
    this.otherNames = const {},
    this.mp3quranPath,
  });

  bool get isPerAyah => mp3quranPath == null;

  /// What the reader actually sees — the one to use in UI text.
  String get displayName => AppLocale.isEn ? nameEn : name;

  /// The name in [code], falling back to English and then Arabic — same
  /// fallback order the rest of the app uses for its 8 extra languages.
  String nameFor(String code) {
    if (code == 'ar') return name;
    if (code == 'en') return nameEn;
    return otherNames[code] ?? nameEn;
  }

  /// Arabic name with the selected language's rendering alongside it — the
  /// same "Arabic (translated)" convention as tBoth(), for the reciter
  /// picker where there's room to show both.
  String get bilingualName {
    final code = AppLocale.code;
    if (code == 'ar') return name;
    final other = nameFor(code);
    return other == name ? name : '$name ($other)';
  }
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
      otherNames: {
        'fr': 'Mahmoud Khalil Al-Houssari',
        'ur': 'محمود خلیل الحصری',
        'id': 'Mahmoud Khalil Al-Hushary',
        'ms': 'Mahmoud Khalil Al-Husari',
        'hi': 'महमूद ख़लील अल-हुसरी',
        'tr': 'Mahmud Halil el-Husarî',
        'bn': 'মাহমুদ খলিল আল-হুসারি',
        'ha': 'Mahmud Khalil Al-Husary',
      },
    ),
    Reciter(
      id: 'Minshawy_Murattal_128kbps',
      name: 'محمد صديق المنشاوي',
      nameEn: 'Muhammad Siddiq Al-Minshawi',
      otherNames: {
        'fr': 'Mohamed Siddiq Al-Minshawi',
        'ur': 'محمد صدیق المنشاوی',
        'id': 'Muhammad Shiddiq Al-Minsyawi',
        'ms': 'Muhammad Siddiq Al-Minsyawi',
        'hi': 'मुहम्मद सिद्दीक़ अल-मिनशावी',
        'tr': 'Muhammed Sıddîk el-Minşâvî',
        'bn': 'মুহাম্মদ সিদ্দিক আল-মিনশাবি',
        'ha': 'Muhammad Sidiq Al-Minshawi',
      },
    ),
    Reciter(
      id: 'Abdul_Basit_Murattal_192kbps',
      name: 'عبد الباسط عبد الصمد',
      nameEn: 'Abdul Basit Abdul Samad',
      otherNames: {
        'fr': 'Abdoul Basit Abdou Samad',
        'ur': 'عبد الباسط عبد الصمد',
        'id': 'Abdul Basith Abdush Shomad',
        'ms': 'Abdul Basit Abdul Samad',
        'hi': 'अब्दुल बासित अब्दुस्समद',
        'tr': 'Abdulbâsıt Abdussamed',
        'bn': 'আবদুল বাসিত আবদুস সামাদ',
        'ha': 'Abdul Basit Abdus Samad',
      },
    ),
    Reciter(
      id: 'Alafasy_128kbps',
      name: 'مشاري العفاسي',
      nameEn: 'Mishary Alafasy',
      otherNames: {
        'fr': 'Mishary Al-Afassy',
        'ur': 'مشاری العفاسی',
        'id': 'Mishari Rasyid Al-Afasy',
        'ms': 'Mishary Al-Afasy',
        'hi': 'मिशारी अल-अफ़ासी',
        'tr': 'Meşârî el-Afâsî',
        'bn': 'মিশারি আল-আফাসি',
        'ha': 'Mishary Alfasy',
      },
    ),
    Reciter(
      id: 'Abdurrahmaan_As-Sudais_192kbps',
      name: 'عبد الرحمن السديس',
      nameEn: 'Abdul Rahman Al-Sudais',
      otherNames: {
        'fr': 'Abdel Rahman As-Sudais',
        'ur': 'عبد الرحمن السدیس',
        'id': 'Abdurrahman As-Sudais',
        'ms': 'Abdul Rahman As-Sudais',
        'hi': 'अब्दुर्रहमान अस-सुदैस',
        'tr': 'Abdurrahman es-Sudeys',
        'bn': 'আবদুর রহমান আস-সুদাইস',
        'ha': 'Abdurrahman Assudais',
      },
    ),
    Reciter(
      id: 'Saood_ash-Shuraym_128kbps',
      name: 'سعود الشريم',
      nameEn: 'Saud Al-Shuraim',
      otherNames: {
        'fr': 'Saoud Ash-Shuraim',
        'ur': 'سعود الشریم',
        'id': 'Saud Asy-Syuraim',
        'ms': 'Saud Asy-Syuraim',
        'hi': 'सऊद अश-शुरैम',
        'tr': 'Suud eş-Şuraym',
        'bn': 'সৌদ আশ-শুরাইম',
        'ha': "Sa'ud Ash-Shuraim",
      },
    ),
    Reciter(
      id: 'Ahmed_Neana_128kbps',
      name: 'أحمد نعينع',
      nameEn: 'Ahmed Neana',
      otherNames: {
        'fr': 'Ahmad Nouaïna',
        'ur': 'احمد نعینع',
        'id': "Ahmad Nu'aina",
        'ms': "Ahmad Nu'ainaa",
        'hi': 'अहमद नईना',
        'tr': 'Ahmed Nuayna',
        'bn': 'আহমদ নুয়াইনা',
        'ha': "Ahmad Nu'aina",
      },
    ),
    Reciter(
      id: 'Ahmed_ibn_Ali_al-Ajamy_128kbps_ketaballah.net',
      name: 'أحمد بن علي العجمي',
      nameEn: 'Ahmed ibn Ali Al-Ajamy',
      otherNames: {
        'fr': 'Ahmad ibn Ali Al-Ajami',
        'ur': 'احمد بن علی العجمی',
        'id': "Ahmad bin Ali Al-'Ajami",
        'ms': 'Ahmad bin Ali Al-Ajami',
        'hi': 'अहमद बिन अली अल-अजमी',
        'tr': 'Ahmed bin Ali el-Acemî',
        'bn': 'আহমদ বিন আলি আল-আজমি',
        'ha': 'Ahmad Dan Ali Al-Ajami',
      },
    ),
    Reciter(
      id: 'hawashi',
      name: 'أحمد الحواشي',
      nameEn: 'Ahmed Al-Hawashi',
      otherNames: {
        'fr': 'Ahmad Al-Hawashi',
        'ur': 'احمد الحواشی',
        'id': 'Ahmad Al-Hawasyi',
        'ms': 'Ahmad Al-Hawasyi',
        'hi': 'अहमद अल-हवाशी',
        'tr': 'Ahmed el-Havâşî',
        'bn': 'আহমদ আল-হাওয়াশি',
        'ha': 'Ahmad Al-Hawashi',
      },
      mp3quranPath: 'server11/hawashi',
    ),
    Reciter(
      id: 'banna',
      name: 'محمود علي البنا',
      nameEn: 'Mahmoud Ali Al-Banna',
      otherNames: {
        'fr': 'Mahmoud Ali Al-Banna',
        'ur': 'محمود علی البنا',
        'id': 'Mahmoud Ali Al-Banna',
        'ms': 'Mahmoud Ali Al-Banna',
        'hi': 'महमूद अली अल-बन्ना',
        'tr': 'Mahmud Ali el-Bennâ',
        'bn': 'মাহমুদ আলি আল-বান্না',
        'ha': 'Mahmud Ali Al-Banna',
      },
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
