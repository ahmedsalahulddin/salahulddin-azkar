import 'package:flutter/material.dart';
import '../constants/theme.dart';
import '../data/library_data.dart';
import '../l10n/strings.dart';
import '../services/app_locale.dart';
import 'book_reader_screen.dart';

/// The shelf: three short collections ready to read, the canonical books a tap
/// away.
class BooksScreen extends StatefulWidget {
  const BooksScreen({super.key});

  @override
  State<BooksScreen> createState() => _BooksScreenState();
}

class _BooksScreenState extends State<BooksScreen> {
  /// Book id -> already on the device.
  final _downloaded = <String, bool>{};

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    for (final book in LibraryService.books) {
      final ready = await LibraryService.isDownloaded(book);
      if (!mounted) return;
      setState(() => _downloaded[book.id] = ready);
    }
  }

  Future<void> _open(IslamicBook book) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => BookReaderScreen(book: book)),
    );
    _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final ready = LibraryService.books.where((b) => b.isBundled).toList();
    final rest = LibraryService.books.where((b) => !b.isBundled).toList();

    return Directionality(
      textDirection: AppLocale.direction,
      child: Scaffold(
        backgroundColor: AppColors.black,
        appBar: AppBar(
          title: Text(t('lib2.booksScreenTitle')),
          backgroundColor: AppColors.black,
          foregroundColor: AppColors.gold,
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 28),
          children: [
            _sectionTitle(
              t('lib2.readyToReadSection'),
              t('lib2.worksOfflineSubtitle'),
            ),
            for (final book in ready) _bookCard(book),
            const SizedBox(height: 18),
            _sectionTitle(
              t('lib2.sixBooksMuwattaSection'),
              t('lib2.downloadForOfflineSubtitle'),
            ),
            for (final book in rest) _bookCard(book),
            const SizedBox(height: 16),
            Text(
              t('lib2.booksHeritageFooter'),
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String title, String subtitle) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 6, 4, 10),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: AppColors.textGold,
            fontSize: 15,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          subtitle,
          style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
        ),
      ],
    ),
  );

  Widget _bookCard(IslamicBook book) {
    final ready = _downloaded[book.id] ?? book.isBundled;

    return GestureDetector(
      onTap: () => _open(book),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.blackCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: ready ? AppColors.goldBorder : AppColors.goldBorder,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: AppColors.goldMuted,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.goldBorder),
              ),
              child: const Center(
                child: Text('📕', style: TextStyle(fontSize: 22)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    book.title,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    book.author,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${AppLocale.digits(book.hadithCount)} '
                    '${t('lib2.hadithUnit')}'
                    '${book.isBundled ? '' : ' · ${book.downloadSize}'}',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              ready
                  ? (AppLocale.isRtl ? Icons.chevron_left : Icons.chevron_right)
                  : Icons.cloud_download_outlined,
              color: ready ? AppColors.textMuted : AppColors.gold,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}
