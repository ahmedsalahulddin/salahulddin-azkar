import 'hisn_data.dart';

/// One step of the Umrah, with the chapters of Hisn al-Muslim that belong to it.
class UmrahStage {
  final String title;
  final String guidance;
  final String icon;

  /// Hisn al-Muslim chapter ids, in the order they are said.
  final List<int> chapterIds;

  const UmrahStage({
    required this.title,
    required this.guidance,
    required this.icon,
    required this.chapterIds,
  });
}

/// The supplications of the Umrah, laid out in the order the rites are
/// performed rather than as a flat list — so the pilgrim can follow along.
///
/// Every dua comes from the Hisn al-Muslim data already bundled with the app,
/// so nothing here is newly sourced and nothing is invented. Chapters tied to
/// Hajj alone — Arafah, Muzdalifah, stoning the pillars — are left out, since
/// they are not part of the Umrah.
class UmrahGuide {
  static const attribution = HisnService.attribution;

  static const stages = <UmrahStage>[
    UmrahStage(
      title: 'السفر والإحرام',
      guidance: 'ما يُقال عند الخروج وركوب الدابة وأثناء الطريق',
      icon: '🧳',
      chapterIds: [95, 96, 102, 97],
    ),
    UmrahStage(
      title: 'التلبية',
      guidance: 'تبدأ من الميقات وتستمر حتى تستلم الحجر الأسود',
      icon: '🕋',
      chapterIds: [115],
    ),
    UmrahStage(
      title: 'دخول المسجد الحرام',
      guidance: 'يُدخل بالرجل اليمنى مع هذا الدعاء',
      icon: '🕌',
      chapterIds: [12, 13],
    ),
    UmrahStage(
      title: 'الطواف',
      guidance: 'سبعة أشواط تبدأ وتنتهي عند الحجر الأسود',
      icon: '🔄',
      chapterIds: [116, 117],
    ),
    UmrahStage(
      title: 'بعد الطواف',
      guidance: 'ركعتان خلف مقام إبراهيم ثم هذه الأذكار',
      icon: '🤲',
      chapterIds: [25],
    ),
    UmrahStage(
      title: 'السعي بين الصفا والمروة',
      guidance: 'يُقال عند الصعود على الصفا وعلى المروة في كل شوط',
      icon: '⛰️',
      chapterIds: [118],
    ),
    UmrahStage(
      title: 'أدعية جامعة أثناء النسك',
      guidance: 'لم يرد دعاء مخصوص في الطواف والسعي، فادعُ بما شئت',
      icon: '📿',
      chapterIds: [129, 130, 107],
    ),
    UmrahStage(
      title: 'الخروج والعودة',
      guidance: 'عند مغادرة المسجد وعند الرجوع من السفر',
      icon: '🏠',
      chapterIds: [14, 100, 105],
    ),
  ];

  /// The stages with their chapters resolved, skipping any chapter the data
  /// does not carry rather than failing the whole screen.
  static Future<List<(UmrahStage, List<HisnChapter>)>> load() async {
    final all = await HisnService.chapters();
    final byId = {for (final c in all) c.id: c};

    return [
      for (final stage in stages)
        (
          stage,
          [
            for (final id in stage.chapterIds)
              if (byId[id] != null) byId[id]!,
          ],
        ),
    ];
  }

  static Future<int> totalDuas() async {
    final resolved = await load();
    return resolved.fold<int>(
      0,
      (sum, entry) => sum + entry.$2.fold<int>(0, (s, c) => s + c.items.length),
    );
  }
}
