import 'library_data.dart';
import 'quran_data.dart';

/// Where a point in a lesson comes from.
///
/// Every claim a lesson makes is anchored to something already in the app —
/// a verse of the bundled Mushaf or a hadith of a bundled collection — and the
/// text is read from there at runtime, never copied into this file. That keeps
/// the wording exactly as the source has it, and it means a reader who wants
/// to check can open the source themselves.
sealed class LessonSource {
  const LessonSource();
}

class VerseSource extends LessonSource {
  final int surah;
  final int ayah;

  const VerseSource(this.surah, this.ayah);
}

class HadithSource extends LessonSource {
  /// Id of a bundled book in [LibraryService.books].
  final String bookId;
  final int number;

  const HadithSource(this.bookId, this.number);
}

/// One point in a lesson: a heading, the explanation, and the source behind it.
class LessonPoint {
  final String title;
  final String body;
  final LessonSource? source;

  const LessonPoint({required this.title, required this.body, this.source});
}

class Lesson {
  final String id;
  final String icon;
  final String title;
  final String summary;

  /// Read at the top of the lesson, before the points.
  final LessonSource? opening;

  final List<LessonPoint> points;

  const Lesson({
    required this.id,
    required this.icon,
    required this.title,
    required this.summary,
    required this.points,
    this.opening,
  });
}

/// A source with its text filled in.
class ResolvedSource {
  final String text;
  final String citation;

  const ResolvedSource({required this.text, required this.citation});
}

class Lessons {
  static const all = <Lesson>[
    Lesson(
      id: 'pillars-islam',
      icon: '🕋',
      title: 'أركان الإسلام',
      summary: 'الخمسة التي بُني عليها الدين',
      opening: HadithSource('nawawi', 3),
      points: [
        LessonPoint(
          title: 'الشهادتان',
          body: 'أن تشهد أن لا إله إلا الله وأن محمداً رسول الله. '
              'وهي أول ما يدخل به المرء في الإسلام، ومعناها إفراد الله '
              'وحده بالعبادة، وتصديق النبي ﷺ فيما أخبر واتّباعه فيما أمر.',
        ),
        LessonPoint(
          title: 'إقام الصلاة',
          body: 'خمس صلوات في اليوم والليلة: الفجر والظهر والعصر والمغرب '
              'والعشاء. وهي أول ما يُحاسب عليه العبد يوم القيامة، '
              'وأوقاتها موقوتة لا تُقدَّم ولا تُؤخَّر عن وقتها بلا عذر.',
          source: VerseSource(4, 103),
        ),
        LessonPoint(
          title: 'إيتاء الزكاة',
          body: 'حقٌّ معلوم في المال يُخرجه من بلغ ماله النصاب وحال عليه '
              'الحول، ومقداره في النقود وعروض التجارة رُبع العُشر — '
              'أي اثنان ونصف في المئة.',
          source: VerseSource(9, 103),
        ),
        LessonPoint(
          title: 'صوم رمضان',
          body: 'الإمساك عن الطعام والشراب وسائر المفطرات من طلوع الفجر '
              'إلى غروب الشمس، طوال شهر رمضان، مع حفظ اللسان والجوارح.',
          source: VerseSource(2, 183),
        ),
        LessonPoint(
          title: 'حج البيت لمن استطاع',
          body: 'مرة واحدة في العمر على من قدر عليه ببدنه وماله وأمن طريقه. '
              'والاستطاعة شرط، فمن لم يستطع فلا حج عليه.',
          source: VerseSource(3, 97),
        ),
      ],
    ),
    Lesson(
      id: 'pillars-faith',
      icon: '🌙',
      title: 'أركان الإيمان',
      summary: 'الستة التي جاءت في حديث جبريل',
      opening: HadithSource('nawawi', 2),
      points: [
        LessonPoint(
          title: 'الإيمان بالله',
          body: 'تصديقٌ بوجوده وربوبيته وألوهيته وأسمائه وصفاته، '
              'وأنه وحده المستحق للعبادة، ليس كمثله شيء.',
          source: VerseSource(112, 1),
        ),
        LessonPoint(
          title: 'وملائكته',
          body: 'خلقٌ من نور، لا يعصون الله ما أمرهم ويفعلون ما يُؤمرون. '
              'منهم جبريل الموكل بالوحي، وميكائيل، وإسرافيل.',
          source: VerseSource(66, 6),
        ),
        LessonPoint(
          title: 'وكتبه',
          body: 'ما أنزله على رسله، ومنها التوراة والإنجيل والزبور، '
              'وخاتمها القرآن المهيمن عليها والمحفوظ من التبديل.',
          source: VerseSource(15, 9),
        ),
        LessonPoint(
          title: 'ورسله',
          body: 'الإيمان بأن الله أرسل رسلاً مبشّرين ومنذرين، '
              'أوّلهم نوح وخاتمهم محمد ﷺ، لا نفرّق بين أحد منهم.',
          source: VerseSource(2, 285),
        ),
        LessonPoint(
          title: 'واليوم الآخر',
          body: 'البعث والحساب والميزان والصراط، والجنة والنار. '
              'وأن كل نفس تُجزى بما كسبت لا تُظلم شيئاً.',
          source: VerseSource(99, 7),
        ),
        LessonPoint(
          title: 'والقدر خيره وشره',
          body: 'أن الله علم كل شيء وكتبه، وأن ما شاء كان وما لم يشأ لم يكن، '
              'مع بقاء اختيار العبد ومسؤوليته عن كسبه.',
          source: VerseSource(54, 49),
        ),
      ],
    ),
    Lesson(
      id: 'ihsan',
      icon: '✨',
      title: 'الإحسان',
      summary: 'أعلى المراتب الثلاث',
      opening: HadithSource('nawawi', 2),
      points: [
        LessonPoint(
          title: 'أن تعبد الله كأنك تراه',
          body: 'أن يستحضر العبد قرب الله منه وهو يعبده، فيؤدّي العبادة '
              'على أتمّ ما يقدر عليه، لا أداءً ناقصاً يُسقط الواجب فحسب.',
        ),
        LessonPoint(
          title: 'فإن لم تكن تراه فإنه يراك',
          body: 'فمن لم يبلغ تلك المرتبة، فليعلم أن الله مطّلع عليه '
              'في سرّه وعلانيته. وهذه هي المراقبة.',
          source: VerseSource(57, 4),
        ),
        LessonPoint(
          title: 'والإحسان في كل شيء',
          body: 'ليس في العبادة وحدها، بل في العمل والمعاملة والقول، '
              'وحتى في الذبح ورفق الإنسان بما تحت يده.',
          source: VerseSource(55, 60),
        ),
      ],
    ),
    Lesson(
      id: 'wudu',
      icon: '💧',
      title: 'الوضوء',
      summary: 'كما جاء في آية المائدة',
      opening: VerseSource(5, 6),
      points: [
        LessonPoint(
          title: 'النية',
          body: 'محلّها القلب، ولا يُتلفّظ بها. وهي ما يميّز العبادة '
              'عن مجرد غسل الأعضاء.',
          source: HadithSource('nawawi', 1),
        ),
        LessonPoint(
          title: 'غسل الوجه',
          body: 'من منابت شعر الرأس إلى أسفل اللحية طولاً، '
              'ومن الأذن إلى الأذن عرضاً. ويُسنّ قبله المضمضة والاستنشاق.',
        ),
        LessonPoint(
          title: 'غسل اليدين إلى المرفقين',
          body: 'مع إدخال المرفقين، ويبدأ باليمنى ثم اليسرى.',
        ),
        LessonPoint(
          title: 'مسح الرأس',
          body: 'يمرّ بيديه المبلولتين على رأسه من مقدّمه إلى مؤخّره ثم يعيدهما، '
              'ويمسح أذنيه معه.',
        ),
        LessonPoint(
          title: 'غسل الرجلين إلى الكعبين',
          body: 'مع تخليل أصابعهما، والبدء باليمنى. '
              'ويُسنّ في الغسل والمسح ثلاثاً، والواجب مرة تعمّ العضو.',
        ),
      ],
    ),
    Lesson(
      id: 'salah',
      icon: '🕌',
      title: 'الصلاة',
      summary: 'مواقيتها وعدد ركعاتها وشروطها',
      opening: VerseSource(29, 45),
      points: [
        LessonPoint(
          title: 'الفروض الخمسة',
          body: 'الفجر ركعتان، والظهر أربع، والعصر أربع، والمغرب ثلاث، '
              'والعشاء أربع. وللمسافر أن يقصر الرباعية إلى ركعتين.',
        ),
        LessonPoint(
          title: 'شروطها قبل الدخول فيها',
          body: 'الطهارة من الحدث والخبث، وستر العورة، واستقبال القبلة، '
              'ودخول الوقت. فمن صلّى قبل الوقت لم تُجزئه.',
          source: VerseSource(2, 144),
        ),
        LessonPoint(
          title: 'أركانها',
          body: 'تكبيرة الإحرام، والقيام مع القدرة، وقراءة الفاتحة، '
              'والركوع، والرفع منه، والسجود، والجلوس بين السجدتين، '
              'والطمأنينة في كل ركن، والتشهد الأخير، ثم التسليم.',
        ),
        LessonPoint(
          title: 'الخشوع روحها',
          body: 'وهو حضور القلب وسكون الجوارح. '
              'وبه وصف الله المفلحين من المؤمنين.',
          source: VerseSource(23, 2),
        ),
      ],
    ),
    Lesson(
      id: 'niyyah',
      icon: '❤️',
      title: 'النية',
      summary: 'أول حديث في الأربعين، وأصل العمل كله',
      opening: HadithSource('nawawi', 1),
      points: [
        LessonPoint(
          title: 'العمل بلا نية لا يُثمر',
          body: 'العادة تصير عبادة بالنية، والعبادة تصير عادة بفقدها. '
              'فالنائم ليقوى على الطاعة مأجور، والمصلّي رياءً محروم.',
        ),
        LessonPoint(
          title: 'ولكل امرئ ما نوى',
          body: 'يُجزى العبد على مقدار نيته لا على مقدار عمله وحده، '
              'فقد يبلغ صاحب العمل القليل بنيته ما لا يبلغه غيره بالكثير.',
        ),
        LessonPoint(
          title: 'والإخلاص شرط القبول',
          body: 'أن يُراد بالعمل وجه الله وحده. '
              'وأن يكون العمل على هدي النبي ﷺ. وبهذين يُقبل العمل.',
          source: VerseSource(98, 5),
        ),
      ],
    ),
  ];

  static Lesson byId(String id) => all.firstWhere((l) => l.id == id);

  /// Reads a source's text out of the bundle it belongs to.
  ///
  /// Returns null when the text cannot be read — a lesson still stands without
  /// its citation showing, and a missing source is no reason to fail a screen.
  static Future<ResolvedSource?> resolve(LessonSource source) async {
    try {
      switch (source) {
        case VerseSource(:final surah, :final ayah):
          final index = await QuranService.index();
          final loaded = await QuranService.surah(surah);
          final verse = loaded.ayahs.firstWhere((a) => a.number == ayah);
          final name = index.firstWhere((s) => s.number == surah).name;
          return ResolvedSource(
            text: verse.text,
            citation: '$name: ${QuranService.toArabicDigits(ayah)}',
          );

        case HadithSource(:final bookId, :final number):
          final book =
              LibraryService.books.firstWhere((b) => b.id == bookId);
          final hadiths = await LibraryService.hadiths(book);
          final hadith = hadiths.firstWhere((h) => h.number == number);
          return ResolvedSource(
            text: hadith.text,
            citation:
                '${book.title} — حديث ${QuranService.toArabicDigits(number)}',
          );
      }
    } catch (_) {
      return null;
    }
  }
}
