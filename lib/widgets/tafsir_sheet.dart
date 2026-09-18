import 'package:flutter/material.dart';
import '../constants/theme.dart';
import '../data/tafsir_data.dart';
import '../l10n/strings.dart';
import 'translation_panel.dart';

const _mushafFont = 'AmiriQuran';

/// Shows one ayah with its commentary, and lets the reader switch between
/// tafsirs. Editions that are not on the device yet offer their download here
/// rather than failing silently.
class TafsirSheet extends StatefulWidget {
  final int surah;
  final int ayah;
  final String reference;
  final String ayahText;

  const TafsirSheet({
    super.key,
    required this.surah,
    required this.ayah,
    required this.reference,
    required this.ayahText,
  });

  @override
  State<TafsirSheet> createState() => _TafsirSheetState();
}

class _TafsirSheetState extends State<TafsirSheet> {
  TafsirEdition _edition = TafsirService.defaultEdition;
  String? _text;
  bool _loading = true;
  bool _needsDownload = false;
  int _downloaded = 0;
  bool _downloading = false;

  @override
  void initState() {
    super.initState();
    TafsirService.selected().then((e) {
      if (mounted) _switchTo(e);
    });
  }

  Future<void> _switchTo(TafsirEdition edition) async {
    setState(() {
      _edition = edition;
      _loading = true;
      _needsDownload = false;
      _text = null;
    });
    await TafsirService.select(edition.id);

    try {
      final map = await TafsirService.forSurahIn(edition, widget.surah);
      if (!mounted) return;
      setState(() {
        _text = map[widget.ayah];
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
      _downloaded = 0;
    });

    final failed = await TafsirService.download(
      _edition,
      onProgress: (done, _) {
        if (mounted) setState(() => _downloaded = done);
      },
    );

    if (!mounted) return;
    setState(() => _downloading = false);

    if (failed == 0) {
      await _switchTo(_edition);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            t('mushaf.downloadSurahsFailed').replaceFirst('%s', '$failed'),
            textDirection: TextDirection.rtl,
          ),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      minChildSize: 0.3,
      maxChildSize: 0.95,
      builder: (context, scrollController) => DefaultTabController(
        length: 2,
        child: Column(
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.textMuted,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Text(
              widget.reference,
              style: const TextStyle(
                color: AppColors.gold,
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            TabBar(
              labelColor: AppColors.gold,
              unselectedLabelColor: AppColors.textMuted,
              indicatorColor: AppColors.gold,
              labelStyle: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
              tabs: [
                Tab(height: 34, text: t('mushaf.tafsir')),
                Tab(height: 34, text: t('mushaf.translationsAndMeaningsTab')),
              ],
            ),
            Expanded(
              child: TabBarView(
                children: [
                  // Tafsir
                  ListView(
                    controller: scrollController,
                    padding: const EdgeInsets.fromLTRB(18, 12, 18, 26),
                    children: [
                      _ayahCard(),
                      const SizedBox(height: 14),
                      _editionPicker(),
                      const SizedBox(height: 16),
                      _body(),
                      const SizedBox(height: 20),
                      Text(
                        _edition.author,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                  // Translations
                  ListView(
                    padding: const EdgeInsets.fromLTRB(18, 12, 18, 26),
                    children: [
                      _ayahCard(),
                      const SizedBox(height: 14),
                      TranslationPanel(surah: widget.surah, ayah: widget.ayah),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _ayahCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.navy,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.goldBorder),
      ),
      child: Text(
        widget.ayahText,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontFamily: _mushafFont,
          color: AppColors.textGold,
          fontSize: 21,
          height: 2.0,
        ),
      ),
    );
  }

  Widget _editionPicker() {
    return SizedBox(
      height: 34,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: TafsirService.editions.length,
        itemBuilder: (context, i) {
          final e = TafsirService.editions[i];
          final active = e.id == _edition.id;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: GestureDetector(
              onTap: _downloading ? null : () => _switchTo(e),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: active ? AppColors.goldMuted : AppColors.blackSurface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: active ? AppColors.gold : AppColors.goldBorder,
                  ),
                ),
                child: Row(
                  children: [
                    Text(
                      e.name,
                      style: TextStyle(
                        color: active ? AppColors.gold : AppColors.textMuted,
                        fontSize: 12,
                        fontWeight: active
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                    if (!e.isBundled) ...[
                      const SizedBox(width: 5),
                      FutureBuilder<bool>(
                        future: TafsirService.isDownloaded(e),
                        builder: (context, snapshot) => Icon(
                          snapshot.data == true
                              ? Icons.offline_pin
                              : Icons.cloud_download_outlined,
                          size: 13,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _body() {
    if (_downloading) {
      return Column(
        children: [
          Text(
            '${t('mushaf.downloadingInProgress')} ${_edition.name}…',
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: _downloaded / 114,
              backgroundColor: AppColors.blackSurface,
              valueColor: const AlwaysStoppedAnimation(AppColors.gold),
              minHeight: 5,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '$_downloaded / ${t('mushaf.totalSurahsCount')}',
            style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
          ),
        ],
      );
    }

    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 30),
        child: Center(
          child: CircularProgressIndicator(
            color: AppColors.gold,
            strokeWidth: 2,
          ),
        ),
      );
    }

    if (_needsDownload) {
      return Column(
        children: [
          const Icon(
            Icons.cloud_download_outlined,
            color: AppColors.textMuted,
            size: 34,
          ),
          const SizedBox(height: 10),
          Text(
            '${_edition.name} ${t('mushaf.editionNotDownloadedYet')}',
            style: const TextStyle(color: AppColors.textPrimary, fontSize: 15),
          ),
          const SizedBox(height: 4),
          Text(
            '${t('mushaf.itsSize')} ${_edition.downloadSize ?? ''} — ${t('mushaf.worksOfflineAfterDownload')}',
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
          ),
          const SizedBox(height: 14),
          ElevatedButton.icon(
            onPressed: _download,
            icon: const Icon(Icons.download, size: 18),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.emerald,
              foregroundColor: AppColors.white,
            ),
            label: Text(t('mushaf.download')),
          ),
        ],
      );
    }

    return Text(
      _text ?? t('mushaf.noTafsirForThisAyah'),
      textAlign: TextAlign.justify,
      style: const TextStyle(
        color: AppColors.textPrimary,
        fontSize: 15,
        height: 1.9,
      ),
    );
  }
}
