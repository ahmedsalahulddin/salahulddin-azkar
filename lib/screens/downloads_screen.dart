import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../constants/theme.dart';
import '../data/adhans.dart';
import '../data/library_data.dart';
import '../data/quran_data.dart';
import '../data/tafsir_data.dart';
import '../data/translation_data.dart';
import '../l10n/strings.dart';
import '../services/adhan_downloads.dart';
import '../services/app_locale.dart';
import '../services/mushaf_image_service.dart';
import '../services/recitation_downloads.dart';
import '../services/recitation_service.dart';

/// Everything the app can keep on the device, one tab per kind, each with a
/// way to take it off again — before this, most of it could be downloaded
/// from somewhere in the app but never deleted from anywhere.
class DownloadsScreen extends StatelessWidget {
  const DownloadsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      // The browser has no disk the app can write to; saying so beats a row
      // of download buttons that each fail.
      return Directionality(
        textDirection: AppLocale.direction,
        child: Scaffold(
          backgroundColor: AppColors.black,
          appBar: AppBar(
            title: Text(t('acct.group.downloads')),
            backgroundColor: AppColors.black,
            foregroundColor: AppColors.gold,
          ),
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Text(
                t('dl.webNote'),
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textMuted, height: 1.7),
              ),
            ),
          ),
        ),
      );
    }
    final tabs = [
      (t('dl.tab.quran'), const _QuranTab()),
      (t('dl.tab.tafsir'), const _TafsirTab()),
      (t('dl.tab.translations'), const _TranslationsTab()),
      (t('dl.tab.books'), const _BooksTab()),
      (t('dl.tab.adhan'), const _AdhanTab()),
    ];
    return Directionality(
      textDirection: AppLocale.direction,
      child: DefaultTabController(
        length: tabs.length,
        child: Scaffold(
          backgroundColor: AppColors.black,
          appBar: AppBar(
            title: Text(t('acct.group.downloads')),
            backgroundColor: AppColors.black,
            foregroundColor: AppColors.gold,
            bottom: TabBar(
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              labelColor: AppColors.gold,
              unselectedLabelColor: AppColors.textMuted,
              indicatorColor: AppColors.gold,
              dividerColor: AppColors.goldBorder,
              tabs: [for (final (label, _) in tabs) Tab(text: label)],
            ),
          ),
          body: TabBarView(children: [for (final (_, tab) in tabs) tab]),
        ),
      ),
    );
  }
}

// ---- shared pieces --------------------------------------------------------

Future<bool> _confirm(BuildContext context, String message) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => Directionality(
      textDirection: AppLocale.direction,
      child: AlertDialog(
        backgroundColor: AppColors.blackCard,
        content: Text(
          message,
          style: const TextStyle(color: AppColors.textPrimary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              t('mushaf.cancel'),
              style: const TextStyle(color: AppColors.textMuted),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              t('dl.delete'),
              style: const TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    ),
  );
  return ok == true;
}

void _say(BuildContext context, String text, {bool error = false}) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(text, textDirection: AppLocale.direction),
      backgroundColor: error ? AppColors.error : AppColors.emerald,
    ),
  );
}

class _Title extends StatelessWidget {
  final String text;
  const _Title(this.text);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(
      text,
      style: const TextStyle(
        color: AppColors.gold,
        fontSize: 15,
        fontWeight: FontWeight.bold,
      ),
    ),
  );
}

class _Note extends StatelessWidget {
  final String text;
  const _Note(this.text);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Text(
      text,
      style: const TextStyle(
        color: AppColors.textMuted,
        fontSize: 12,
        height: 1.6,
      ),
    ),
  );
}

BoxDecoration get _card => BoxDecoration(
  color: AppColors.blackCard,
  borderRadius: BorderRadius.circular(12),
  border: Border.all(color: AppColors.goldBorder),
);

/// One downloadable item: download it, watch it arrive, or delete it.
class _RemoteItem extends StatefulWidget {
  final String title;
  final String subtitle;
  final Future<bool> Function() isDownloaded;
  final Future<bool> Function(void Function(int done, int total)) download;
  final Future<void> Function() remove;

  const _RemoteItem({
    super.key,
    required this.title,
    required this.subtitle,
    required this.isDownloaded,
    required this.download,
    required this.remove,
  });

  @override
  State<_RemoteItem> createState() => _RemoteItemState();
}

class _RemoteItemState extends State<_RemoteItem> {
  bool? _ready;
  bool _busy = false;
  double _progress = 0;

  @override
  void initState() {
    super.initState();
    widget.isDownloaded().then((v) {
      if (mounted) setState(() => _ready = v);
    });
  }

  Future<void> _start() async {
    setState(() {
      _busy = true;
      _progress = 0;
    });
    final ok = await widget.download((done, total) {
      if (mounted && total > 0) setState(() => _progress = done / total);
    });
    if (!mounted) return;
    setState(() {
      _busy = false;
      _ready = ok;
    });
    if (!ok) _say(context, t('mushaf.downloadIncomplete'), error: true);
  }

  Future<void> _delete() async {
    if (!await _confirm(context, t('dl.deleteConfirm'))) return;
    await widget.remove();
    if (!mounted) return;
    setState(() => _ready = false);
    _say(context, t('mushaf.downloadRemoved'));
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: _card,
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 14,
                      ),
                    ),
                    if (widget.subtitle.isNotEmpty)
                      Text(
                        widget.subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 11,
                        ),
                      ),
                  ],
                ),
              ),
              if (_busy)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.gold,
                  ),
                )
              else if (_ready == true) ...[
                const Icon(
                  Icons.offline_pin,
                  color: AppColors.emeraldLight,
                  size: 20,
                ),
                IconButton(
                  onPressed: _delete,
                  tooltip: t('dl.delete'),
                  icon: const Icon(
                    Icons.delete_outline,
                    color: AppColors.textMuted,
                    size: 20,
                  ),
                ),
              ] else if (_ready == false)
                IconButton(
                  onPressed: _start,
                  icon: const Icon(
                    Icons.download,
                    color: AppColors.gold,
                    size: 20,
                  ),
                ),
            ],
          ),
          if (_busy) ...[
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: _progress == 0 ? null : _progress,
                backgroundColor: AppColors.blackSurface,
                valueColor: const AlwaysStoppedAnimation(AppColors.gold),
                minHeight: 4,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ---- القرآن ---------------------------------------------------------------

class _QuranTab extends StatefulWidget {
  const _QuranTab();

  @override
  State<_QuranTab> createState() => _QuranTabState();
}

class _QuranTabState extends State<_QuranTab> {
  int _cached = 0;
  bool _running = false;
  int _done = 0;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final count = await MushafImageService.cachedCount();
    if (mounted) setState(() => _cached = count);
  }

  Future<void> _start() async {
    setState(() {
      _running = true;
      _done = 0;
    });
    final failed = await MushafImageService.downloadAll(
      onProgress: (done, _) {
        if (mounted) setState(() => _done = done);
      },
    );
    if (!mounted) return;
    setState(() => _running = false);
    await _refresh();
    if (!mounted) return;
    _say(
      context,
      failed == 0
          ? t('mushaf.downloadAllComplete')
          : t('mushaf.downloadPagesFailed').replaceFirst('%s', '$failed'),
      error: failed != 0,
    );
  }

  Future<void> _clear() async {
    if (!await _confirm(context, t('dl.deleteAllConfirm'))) return;
    await MushafImageService.clearCache();
    await _refresh();
    if (mounted) _say(context, t('mushaf.downloadRemoved'));
  }

  @override
  Widget build(BuildContext context) {
    const total = QuranService.pageCount;
    final complete = _cached >= total;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _Title(t('dl.mushafPages')),
        _Note(t('mushaf.downloadPagesNote')),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: _card,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    t('mushaf.pagesLabel'),
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    _running ? '$_done / $total' : '$_cached / $total',
                    style: const TextStyle(
                      color: AppColors.textGold,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: (_running ? _done : _cached) / total,
                  backgroundColor: AppColors.blackSurface,
                  valueColor: const AlwaysStoppedAnimation(AppColors.gold),
                  minHeight: 5,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _running
                        ? OutlinedButton(
                            onPressed: MushafImageService.cancelDownloadAll,
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(
                                color: AppColors.goldBorder,
                              ),
                            ),
                            child: Text(
                              t('mushaf.stopDownload'),
                              style: const TextStyle(
                                color: AppColors.textMuted,
                              ),
                            ),
                          )
                        : ElevatedButton(
                            onPressed: complete ? null : _start,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.emerald,
                              disabledBackgroundColor: AppColors.blackSurface,
                            ),
                            child: Text(
                              complete
                                  ? t('mushaf.downloadComplete')
                                  : t('mushaf.downloadAllMushaf'),
                              style: const TextStyle(color: AppColors.white),
                            ),
                          ),
                  ),
                  if (!_running && _cached > 0) ...[
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: _clear,
                      tooltip: t('dl.deleteAll'),
                      icon: const Icon(
                        Icons.delete_outline,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        _Title(t('dl.recitations')),
        _Note(t('dl.recitationsNote')),
        ValueListenableBuilder<Set<String>>(
          valueListenable: RecitationDownloads.ready,
          builder: (context, _, _) => Column(
            children: [
              for (final r in RecitationService.reciters) _reciterRow(r),
            ],
          ),
        ),
      ],
    );
  }

  Widget _reciterRow(Reciter r) {
    final n = RecitationDownloads.countFor(r.id);
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => _ReciterDownloadsScreen(reciter: r)),
      ),
      behavior: HitTestBehavior.opaque,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: _card,
        child: Row(
          children: [
            Icon(
              n > 0 ? Icons.offline_pin : Icons.record_voice_over_outlined,
              color: n > 0 ? AppColors.emeraldLight : AppColors.gold,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                r.displayName,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 14,
                ),
              ),
            ),
            Text(
              t('dl.surahCount').replaceFirst('{n}', '$n'),
              style: TextStyle(
                color: n > 0 ? AppColors.textGold : AppColors.textMuted,
                fontSize: 12,
              ),
            ),
            const SizedBox(width: 6),
            Icon(Icons.chevron_left, color: AppColors.textMuted, size: 18),
          ],
        ),
      ),
    );
  }
}

/// One reciter's 114 surahs — download or delete each, or all at once.
class _ReciterDownloadsScreen extends StatefulWidget {
  final Reciter reciter;
  const _ReciterDownloadsScreen({required this.reciter});

  @override
  State<_ReciterDownloadsScreen> createState() =>
      _ReciterDownloadsScreenState();
}

class _ReciterDownloadsScreenState extends State<_ReciterDownloadsScreen> {
  List<SurahInfo> _surahs = const [];

  @override
  void initState() {
    super.initState();
    QuranService.index().then((s) {
      if (mounted) setState(() => _surahs = s);
    });
  }

  Future<void> _deleteAll() async {
    if (!await _confirm(context, t('dl.deleteAllConfirm'))) return;
    await RecitationDownloads.removeAllFor(widget.reciter.id);
    if (mounted) _say(context, t('mushaf.downloadRemoved'));
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: AppLocale.direction,
      child: Scaffold(
        backgroundColor: AppColors.black,
        appBar: AppBar(
          title: Text(widget.reciter.displayName),
          backgroundColor: AppColors.black,
          foregroundColor: AppColors.gold,
          actions: [
            ValueListenableBuilder<Set<String>>(
              valueListenable: RecitationDownloads.ready,
              builder: (context, _, _) =>
                  RecitationDownloads.countFor(widget.reciter.id) == 0
                  ? const SizedBox.shrink()
                  : TextButton.icon(
                      onPressed: _deleteAll,
                      icon: const Icon(
                        Icons.delete_sweep_outlined,
                        color: AppColors.error,
                        size: 18,
                      ),
                      label: Text(
                        t('dl.deleteAll'),
                        style: const TextStyle(color: AppColors.error),
                      ),
                    ),
            ),
          ],
        ),
        body: _surahs.isEmpty
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.gold),
              )
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _surahs.length + 1,
                itemBuilder: (context, i) => i == 0
                    ? _Note(t('mushaf.recitationsStreamingNote'))
                    : _SurahRow(reciter: widget.reciter, info: _surahs[i - 1]),
              ),
      ),
    );
  }
}

class _SurahRow extends StatelessWidget {
  final Reciter reciter;
  final SurahInfo info;
  const _SurahRow({required this.reciter, required this.info});

  String get _key => RecitationDownloads.keyOf(reciter.id, info.number);

  Future<void> _start(BuildContext context) async {
    final ok = await RecitationDownloads.download(reciter: reciter, info: info);
    if (!ok && context.mounted) {
      _say(context, t('mushaf.downloadIncomplete'), error: true);
    }
  }

  Future<void> _remove(BuildContext context) async {
    if (!await _confirm(context, t('mushaf.removeDownloadConfirm'))) return;
    await RecitationDownloads.remove(reciterId: reciter.id, surah: info.number);
    if (context.mounted) _say(context, t('mushaf.downloadRemoved'));
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Set<String>>(
      valueListenable: RecitationDownloads.ready,
      builder: (context, ready, _) =>
          ValueListenableBuilder<MapEntry<String, double?>?>(
            valueListenable: RecitationDownloads.active,
            builder: (context, active, _) {
              final isReady = ready.contains(_key);
              final busy = active?.key == _key;
              final progress = active?.value;
              return Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                decoration: _card,
                child: Row(
                  children: [
                    SizedBox(
                      width: 30,
                      child: Text(
                        '${info.number}',
                        style: const TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        info.name,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    if (busy)
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            value: progress == null || progress == 0
                                ? null
                                : progress,
                            color: AppColors.gold,
                          ),
                        ),
                      )
                    else if (isReady) ...[
                      const Icon(
                        Icons.offline_pin,
                        color: AppColors.emeraldLight,
                        size: 18,
                      ),
                      IconButton(
                        onPressed: () => _remove(context),
                        tooltip: t('dl.delete'),
                        icon: const Icon(
                          Icons.delete_outline,
                          color: AppColors.textMuted,
                          size: 20,
                        ),
                      ),
                    ] else
                      IconButton(
                        onPressed: () => _start(context),
                        icon: const Icon(
                          Icons.download,
                          color: AppColors.gold,
                          size: 20,
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
    );
  }
}

// ---- التفاسير / التراجم ----------------------------------------------------

class _TafsirTab extends StatelessWidget {
  const _TafsirTab();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _Note(t('mushaf.tafsirsBundledNote')),
        for (final e in TafsirService.editions.where((e) => !e.isBundled))
          _RemoteItem(
            key: ValueKey('tafsir-${e.id}'),
            title: e.name,
            subtitle: '${e.author} · ${e.downloadSize ?? ''}',
            isDownloaded: () => TafsirService.isDownloaded(e),
            download: (p) async =>
                await TafsirService.download(e, onProgress: p) == 0,
            remove: () => TafsirService.deleteDownload(e),
          ),
      ],
    );
  }
}

class _TranslationsTab extends StatelessWidget {
  const _TranslationsTab();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _Note(t('dl.translationsNote')),
        for (final tr in TranslationService.available)
          _RemoteItem(
            key: ValueKey('tr-${tr.id}'),
            title: tr.language,
            subtitle: tr.translator,
            isDownloaded: () => TranslationService.isDownloaded(tr),
            download: (p) async =>
                await TranslationService.download(tr, onProgress: p) == 0,
            remove: () => TranslationService.deleteDownload(tr),
          ),
      ],
    );
  }
}

// ---- الكتب ------------------------------------------------------------------

class _BooksTab extends StatelessWidget {
  const _BooksTab();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        for (final book in LibraryService.books) _BookCard(book: book),
      ],
    );
  }
}

class _BookCard extends StatelessWidget {
  final IslamicBook book;
  const _BookCard({required this.book});

  @override
  Widget build(BuildContext context) {
    final title = t('book.${book.id}');
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: _card,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title == 'book.${book.id}' ? book.title : title,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            book.author,
            style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (book.isBundled)
                _StaticChip(label: t('dl.bundled'))
              else
                _BookChip(
                  label:
                      '${t('dl.bookText')}'
                      '${book.downloadSize == null ? '' : ' · ${book.downloadSize}'}',
                  isDownloaded: () => LibraryService.isDownloaded(book),
                  download: (p) => LibraryService.download(book, onProgress: p),
                  remove: () => LibraryService.deleteDownload(book),
                ),
              for (final lang in book.translations.keys)
                _BookChip(
                  label: AppLocale.nameOf(lang) == lang
                      ? lang.toUpperCase()
                      : AppLocale.nameOf(lang),
                  isDownloaded: () =>
                      LibraryService.isTranslationDownloaded(book, lang),
                  download: (p) => LibraryService.downloadTranslation(
                    book,
                    lang,
                    onProgress: p,
                  ),
                  remove: () => LibraryService.deleteTranslation(book, lang),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StaticChip extends StatelessWidget {
  final String label;
  const _StaticChip({required this.label});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: AppColors.blackSurface,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      label,
      style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
    ),
  );
}

/// A book's text or one of its translations: tap to download, tap again to
/// delete.
class _BookChip extends StatefulWidget {
  final String label;
  final Future<bool> Function() isDownloaded;
  final Future<bool> Function(void Function(int received, int? total)) download;
  final Future<void> Function() remove;

  const _BookChip({
    required this.label,
    required this.isDownloaded,
    required this.download,
    required this.remove,
  });

  @override
  State<_BookChip> createState() => _BookChipState();
}

class _BookChipState extends State<_BookChip> {
  bool? _ready;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    widget.isDownloaded().then((v) {
      if (mounted) setState(() => _ready = v);
    });
  }

  Future<void> _tap() async {
    if (_busy || _ready == null) return;
    if (_ready!) {
      if (!await _confirm(context, t('dl.deleteConfirm'))) return;
      await widget.remove();
      if (!mounted) return;
      setState(() => _ready = false);
      _say(context, t('mushaf.downloadRemoved'));
      return;
    }
    setState(() => _busy = true);
    final ok = await widget.download((_, _) {});
    if (!mounted) return;
    setState(() {
      _busy = false;
      _ready = ok;
    });
    if (!ok) _say(context, t('mushaf.downloadIncomplete'), error: true);
  }

  @override
  Widget build(BuildContext context) {
    final ready = _ready == true;
    return GestureDetector(
      onTap: _tap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: ready ? AppColors.goldMuted : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: ready ? AppColors.gold : AppColors.goldBorder,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_busy)
              const SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(
                  strokeWidth: 1.5,
                  color: AppColors.gold,
                ),
              )
            else
              Icon(
                ready ? Icons.offline_pin : Icons.download,
                size: 14,
                color: ready ? AppColors.emeraldLight : AppColors.gold,
              ),
            const SizedBox(width: 6),
            Text(
              widget.label,
              style: TextStyle(
                color: ready ? AppColors.gold : AppColors.textSecondary,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---- الأذان -----------------------------------------------------------------

class _AdhanTab extends StatelessWidget {
  const _AdhanTab();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _Note(t('dl.adhanNote')),
        for (final a in Adhans.all.where((a) => !a.isBundled))
          _RemoteItem(
            key: ValueKey('adhan-${a.id}'),
            title: a.name,
            subtitle: a.place,
            isDownloaded: () async => AdhanDownloads.ready.value.contains(a.id),
            download: (_) => AdhanDownloads.fetch(a),
            remove: () => AdhanDownloads.remove(a),
          ),
      ],
    );
  }
}
