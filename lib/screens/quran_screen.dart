import 'package:flutter/material.dart';
import '../constants/theme.dart';
import '../data/quran_data.dart';
import '../services/storage_service.dart';
import 'surah_screen.dart';

class QuranScreen extends StatefulWidget {
  const QuranScreen({super.key});

  @override
  State<QuranScreen> createState() => _QuranScreenState();
}

class _QuranScreenState extends State<QuranScreen> {
  final _searchController = TextEditingController();
  List<SurahInfo> _all = [];
  String _search = '';
  int? _lastSurah;
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
    final list = await QuranService.index();
    final last = await StorageService.getLastSurah();
    if (!mounted) return;
    setState(() {
      _all = list;
      _lastSurah = last;
      _loading = false;
    });
  }

  List<SurahInfo> get _filtered {
    if (_search.isEmpty) return _all;
    final q = _search.trim();
    final qLower = q.toLowerCase();
    return _all.where((s) {
      return s.name.contains(q) ||
          s.nameEn.toLowerCase().contains(qLower) ||
          s.number.toString() == q;
    }).toList();
  }

  Future<void> _open(SurahInfo s) async {
    await StorageService.setLastSurah(s.number);
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => SurahScreen(info: s)),
    );
    if (mounted) setState(() => _lastSurah = s.number);
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    final last = _lastSurah == null
        ? null
        : _all.where((s) => s.number == _lastSurah).firstOrNull;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.black,
        appBar: AppBar(
          title: const Text('القرآن الكريم'),
          backgroundColor: AppColors.black,
          foregroundColor: AppColors.gold,
        ),
        body: _loading
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.gold))
            : Column(
                children: [
                  // Continue reading
                  if (last != null && _search.isEmpty)
                    GestureDetector(
                      onTap: () => _open(last),
                      child: Container(
                        margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [AppColors.navyLight, AppColors.navy],
                          ),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.goldBorder),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.bookmark, color: AppColors.gold, size: 22),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('متابعة القراءة',
                                      style: TextStyle(
                                          color: AppColors.textMuted, fontSize: 11)),
                                  const SizedBox(height: 2),
                                  Text('سورة ${last.name}',
                                      style: const TextStyle(
                                          color: AppColors.textGold,
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),
                            const Icon(Icons.chevron_left,
                                color: AppColors.textMuted, size: 22),
                          ],
                        ),
                      ),
                    ),

                  // Search
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: TextField(
                      controller: _searchController,
                      onChanged: (v) => setState(() => _search = v),
                      textAlign: TextAlign.right,
                      style: const TextStyle(color: AppColors.textPrimary),
                      decoration: InputDecoration(
                        hintText: 'ابحث عن سورة…',
                        hintStyle: const TextStyle(
                            color: AppColors.textMuted, fontSize: 14),
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
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        suffixIcon:
                            const Icon(Icons.search, color: AppColors.textMuted),
                      ),
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
                            padding: const EdgeInsets.only(bottom: 16),
                            itemCount: filtered.length,
                            itemBuilder: (context, i) => _surahTile(filtered[i]),
                          ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _surahTile(SurahInfo s) {
    return GestureDetector(
      onTap: () => _open(s),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.blackCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.goldBorder),
        ),
        child: Row(
          children: [
            // Number in an octagon-ish badge
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: AppColors.goldMuted,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.goldBorder),
              ),
              child: Center(
                child: Text(
                  QuranService.toArabicDigits(s.number),
                  style: const TextStyle(
                      color: AppColors.gold,
                      fontSize: 14,
                      fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(s.name,
                      style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 17,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text('${s.type} • ${s.ayahCount} آية',
                      style: const TextStyle(
                          color: AppColors.textMuted, fontSize: 12)),
                ],
              ),
            ),
            Text(s.nameEn,
                style: const TextStyle(
                    color: AppColors.textMuted, fontSize: 11)),
          ],
        ),
      ),
    );
  }
}
