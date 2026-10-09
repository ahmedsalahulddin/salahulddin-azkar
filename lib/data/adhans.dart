import '../l10n/strings.dart';
import '../services/app_locale.dart';

/// One recorded adhan.
///
/// Only historical recordings more than fifty years old are offered (the
/// related-rights term in Egypt and Saudi Arabia), always under the sheikh's
/// name and trimmed only — the voice itself is never altered.
///
/// Each one is two files: the whole adhan, which the app plays and Android
/// uses as the alert, and its first 29 seconds as a CAF clip, because iOS
/// plays no longer a sound with a notification.
class Adhan {
  final String id;
  final String name;
  final String place;

  /// The sheikh's name in Latin letters, for readers of the languages that
  /// do not use the Arabic script.
  final String nameLatin;

  /// Key under adh.place.* for [place] in the reader's language.
  final String placeKey;

  /// False for the ones fetched on demand from [host].
  final bool bundled;

  const Adhan({
    required this.id,
    required this.name,
    required this.place,
    required this.nameLatin,
    required this.placeKey,
    this.bundled = false,
  });

  static const host = 'https://qdata.salahulddin.com/adhan';

  bool get isBundled => bundled;

  /// [name] as the reader reads it.
  String get displayName =>
      const {'ar', 'ur'}.contains(AppLocale.code) ? name : nameLatin;

  /// [place] as the reader reads it.
  String get displayPlace =>
      AppLocale.code == 'ar' ? place : t('adh.place.$placeKey');

  /// The file name shared by every copy: res/raw on Android, Library/Sounds
  /// on iOS, and the server.
  String get resource => 'adhan_$id';

  /// The whole adhan, for a downloadable one.
  String? get url => bundled ? null : '$host/$resource.m4a';

  /// The 29-second iOS alert clip, for a downloadable one.
  String? get clipUrl => bundled ? null : '$host/$resource.caf';
}

class Adhans {
  /// Two ship with the app so the alert works on first launch, offline; the
  /// rest are a tap away.
  static const all = <Adhan>[
    Adhan(
      id: 'mustafa1948',
      name: 'الشيخ مصطفى إسماعيل',
      place: 'القصر الملكي ١٩٤٨',
      nameLatin: 'Sheikh Mustafa Ismail',
      placeKey: 'palace1948',
      bundled: true,
    ),
    Adhan(
      id: 'minshawi',
      name: 'الشيخ محمد صديق المنشاوي',
      place: 'تسجيل قديم',
      nameLatin: 'Sheikh Muhammad Siddiq al-Minshawi',
      placeKey: 'old',
      bundled: true,
    ),
    Adhan(
      id: 'mustafa1971',
      name: 'الشيخ مصطفى إسماعيل',
      place: 'أرمنت ١٩٧١',
      nameLatin: 'Sheikh Mustafa Ismail',
      placeKey: 'armant1971',
    ),
    Adhan(
      id: 'refaat',
      name: 'الشيخ محمد رفعت',
      place: 'تسجيل قديم',
      nameLatin: 'Sheikh Muhammad Rifat',
      placeKey: 'old',
    ),
  ];

  static const defaultId = 'mustafa1948';

  static bool known(String? id) => all.any((a) => a.id == id);

  static Adhan byId(String id) =>
      all.firstWhere((a) => a.id == id, orElse: () => all.first);
}

/// The kinds of dhikr a general reminder can draw from.
enum DhikrFlavour {
  all('all', 'الكل', null),
  salawat('salawat', 'الصلاة على النبي ﷺ', 'صلاة'),
  tasbih('tasbih', 'التسبيح', 'سبحان'),
  tahmid('tahmid', 'التحميد', 'الحمد'),
  tahlil('tahlil', 'التهليل', 'لا إله إلا الله'),
  takbir('takbir', 'التكبير', 'الله أكبر'),
  adhkar('adhkar', 'أذكار متنوعة', null),
  duas('duas', 'أدعية متنوعة', 'اللهم');

  const DhikrFlavour(this.id, this.label, this.marker);

  final String id;
  final String label;

  /// The phrase that identifies this kind inside a dhikr's text. Null means
  /// the flavour is not decided by a phrase — "all" takes everything, and
  /// "adhkar" is whatever the named kinds leave over.
  final String? marker;

  static DhikrFlavour byId(String? id) =>
      values.firstWhere((f) => f.id == id, orElse: () => all);
}
