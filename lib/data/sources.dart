import '../l10n/strings.dart';
import '../services/app_locale.dart';

/// Where everything in the app came from.
///
/// The app carries other people's work: the Qur'an as the King Fahd Complex
/// sets it, adhkar a scholar collected, tafsir written across eleven
/// centuries, recitations someone recorded and someone else pays to serve.
/// Naming each one is the least that owes them, and it is also the reader's
/// right — they should be able to see whose text they are trusting.
///
/// It is kept as data rather than as a page of prose so nothing can be added
/// to the app without a line here to answer for it.
enum SourceKind {
  scripture('النصّ'),
  audio('الصوت'),
  type('الخطوط'),
  software('البرمجيات');

  final String label;
  const SourceKind(this.label);

  /// [label] in the reader's language.
  String get displayLabel => t('src.kind.$name');
}

/// How freely a source may be carried.
enum Standing {
  /// Its author died long enough ago that no right remains.
  publicDomain('ملك عام', 'سقطت حقوقه بالتقادم'),

  /// Published under a licence that permits this use.
  licensed('رخصة مفتوحة', 'منشور برخصة تسمح بهذا الاستخدام'),

  /// A living right, carried on the owner's own published permission or
  /// pending their word. Named plainly rather than assumed.
  permission('بإذن صاحبه', 'عمل حديث — يُستخدم وفق إذن صاحبه'),

  /// Served from someone else's host. Not a question of ownership.
  hosted('استضافة خارجية', 'يُبثّ من خادم جهة أخرى');

  final String label;
  final String note;
  const Standing(this.label, this.note);

  /// [label] and [note] in the reader's language.
  String get displayLabel => t('src.standing.$name');
  String get displayNote => t('src.standing.$name.note');
}

class AppSource {
  /// Names this source's lines in the translation tables.
  final String id;
  final String title;

  /// Who holds the right, or who the work belongs to.
  final String holder;

  final SourceKind kind;
  final Standing standing;

  /// Anything the reader should know: an edition, a death date that settles
  /// the question, a licence name.
  final String? detail;

  /// The source's own site. Several of them (EveryAyah, HadeethEnc,
  /// alquran.cloud) make a link back a condition of use, so it is shown, and
  /// tappable, rather than only named.
  final String? url;

  const AppSource({
    required this.id,
    required this.title,
    required this.holder,
    required this.kind,
    required this.standing,
    this.detail,
    this.url,
  });

  /// One of this source's lines in the reader's language; names of books and
  /// publishers have no translation and stay as written.
  String _line(String field, String arabic) {
    if (AppLocale.code == 'ar') return arabic;
    final key = 'src.$id.$field';
    final text = t(key);
    return text == key ? arabic : text;
  }

  String get displayTitle => _line('title', title);
  String get displayHolder => _line('holder', holder);
  String? get displayDetail => detail == null ? null : _line('detail', detail!);
}

class Sources {
  static const all = <AppSource>[
    // ---- scripture and text --------------------------------------------
    AppSource(
      id: 'mushafText',
      title: 'نصّ المصحف الشريف',
      holder: 'مجمع الملك فهد لطباعة المصحف الشريف',
      kind: SourceKind.scripture,
      standing: Standing.permission,
      detail: 'رواية حفص عن عاصم، بالرسم العثماني',
    ),
    AppSource(
      id: 'mushafPages',
      title: 'صور صفحات المصحف',
      holder:
          'مجمع الملك فهد لطباعة المصحف الشريف — تُبثّ من مشروع Quran.com (files.quran.app)',
      kind: SourceKind.scripture,
      standing: Standing.hosted,
      detail: '٦٠٤ صفحة بمقاس مصحف المدينة، تُعرض كما هي دون تعديل',
      url: 'https://quran.com',
    ),
    AppSource(
      id: 'hisn',
      title: 'حصن المسلم',
      holder: 'سعيد بن علي بن وهف القحطاني',
      kind: SourceKind.scripture,
      standing: Standing.permission,
      detail: '١٣٢ باباً — ٢٦٧ ذكراً',
    ),
    AppSource(
      id: 'hadeethenc',
      title: 'موسوعة الحديث',
      holder: 'hadeethenc.com — جمعية الدعوة والإرشاد وتوعية الجاليات بالربوة',
      kind: SourceKind.scripture,
      standing: Standing.hosted,
      detail:
          'أحاديث مصنّفة بالموضوع مع شرحها، بترجمات معتمدة لا آلية، تُعرض دون تعديل',
      url: 'https://hadeethenc.com',
    ),
    AppSource(
      id: 'muyassar',
      title: 'التفسير الميسّر',
      holder: 'مجمع الملك فهد لطباعة المصحف الشريف',
      kind: SourceKind.scripture,
      standing: Standing.permission,
    ),
    AppSource(
      id: 'mukhtasar',
      title: 'المختصر في التفسير',
      holder: 'مركز تفسير للدراسات القرآنية',
      kind: SourceKind.scripture,
      standing: Standing.permission,
    ),
    AppSource(
      id: 'tafsirClassics',
      title: 'تفسير الطبري والبغوي وابن كثير',
      holder: 'أئمة التفسير',
      kind: SourceKind.scripture,
      standing: Standing.publicDomain,
      detail: 'توفّوا بين القرنين الرابع والثامن الهجريين',
    ),
    AppSource(
      id: 'tafsirLater',
      title: 'تفسير الشوكاني',
      holder: 'أئمة التفسير',
      kind: SourceKind.scripture,
      standing: Standing.publicDomain,
    ),
    AppSource(
      id: 'translations',
      title: 'ترجمات معاني القرآن',
      holder: 'alquran.cloud (Islamic Network) — ولكل ترجمة مترجمها',
      kind: SourceKind.scripture,
      standing: Standing.permission,
      detail:
          'Saheeh International (English) · Muhammad Hamidullah (Français) · '
          'Diyanet İşleri (Türkçe) · Abul A\'la Maududi (اردو) · '
          'Kementerian Agama RI (Indonesia) · Abdullah Muhammad Basmeih (Melayu) · '
          'Suhel Farooq Khan & Saifur Rahman Nadwi (हिन्दी) · '
          'Abubakar Mahmoud Gumi (Hausa) · Abu Rida (Deutsch) · '
          'Elmir Kuliev (Русский) — '
          'والبنغالية: د. أبو بكر محمد زكريا، طبعة مجمع الملك فهد، من مستودع fawazahmed0 — '
          'والإسبانية: مركز نور الدولي (منتدى الإسلام) من موسوعة QuranEnc',
      url: 'https://alquran.cloud',
    ),
    AppSource(
      id: 'quranenc',
      title: 'موسوعة القرآن الكريم المترجمة',
      holder: 'QuranEnc.com — جمعية خدمة المحتوى الإسلامي باللغات',
      kind: SourceKind.scripture,
      standing: Standing.permission,
      detail: 'الترجمة الإسبانية لمركز نور الدولي، تُعرض دون تعديل',
      url: 'https://quranenc.com',
    ),
    AppSource(
      id: 'tafsirFiles',
      title: 'ملفات التفاسير المُنزَّلة',
      holder: 'مستودع spa5k/tafsir_api — نصوص التفاسير من Quran.com',
      kind: SourceKind.scripture,
      standing: Standing.licensed,
      detail: 'رخصة MIT',
      url: 'https://github.com/spa5k/tafsir_api',
    ),
    AppSource(
      id: 'hadithLinks',
      title: 'روابط التحقق من الأحاديث',
      holder: 'sunnah.com',
      kind: SourceKind.scripture,
      standing: Standing.hosted,
      detail: 'روابط فقط تفتح الحديث على موقعهم، دون نسخ أي نصّ منه',
      url: 'https://sunnah.com',
    ),
    AppSource(
      id: 'arbaeen',
      title: 'الأربعون النووية والأربعون القدسية',
      holder: 'الإمام النووي وأهل العلم — رحمهم الله',
      kind: SourceKind.scripture,
      standing: Standing.publicDomain,
    ),
    AppSource(
      id: 'hadithFiles',
      title: 'ملفات الأحاديث والترجمات المُنزَّلة',
      holder: 'مستودعات fawazahmed0 — ولكل ترجمة مترجمها',
      kind: SourceKind.scripture,
      standing: Standing.licensed,
      detail: 'رخصة Unlicense — ملك عام',
      url: 'https://github.com/fawazahmed0/hadith-api',
    ),

    // ---- audio -----------------------------------------------------------
    AppSource(
      id: 'reciters',
      title: 'تلاوات القرّاء',
      holder: 'كل قارئ وناشر تسجيله — تُبثّ من EveryAyah.com و mp3quran.net',
      kind: SourceKind.audio,
      standing: Standing.hosted,
      detail:
          'التسجيل عملٌ محفوظ لصاحبه، والتطبيق لا ينسخه. يُستخدم لغير '
          'غرض تجاري، وفق ما يسمح به الموقعان',
      url: 'https://everyayah.com',
    ),
    AppSource(
      id: 'mp3quran',
      title: 'تلاوات mp3quran والإذاعة',
      holder: 'mp3quran.net و qurango.net',
      kind: SourceKind.audio,
      standing: Standing.hosted,
      detail: 'يسمح الموقع لأي زائر أو مطوّر باستخدام موادّه وروابطه',
      url: 'https://mp3quran.net',
    ),
    AppSource(
      id: 'azkarAudio',
      title: 'تسجيلات الأذكار',
      holder: 'hisnmuslim.com',
      kind: SourceKind.audio,
      standing: Standing.hosted,
      url: 'https://www.hisnmuslim.com',
    ),
    AppSource(
      id: 'adhan',
      title: 'أصوات الأذان',
      holder:
          'الشيخ مصطفى إسماعيل (القصر الملكي ١٩٤٨، أرمنت ١٩٧١)، '
          'والشيخ محمد صديق المنشاوي (ت ١٩٦٩)، والشيخ محمد رفعت (ت ١٩٥٠)',
      kind: SourceKind.audio,
      standing: Standing.publicDomain,
      detail:
          'تسجيلات تاريخية مضى عليها أكثر من خمسين عاماً، مدة حماية '
          'التسجيل الصوتي في مصر والسعودية. لم يُغيَّر الصوت، واقتُصر على '
          'قصّ البداية والنهاية',
      url: 'https://archive.org/details/Mustafa_Azan',
    ),
    AppSource(
      id: 'radio',
      title: 'الإذاعات',
      holder:
          'إذاعة القرآن الكريم من القاهرة، وإذاعة القرآن الكريم من السعودية '
          '(عبر Radiojar)، وإذاعات تراتيل والقرّاء ومشاري العفاسي (عبر mp3quran)',
      kind: SourceKind.audio,
      standing: Standing.hosted,
      detail:
          'يُشغَّل البثّ كما تنشره الإذاعة، دون إعادة بثّ، ويبقى حقّه لأصحابه',
    ),

    // ---- type ------------------------------------------------------------
    AppSource(
      id: 'amiri',
      title: 'خط أميري قرآن',
      holder: 'خالد حسني ومشروع الخط الأميري',
      kind: SourceKind.type,
      standing: Standing.licensed,
      detail: 'رخصة الخطوط المفتوحة SIL OFL',
    ),

    // ---- software --------------------------------------------------------
    AppSource(
      id: 'prayerCalc',
      title: 'حساب مواقيت الصلاة',
      holder: 'حزمة adhan — خوارزميات الهيئات المعتمدة',
      kind: SourceKind.software,
      standing: Standing.licensed,
    ),
    AppSource(
      id: 'ornaments',
      title: 'زخارف إطارات المصحف',
      holder: 'التطبيق نفسه',
      kind: SourceKind.software,
      standing: Standing.licensed,
      detail: 'مرسومة داخل التطبيق، لا صور منقولة',
    ),
  ];

  static List<AppSource> of(SourceKind kind) =>
      all.where((s) => s.kind == kind).toList();
}
