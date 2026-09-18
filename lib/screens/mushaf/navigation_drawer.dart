import 'package:flutter/material.dart';
import '../../constants/theme.dart';
import '../../data/quran_data.dart';
import '../../l10n/strings.dart';
import '../../services/bookmark_service.dart';
import 'appearance_tabs.dart';
import 'browse_tabs.dart';
import 'downloads_tab.dart';

/// Everything the reader can reach without leaving the page: where to go, what
/// to search, what is saved, and what the page looks like.
class MushafNavigationDrawer extends StatelessWidget {
  final List<SurahInfo> index;
  final List<MushafPage> pages;
  final ValueChanged<SurahInfo> onSurah;
  final ValueChanged<int> onPage;
  final ValueChanged<Bookmark> onBookmark;

  const MushafNavigationDrawer({
    super.key,
    required this.index,
    required this.pages,
    required this.onSurah,
    required this.onPage,
    required this.onBookmark,
  });

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: AppColors.black,
      width: MediaQuery.sizeOf(context).width * 0.92,
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: SafeArea(
          child: _DrawerBody(
            index: index,
            pages: pages,
            onSurah: onSurah,
            onPage: onPage,
            onBookmark: onBookmark,
          ),
        ),
      ),
    );
  }
}

/// Tabs run down the side rather than across the top: five Arabic labels do
/// not fit on one line on a phone, and a scrolling tab strip hides whichever
/// ones happen to be off-screen.
class _DrawerBody extends StatefulWidget {
  final List<SurahInfo> index;
  final List<MushafPage> pages;
  final ValueChanged<SurahInfo> onSurah;
  final ValueChanged<int> onPage;
  final ValueChanged<Bookmark> onBookmark;

  const _DrawerBody({
    required this.index,
    required this.pages,
    required this.onSurah,
    required this.onPage,
    required this.onBookmark,
  });

  @override
  State<_DrawerBody> createState() => _DrawerBodyState();
}

class _DrawerBodyState extends State<_DrawerBody> {
  int _tab = 0;

  List<({IconData icon, String label})> get _tabs => [
    (icon: Icons.menu_book, label: t('mushaf.tabSurahs')),
    (icon: Icons.auto_stories, label: t('mushaf.tabJuz')),
    (icon: Icons.search, label: t('mushaf.tabWords')),
    (icon: Icons.bookmark, label: t('mushaf.tabBookmarks')),
    (icon: Icons.download, label: t('mushaf.tabDownloads')),
    (icon: Icons.filter_frames, label: t('mushaf.tabFrame')),
    (icon: Icons.palette, label: t('mushaf.tabColor')),
  ];

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _rail(),
        const VerticalDivider(width: 1, color: AppColors.goldBorder),
        Expanded(
          child: IndexedStack(
            index: _tab,
            children: [
              SurahTab(index: widget.index, onSurah: widget.onSurah),
              JuzTab(pages: widget.pages, onPage: widget.onPage),
              WordSearchTab(onGoTo: widget.onSurah, index: widget.index),
              BookmarksTab(index: widget.index, onBookmark: widget.onBookmark),
              const DownloadsTab(),
              const FrameTab(),
              const PaletteTab(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _rail() {
    return Container(
      width: 78,
      color: AppColors.blackCard,
      child: Column(
        children: [
          const SizedBox(height: 10),
          Text(
            t('mushaf.browse'),
            style: const TextStyle(
              color: AppColors.gold,
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          for (var i = 0; i < _tabs.length; i++) _railItem(i),
        ],
      ),
    );
  }

  Widget _railItem(int i) {
    final active = _tab == i;
    return GestureDetector(
      onTap: () => setState(() => _tab = i),
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: active ? AppColors.goldMuted : Colors.transparent,
          border: Border(
            right: BorderSide(
              color: active ? AppColors.gold : Colors.transparent,
              width: 3,
            ),
          ),
        ),
        child: Column(
          children: [
            Icon(
              _tabs[i].icon,
              size: 20,
              color: active ? AppColors.gold : AppColors.textMuted,
            ),
            const SizedBox(height: 4),
            Text(
              _tabs[i].label,
              style: TextStyle(
                color: active ? AppColors.gold : AppColors.textMuted,
                fontSize: 11,
                fontWeight: active ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
