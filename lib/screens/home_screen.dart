import 'package:flutter/material.dart';
import '../constants/theme.dart';
import '../data/home_shelves.dart';
import '../services/section_config.dart';
import '../widgets/prayer_times_card.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final all = buildShelves();

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.black,
        body: SafeArea(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 10),

                // The verse now turns under the arch, inside the card.
                const PrayerTimesCard(),
                const SizedBox(height: 20),

                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 0, 16, 10),
                  child: Text('الأقسام',
                      style: TextStyle(
                          color: AppColors.textGold,
                          fontSize: 17,
                          fontWeight: FontWeight.bold)),
                ),

                // Visibility and order can be changed remotely; if that config
                // is unavailable every section shows in its built-in order.
                ValueListenableBuilder<Map<String, SectionSetting>>(
                  valueListenable: SectionConfig.settings,
                  builder: (context, _, _) {
                    final visible = [
                      for (var i = 0; i < all.length; i++)
                        if (SectionConfig.isVisible(all[i].key)) (all[i], i),
                    ]..sort((a, b) => SectionConfig.orderOf(a.$1.key, a.$2)
                        .compareTo(SectionConfig.orderOf(b.$1.key, b.$2)));

                    return Column(
                      children: [
                        for (final (shelf, _) in visible) _shelfRow(context, shelf),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// A shelf: its name, then one card that stays put and the rest running
  /// off the side. Pinning the first card means the thing a reader opens most
  /// is always under the thumb, however far they scrolled the row last time.
  Widget _shelfRow(BuildContext context, HomeShelf shelf) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: GestureDetector(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => shelf.all()),
              ),
              behavior: HitTestBehavior.opaque,
              child: Row(
                children: [
                  Text(shelf.icon, style: const TextStyle(fontSize: 17)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(shelf.title,
                        style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.bold)),
                  ),
                  const Text('الكل',
                      style:
                          TextStyle(color: AppColors.textGold, fontSize: 12)),
                  const Icon(Icons.chevron_left,
                      color: AppColors.textGold, size: 18),
                ],
              ),
            ),
          ),
          SizedBox(
            // Tall enough for a two-line title plus its subtitle; anything
            // less and the longer adhkar names overflow the card.
            height: 124,
            child: Row(
              children: [
                const SizedBox(width: 16),
                _shelfCard(context, shelf.pinned, shelf.tint, pinned: true),
                const SizedBox(width: 8),
                Expanded(
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.only(left: 16),
                    itemCount: shelf.rest.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    itemBuilder: (context, i) =>
                        _shelfCard(context, shelf.rest[i], shelf.tint),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _shelfCard(BuildContext context, ShelfItem item, Color tint,
      {bool pinned = false}) {
    return GestureDetector(
      onTap: () => item.open(context),
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 116,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
        decoration: BoxDecoration(
          color: AppColors.blackCard,
          borderRadius: BorderRadius.circular(14),
          // The pinned card carries the full gold edge; the rest are quieter,
          // so the row reads as "this one, and then the others".
          border: Border.all(
              color: pinned ? AppColors.gold : AppColors.goldBorder),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: tint,
                borderRadius: BorderRadius.circular(11),
              ),
              child: Center(
                  child: Text(item.icon, style: const TextStyle(fontSize: 19))),
            ),
            const SizedBox(height: 7),
            Text(item.title,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 12,
                    height: 1.25,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 2),
            Text(item.subtitle,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style:
                    const TextStyle(color: AppColors.textMuted, fontSize: 10)),
          ],
        ),
      ),
    );
  }
}
