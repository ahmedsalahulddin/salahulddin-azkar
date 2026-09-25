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
}

class AppSource {
  final String title;

  /// Who holds the right, or who the work belongs to.
  final String holder;

  final SourceKind kind;
  final Standing standing;

  /// Anything the reader should know: an edition, a death date that settles
  /// the question, a licence name.
  final String? detail;

  const AppSource({
    required this.title,
    required this.holder,
    required this.kind,
    required this.standing,
    this.detail,
  });
}

class Sources {
  static const all = <AppSource>[
    // ---- scripture and text --------------------------------------------
    AppSource(
      title: 'نصّ المصحف الشريف',
      holder: 'مجمع الملك فهد لطباعة المصحف الشريف',
      kind: SourceKind.scripture,
      standing: Standing.permission,
      detail: 'رواية حفص عن عاصم، بالرسم العثماني',
    ),
    AppSource(
      title: 'صور صفحات المصحف',
      holder: 'files.quran.app — بخطوط مجمع الملك فهد',
      kind: SourceKind.scripture,
      standing: Standing.hosted,
      detail: '٦٠٤ صفحة بمقاس مصحف المدينة',
    ),
    AppSource(
      title: 'حصن المسلم',
      holder: 'سعيد بن علي بن وهف القحطاني',
      kind: SourceKind.scripture,
      standing: Standing.permission,
      detail: '١٣٢ باباً — ٢٦٧ ذكراً',
    ),
    AppSource(
      title: 'موسوعة الحديث',
      holder: 'hadeethenc.com — جمعية الدعوة والإرشاد وتوعية الجاليات بالربوة',
      kind: SourceKind.scripture,
      standing: Standing.hosted,
      detail: 'أحاديث مصنّفة بالموضوع مع شرحها، بترجمات معتمدة لا آلية',
    ),
    AppSource(
      title: 'التفسير الميسّر',
      holder: 'مجمع الملك فهد لطباعة المصحف الشريف',
      kind: SourceKind.scripture,
      standing: Standing.permission,
    ),
    AppSource(
      title: 'المختصر في التفسير',
      holder: 'مركز تفسير للدراسات القرآنية',
      kind: SourceKind.scripture,
      standing: Standing.permission,
    ),
    AppSource(
      title: 'تفسير الطبري والبغوي والقرطبي وابن كثير',
      holder: 'أئمة التفسير',
      kind: SourceKind.scripture,
      standing: Standing.publicDomain,
      detail: 'توفّوا بين القرنين الرابع والثامن الهجريين',
    ),
    AppSource(
      title: 'تفسير الجلالين والشوكاني والألوسي والسعدي',
      holder: 'أئمة التفسير',
      kind: SourceKind.scripture,
      standing: Standing.publicDomain,
    ),
    AppSource(
      title: 'ملفات التفاسير المُنزَّلة',
      holder: 'مستودع spa5k/tafsir_api',
      kind: SourceKind.scripture,
      standing: Standing.licensed,
      detail: 'رخصة MIT',
    ),
    AppSource(
      title: 'الأربعون النووية والأربعون القدسية',
      holder: 'الإمام النووي وأهل العلم — رحمهم الله',
      kind: SourceKind.scripture,
      standing: Standing.publicDomain,
    ),
    AppSource(
      title: 'ملفات الأحاديث والترجمات المُنزَّلة',
      holder: 'مستودعات fawazahmed0',
      kind: SourceKind.scripture,
      standing: Standing.licensed,
      detail: 'رخصة Unlicense — ملك عام',
    ),

    // ---- audio -----------------------------------------------------------
    AppSource(
      title: 'تلاوات القرّاء التسعة',
      holder: 'كل قارئ وناشر تسجيله — تُبثّ من everyayah.com و mp3quran.net',
      kind: SourceKind.audio,
      standing: Standing.hosted,
      detail: 'التسجيل عملٌ محفوظ لصاحبه، والتطبيق لا ينسخه',
    ),
    AppSource(
      title: 'تسجيلات الأذكار',
      holder: 'hisnmuslim.com',
      kind: SourceKind.audio,
      standing: Standing.hosted,
    ),
    AppSource(
      title: 'أصوات الأذان',
      holder: 'qurango.net و islamcan.com',
      kind: SourceKind.audio,
      standing: Standing.hosted,
    ),
    AppSource(
      title: 'الإذاعات',
      holder: 'كل إذاعة وبثّها المباشر',
      kind: SourceKind.audio,
      standing: Standing.hosted,
      detail: 'يُشغَّل البثّ كما تنشره الإذاعة، دون إعادة بثّ',
    ),

    // ---- type ------------------------------------------------------------
    AppSource(
      title: 'خط أميري قرآن',
      holder: 'خالد حسني ومشروع الخط الأميري',
      kind: SourceKind.type,
      standing: Standing.licensed,
      detail: 'رخصة الخطوط المفتوحة SIL OFL',
    ),

    // ---- software --------------------------------------------------------
    AppSource(
      title: 'حساب مواقيت الصلاة',
      holder: 'حزمة adhan — خوارزميات الهيئات المعتمدة',
      kind: SourceKind.software,
      standing: Standing.licensed,
    ),
    AppSource(
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
