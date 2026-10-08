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

  /// False for the ones fetched on demand from [host].
  final bool bundled;

  const Adhan({
    required this.id,
    required this.name,
    required this.place,
    this.bundled = false,
  });

  static const host = 'https://qdata.salahulddin.com/adhan';

  bool get isBundled => bundled;

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
      bundled: true,
    ),
    Adhan(
      id: 'minshawi',
      name: 'الشيخ محمد صديق المنشاوي',
      place: 'تسجيل قديم',
      bundled: true,
    ),
    Adhan(id: 'mustafa1971', name: 'الشيخ مصطفى إسماعيل', place: 'أرمنت ١٩٧١'),
    Adhan(id: 'refaat', name: 'الشيخ محمد رفعت', place: 'تسجيل قديم'),
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
