import 'package:flutter/material.dart';
import '../constants/theme.dart';
import '../data/adhkar_data.dart';
import '../data/quran_data.dart' show QuranService;
import '../l10n/strings.dart';
import '../services/favourites.dart';
import '../services/storage_service.dart';
import '../widgets/adhkar_card.dart';
import '../widgets/dhikr_audio.dart';
import '../widgets/dhikr_text.dart';
import '../widgets/favourite_star.dart';
import '../widgets/speak_button.dart';
import '../widgets/tasbih_counter.dart';

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  List<FavouriteEntry> _favorites = [];

  /// Shared by every Hisn dhikr on this screen, so starting one stops the last.
  final _audio = DhikrAudioController();

  @override
  void initState() {
    super.initState();
    _loadFavorites();
    // This screen is kept alive by the IndexedStack, so it has to be told when
    // a star is tapped elsewhere rather than reloading on rebuild.
    StorageService.favouritesRevision.addListener(_loadFavorites);
  }

  @override
  void dispose() {
    StorageService.favouritesRevision.removeListener(_loadFavorites);
    _audio.dispose();
    // Leaving the tab ends the reading; a voice with no screen behind it has
    // no way to be stopped.
    Tts.stop();
    super.dispose();
  }

  Future<void> _loadFavorites() async {
    final entries = await Favourites.resolve();
    if (mounted) setState(() => _favorites = entries);
  }

  /// A categorised dhikr keeps the card it always had; one from Hisn gets a
  /// plainer card that still says where it came from and can be read aloud.
  /// Reads the whole list aloud, in order, text only.
  ///
  /// The recorded recitation belongs to one dhikr and names its chapter
  /// first; going through twenty of them meant twenty announcements. This
  /// reads the words themselves, once each, and moves on by itself.
  Widget _readAllBar() {
    return ValueListenableBuilder<int?>(
      valueListenable: Tts.readingIndex,
      builder: (context, at, _) {
        if (at == null) {
          return GestureDetector(
            onTap: () => Tts.readAll([for (final e in _favorites) e.text]),
            behavior: HitTestBehavior.opaque,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
              decoration: BoxDecoration(
                color: AppColors.goldMuted,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.goldBorder),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.play_arrow, color: AppColors.gold, size: 18),
                  const SizedBox(width: 6),
                  Text(
                    t('misc.readAll'),
                    style: const TextStyle(
                      color: AppColors.gold,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(
                Icons.stop_circle_outlined,
                color: AppColors.gold,
                size: 24,
              ),
              onPressed: Tts.stop,
              tooltip: t('misc.stop'),
            ),
            Text(
              t('misc.readingProgress')
                  .replaceAll('{current}', QuranService.toArabicDigits(at + 1))
                  .replaceAll(
                    '{total}',
                    QuranService.toArabicDigits(_favorites.length),
                  ),
              style: const TextStyle(color: AppColors.textGold, fontSize: 12),
            ),
            IconButton(
              icon: const Icon(
                Icons.skip_next,
                color: AppColors.textSecondary,
                size: 22,
              ),
              onPressed: Tts.skip,
              tooltip: t('misc.next'),
            ),
          ],
        );
      },
    );
  }

  Widget _card(FavouriteEntry entry, {bool reading = false}) {
    final dhikr = entry.dhikr;
    if (dhikr != null) {
      final card = AdhkarCard(
        dhikr: dhikr,
        fontSize: FontSizeOption.medium,
        onTasbih: () => _openTasbih(dhikr),
      );
      // Marked while it is the one being read, so the reader can follow along
      // a list of twenty without counting.
      return reading ? _lit(card) : card;
    }

    final card = Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
      decoration: BoxDecoration(
        color: AppColors.blackCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: reading ? AppColors.gold : AppColors.goldBorder,
          width: reading ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            entry.text,
            textAlign: TextAlign.justify,
            textDirection: TextDirection.rtl,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 18,
              height: 1.9,
            ),
          ),
          Row(
            children: [
              Expanded(
                child: Text(
                  entry.origin,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 11,
                  ),
                ),
              ),
              if (entry.hisn != null)
                DhikrListenButton(dhikr: entry.hisn!, controller: _audio),
              const SizedBox(width: 4),
              FavouriteStar(id: entry.id, size: 19, announce: false),
            ],
          ),
        ],
      ),
    );
    return card;
  }

  /// A ring around whatever is being read, for cards that draw their own
  /// border and cannot simply be told to light it.
  Widget _lit(Widget card) => Container(
    margin: const EdgeInsets.symmetric(horizontal: 10),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: AppColors.gold, width: 2),
    ),
    child: card,
  );

  void _openTasbih(Dhikr dhikr) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => TasbihCounter(dhikr: dhikr)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.black,
        body: SafeArea(
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: const BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: AppColors.goldBorder),
                  ),
                ),
                child: Column(
                  children: [
                    const Text('⭐', style: TextStyle(fontSize: 32)),
                    const SizedBox(height: 4),
                    Text(
                      t('misc.myAdhkarTitle'),
                      style: const TextStyle(
                        color: AppColors.gold,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      t(
                        'misc.savedAdhkarCount',
                      ).replaceAll('{count}', '${_favorites.length}'),
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const DhikrLangButton(),
                    if (_favorites.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      _readAllBar(),
                    ],
                  ],
                ),
              ),

              // List
              Expanded(
                child: _favorites.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text(
                              '☆',
                              style: TextStyle(
                                fontSize: 64,
                                color: AppColors.textMuted,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              t('misc.noSavedAdhkar'),
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 40,
                              ),
                              child: Text(
                                t('misc.favoritesEmptyHint'),
                                style: const TextStyle(
                                  color: AppColors.textMuted,
                                  fontSize: 14,
                                  height: 1.6,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadFavorites,
                        child: ListView.builder(
                          itemCount: _favorites.length,
                          padding: const EdgeInsets.only(bottom: 24, top: 8),
                          itemBuilder: (context, index) =>
                              ValueListenableBuilder<int?>(
                                valueListenable: Tts.readingIndex,
                                builder: (context, at, _) => _card(
                                  _favorites[index],
                                  reading: at == index,
                                ),
                              ),
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
