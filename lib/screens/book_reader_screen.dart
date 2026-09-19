import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../constants/theme.dart';
import '../l10n/strings.dart';
import '../widgets/speed_button.dart';
import '../widgets/speak_button.dart';
import '../data/library_data.dart';
import '../data/quran_data.dart' show QuranService;
import '../services/library_bookmarks.dart';

/// Reads one book, searching across its hadiths.
///
/// A downloadable book offers its download here rather than opening empty.
class BookReaderScreen extends StatefulWidget {
  final IslamicBook book;

  const BookReaderScreen({super.key, required this.book});

  @override
  State<BookReaderScreen> createState() => _BookReaderScreenState();
}

class _BookReaderScreenState extends State<BookReaderScreen> {
  final _searchController = TextEditingController();

  List<Hadith>? _hadiths;
  String _search = '';
  bool _bookmarkedOnly = false;
  bool _loading = true;
  bool _needsDownload = false;
  bool _downloading = false;
  int _received = 0;
  int? _expectedBytes;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    // Leaving the reader ends the reading; a voice with no screen behind it
    // has no way to be stopped.
    Tts.stop();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final list = await LibraryService.hadiths(widget.book);
      if (!mounted) return;
      setState(() {
        _hadiths = list;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _needsDownload = true;
      });
    }
  }

  Future<void> _download() async {
    setState(() {
      _downloading = true;
      _received = 0;
    });

    final ok = await LibraryService.download(
      widget.book,
      onProgress: (received, total) {
        if (mounted) {
          setState(() {
            _received = received;
            _expectedBytes = total;
          });
        }
      },
    );

    if (!mounted) return;
    setState(() => _downloading = false);

    if (ok) {
      setState(() {
        _loading = true;
        _needsDownload = false;
      });
      await _load();
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            t('lib2.downloadFailedMessage'),
            textDirection: TextDirection.rtl,
          ),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  List<Hadith> get _filtered {
    var all = _hadiths ?? const <Hadith>[];
    if (_bookmarkedOnly) {
      all = all
          .where((h) => LibraryBookmarks.has(widget.book.id, h.number))
          .toList();
    }
    final q = _search.trim();
    if (q.isEmpty) return all;
    return all.where((h) => h.text.contains(q)).toList();
  }

  Future<void> _toggleBookmark(Hadith h) async {
    await LibraryBookmarks.toggle(widget.book.id, h.number);
    HapticFeedback.lightImpact();
    if (mounted) setState(() {});
  }

  Future<void> _copy(Hadith h) async {
    await Clipboard.setData(
      ClipboardData(
        text:
            '${h.text}\n\n[${widget.book.title} — '
            '${t('lib2.hadithUnit')} ${h.number}]',
      ),
    );
    if (!mounted) return;
    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          t('lib2.hadithCopiedMessage'),
          textDirection: TextDirection.rtl,
        ),
        backgroundColor: AppColors.emerald,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.black,
        appBar: AppBar(
          title: Text(widget.book.title, style: const TextStyle(fontSize: 17)),
          backgroundColor: AppColors.black,
          foregroundColor: AppColors.gold,
          actions: [
            if (!_loading && !_needsDownload && !_downloading) _readAllBar(),
            const SpeedButton(showLabel: false),
          ],
        ),
        body: _downloading
            ? _downloadProgress()
            : _needsDownload
            ? _downloadPrompt()
            : _loading
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.gold),
              )
            : _reader(),
      ),
    );
  }

  Widget _downloadProgress() {
    final total = _expectedBytes;
    final mb = (_received / 1024 / 1024).toStringAsFixed(1);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '${t('lib2.downloadingPrefix')} ${widget.book.title}',
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                // Falls back to an indeterminate bar when the server does not
                // announce a length.
                value: total == null || total == 0 ? null : _received / total,
                backgroundColor: AppColors.blackSurface,
                valueColor: const AlwaysStoppedAnimation(AppColors.gold),
                minHeight: 6,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              '$mb ${t('lib2.megabytesUnit')}',
              style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _downloadPrompt() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('📕', style: TextStyle(fontSize: 44)),
            const SizedBox(height: 14),
            Text(
              widget.book.title,
              style: const TextStyle(
                color: AppColors.gold,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              widget.book.author,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              widget.book.description,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textMuted,
                fontSize: 12,
                height: 1.6,
              ),
            ),
            const SizedBox(height: 22),
            ElevatedButton.icon(
              onPressed: _download,
              icon: const Icon(Icons.download, size: 18),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.emerald,
                foregroundColor: AppColors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 22,
                  vertical: 12,
                ),
              ),
              label: Text(
                '${t('lib2.downloadButtonPrefix')} (${widget.book.downloadSize}) — '
                '${QuranService.toArabicDigits(widget.book.hadithCount)} '
                '${t('lib2.hadithUnit')}',
              ),
            ),
            const SizedBox(height: 10),
            Text(
              t('lib2.worksOfflineAfterDownload'),
              style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }

  Widget _reader() {
    final filtered = _filtered;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
          child: TextField(
            controller: _searchController,
            onChanged: (v) => setState(() => _search = v),
            textAlign: TextAlign.right,
            style: const TextStyle(color: AppColors.textPrimary),
            decoration: InputDecoration(
              hintText: t('lib2.searchHadithTextsHint'),
              hintStyle: const TextStyle(
                color: AppColors.textMuted,
                fontSize: 14,
              ),
              filled: true,
              fillColor: AppColors.blackSurface,
              isDense: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.goldBorder),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.goldBorder),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.gold),
              ),
              suffixIcon: const Icon(Icons.search, color: AppColors.textMuted),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Text(
                _search.isEmpty
                    ? '${QuranService.toArabicDigits(filtered.length)} '
                          '${t('lib2.hadithUnit')}'
                    : '${QuranService.toArabicDigits(filtered.length)} '
                          '${t('lib2.resultsUnit')}',
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 12,
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () =>
                    setState(() => _bookmarkedOnly = !_bookmarkedOnly),
                behavior: HitTestBehavior.opaque,
                child: Row(
                  children: [
                    Icon(
                      _bookmarkedOnly ? Icons.bookmark : Icons.bookmark_border,
                      color: _bookmarkedOnly
                          ? AppColors.gold
                          : AppColors.textMuted,
                      size: 16,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      t('lib2.bookmarkedOnlyLabel'),
                      style: TextStyle(
                        color: _bookmarkedOnly
                            ? AppColors.gold
                            : AppColors.textMuted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: filtered.isEmpty
              ? Center(
                  child: Text(
                    _bookmarkedOnly && _search.isEmpty
                        ? t('lib2.noBookmarksYet')
                        : t('lib2.noResultsFound'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 15,
                    ),
                  ),
                )
              : ValueListenableBuilder<int?>(
                  valueListenable: Tts.readingIndex,
                  builder: (context, readingAt, _) => ListView.builder(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
                    itemCount: filtered.length,
                    itemBuilder: (context, i) => _hadithCard(
                      filtered[i],
                      reading: i == readingAt,
                    ),
                  ),
                ),
        ),
      ],
    );
  }

  /// Toggles between "play the whole book, chapter by chapter" and, once
  /// running, a stop and skip control with a progress count — the same
  /// pattern My Adhkar uses to read a saved list straight through.
  Widget _readAllBar() {
    return ValueListenableBuilder<int?>(
      valueListenable: Tts.readingIndex,
      builder: (context, at, _) {
        if (at == null) {
          return IconButton(
            onPressed: () => Tts.readAll([for (final h in _filtered) h.text]),
            icon: const Icon(Icons.play_arrow, color: AppColors.gold),
            tooltip: t('misc.readAll'),
          );
        }
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              t('misc.readingProgress')
                  .replaceAll('{current}', QuranService.toArabicDigits(at + 1))
                  .replaceAll(
                    '{total}',
                    QuranService.toArabicDigits(_filtered.length),
                  ),
              style: const TextStyle(color: AppColors.textGold, fontSize: 11),
            ),
            IconButton(
              icon: const Icon(Icons.skip_next, color: AppColors.textSecondary),
              onPressed: Tts.skip,
              tooltip: t('misc.next'),
            ),
            IconButton(
              icon: const Icon(
                Icons.stop_circle_outlined,
                color: AppColors.gold,
              ),
              onPressed: Tts.stop,
              tooltip: t('misc.stop'),
            ),
          ],
        );
      },
    );
  }

  Widget _hadithCard(Hadith h, {bool reading = false}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.blackCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: reading ? AppColors.gold : AppColors.goldBorder,
          width: reading ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  h.text,
                  textAlign: TextAlign.justify,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 16,
                    height: 1.9,
                  ),
                ),
              ),
              SpeakButton(id: '${widget.book.id}:${h.number}', text: h.text),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: AppColors.goldMuted,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.goldBorder),
                ),
                child: Text(
                  '${t('lib2.hadithUnit')} ${QuranService.toArabicDigits(h.number)}',
                  style: const TextStyle(
                    color: AppColors.textGold,
                    fontSize: 11,
                  ),
                ),
              ),
              if (h.grade != null) ...[
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    h.grade!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
              const Spacer(),
              GestureDetector(
                onTap: () => _toggleBookmark(h),
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(
                    LibraryBookmarks.has(widget.book.id, h.number)
                        ? Icons.bookmark
                        : Icons.bookmark_border,
                    color: LibraryBookmarks.has(widget.book.id, h.number)
                        ? AppColors.gold
                        : AppColors.textMuted,
                    size: 17,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              GestureDetector(
                onTap: () => _copy(h),
                behavior: HitTestBehavior.opaque,
                child: const Padding(
                  padding: EdgeInsets.all(4),
                  child: Icon(Icons.copy, color: AppColors.textMuted, size: 17),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
