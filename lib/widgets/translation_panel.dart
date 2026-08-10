import 'package:flutter/material.dart';
import '../constants/theme.dart';
import '../data/translation_data.dart';

/// Shows the meanings of one ayah in another language, and lets the reader
/// pick which translation to read. None ship with the app, so an unfetched
/// translation offers its download here rather than showing an empty panel.
class TranslationPanel extends StatefulWidget {
  final int surah;
  final int ayah;

  const TranslationPanel({super.key, required this.surah, required this.ayah});

  @override
  State<TranslationPanel> createState() => _TranslationPanelState();
}

class _TranslationPanelState extends State<TranslationPanel> {
  Translation? _translation;
  String? _text;
  bool _loading = true;
  bool _needsDownload = false;
  bool _downloading = false;
  int _done = 0;

  @override
  void initState() {
    super.initState();
    TranslationService.selected().then((t) {
      if (!mounted) return;
      if (t == null) {
        setState(() => _loading = false); // nothing chosen yet
      } else {
        _switchTo(t);
      }
    });
  }

  Future<void> _switchTo(Translation translation) async {
    setState(() {
      _translation = translation;
      _loading = true;
      _needsDownload = false;
      _text = null;
    });
    await TranslationService.select(translation.id);

    try {
      final map = await TranslationService.forSurah(translation, widget.surah);
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
    final translation = _translation;
    if (translation == null) return;

    setState(() {
      _downloading = true;
      _done = 0;
    });

    final failed = await TranslationService.download(
      translation,
      onProgress: (done, _) {
        if (mounted) setState(() => _done = done);
      },
    );

    if (!mounted) return;
    setState(() => _downloading = false);

    if (failed == 0) {
      await _switchTo(translation);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تعذّر تنزيل $failed سورة — أعد المحاولة لإكمالها',
              textDirection: TextDirection.rtl),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _languagePicker(),
        const SizedBox(height: 14),
        _body(),
        if (_translation != null && !_needsDownload && !_downloading) ...[
          const SizedBox(height: 16),
          Text(_translation!.translator,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
        ],
      ],
    );
  }

  Widget _languagePicker() {
    return SizedBox(
      height: 34,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: TranslationService.available.length,
        itemBuilder: (context, i) {
          final t = TranslationService.available[i];
          final active = t.id == _translation?.id;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: GestureDetector(
              onTap: _downloading ? null : () => _switchTo(t),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: active ? AppColors.goldMuted : AppColors.blackSurface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: active ? AppColors.gold : AppColors.goldBorder),
                ),
                child: Row(
                  children: [
                    Text(t.language,
                        style: TextStyle(
                          color: active ? AppColors.gold : AppColors.textMuted,
                          fontSize: 12,
                          fontWeight:
                              active ? FontWeight.bold : FontWeight.normal,
                        )),
                    const SizedBox(width: 5),
                    FutureBuilder<bool>(
                      future: TranslationService.isDownloaded(t),
                      builder: (context, snapshot) => Icon(
                        snapshot.data == true
                            ? Icons.offline_pin
                            : Icons.cloud_download_outlined,
                        size: 13,
                        color: AppColors.textMuted,
                      ),
                    ),
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
          Text('جاري تنزيل ${_translation!.language}…',
              style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: 14)),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: _done / 114,
              backgroundColor: AppColors.blackSurface,
              valueColor: const AlwaysStoppedAnimation(AppColors.gold),
              minHeight: 5,
            ),
          ),
          const SizedBox(height: 6),
          Text('$_done / ١١٤ سورة',
              style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
        ],
      );
    }

    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 30),
        child: Center(
          child: CircularProgressIndicator(color: AppColors.gold, strokeWidth: 2),
        ),
      );
    }

    if (_translation == null) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Text(
          'اختر لغة من الأعلى لعرض معاني الآية بها',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.textMuted, fontSize: 13),
        ),
      );
    }

    if (_needsDownload) {
      return Column(
        children: [
          const Icon(Icons.cloud_download_outlined,
              color: AppColors.textMuted, size: 34),
          const SizedBox(height: 10),
          Text('${_translation!.language} غير منزَّلة بعد',
              style:
                  const TextStyle(color: AppColors.textPrimary, fontSize: 15)),
          const SizedBox(height: 4),
          const Text('بعد التنزيل تعمل بلا إنترنت',
              style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
          const SizedBox(height: 14),
          ElevatedButton.icon(
            onPressed: _download,
            icon: const Icon(Icons.download, size: 18),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.emerald,
              foregroundColor: AppColors.white,
            ),
            label: const Text('تنزيل'),
          ),
        ],
      );
    }

    final t = _translation!;
    return Directionality(
      // Urdu and the like read right-to-left; the rest do not.
      textDirection: t.isRtl ? TextDirection.rtl : TextDirection.ltr,
      child: Text(
        _text ?? 'لا تتوفر ترجمة لهذه الآية',
        textAlign: t.isRtl ? TextAlign.right : TextAlign.left,
        style: const TextStyle(
          color: AppColors.textPrimary,
          fontSize: 15,
          height: 1.8,
        ),
      ),
    );
  }
}
