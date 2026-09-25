import 'package:flutter/material.dart';
import '../constants/theme.dart';
import '../data/home_shelves.dart';
import '../l10n/strings.dart';
import '../services/app_locale.dart';
import '../services/duas_service.dart';
import '../services/section_config.dart';
import '../widgets/bilingual_text.dart';
import '../widgets/language_notice_dialog.dart';
import '../widgets/prayer_times_card.dart';
import 'search_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
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
                _searchBar(context),
                const SizedBox(height: 12),

                // The verse now turns under the arch, inside the card.
                const PrayerTimesCard(),
                const SizedBox(height: 20),

                // Rebuilt whenever the locale, section-visibility config, or
                // the duas base collection changes — the last one arrives
                // asynchronously after startup, so the shelf appears as soon
                // as it resolves instead of waiting for a full app restart.
                ValueListenableBuilder<String>(
                  valueListenable: AppLocale.locale,
                  builder: (context, _, _) {
                    return ValueListenableBuilder<List<DuaCategory>>(
                      valueListenable: DuasService.baseCache,
                      builder: (context, _, _) {
                        final all = buildShelves();
                        return ValueListenableBuilder<
                          Map<String, SectionSetting>
                        >(
                          valueListenable: SectionConfig.settings,
                          builder: (context, _, _) {
                            final visible =
                                [
                                  for (var i = 0; i < all.length; i++)
                                    if (SectionConfig.isVisible(all[i].key))
                                      (all[i], i),
                                ]..sort(
                                  (a, b) =>
                                      SectionConfig.orderOf(
                                        a.$1.key,
                                        a.$2,
                                      ).compareTo(
                                        SectionConfig.orderOf(b.$1.key, b.$2),
                                      ),
                                );

                            return Column(
                              children: [
                                for (final (shelf, _) in visible)
                                  if (_withVisibleCards(shelf) case final s?)
                                    _shelfRow(context, s),
                              ],
                            );
                          },
                        );
                      },
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

  /// Filters a shelf's cards by [SectionConfig.isVisible] and re-sorts the
  /// survivors by [SectionConfig.orderOf], same as the shelves themselves —
  /// a card with no [ShelfItem.cardKey] is always kept, so nothing built
  /// outside home_shelves.dart can vanish by omission. Null means every
  /// card on this shelf is hidden, so the shelf itself has nothing to show.
  HomeShelf? _withVisibleCards(HomeShelf shelf) {
    final all = [shelf.pinned, ...shelf.rest];
    final visible =
        [
          for (var i = 0; i < all.length; i++)
            if (all[i].cardKey == null ||
                SectionConfig.isVisible(all[i].cardKey!))
              (all[i], i),
        ]..sort(
          (a, b) => SectionConfig.orderOf(
            a.$1.cardKey ?? '',
            a.$2,
          ).compareTo(SectionConfig.orderOf(b.$1.cardKey ?? '', b.$2)),
        );
    if (visible.isEmpty) return null;

    final cards = [for (final (item, _) in visible) item];
    return HomeShelf(
      key: shelf.key,
      icon: shelf.icon,
      title: shelf.title,
      tint: shelf.tint,
      all: shelf.all,
      pinned: cards.first,
      rest: cards.skip(1).toList(),
    );
  }

  /// The way into everything at once, across the full width.
  Widget _searchBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SearchScreen()),
              ),
              behavior: HitTestBehavior.opaque,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: AppColors.blackCard,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.goldBorder),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.search, color: AppColors.gold, size: 20),
                    const SizedBox(width: 10),
                    Text(
                      t('search.label'),
                      style: const TextStyle(
                        color: AppColors.gold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        t('search.hint'),
                        style: const TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 12.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          _langToggle(),
        ],
      ),
    );
  }

  /// Switches the language, then — unless the reader just picked Arabic,
  /// where nothing is missing — shows what's fully translated in it and a
  /// way to flag anything that still isn't.
  Future<void> _changeLang(BuildContext context, String code) async {
    await AppLocale.set(code);
    if (code == 'ar' || !context.mounted) return;
    await showLanguageNotice(context, code);
  }

  Widget _langToggle() {
    return ValueListenableBuilder<String>(
      valueListenable: AppLocale.locale,
      builder: (context, locale, __) => PopupMenuButton<String>(
        tooltip: AppLocale.nameOf(locale),
        color: AppColors.blackCard,
        onSelected: (code) => _changeLang(context, code),
        itemBuilder: (_) => [
          for (final (code, name) in AppLocale.languages)
            PopupMenuItem(
              value: code,
              child: Row(
                children: [
                  Icon(
                    code == locale
                        ? Icons.radio_button_checked
                        : Icons.radio_button_off,
                    size: 16,
                    color: code == locale
                        ? AppColors.gold
                        : AppColors.textMuted,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    name,
                    style: TextStyle(
                      color: code == locale
                          ? AppColors.gold
                          : AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
        ],
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.blackCard,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: locale == 'ar' ? AppColors.goldBorder : AppColors.gold,
            ),
          ),
          child: Text(
            locale == 'ar' ? 'EN' : locale.toUpperCase(),
            style: TextStyle(
              color: locale == 'ar' ? AppColors.textMuted : AppColors.gold,
              fontSize: 13,
              fontWeight: FontWeight.bold,
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
                    child: Text(
                      shelf.title,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Text(
                    t('home.seeAll'),
                    style: const TextStyle(
                      color: AppColors.textGold,
                      fontSize: 12,
                    ),
                  ),
                  const Icon(
                    Icons.chevron_left,
                    color: AppColors.textGold,
                    size: 18,
                  ),
                ],
              ),
            ),
          ),
          SizedBox(
            // Tall enough for a three-line title (Arabic name plus its
            // English translation in parentheses) plus a subtitle; anything
            // less and the longer titles overflow the card.
            height: 136,
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

  Widget _shelfCard(
    BuildContext context,
    ShelfItem item,
    Color tint, {
    bool pinned = false,
  }) {
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
            color: pinned ? AppColors.gold : AppColors.goldBorder,
          ),
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
                child: Text(item.icon, style: const TextStyle(fontSize: 19)),
              ),
            ),
            const SizedBox(height: 7),
            BilingualText(
              item.title,
              textAlign: TextAlign.center,
              maxLines: 2,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 12,
                height: 1.2,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              item.subtitle,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: AppColors.textMuted, fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }
}
