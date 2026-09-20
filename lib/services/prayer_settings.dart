import 'package:adhan/adhan.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// How the prayer times are worked out.
///
/// This is not a preference in the way a font size is. Each authority sets its
/// own twilight angles, so the same coordinates give genuinely different times
/// for Fajr and Isha — Umm al-Qura counts Isha as ninety minutes after Maghrib
/// whatever the season, while Egypt uses an angle. Picking Makkah's method for
/// a reader in Cairo does not shade the answer; it makes it wrong.
enum PrayerMethod {
  auto('auto', 'تلقائي حسب موقعك', 'يختار طريقة بلدك'),
  ummAlQura('umm_al_qura', 'أم القرى', 'السعودية'),
  egyptian('egyptian', 'الهيئة المصرية للمساحة', 'مصر وبلاد الشام'),
  muslimWorldLeague('mwl', 'رابطة العالم الإسلامي', 'أوروبا وكثير من البلاد'),
  karachi('karachi', 'جامعة العلوم الإسلامية بكراتشي', 'باكستان والهند'),
  dubai('dubai', 'دبي', 'الإمارات'),
  turkey('turkey', 'رئاسة الشؤون الدينية', 'تركيا'),
  northAmerica('north_america', 'ISNA', 'أمريكا الشمالية');

  const PrayerMethod(this.id, this.label, this.where);

  final String id;
  final String label;

  /// Where this method is the one in use.
  final String where;

  static PrayerMethod byId(String? id) =>
      values.firstWhere((m) => m.id == id, orElse: () => auto);

  CalculationParameters get parameters => switch (this) {
    PrayerMethod.auto => CalculationMethod.umm_al_qura.getParameters(),
    PrayerMethod.ummAlQura => CalculationMethod.umm_al_qura.getParameters(),
    PrayerMethod.egyptian => CalculationMethod.egyptian.getParameters(),
    PrayerMethod.muslimWorldLeague =>
      CalculationMethod.muslim_world_league.getParameters(),
    PrayerMethod.karachi => CalculationMethod.karachi.getParameters(),
    PrayerMethod.dubai => CalculationMethod.dubai.getParameters(),
    PrayerMethod.turkey => CalculationMethod.turkey.getParameters(),
    PrayerMethod.northAmerica =>
      CalculationMethod.north_america.getParameters(),
  };

  /// The method in use where the reader is standing.
  ///
  /// Rough boxes, deliberately: the point is to be right for the country the
  /// reader is actually in rather than to trace a border. Anywhere unrecognised
  /// falls to the Muslim World League, which is the usual default outside the
  /// regions that publish their own.
  static PrayerMethod forPlace(double latitude, double longitude) {
    bool within(double south, double north, double west, double east) =>
        latitude >= south &&
        latitude <= north &&
        longitude >= west &&
        longitude <= east;

    if (within(16, 32.5, 34, 56)) return PrayerMethod.ummAlQura; // الجزيرة
    if (within(22, 32, 24, 37)) return PrayerMethod.egyptian; // مصر
    if (within(29, 38, 34, 43)) return PrayerMethod.egyptian; // الشام والعراق
    if (within(22, 27, 51, 57)) return PrayerMethod.dubai; // الإمارات وعُمان
    if (within(23, 38, 60, 89)) return PrayerMethod.karachi; // باكستان والهند
    if (within(35, 43, 25, 45)) return PrayerMethod.turkey; // تركيا
    if (within(14, 72, -170, -50)) return PrayerMethod.northAmerica;
    return PrayerMethod.muslimWorldLeague;
  }
}

/// Which school's rule for Asr. The two differ by roughly forty minutes in
/// summer, which is enough to pray at the wrong time.
enum AsrSchool {
  standard('standard', 'الجمهور', 'الشافعي ومالك وأحمد', Madhab.shafi),
  hanafi('hanafi', 'الحنفي', 'ظل المثلين', Madhab.hanafi);

  const AsrSchool(this.id, this.label, this.note, this.madhab);

  final String id;
  final String label;
  final String note;
  final Madhab madhab;

  static AsrSchool byId(String? id) =>
      values.firstWhere((s) => s.id == id, orElse: () => standard);
}

/// The reader's choice of method and school, remembered between runs.
class PrayerSettings {
  static const _methodKey = '@noor_prayer_method';
  static const _schoolKey = '@noor_asr_school';

  static final method = ValueNotifier<PrayerMethod>(PrayerMethod.auto);
  static final school = ValueNotifier<AsrSchool>(AsrSchool.standard);

  static Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      method.value = PrayerMethod.byId(prefs.getString(_methodKey));
      school.value = AsrSchool.byId(prefs.getString(_schoolKey));
    } catch (_) {
      // The defaults are sound: automatic, and the majority's Asr.
    }
  }

  static Future<void> setMethod(PrayerMethod value) async {
    method.value = value;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_methodKey, value.id);
    } catch (_) {
      // Applies to this session regardless.
    }
  }

  static Future<void> setSchool(AsrSchool value) async {
    school.value = value;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_schoolKey, value.id);
    } catch (_) {
      // Applies to this session regardless.
    }
  }

  /// The parameters to compute with at [latitude], [longitude].
  static CalculationParameters parametersFor(
    double latitude,
    double longitude,
  ) {
    final chosen = method.value == PrayerMethod.auto
        ? PrayerMethod.forPlace(latitude, longitude)
        : method.value;
    return chosen.parameters..madhab = school.value.madhab;
  }

  /// What "تلقائي" resolves to at [latitude], [longitude], for showing the
  /// reader which method they are actually on.
  static PrayerMethod effective(double latitude, double longitude) =>
      method.value == PrayerMethod.auto
      ? PrayerMethod.forPlace(latitude, longitude)
      : method.value;
}
