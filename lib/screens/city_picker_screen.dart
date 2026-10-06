import 'dart:async';

import 'package:flutter/material.dart';

import '../constants/theme.dart';
import '../l10n/strings.dart';
import '../services/app_locale.dart';
import '../services/prayer_place.dart';

/// What the reader settled on in [CityPickerScreen].
enum CityChoice { myLocation, city }

/// Search a city by name and use its prayer times, or go back to the phone's
/// own location. Pops with the [CityChoice] made, or null if left untouched.
class CityPickerScreen extends StatefulWidget {
  const CityPickerScreen({super.key});

  @override
  State<CityPickerScreen> createState() => _CityPickerScreenState();
}

class _CityPickerScreenState extends State<CityPickerScreen> {
  final _query = TextEditingController();
  Timer? _debounce;
  List<PrayerPlace> _results = const [];
  bool _searching = false;
  bool _failed = false;
  int _searchId = 0;

  @override
  void dispose() {
    _debounce?.cancel();
    _query.dispose();
    super.dispose();
  }

  void _onChanged(String text) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 450), () => _search(text));
  }

  Future<void> _search(String text) async {
    final id = ++_searchId;
    if (text.trim().length < 2) {
      setState(() {
        _results = const [];
        _searching = false;
        _failed = false;
      });
      return;
    }
    setState(() {
      _searching = true;
      _failed = false;
    });
    try {
      final found = await PrayerPlace.search(text);
      if (!mounted || id != _searchId) return;
      setState(() {
        _results = found;
        _searching = false;
      });
    } catch (_) {
      if (!mounted || id != _searchId) return;
      setState(() {
        _results = const [];
        _searching = false;
        _failed = true;
      });
    }
  }

  Future<void> _pick(PrayerPlace? place) async {
    await PrayerPlace.choose(place);
    if (!mounted) return;
    Navigator.pop(
      context,
      place == null ? CityChoice.myLocation : CityChoice.city,
    );
  }

  @override
  Widget build(BuildContext context) {
    final current = PrayerPlace.current.value;
    final typed = _query.text.trim().length >= 2;
    return Directionality(
      textDirection: AppLocale.direction,
      child: Scaffold(
        backgroundColor: AppColors.black,
        appBar: AppBar(
          backgroundColor: AppColors.black,
          foregroundColor: AppColors.gold,
          title: Text(t('place.title')),
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          children: [
            TextField(
              controller: _query,
              autofocus: true,
              onChanged: _onChanged,
              onSubmitted: _search,
              textInputAction: TextInputAction.search,
              style: const TextStyle(color: AppColors.textPrimary),
              cursorColor: AppColors.gold,
              decoration: InputDecoration(
                hintText: t('place.search'),
                hintStyle: const TextStyle(color: AppColors.textMuted),
                prefixIcon: const Icon(Icons.search, color: AppColors.gold),
                suffixIcon: _searching
                    ? const Padding(
                        padding: EdgeInsets.all(14),
                        child: SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.gold,
                          ),
                        ),
                      )
                    : null,
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
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: AppColors.gold),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              t('place.hint'),
              style: const TextStyle(
                color: AppColors.textMuted,
                fontSize: 12,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 12),
            _tile(
              icon: Icons.my_location,
              title: t('place.myLocation'),
              sub: t('place.myLocationSub'),
              selected: current == null,
              onTap: () => _pick(null),
            ),
            if (current != null && !typed)
              _tile(
                icon: Icons.location_city,
                title: current.name,
                sub: current.where,
                selected: true,
                onTap: () => Navigator.pop(context),
              ),
            if (_failed) _note(t('place.failed')),
            if (typed && !_searching && !_failed && _results.isEmpty)
              _note(t('place.noResults')),
            for (final p in _results)
              _tile(
                icon: Icons.location_on_outlined,
                title: p.name,
                sub: p.where,
                selected: current != null && current.sameAs(p),
                onTap: () => _pick(p),
              ),
          ],
        ),
      ),
    );
  }

  Widget _note(String text) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 18),
    child: Text(
      text,
      textAlign: TextAlign.center,
      style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
    ),
  );

  Widget _tile({
    required IconData icon,
    required String title,
    required String sub,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: selected ? AppColors.goldMuted : AppColors.blackCard,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: selected ? AppColors.gold : AppColors.goldBorder,
              ),
            ),
            child: Row(
              children: [
                Icon(icon, color: AppColors.gold, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (sub.isNotEmpty)
                        Text(
                          sub,
                          style: const TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 12,
                          ),
                        ),
                    ],
                  ),
                ),
                if (selected)
                  const Icon(
                    Icons.check_circle,
                    color: AppColors.gold,
                    size: 20,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
