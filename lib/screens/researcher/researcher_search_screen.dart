import 'dart:async';

import 'package:flutter/material.dart';

import '../../constants/theme.dart';
import '../../data/quran_data.dart';
import '../../data/researcher_data.dart';
import '../../l10n/strings.dart';
import '../../services/app_locale.dart';

/// Searches the books downloaded on this device. Pops with the hit the
/// reader opens.
class ResearcherSearchScreen extends StatefulWidget {
  const ResearcherSearchScreen({super.key});

  @override
  State<ResearcherSearchScreen> createState() => _ResearcherSearchScreenState();
}

class _ResearcherSearchScreenState extends State<ResearcherSearchScreen> {
  final _query = TextEditingController();
  Timer? _debounce;
  List<ResearcherHit> _hits = const [];
  bool _searching = false;
  int _downloaded = -1;
  Map<int, String> _surahNames = const {};
  int _run = 0;

  @override
  void initState() {
    super.initState();
    _prepare();
  }

  Future<void> _prepare() async {
    var n = 0;
    for (final b in await ResearcherService.catalog()) {
      if (await ResearcherService.isDownloaded(b)) n++;
    }
    final names = {
      for (final s in await QuranService.index()) s.number: s.name,
    };
    if (mounted) {
      setState(() {
        _downloaded = n;
        _surahNames = names;
      });
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _query.dispose();
    super.dispose();
  }

  void _changed(String q) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () => _search(q));
  }

  Future<void> _search(String q) async {
    final run = ++_run;
    if (q.trim().length < 2) {
      setState(() {
        _hits = const [];
        _searching = false;
      });
      return;
    }
    setState(() => _searching = true);
    final hits = await ResearcherService.search(q);
    if (!mounted || run != _run) return;
    setState(() {
      _hits = hits;
      _searching = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final typed = _query.text.trim().length >= 2;
    return Directionality(
      textDirection: AppLocale.direction,
      child: Scaffold(
        backgroundColor: AppColors.black,
        appBar: AppBar(
          backgroundColor: AppColors.black,
          foregroundColor: AppColors.gold,
          title: Text(t('researcher.search')),
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 30),
          children: [
            TextField(
              controller: _query,
              autofocus: true,
              onChanged: _changed,
              onSubmitted: _search,
              textInputAction: TextInputAction.search,
              // Searches the Arabic books.
              textDirection: TextDirection.rtl,
              style: const TextStyle(color: AppColors.textPrimary),
              cursorColor: AppColors.gold,
              decoration: InputDecoration(
                hintText: t('researcher.searchHint'),
                hintStyle: const TextStyle(color: AppColors.textMuted),
                prefixIcon: const Icon(Icons.search, color: AppColors.gold),
                filled: true,
                fillColor: AppColors.blackCard,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: AppColors.goldBorder),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: AppColors.goldBorder),
                ),
              ),
            ),
            const SizedBox(height: 8),
            if (_downloaded >= 0)
              Text(
                _downloaded == 0
                    ? t('researcher.searchNoBooks')
                    : t(
                        'researcher.searchScope',
                      ).replaceFirst('%s', AppLocale.digits(_downloaded)),
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 12,
                ),
              ),
            const SizedBox(height: 12),
            if (_searching)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(
                  child: CircularProgressIndicator(color: AppColors.gold),
                ),
              )
            else if (typed && _hits.isEmpty && _downloaded > 0)
              Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  t('researcher.noResults'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.textMuted),
                ),
              ),
            for (final h in _hits)
              Card(
                color: AppColors.blackCard,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(color: AppColors.goldBorder),
                ),
                child: ListTile(
                  onTap: () => Navigator.pop(context, h),
                  title: Text(
                    '${h.book.name} — ${_surahNames[h.surah] ?? ''} ${QuranService.toArabicDigits(h.ayah)}',
                    textDirection: TextDirection.rtl,
                    style: const TextStyle(
                      color: AppColors.gold,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  subtitle: Text(
                    h.snippet,
                    textDirection: TextDirection.rtl,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                      height: 1.6,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
