import 'package:shared_preferences/shared_preferences.dart';

class Reciter {
  /// Folder name on the CDN.
  final String id;
  final String name;

  const Reciter({required this.id, required this.name});
}

/// Per-ayah recitation streamed from everyayah.com.
///
/// That host is used rather than the other common mirrors because it is the
/// only one that returns `Access-Control-Allow-Origin: *` — without it the web
/// build cannot play anything — and it honours range requests for seeking.
class RecitationService {
  static const _reciterKey = '@noor_reciter';

  static const reciters = <Reciter>[
    Reciter(id: 'Husary_128kbps', name: 'محمود خليل الحصري'),
    Reciter(id: 'Minshawy_Murattal_128kbps', name: 'محمد صديق المنشاوي'),
    Reciter(id: 'Abdul_Basit_Murattal_192kbps', name: 'عبد الباسط عبد الصمد'),
    Reciter(id: 'Alafasy_128kbps', name: 'مشاري العفاسي'),
    Reciter(id: 'Abdurrahmaan_As-Sudais_192kbps', name: 'عبد الرحمن السديس'),
    Reciter(id: 'Saood_ash-Shuraym_128kbps', name: 'سعود الشريم'),
  ];

  static Reciter get defaultReciter => reciters.first;

  /// e.g. surah 2, ayah 255 becomes `.../data/{reciter}/002255.mp3`
  static String urlFor({
    required String reciterId,
    required int surah,
    required int ayah,
  }) {
    final s = surah.toString().padLeft(3, '0');
    final a = ayah.toString().padLeft(3, '0');
    return 'https://everyayah.com/data/$reciterId/$s$a.mp3';
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
