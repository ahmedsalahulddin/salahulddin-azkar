import 'dart:async';
import 'package:flutter/material.dart';
import '../../constants/theme.dart';
import '../../data/quran_data.dart';
import '../../services/bookmark_service.dart';

/// The search box the drawer's two search tabs share — same shape, same
/// placement, so moving between them changes only what is being searched.
class MushafSearchField extends StatelessWidget {
  final String hint;
  final ValueChanged<String> onChanged;
  final TextEditingController? controller;

  const MushafSearchField({
    super.key,
    required this.hint,
    required this.onChanged,
    this.controller,
  });

  @override
  Widget build(BuildContext context) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: AppColors.goldBorder),
    );

    return Padding(
      padding: const EdgeInsets.all(10),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        textAlign: TextAlign.right,
        style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 13),
          filled: true,
          fillColor: AppColors.blackSurface,
          isDense: true,
          border: border,
          enabledBorder: border,
          suffixIcon:
              const Icon(Icons.search, color: AppColors.textMuted, size: 18),
        ),
      ),
    );
  }
}

class SurahTab extends StatefulWidget {
  final List<SurahInfo> index;
  final ValueChanged<SurahInfo> onSurah;

  const SurahTab({super.key, required this.index, required this.onSurah});

  @override
  State<SurahTab> createState() => _SurahTabState();
}

class _SurahTabState extends State<SurahTab> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final q = _query.trim();
    final filtered = q.isEmpty
        ? widget.index
        : widget.index
            .where((s) => QuranService.surahMatches(s, q))
            .toList();

    return Column(
      children: [
        MushafSearchField(
          hint: 'ابحث عن سورة…',
          onChanged: (v) => setState(() => _query = v),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: filtered.length,
            itemBuilder: (context, i) => ListTile(
              dense: true,
              leading: Text(QuranService.toArabicDigits(filtered[i].number),
                  style: const TextStyle(color: AppColors.gold, fontSize: 13)),
              title: Text(filtered[i].name,
                  style: const TextStyle(
                      color: AppColors.textPrimary, fontSize: 14)),
              subtitle: Text(
                  '${filtered[i].type} • ${filtered[i].ayahCount} آية',
                  style: const TextStyle(
                      color: AppColors.textMuted, fontSize: 11)),
              onTap: () => widget.onSurah(filtered[i]),
            ),
          ),
        ),
      ],
    );
  }
}

class JuzTab extends StatelessWidget {
  final List<MushafPage> pages;
  final ValueChanged<int> onPage;

  const JuzTab({super.key, required this.pages, required this.onPage});

  @override
  Widget build(BuildContext context) {
    final firstPage = <int, int>{};
    for (final p in pages) {
      firstPage.putIfAbsent(p.juz, () => p.number);
    }
    final juz = firstPage.keys.toList()..sort();

    return ListView.builder(
      itemCount: juz.length,
      itemBuilder: (context, i) => ListTile(
        dense: true,
        leading: Text(QuranService.toArabicDigits(juz[i]),
            style: const TextStyle(color: AppColors.gold, fontSize: 13)),
        title: Text('الجزء ${QuranService.toArabicDigits(juz[i])}',
            style:
                const TextStyle(color: AppColors.textPrimary, fontSize: 14)),
        subtitle: Text(
            'يبدأ في صفحة ${QuranService.toArabicDigits(firstPage[juz[i]]!)}',
            style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
        onTap: () => onPage(firstPage[juz[i]]!),
      ),
    );
  }
}

/// Finds a word anywhere in the Mushaf and lists where it occurs, in order.
///
/// Matching ignores diacritics: nobody types the Mushaf's tashkeel, so a plain
/// query has to reach the marked-up text.
class WordSearchTab extends StatefulWidget {
  final List<SurahInfo> index;
  final ValueChanged<SurahInfo> onGoTo;

  const WordSearchTab({super.key, required this.index, required this.onGoTo});

  @override
  State<WordSearchTab> createState() => _WordSearchTabState();
}

class _WordSearchTabState extends State<WordSearchTab> {
  final _controller = TextEditingController();
  List<AyahHit> _hits = const [];
  int _occurrences = 0;
  bool _searching = false;
  String _lastQuery = '';

  /// A search reads all six thousand ayahs twice — once for the hits, once for
  /// the count. Running that per keystroke made typing a five-letter word run
  /// five full sweeps, four of them already stale. Waiting for a pause in the
  /// typing runs one.
  static const _settle = Duration(milliseconds: 250);
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String query) {
    _debounce?.cancel();
    _debounce = Timer(_settle, () => _run(query));
  }

  Future<void> _run(String query) async {
    final trimmed = query.trim();
    if (trimmed == _lastQuery) return;
    _lastQuery = trimmed;

    if (trimmed.isEmpty) {
      setState(() {
        _hits = const [];
        _occurrences = 0;
        _searching = false;
      });
      return;
    }

    setState(() => _searching = true);
    final hits = await QuranService.search(trimmed);
    final count = await QuranService.countOccurrences(trimmed);
    if (!mounted || _lastQuery != trimmed) return;
    setState(() {
      _hits = hits;
      _occurrences = count;
      _searching = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        MushafSearchField(
          hint: 'اكتب كلمة…',
          controller: _controller,
          onChanged: _onChanged,
        ),
        if (_searching)
          const Padding(
            padding: EdgeInsets.all(8),
            child: SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: AppColors.gold),
            ),
          )
        else if (_lastQuery.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              children: [
                Text(
                  _hits.isEmpty
                      ? 'لا نتائج'
                      : 'وردت ${QuranService.toArabicDigits(_occurrences)} مرة '
                          'في ${QuranService.toArabicDigits(_hits.length)} آية',
                  style: const TextStyle(
                      color: AppColors.textGold, fontSize: 12),
                ),
              ],
            ),
          ),
        Expanded(
          child: _lastQuery.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'ابحث عن أي كلمة في المصحف.\nلا حاجة لكتابة التشكيل.',
                      textAlign: TextAlign.center,
                      style:
                          TextStyle(color: AppColors.textMuted, fontSize: 13),
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(10, 8, 10, 16),
                  itemCount: _hits.length,
                  itemBuilder: (context, i) => _hitCard(_hits[i]),
                ),
        ),
      ],
    );
  }

  Widget _hitCard(AyahHit hit) {
    return GestureDetector(
      onTap: () {
        final info =
            widget.index.where((s) => s.number == hit.surah).firstOrNull;
        if (info != null) widget.onGoTo(info);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(11),
        decoration: BoxDecoration(
          color: AppColors.blackCard,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.goldBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              hit.text,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontFamily: mushafFont,
                color: AppColors.textPrimary,
                fontSize: 16,
                height: 1.9,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '${hit.surahName} — آية ${QuranService.toArabicDigits(hit.ayah)}',
              style:
                  const TextStyle(color: AppColors.textMuted, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}

class BookmarksTab extends StatefulWidget {
  final List<SurahInfo> index;
  final ValueChanged<Bookmark> onBookmark;

  const BookmarksTab(
      {super.key, required this.index, required this.onBookmark});

  @override
  State<BookmarksTab> createState() => _BookmarksTabState();
}

class _BookmarksTabState extends State<BookmarksTab> {
  List<Bookmark>? _marks;

  @override
  void initState() {
    super.initState();
    BookmarkService.all().then((m) {
      if (mounted) setState(() => _marks = m);
    });
  }

  /// A mark saved against a surah the index no longer carries names itself by
  /// number. Losing the name is a blemish; throwing here would take the whole
  /// list of marks down with it.
  String _name(int surah) =>
      widget.index
          .where((s) => s.number == surah)
          .firstOrNull
          ?.name ??
      'سورة ${QuranService.toArabicDigits(surah)}';

  @override
  Widget build(BuildContext context) {
    final marks = _marks;
    if (marks == null) {
      return const Center(
          child: CircularProgressIndicator(color: AppColors.gold));
    }
    if (marks.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'لا توجد علامات بعد.\nاضغط على آية ثم «علامة».',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textMuted, fontSize: 13),
          ),
        ),
      );
    }

    return ListView.builder(
      itemCount: marks.length,
      itemBuilder: (context, i) {
        final b = marks[i];
        return ListTile(
          dense: true,
          leading: Text(b.kind.icon, style: const TextStyle(fontSize: 18)),
          title: Text('${_name(b.surah)} — آية ${b.ayah}',
              style:
                  const TextStyle(color: AppColors.textPrimary, fontSize: 14)),
          subtitle: Text(
              b.note ??
                  '${b.kind.label} • صفحة ${QuranService.toArabicDigits(b.page)}',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
          trailing: IconButton(
            icon: const Icon(Icons.delete_outline,
                color: AppColors.textMuted, size: 18),
            onPressed: () async {
              await BookmarkService.remove(b.kind, b.surah, b.ayah);
              final refreshed = await BookmarkService.all();
              if (mounted) setState(() => _marks = refreshed);
            },
          ),
          onTap: () => widget.onBookmark(b),
        );
      },
    );
  }
}
