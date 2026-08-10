import 'package:flutter/material.dart';
import '../constants/theme.dart';
import '../data/adhkar_data.dart';
import '../services/storage_service.dart';
import '../widgets/adhkar_card.dart';
import '../widgets/tasbih_counter.dart';

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  List<Dhikr> _favorites = [];

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
    super.dispose();
  }

  Future<void> _loadFavorites() async {
    final favIds = await StorageService.getFavorites();
    if (mounted) {
      setState(() {
        _favorites = adhkar.where((d) => favIds.contains(d.id)).toList();
      });
    }
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
                          itemBuilder: (context, index) => AdhkarCard(
                            dhikr: _favorites[index],
                            fontSize: FontSizeOption.medium,
                            onTasbih: () => _openTasbih(_favorites[index]),
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
