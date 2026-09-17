import 'dart:convert';
import 'package:http/http.dart' as http;

/// One topic in hadeethenc.com's category tree. Categories nest — a category
/// with children is a folder to browse into; one with none holds hadiths
/// directly.
class HadeethCategory {
  final String id;
  final String title;
  final int hadeethsCount;
  final String? parentId;

  const HadeethCategory({
    required this.id,
    required this.title,
    required this.hadeethsCount,
    this.parentId,
  });

  factory HadeethCategory.fromJson(Map<String, dynamic> j) => HadeethCategory(
    id: j['id'] as String,
    title: j['title'] as String,
    hadeethsCount: int.tryParse('${j['hadeeths_count']}') ?? 0,
    parentId: j['parent_id'] as String?,
  );
}

/// A hadith as it appears in a category listing — just enough to show a row;
/// [HadeethDetail] carries the full text.
class HadeethSummary {
  final String id;
  final String title;

  const HadeethSummary({required this.id, required this.title});

  factory HadeethSummary.fromJson(Map<String, dynamic> j) =>
      HadeethSummary(id: j['id'] as String, title: j['title'] as String);
}

/// The full hadith, with its Arabic original alongside the reader's chosen
/// language — this API's translations are a scholarly team's, not a machine
/// rendering, so nothing here carries the Claude-translation disclosure the
/// rest of the app's translated text does.
class HadeethDetail {
  final String id;
  final String title;
  final String hadeeth;
  final String hadeethAr;
  final String? explanation;
  final String? explanationAr;
  final List<String> hints;
  final List<String> hintsAr;
  final String? attribution;
  final String? attributionAr;
  final String? grade;
  final String? gradeAr;

  const HadeethDetail({
    required this.id,
    required this.title,
    required this.hadeeth,
    required this.hadeethAr,
    this.explanation,
    this.explanationAr,
    this.hints = const [],
    this.hintsAr = const [],
    this.attribution,
    this.attributionAr,
    this.grade,
    this.gradeAr,
  });

  factory HadeethDetail.fromJson(Map<String, dynamic> j) {
    List<String> strings(dynamic v) => (v as List? ?? [])
        .map((e) => '$e'.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    return HadeethDetail(
      id: j['id'] as String,
      title: j['title'] as String,
      hadeeth: j['hadeeth'] as String? ?? '',
      hadeethAr: j['hadeeth_ar'] as String? ?? '',
      explanation: j['explanation'] as String?,
      explanationAr: j['explanation_ar'] as String?,
      hints: strings(j['hints']),
      hintsAr: strings(j['hints_ar']),
      attribution: j['attribution'] as String?,
      attributionAr: j['attribution_ar'] as String?,
      grade: j['grade'] as String?,
      gradeAr: j['grade_ar'] as String?,
    );
  }
}

/// A page of hadith summaries, with enough to know whether another page
/// exists.
class HadeethPage {
  final List<HadeethSummary> items;
  final int page;
  final int totalPages;

  const HadeethPage({
    required this.items,
    required this.page,
    required this.totalPages,
  });

  bool get hasMore => page < totalPages;
}

/// The Encyclopedia of Translated Prophetic Hadiths (hadeethenc.com) —
/// hadiths grouped by topic with an explanation and hints, in a scholarly
/// translation team's own words rather than a machine rendering. Always
/// live-fetched: the tree is 450+ categories deep, far more than is worth
/// bundling, and a reader who opens this section already has a connection.
class HadithEncyclopediaService {
  static const _host = 'https://hadeethenc.com/api/v1';

  /// Languages this source actually covers, in menu order. Arabic is
  /// implicit — every hadith is shown with its Arabic text regardless of
  /// which of these is picked, so it is not listed separately here.
  static const supportedLanguages = <(String code, String name)>[
    ('en', 'English'),
    ('fr', 'Français'),
    ('ur', 'اردو'),
    ('id', 'Indonesia'),
    ('tr', 'Türkçe'),
    ('bn', 'বাংলা'),
    ('hi', 'हिन्दी'),
    ('ha', 'Hausa'),
  ];

  static final Map<String, List<HadeethCategory>> _categoryCache = {};
  static final Map<String, HadeethDetail> _detailCache = {};

  static Future<List<HadeethCategory>> categories(String lang) async {
    final cached = _categoryCache[lang];
    if (cached != null) return cached;

    final res = await http
        .get(Uri.parse('$_host/categories/list/?language=$lang'))
        .timeout(const Duration(seconds: 15));
    if (res.statusCode != 200) {
      throw StateError('categories request failed (${res.statusCode})');
    }
    final list = (jsonDecode(res.body) as List)
        .map((e) => HadeethCategory.fromJson(e as Map<String, dynamic>))
        .toList();
    return _categoryCache[lang] = list;
  }

  /// Direct children of [parentId], or the top-level topics when it is null.
  static List<HadeethCategory> childrenOf(
    List<HadeethCategory> all,
    String? parentId,
  ) => all.where((c) => c.parentId == parentId).toList();

  static Future<HadeethPage> hadeeths({
    required String lang,
    required String categoryId,
    int page = 1,
    int perPage = 20,
  }) async {
    final res = await http
        .get(
          Uri.parse(
            '$_host/hadeeths/list/?language=$lang&category_id=$categoryId&page=$page&per_page=$perPage',
          ),
        )
        .timeout(const Duration(seconds: 15));
    if (res.statusCode != 200) {
      throw StateError('hadeeths request failed (${res.statusCode})');
    }
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final items = (body['data'] as List)
        .map((e) => HadeethSummary.fromJson(e as Map<String, dynamic>))
        .toList();
    final meta = body['meta'] as Map<String, dynamic>?;
    final totalPages = int.tryParse('${meta?['last_page'] ?? 1}') ?? 1;
    return HadeethPage(items: items, page: page, totalPages: totalPages);
  }

  static Future<HadeethDetail> detail({
    required String lang,
    required String id,
  }) async {
    final key = '$lang:$id';
    final cached = _detailCache[key];
    if (cached != null) return cached;

    final res = await http
        .get(Uri.parse('$_host/hadeeths/one/?language=$lang&id=$id'))
        .timeout(const Duration(seconds: 15));
    if (res.statusCode != 200) {
      throw StateError('hadeeth detail request failed (${res.statusCode})');
    }
    final detail = HadeethDetail.fromJson(
      jsonDecode(res.body) as Map<String, dynamic>,
    );
    return _detailCache[key] = detail;
  }
}
