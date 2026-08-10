import 'package:flutter/material.dart';
import '../constants/theme.dart';
import '../data/hisn_data.dart';
import 'hisn_chapter_screen.dart';

/// The 132 chapters of Hisn al-Muslim, searchable by title.
class SahihAdhkarScreen extends StatefulWidget {
  const SahihAdhkarScreen({super.key});

  @override
  State<SahihAdhkarScreen> createState() => _SahihAdhkarScreenState();
}

class _SahihAdhkarScreenState extends State<SahihAdhkarScreen> {
  final _searchController = TextEditingController();
  List<HisnChapter> _all = [];
  String _search = '';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final list = await HisnService.chapters();
    if (!mounted) return;
    setState(() {
      _all = list;
      _loading = false;
    });
  }

  List<HisnChapter> get _filtered {
    final q = _search.trim();
    if (q.isEmpty) return _all;
    // Match the chapter title or the text of any dhikr inside it.
    return _all
        .where((c) =>
            c.title.contains(q) || c.items.any((d) => d.text.contains(q)))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.black,
        appBar: AppBar(
          title: const Text(HisnService.title),
          backgroundColor: AppColors.black,
          foregroundColor: AppColors.gold,
        ),
        body: _loading
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.gold))
            : Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
                    child: TextField(
                      controller: _searchController,
                      onChanged: (v) => setState(() => _search = v),
                      textAlign: TextAlign.right,
                      style: const TextStyle(color: AppColors.textPrimary),
                      decoration: InputDecoration(
                        hintText: 'ابحث في الأبواب والأذكار…',
                        hintStyle: const TextStyle(
                            color: AppColors.textMuted, fontSize: 14),
                        filled: true,
                        fillColor: AppColors.blackSurface,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                              const BorderSide(color: AppColors.goldBorder),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                              const BorderSide(color: AppColors.goldBorder),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: AppColors.gold),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        suffixIcon:
                            const Icon(Icons.search, color: AppColors.textMuted),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        Text(
                          _search.isEmpty
                              ? '${_all.length} باباً'
                              : '${filtered.length} نتيجة',
                          style: const TextStyle(
                              color: AppColors.textMuted, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: filtered.isEmpty
                        ? const Center(
                            child: Text('لا توجد نتائج',
                                style: TextStyle(
                                    color: AppColors.textMuted, fontSize: 16)),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(12, 8, 12, 20),
                            itemCount: filtered.length + 1,
                            itemBuilder: (context, i) {
                              if (i == filtered.length) {
                                return Padding(
                                  padding: const EdgeInsets.only(top: 12),
                                  child: Text(
                                    HisnService.attribution,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                        color: AppColors.textMuted,
                                        fontSize: 11),
                                  ),
                                );
                              }
                              return _chapterTile(filtered[i]);
                            },
                          ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _chapterTile(HisnChapter c) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => HisnChapterScreen(chapter: c)),
      ),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 3),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.blackCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.goldBorder),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(c.title,
                      style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 3),
                  Text(
                    c.items.length == 1 ? 'ذكر واحد' : '${c.items.length} أذكار',
                    style: const TextStyle(
                        color: AppColors.textMuted, fontSize: 11),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_left,
                color: AppColors.textMuted, size: 20),
          ],
        ),
      ),
    );
  }
}
