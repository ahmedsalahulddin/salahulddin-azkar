import 'package:flutter/material.dart';
import '../constants/theme.dart';
import '../data/hadith_encyclopedia_data.dart';
import '../l10n/strings.dart';
import 'hadith_encyclopedia_list_screen.dart';

/// Browses hadeethenc.com's topic tree — 7 top-level subjects fanning out
/// into ~450 categories. Pushing into a category with children shows this
/// same screen one level deeper; a category with none goes straight to its
/// hadith list.
class HadithEncyclopediaScreen extends StatefulWidget {
  final String? parentId;
  final String? title;
  final String lang;

  const HadithEncyclopediaScreen({
    super.key,
    this.parentId,
    this.title,
    this.lang = 'ar',
  });

  @override
  State<HadithEncyclopediaScreen> createState() =>
      _HadithEncyclopediaScreenState();
}

class _HadithEncyclopediaScreenState extends State<HadithEncyclopediaScreen> {
  List<HadeethCategory>? _all;
  String? _error;
  late String _lang;

  @override
  void initState() {
    super.initState();
    _lang = widget.lang;
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _all = null;
      _error = null;
    });
    try {
      final all = await HadithEncyclopediaService.categories(_lang);
      if (!mounted) return;
      setState(() => _all = all);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = t('lib2.failedToLoadSectionsMessage'));
    }
  }

  void _pickLang() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      backgroundColor: AppColors.blackCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
                child: Text(
                  t('lib2.translationLanguageLabel'),
                  style: const TextStyle(color: AppColors.gold, fontSize: 15),
                ),
              ),
              for (final l in HadithEncyclopediaService.supportedLanguages)
                ListTile(
                  leading: Icon(
                    l.$1 == _lang
                        ? Icons.radio_button_checked
                        : Icons.radio_button_unchecked,
                    color: l.$1 == _lang ? AppColors.gold : AppColors.textMuted,
                    size: 19,
                  ),
                  title: Text(
                    l.$2,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 14,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    if (l.$1 != _lang) {
                      setState(() => _lang = l.$1);
                      _load();
                    }
                  },
                ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  void _open(HadeethCategory category, List<HadeethCategory> children) {
    if (children.isNotEmpty) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => HadithEncyclopediaScreen(
            parentId: category.id,
            title: category.title,
            lang: _lang,
          ),
        ),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              HadithEncyclopediaListScreen(category: category, lang: _lang),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final all = _all;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.black,
        appBar: AppBar(
          backgroundColor: AppColors.black,
          foregroundColor: AppColors.gold,
          title: Text(
            widget.title ?? t('lib2.hadithEncyclopediaTitle'),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          actions: [
            TextButton.icon(
              onPressed: _pickLang,
              icon: const Icon(Icons.language, size: 17),
              label: Text(
                HadithEncyclopediaService.supportedLanguages
                    .firstWhere((l) => l.$1 == _lang)
                    .$2,
                style: const TextStyle(fontSize: 13),
              ),
              style: TextButton.styleFrom(foregroundColor: AppColors.gold),
            ),
          ],
        ),
        body: _error != null
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _error!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: AppColors.textMuted),
                      ),
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: _load,
                        child: Text(
                          t('lib2.retryButton'),
                          style: const TextStyle(color: AppColors.gold),
                        ),
                      ),
                    ],
                  ),
                ),
              )
            : all == null
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.gold),
              )
            : _list(all),
      ),
    );
  }

  Widget _list(List<HadeethCategory> all) {
    final items = HadithEncyclopediaService.childrenOf(all, widget.parentId);
    if (items.isEmpty) {
      return Center(
        child: Text(
          t('lib2.noSectionsHereMessage'),
          style: const TextStyle(color: AppColors.textMuted),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: items.length,
      itemBuilder: (context, i) {
        final c = items[i];
        final children = HadithEncyclopediaService.childrenOf(all, c.id);
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: AppColors.blackCard,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.goldBorder),
          ),
          child: ListTile(
            title: Text(
              c.title,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 14,
              ),
            ),
            subtitle: Text(
              '${c.hadeethsCount} ${t('lib2.hadithUnit')}',
              style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
            ),
            trailing: const Icon(
              Icons.chevron_left,
              color: AppColors.textMuted,
            ),
            onTap: () => _open(c, children),
          ),
        );
      },
    );
  }
}
