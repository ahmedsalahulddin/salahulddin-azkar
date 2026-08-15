import 'package:flutter/material.dart';
import '../constants/theme.dart';
import '../data/adhkar_data.dart';
import '../services/favourites.dart';
import '../services/storage_service.dart';
import '../widgets/adhkar_card.dart';
import '../widgets/dhikr_audio.dart';
import '../widgets/favourite_star.dart';
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
    super.dispose();
  }

  Future<void> _loadFavorites() async {
    final entries = await Favourites.resolve();
    if (mounted) setState(() => _favorites = entries);
  }

  /// A categorised dhikr keeps the card it always had; one from Hisn gets a
  /// plainer card that still says where it came from and can be read aloud.
  Widget _card(FavouriteEntry entry) {
    final dhikr = entry.dhikr;
    if (dhikr != null) {
      return AdhkarCard(
        dhikr: dhikr,
        fontSize: FontSizeOption.medium,
        onTasbih: () => _openTasbih(dhikr),
      );
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
      decoration: BoxDecoration(
        color: AppColors.blackCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.goldBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            entry.text,
            textAlign: TextAlign.justify,
            textDirection: TextDirection.rtl,
            style: const TextStyle(
                color: AppColors.textPrimary, fontSize: 18, height: 1.9),
          ),
          Row(
            children: [
              Expanded(
                child: Text(
                  entry.origin,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: AppColors.textMuted, fontSize: 11),
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
  }

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
                  border: Border(bottom: BorderSide(color: AppColors.goldBorder)),
                ),
                child: Column(
                  children: [
                    const Text('⭐', style: TextStyle(fontSize: 32)),
                    const SizedBox(height: 4),
                    const Text('أذكاري',
                        style: TextStyle(color: AppColors.gold, fontSize: 24, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text('${_favorites.length} أذكار محفوظة',
                        style: const TextStyle(color: AppColors.textMuted, fontSize: 13)),
                  ],
                ),
              ),

              // List
              Expanded(
                child: _favorites.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Text('☆', style: TextStyle(fontSize: 64, color: AppColors.textMuted)),
                            SizedBox(height: 16),
                            Text('لا توجد أذكار محفوظة',
                                style: TextStyle(color: AppColors.textSecondary, fontSize: 20, fontWeight: FontWeight.bold)),
                            SizedBox(height: 8),
                            Padding(
                              padding: EdgeInsets.symmetric(horizontal: 40),
                              child: Text(
                                'اضغط على النجمة ★ في أي ذكر لإضافته إلى المفضلة',
                                style: TextStyle(color: AppColors.textMuted, fontSize: 14, height: 1.6),
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
                              _card(_favorites[index]),
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
