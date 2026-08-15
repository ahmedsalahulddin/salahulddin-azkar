/// One recorded adhan.
///
/// Android plays a notification sound from a bundled resource, never from a
/// URL — the system reads the file itself, and it cannot reach the network to
/// do it. So a downloadable adhan is copied into the app's own storage first,
/// and only then can it be chosen.
class Adhan {
  final String id;
  final String name;
  final String place;

  /// Present for the two that ship inside the app; the rest arrive from here.
  final String? url;

  const Adhan({
    required this.id,
    required this.name,
    required this.place,
    this.url,
  });

  bool get isBundled => url == null;
}

class Adhans {
  /// Two ship with the app so the feature works on first launch, offline, and
  /// without asking. Ten more are a tap away for whoever wants a particular
  /// voice — bundling all twelve would add eight megabytes for eleven files
  /// most readers will never play.
  static const all = <Adhan>[
    Adhan(id: 'makkah', name: 'أذان مكة المكرمة', place: 'مُرفق بالتطبيق'),
    Adhan(id: 'madinah', name: 'أذان المدينة المنورة', place: 'مُرفق بالتطبيق'),
    Adhan(
      id: 'afasy',
      name: 'أذان مشاري العفاسي',
      place: 'يحتاج تنزيلاً',
      url: 'https://www.islamcan.com/audio/adhan/azan2.mp3',
    ),
    Adhan(
      id: 'egypt',
      name: 'أذان مصري',
      place: 'يحتاج تنزيلاً',
      url: 'https://www.islamcan.com/audio/adhan/azan3.mp3',
    ),
    Adhan(
      id: 'aqsa',
      name: 'أذان المسجد الأقصى',
      place: 'يحتاج تنزيلاً',
      url: 'https://www.islamcan.com/audio/adhan/azan4.mp3',
    ),
    Adhan(
      id: 'turkey',
      name: 'أذان تركي',
      place: 'يحتاج تنزيلاً',
      url: 'https://www.islamcan.com/audio/adhan/azan5.mp3',
    ),
    Adhan(
      id: 'fajr',
      name: 'أذان الفجر',
      place: 'بزيادة «الصلاة خير من النوم»',
      url: 'https://www.islamcan.com/audio/adhan/azan6.mp3',
    ),
    Adhan(
      id: 'nasser',
      name: 'أذان ناصر القطامي',
      place: 'يحتاج تنزيلاً',
      url: 'https://www.islamcan.com/audio/adhan/azan7.mp3',
    ),
    Adhan(
      id: 'hidayah',
      name: 'أذان الهداية',
      place: 'يحتاج تنزيلاً',
      url: 'https://www.islamcan.com/audio/adhan/azan9.mp3',
    ),
    Adhan(
      id: 'classic',
      name: 'أذان كلاسيكي',
      place: 'يحتاج تنزيلاً',
      url: 'https://www.islamcan.com/audio/adhan/azan10.mp3',
    ),
  ];

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
