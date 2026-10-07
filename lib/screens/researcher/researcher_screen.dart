import 'package:flutter/material.dart';

import '../../constants/theme.dart';
import '../../data/quran_data.dart';
import '../../data/researcher_data.dart';
import '../../l10n/strings.dart';
import '../../services/app_locale.dart';
import '../../widgets/gharib_panel.dart';
import 'researcher_search_screen.dart';
import 'researcher_text.dart';

/// «الباحث القرآني»: pick a surah and an ayah, then read what the books of
/// the salaf say about it — tafsir, gharib, i'rab and the occasions of
/// revelation — each as its printed pages.
class ResearcherScreen extends StatefulWidget {
  final int surah;
  final int ayah;
  final ResearcherCategory initialCategory;
  final int? initialBook;

  const ResearcherScreen({
    super.key,
    this.surah = 1,
    this.ayah = 1,
    this.initialCategory = ResearcherCategory.tafsir,
    this.initialBook,
  });

  @override
  State<ResearcherScreen> createState() => _ResearcherScreenState();
}

class _ResearcherScreenState extends State<ResearcherScreen>
    with SingleTickerProviderStateMixin {
  late int _surah = widget.surah;
  late int _ayah = widget.ayah;
  List<SurahInfo> _surahs = const [];
  List<ResearcherBook> _books = const [];
  Surah? _surahText;
  late final TabController _tabs = TabController(
    length: ResearcherCategory.values.length,
    vsync: this,
    initialIndex: widget.initialCategory.index,
  );

  /// The chosen book per shelf. For «غريب», 0 is the King Fahd Complex's
  /// الميسر في غريب القرآن, which ships inside the app.
  final Map<ResearcherCategory, int> _chosen = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final surahs = await QuranService.index();
    final books = await ResearcherService.catalog();
    if (!mounted) return;
    setState(() {
      _surahs = surahs;
      _books = books;
      for (final c in ResearcherCategory.values) {
        final first = c == ResearcherCategory.gharib
            ? 0
            : books.where((b) => b.category == c).firstOrNull?.id;
        if (first != null) _chosen[c] = first;
      }
      if (widget.initialBook != null) {
        _chosen[widget.initialCategory] = widget.initialBook!;
      }
    });
    await _loadSurahText();
  }

  Future<void> _loadSurahText() async {
    final s = await QuranService.surah(_surah);
    if (mounted) setState(() => _surahText = s);
  }

  int get _ayahCount =>
      _surahs.where((s) => s.number == _surah).firstOrNull?.ayahCount ?? 7;

  String get _surahName =>
      _surahs.where((s) => s.number == _surah).firstOrNull?.name ?? '';

  void _go(int surah, int ayah) {
    final changed = surah != _surah;
    setState(() {
      _surah = surah;
      _ayah = ayah;
      if (changed) _surahText = null;
    });
    if (changed) _loadSurahText();
  }

  void _step(int by) {
    var s = _surah;
    var a = _ayah + by;
    if (a < 1) {
      if (s == 1) return;
      s--;
      a = _surahs.where((x) => x.number == s).firstOrNull?.ayahCount ?? 1;
    } else if (a > _ayahCount) {
      if (s == 114) return;
      s++;
      a = 1;
    }
    _go(s, a);
  }

  Future<void> _pickSurah() async {
    final picked = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: AppColors.blackCard,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.75,
        builder: (_, controller) => Directionality(
          textDirection: TextDirection.rtl,
          child: ListView.builder(
            controller: controller,
            itemCount: _surahs.length,
            itemBuilder: (_, i) {
              final s = _surahs[i];
              return ListTile(
                leading: Text(
                  QuranService.toArabicDigits(s.number),
                  style: const TextStyle(color: AppColors.gold),
                ),
                title: Text(
                  s.name,
                  style: TextStyle(
                    color: s.number == _surah
                        ? AppColors.gold
                        : AppColors.textPrimary,
                  ),
                ),
                trailing: Text(
                  '${QuranService.toArabicDigits(s.ayahCount)} ${t('researcher.ayat')}',
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 12,
                  ),
                ),
                onTap: () => Navigator.pop(ctx, s.number),
              );
            },
          ),
        ),
      ),
    );
    if (picked != null) _go(picked, 1);
  }

  Future<void> _pickAyah() async {
    final picked = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: AppColors.blackCard,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: GridView.count(
          crossAxisCount: 6,
          padding: const EdgeInsets.all(16),
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          children: [
            for (var a = 1; a <= _ayahCount; a++)
              InkWell(
                onTap: () => Navigator.pop(ctx, a),
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: a == _ayah ? AppColors.gold : AppColors.blackSurface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.goldBorder),
                  ),
                  child: Text(
                    QuranService.toArabicDigits(a),
                    style: TextStyle(
                      color: a == _ayah
                          ? AppColors.black
                          : AppColors.textPrimary,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
    if (picked != null) _go(_surah, picked);
  }

  Future<void> _openSearch() async {
    final hit = await Navigator.push<ResearcherHit>(
      context,
      MaterialPageRoute(builder: (_) => const ResearcherSearchScreen()),
    );
    if (hit == null || !mounted) return;
    setState(() => _chosen[hit.book.category] = hit.book.id);
    _tabs.animateTo(hit.book.category.index);
    _go(hit.surah, hit.ayah);
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.black,
        appBar: AppBar(
          backgroundColor: AppColors.black,
          foregroundColor: AppColors.gold,
          title: Text(t('researcher.title')),
          actions: [
            IconButton(
              tooltip: t('researcher.search'),
              icon: const Icon(Icons.search),
              onPressed: _openSearch,
            ),
          ],
          bottom: TabBar(
            controller: _tabs,
            isScrollable: false,
            labelColor: AppColors.gold,
            unselectedLabelColor: AppColors.textMuted,
            indicatorColor: AppColors.gold,
            labelStyle: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
            tabs: [
              Tab(text: t('researcher.cat.tafsir')),
              Tab(text: t('researcher.cat.gharib')),
              Tab(text: t('researcher.cat.irab')),
              Tab(text: t('researcher.cat.asbab')),
            ],
          ),
        ),
        body: Column(
          children: [
            _picker(),
            Expanded(
              child: TabBarView(
                controller: _tabs,
                children: [
                  for (final c in ResearcherCategory.values) _shelf(c),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Surah and ayah, with the ayah's text under them.
  Widget _picker() {
    final text = _surahText?.ayahs
        .where((a) => a.number == _ayah)
        .firstOrNull
        ?.text;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.goldBorder)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_right, color: AppColors.gold),
                onPressed: () => _step(-1),
              ),
              Expanded(
                child: Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: _selector(
                        '${t('researcher.surah')} $_surahName',
                        _pickSurah,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 2,
                      child: _selector(
                        '${t('researcher.ayah')} ${QuranService.toArabicDigits(_ayah)}',
                        _pickAyah,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_left, color: AppColors.gold),
                onPressed: () => _step(1),
              ),
            ],
          ),
          if (text != null) ...[
            const SizedBox(height: 6),
            Container(
              width: double.infinity,
              constraints: const BoxConstraints(maxHeight: 120),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.navy,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.goldBorder),
              ),
              child: SingleChildScrollView(
                child: Text(
                  text,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: 'AmiriQuran',
                    color: AppColors.textGold,
                    fontSize: 19,
                    height: 1.9,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _selector(String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: AppColors.blackCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.goldBorder),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 14,
                ),
              ),
            ),
            const Icon(Icons.expand_more, color: AppColors.gold, size: 18),
          ],
        ),
      ),
    );
  }

  /// One shelf: its books as chips, then the chosen book on this ayah.
  Widget _shelf(ResearcherCategory c) {
    final books = _books.where((b) => b.category == c).toList();
    final chosen = _chosen[c];
    final book = books.where((b) => b.id == chosen).firstOrNull;
    return ListView(
      key: PageStorageKey('shelf-${c.name}'),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 30),
      children: [
        SizedBox(
          height: 36,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              if (c == ResearcherCategory.gharib)
                _chip(t('researcher.muyassarGharib'), chosen == 0, () {
                  setState(() => _chosen[c] = 0);
                }),
              for (final b in books)
                _chip(b.name, b.id == chosen, () {
                  setState(() => _chosen[c] = b.id);
                }),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (c == ResearcherCategory.gharib && chosen == 0)
          GharibPanel(surah: _surah, ayah: _ayah)
        else if (book != null) ...[
          _bookHeader(book),
          const SizedBox(height: 10),
          _BookPages(
            key: ValueKey('${book.id}-$_surah-$_ayah'),
            book: book,
            surah: _surah,
            ayah: _ayah,
          ),
        ],
      ],
    );
  }

  Widget _chip(String label, bool selected, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(end: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
        selectedColor: AppColors.gold,
        backgroundColor: AppColors.blackCard,
        side: const BorderSide(color: AppColors.goldBorder),
        labelStyle: TextStyle(
          color: selected ? AppColors.black : AppColors.textPrimary,
          fontSize: 13,
          fontWeight: selected ? FontWeight.bold : FontWeight.normal,
        ),
        showCheckmark: false,
      ),
    );
  }

  Widget _bookHeader(ResearcherBook book) {
    final death = book.death.isEmpty
        ? ''
        : ' (ت ${QuranService.toArabicDigits(int.tryParse(book.death) ?? 0)}هـ)';
    return Row(
      children: [
        Expanded(
          child: Text(
            '${book.author}$death',
            style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
          ),
        ),
        _DownloadButton(book: book),
      ],
    );
  }
}

/// The printed pages of one book on one ayah.
class _BookPages extends StatelessWidget {
  final ResearcherBook book;
  final int surah;
  final int ayah;

  const _BookPages({
    super.key,
    required this.book,
    required this.surah,
    required this.ayah,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<ResearcherPage>?>(
      future: ResearcherService.pagesFor(book, surah, ayah),
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Padding(
            padding: EdgeInsets.all(30),
            child: Center(
              child: CircularProgressIndicator(color: AppColors.gold),
            ),
          );
        }
        final pages = snap.data;
        if (pages == null) {
          return _note(t('researcher.offline'));
        }
        if (pages.isEmpty) return _note(t('researcher.nothing'));
        return Column(
          children: [
            for (final p in pages) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
                decoration: BoxDecoration(
                  color: AppColors.blackCard,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.goldBorder),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${t('researcher.part')} ${QuranService.toArabicDigits(int.tryParse(p.part) ?? 1)} — ${t('researcher.page')} ${QuranService.toArabicDigits(int.tryParse(p.page) ?? 0)}',
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: 6),
                    ResearcherText(p.text),
                  ],
                ),
              ),
              const SizedBox(height: 10),
            ],
            Text(
              '${book.name} — ${t('researcher.source')}',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textMuted,
                fontSize: 10.5,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _note(String text) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 30),
    child: Text(
      text,
      textAlign: TextAlign.center,
      style: const TextStyle(color: AppColors.textMuted, fontSize: 14),
    ),
  );
}

/// Download the whole book for reading offline and for search.
class _DownloadButton extends StatefulWidget {
  final ResearcherBook book;
  const _DownloadButton({required this.book});

  @override
  State<_DownloadButton> createState() => _DownloadButtonState();
}

class _DownloadButtonState extends State<_DownloadButton> {
  bool? _done;
  double? _progress;

  @override
  void initState() {
    super.initState();
    ResearcherService.isDownloaded(widget.book).then((d) {
      if (mounted) setState(() => _done = d);
    });
  }

  Future<void> _download() async {
    setState(() => _progress = 0);
    final failed = await ResearcherService.download(
      widget.book,
      onProgress: (d, total) {
        if (mounted) setState(() => _progress = d / total);
      },
    );
    if (!mounted) return;
    setState(() {
      _progress = null;
      _done = failed == 0;
    });
    if (failed > 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(t('researcher.downloadFailed'))));
    }
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.blackCard,
        content: Text(
          t('researcher.deleteConfirm').replaceFirst('%s', widget.book.name),
          style: const TextStyle(color: AppColors.textPrimary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(t('researcher.cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              t('researcher.delete'),
              style: const TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await ResearcherService.deleteDownload(widget.book);
    if (mounted) setState(() => _done = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_done == null) return const SizedBox.shrink();
    if (_progress != null) {
      return SizedBox(
        width: 80,
        child: LinearProgressIndicator(
          value: _progress,
          color: AppColors.gold,
          backgroundColor: AppColors.goldMuted,
        ),
      );
    }
    if (_done!) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.offline_pin, color: AppColors.gold, size: 16),
          const SizedBox(width: 4),
          Text(
            t('researcher.downloaded'),
            style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
          ),
          IconButton(
            tooltip: t('researcher.delete'),
            visualDensity: VisualDensity.compact,
            icon: const Icon(
              Icons.delete_outline,
              color: AppColors.textMuted,
              size: 18,
            ),
            onPressed: _delete,
          ),
        ],
      );
    }
    final mb = (widget.book.bytes / 1e6).toStringAsFixed(1);
    return TextButton.icon(
      onPressed: _download,
      icon: const Icon(Icons.download_rounded, size: 16, color: AppColors.gold),
      label: Text(
        '${t('researcher.download')} ($mb ${AppLocale.isEn ? 'MB' : 'م.ب'})',
        style: const TextStyle(color: AppColors.gold, fontSize: 12),
      ),
    );
  }
}
