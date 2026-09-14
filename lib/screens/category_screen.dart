import 'package:flutter/material.dart';
import '../constants/theme.dart';
import '../data/adhkar_data.dart';
import '../l10n/strings.dart';
import '../widgets/adhkar_card.dart';
import '../widgets/bilingual_text.dart';
import '../widgets/tasbih_counter.dart';

class CategoryScreen extends StatefulWidget {
  final AdhkarCategory category;

  const CategoryScreen({super.key, required this.category});

  @override
  State<CategoryScreen> createState() => _CategoryScreenState();
}

class _CategoryScreenState extends State<CategoryScreen> {
  String _search = '';
  final _searchController = TextEditingController();

  List<Dhikr> get _filteredAdhkar {
    final all = getAdhkarByCategory(widget.category.id);
    if (_search.isEmpty) return all;
    return all.where((d) =>
        d.text.contains(_search) ||
        d.source.contains(_search) ||
        (d.benefit?.contains(_search) ?? false)).toList();
  }

  void _openTasbih(Dhikr dhikr) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => TasbihCounter(dhikr: dhikr)),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredAdhkar;
    final cat = widget.category;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.black,
        appBar: AppBar(
          backgroundColor: AppColors.black,
          foregroundColor: AppColors.gold,
          title: BilingualText(
            tBoth('adhkar.cat.${cat.id}'),
            style: const TextStyle(
                color: AppColors.gold, fontSize: 17, fontWeight: FontWeight.w600),
            maxLines: 2,
          ),
          centerTitle: true,
        ),
        body: Column(
          children: [
            // Header: the title is already in the app bar, so only the guidance
            // on when to say these adhkar earns its space here.
            Container(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: AppColors.goldBorder)),
              ),
              child: Text(
                cat.description,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 13),
              ),
            ),

            // Search
            Padding(
              padding: const EdgeInsets.all(12),
              child: TextField(
                controller: _searchController,
                onChanged: (v) => setState(() => _search = v),
                textAlign: TextAlign.right,
                textDirection: TextDirection.rtl,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: InputDecoration(
                  hintText: 'ابحث في ${cat.name}...',
                  hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 14),
                  filled: true,
                  fillColor: AppColors.blackSurface,
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
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  suffixIcon: const Icon(Icons.search, color: AppColors.textMuted),
                ),
              ),
            ),

            // List
            Expanded(
              child: filtered.isEmpty
                  ? const Center(
                      child: Text('لا توجد نتائج',
                          style: TextStyle(color: AppColors.textMuted, fontSize: 16)),
                    )
                  : ListView.builder(
                      itemCount: filtered.length,
                      padding: const EdgeInsets.only(bottom: 24),
                      itemBuilder: (context, index) => AdhkarCard(
                        dhikr: filtered[index],
                        fontSize: FontSizeOption.medium,
                        onTasbih: () => _openTasbih(filtered[index]),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
