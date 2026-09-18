import 'package:flutter/material.dart';
import '../constants/theme.dart';
import '../data/hadith_encyclopedia_data.dart';
import '../l10n/strings.dart';

/// One category's hadiths, paginated. Each row expands in place to its full
/// text — Arabic first, then the picked language, then the explanation and
/// hints — fetched only once tapped open, since a category can hold hundreds.
class HadithEncyclopediaListScreen extends StatefulWidget {
  final HadeethCategory category;
  final String lang;

  const HadithEncyclopediaListScreen({
    super.key,
    required this.category,
    required this.lang,
  });

  @override
  State<HadithEncyclopediaListScreen> createState() =>
      _HadithEncyclopediaListScreenState();
}

class _HadithEncyclopediaListScreenState
    extends State<HadithEncyclopediaListScreen> {
  final _items = <HadeethSummary>[];
  int _page = 1;
  bool _hasMore = true;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadPage();
  }

  Future<void> _loadPage() async {
    if (_loading || !_hasMore) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await HadithEncyclopediaService.hadeeths(
        lang: widget.lang,
        categoryId: widget.category.id,
        page: _page,
      );
      if (!mounted) return;
      setState(() {
        _items.addAll(result.items);
        _hasMore = result.hasMore;
        _page++;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = t('lib2.failedToLoadHadithsMessage');
      });
    }
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
          title: Text(
            widget.category.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 15),
          ),
        ),
        body: NotificationListener<ScrollNotification>(
          onNotification: (n) {
            if (n.metrics.pixels > n.metrics.maxScrollExtent - 300) _loadPage();
            return false;
          },
          child: ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: _items.length + 1,
            itemBuilder: (context, i) {
              if (i == _items.length) return _footer();
              return _HadeethCard(
                key: ValueKey(_items[i].id),
                summary: _items[i],
                lang: widget.lang,
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _footer() {
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textMuted),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: _loadPage,
                child: Text(
                  t('lib2.retryButton'),
                  style: const TextStyle(color: AppColors.gold),
                ),
              ),
            ],
          ),
        ),
      );
    }
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.all(20),
        child: Center(
          child: CircularProgressIndicator(
            color: AppColors.gold,
            strokeWidth: 2,
          ),
        ),
      );
    }
    if (!_hasMore && _items.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Text(
            t('lib2.noHadithsInSectionMessage'),
            style: const TextStyle(color: AppColors.textMuted),
          ),
        ),
      );
    }
    return const SizedBox(height: 24);
  }
}

class _HadeethCard extends StatefulWidget {
  final HadeethSummary summary;
  final String lang;

  const _HadeethCard({super.key, required this.summary, required this.lang});

  @override
  State<_HadeethCard> createState() => _HadeethCardState();
}

class _HadeethCardState extends State<_HadeethCard> {
  bool _open = false;
  HadeethDetail? _detail;
  bool _loading = false;
  bool _failed = false;

  Future<void> _toggle() async {
    setState(() => _open = !_open);
    if (!_open || _detail != null || _loading) return;
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final detail = await HadithEncyclopediaService.detail(
        lang: widget.lang,
        id: widget.summary.id,
      );
      if (!mounted) return;
      setState(() {
        _detail = detail;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _failed = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.blackCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _open ? AppColors.gold : AppColors.goldBorder,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: _toggle,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.summary.title,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 13.5,
                        height: 1.5,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Icon(
                    _open ? Icons.expand_less : Icons.expand_more,
                    color: AppColors.textMuted,
                  ),
                ],
              ),
            ),
          ),
          if (_open) _body(),
        ],
      ),
    );
  }

  Widget _body() {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.only(bottom: 16),
        child: Center(
          child: CircularProgressIndicator(
            color: AppColors.gold,
            strokeWidth: 2,
          ),
        ),
      );
    }
    if (_failed) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
        child: Column(
          children: [
            Text(
              t('lib2.failedToLoadTextMessage'),
              style: const TextStyle(color: AppColors.textMuted),
            ),
            TextButton(
              onPressed: _toggle,
              child: Text(
                t('lib2.retryButton'),
                style: const TextStyle(color: AppColors.gold),
              ),
            ),
          ],
        ),
      );
    }
    final d = _detail;
    if (d == null) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Divider(color: AppColors.goldBorder, height: 20),
          Text(
            d.hadeethAr,
            textDirection: TextDirection.rtl,
            textAlign: TextAlign.right,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 16,
              height: 1.9,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.goldMuted,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              d.hadeeth,
              textDirection: TextDirection.ltr,
              textAlign: TextAlign.left,
              style: const TextStyle(
                color: AppColors.textGold,
                fontSize: 13.5,
                height: 1.55,
              ),
            ),
          ),
          if (d.grade != null || d.attribution != null) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                if (d.gradeAr != null) _badge('${d.gradeAr}'),
                if (d.attributionAr != null) _badge('${d.attributionAr}'),
              ],
            ),
          ],
          if (d.explanationAr != null && d.explanationAr!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              t('lib2.explanationSectionHeader'),
              style: const TextStyle(
                color: AppColors.gold,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              d.explanationAr!,
              textDirection: TextDirection.rtl,
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
                height: 1.7,
              ),
            ),
          ],
          if (d.explanation != null && d.explanation!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              d.explanation!,
              textDirection: TextDirection.ltr,
              textAlign: TextAlign.left,
              style: const TextStyle(
                color: AppColors.textMuted,
                fontSize: 12,
                height: 1.6,
              ),
            ),
          ],
          if (d.hintsAr.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              t('lib2.benefitsSectionHeader'),
              style: const TextStyle(
                color: AppColors.gold,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            for (final h in d.hintsAr)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  '• $h',
                  textDirection: TextDirection.rtl,
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12.5,
                    height: 1.6,
                  ),
                ),
              ),
          ],
          const SizedBox(height: 8),
          Text(
            '${t('lib2.certifiedTranslationLabel')} — hadeethenc.com',
            textDirection: TextDirection.rtl,
            textAlign: TextAlign.right,
            style: const TextStyle(color: AppColors.textMuted, fontSize: 10),
          ),
        ],
      ),
    );
  }

  Widget _badge(String label) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: AppColors.emeraldMuted,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: AppColors.emeraldLight),
    ),
    child: Text(
      label,
      style: const TextStyle(color: AppColors.emeraldLight, fontSize: 11),
    ),
  );
}
