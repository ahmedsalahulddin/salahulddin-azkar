import '../data/adhkar_data.dart';
import '../data/hisn_data.dart';
import 'storage_service.dart';

/// One saved dhikr, whichever part of the app it was starred in.
///
/// The favourites used to be a filter over the categorised adhkar, which is
/// why only those seven categories had a star: everything in Hisn al-Muslim —
/// the 132 chapters that are the bulk of the section — could be read but never
/// kept. An entry now carries its own text, so the tab can hold both.
class FavouriteEntry {
  final String id;

  /// The dhikr as it will be shown, already resolved from its source.
  final String text;

  /// Where it was starred: the category name, or the chapter of Hisn.
  final String origin;

  /// Set for the categorised adhkar, so the existing card keeps its counter,
  /// its benefit note and its recitation.
  final Dhikr? dhikr;

  /// Set for the adhkar of Hisn al-Muslim.
  final HisnDhikr? hisn;

  const FavouriteEntry({
    required this.id,
    required this.text,
    required this.origin,
    this.dhikr,
    this.hisn,
  });
}

/// Resolves stored favourite ids back into readable adhkar.
///
/// Ids are namespaced rather than numbered: a categorised dhikr keeps the
/// plain id it has always had — `morning-6` — so nobody's saved adhkar are
/// lost, and a chapter of Hisn is `hisn/104/2`. An id that no longer resolves
/// is dropped from the list rather than shown as a blank card.
class Favourites {
  static const _hisnPrefix = 'hisn/';

  static String hisnId(int chapterId, int number) =>
      '$_hisnPrefix$chapterId/$number';

  static bool isHisn(String id) => id.startsWith(_hisnPrefix);

  /// (chapterId, number) for a Hisn id, or null if it is not one or is
  /// malformed — an id written by a newer build, or a truncated sync row.
  static (int, int)? _parseHisn(String id) {
    if (!isHisn(id)) return null;
    final parts = id.substring(_hisnPrefix.length).split('/');
    if (parts.length != 2) return null;
    final chapter = int.tryParse(parts[0]);
    final number = int.tryParse(parts[1]);
    if (chapter == null || number == null) return null;
    return (chapter, number);
  }

  /// Every favourite, in the order it was starred.
  static Future<List<FavouriteEntry>> resolve() async {
    final ids = await StorageService.getFavorites();
    if (ids.isEmpty) return const [];

    final byId = {for (final d in adhkar) d.id: d};
    final categoryNames = {for (final c in categories) c.id: c.name};

    // Only read the chapters when a Hisn favourite is actually stored; most
    // readers have none, and the file is the largest asset in the app.
    List<HisnChapter> chapters = const [];
    if (ids.any(isHisn)) {
      try {
        chapters = await HisnService.chapters();
      } catch (_) {
        // Unreadable data drops the Hisn favourites from this listing rather
        // than emptying the whole tab.
      }
    }
    final chapterById = {for (final c in chapters) c.id: c};

    final entries = <FavouriteEntry>[];
    for (final id in ids) {
      final dhikr = byId[id];
      if (dhikr != null) {
        entries.add(FavouriteEntry(
          id: id,
          text: dhikr.text,
          origin: categoryNames[dhikr.categoryId] ?? '',
          dhikr: dhikr,
        ));
        continue;
      }

      final parsed = _parseHisn(id);
      if (parsed == null) continue;
      final chapter = chapterById[parsed.$1];
      if (chapter == null) continue;
      final item =
          chapter.items.where((i) => i.number == parsed.$2).firstOrNull;
      if (item == null) continue;

      entries.add(FavouriteEntry(
        id: id,
        text: item.text,
        origin: chapter.title,
        hisn: item,
      ));
    }
    return entries;
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
