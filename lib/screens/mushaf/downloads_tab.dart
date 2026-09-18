import 'package:flutter/material.dart';
import '../../constants/theme.dart';
import '../../data/quran_data.dart';
import '../../data/tafsir_data.dart';
import '../../data/translation_data.dart';
import '../../l10n/strings.dart';
import '../../services/mushaf_image_service.dart';

/// Pulls the whole Mushaf down so it reads with no connection at all.
class DownloadsTab extends StatefulWidget {
  const DownloadsTab({super.key});

  @override
  State<DownloadsTab> createState() => _DownloadsTabState();
}

class _DownloadsTabState extends State<DownloadsTab> {
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

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          failed == 0
              ? t('mushaf.downloadAllComplete')
              : t('mushaf.downloadPagesFailed').replaceFirst('%s', '$failed'),
          textDirection: TextDirection.rtl,
        ),
        backgroundColor: failed == 0 ? AppColors.emerald : AppColors.error,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const total = QuranService.pageCount;
    final complete = _cached >= total;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _SectionTitle(t('mushaf.downloadExtrasTitle')),
        const SizedBox(height: 6),
        _SectionNote(t('mushaf.downloadPagesNote')),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.blackCard,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.goldBorder),
          ),
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
              if (_running)
                OutlinedButton(
                  onPressed: MushafImageService.cancelDownloadAll,
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.goldBorder),
                  ),
                  child: Text(
                    t('mushaf.stopDownload'),
                    style: const TextStyle(color: AppColors.textMuted),
                  ),
                )
              else
                ElevatedButton(
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
            ],
          ),
        ),
        const SizedBox(height: 18),
        _SectionTitle(t('mushaf.tafsirsAndTranslationsTitle')),
        const SizedBox(height: 6),
        _SectionNote(t('mushaf.tafsirsBundledNote')),
        const SizedBox(height: 10),
        for (final edition in TafsirService.editions.where((e) => !e.isBundled))
          _RemoteItem(
            title: edition.name,
            subtitle: '${edition.author} · ${edition.downloadSize}',
            isDownloaded: () => TafsirService.isDownloaded(edition),
            download: (onProgress) async {
              final failed = await TafsirService.download(
                edition,
                onProgress: (done, total) => onProgress(done, total),
              );
              return failed == 0;
            },
          ),
        for (final translation in TranslationService.available)
          _RemoteItem(
            title: translation.language,
            subtitle: translation.translator,
            isDownloaded: () => TranslationService.isDownloaded(translation),
            download: (onProgress) async {
              final failed = await TranslationService.download(
                translation,
                onProgress: (done, total) => onProgress(done, total),
              );
              return failed == 0;
            },
          ),

        const SizedBox(height: 18),
        _SectionTitle(t('mushaf.recitationsTitle')),
        const SizedBox(height: 6),
        _SectionNote(t('mushaf.recitationsStreamingNote')),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;

  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: const TextStyle(
      color: AppColors.gold,
      fontSize: 15,
      fontWeight: FontWeight.bold,
    ),
  );
}

class _SectionNote extends StatelessWidget {
  final String text;

  const _SectionNote(this.text);

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: const TextStyle(
      color: AppColors.textMuted,
      fontSize: 12,
      height: 1.6,
    ),
  );
}

/// A downloadable extra: shows whether it is already on the device, and its
/// progress while it arrives.
class _RemoteItem extends StatefulWidget {
  final String title;
  final String subtitle;
  final Future<bool> Function() isDownloaded;
  final Future<bool> Function(void Function(int done, int total)) download;

  const _RemoteItem({
    required this.title,
    required this.subtitle,
    required this.isDownloaded,
    required this.download,
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

    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            t('mushaf.downloadIncomplete'),
            textDirection: TextDirection.rtl,
          ),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.blackCard,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.goldBorder),
      ),
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
              else if (_ready == true)
                const Icon(
                  Icons.offline_pin,
                  color: AppColors.emeraldLight,
                  size: 20,
                )
              else
                GestureDetector(
                  onTap: _start,
                  behavior: HitTestBehavior.opaque,
                  child: const Padding(
                    padding: EdgeInsets.all(4),
                    child: Icon(
                      Icons.download,
                      color: AppColors.gold,
                      size: 20,
                    ),
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
