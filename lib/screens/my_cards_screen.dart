import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../constants/theme.dart';
import '../services/my_cards_meta.dart';

/// The reader's own cards: pictures added from the phone, kept in the app's
/// folder so they are there next Eid too, and shared like any other card.
class MyCards {
  static Future<Directory> _dir() async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory('${base.path}/my_cards');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  /// Newest first — the card just added is the one about to be sent.
  static Future<List<File>> list() async {
    final dir = await _dir();
    final files = await dir
        .list()
        .where((e) => e is File)
        .cast<File>()
        .toList();
    files.sort((a, b) => b.path.compareTo(a.path));
    return files;
  }

  /// Copies a picked image into the folder. The copy is the point: the card
  /// must survive the original being deleted from the gallery.
  static Future<File?> add() async {
    final picked = await ImagePicker()
        .pickImage(source: ImageSource.gallery, imageQuality: 92);
    if (picked == null) return null;

    final dir = await _dir();
    final stamp = DateTime.now().millisecondsSinceEpoch;
    final extension = picked.path.split('.').last.toLowerCase();
    return File(picked.path).copy('${dir.path}/card_$stamp.$extension');
  }

  static Future<void> remove(File file) async {
    if (await file.exists()) await file.delete();
    await MyCardsMeta.forget(nameOf(file));
  }

  static String nameOf(File file) => file.path.split('/').last;

  /// The card's name if it was given one, otherwise the day it was added —
  /// never the file name, which says nothing to anyone.
  static String labelFor(File file) {
    final title = MyCardsMeta.titleOf(nameOf(file));
    if (title.isNotEmpty) return title;

    final stamp = int.tryParse(
        RegExp(r'card_(\d+)').firstMatch(nameOf(file))?.group(1) ?? '');
    if (stamp == null) return 'بطاقة';
    final at = DateTime.fromMillisecondsSinceEpoch(stamp);
    return '${at.year}/${at.month}/${at.day}';
  }

  static int _stampOf(File file) =>
      int.tryParse(
          RegExp(r'card_(\d+)').firstMatch(nameOf(file))?.group(1) ?? '') ??
      0;

  /// Applies the reader's search, group filter and order — in that order, so
  /// a search inside a group searches the group.
  static List<File> arrange(
    List<File> cards, {
    required String query,
    required String group,
    required CardSort sort,
  }) {
    var out = cards;

    if (group.isNotEmpty) {
      out = out
          .where((f) => MyCardsMeta.groupOf(nameOf(f)) == group)
          .toList();
    }

    final needle = query.trim();
    if (needle.isNotEmpty) {
      out = out
          .where((f) =>
              labelFor(f).contains(needle) ||
              MyCardsMeta.groupOf(nameOf(f)).contains(needle))
          .toList();
    } else {
      out = [...out];
    }

    switch (sort) {
      case CardSort.newest:
        out.sort((a, b) => _stampOf(b).compareTo(_stampOf(a)));
      case CardSort.oldest:
        out.sort((a, b) => _stampOf(a).compareTo(_stampOf(b)));
      case CardSort.name:
        out.sort((a, b) => labelFor(a).compareTo(labelFor(b)));
      case CardSort.group:
        // Cards with no group sit after the named ones rather than first,
        // where an empty string would otherwise put them.
        out.sort((a, b) {
          final ga = MyCardsMeta.groupOf(nameOf(a));
          final gb = MyCardsMeta.groupOf(nameOf(b));
          if (ga.isEmpty != gb.isEmpty) return ga.isEmpty ? 1 : -1;
          final byGroup = ga.compareTo(gb);
          return byGroup != 0 ? byGroup : _stampOf(b).compareTo(_stampOf(a));
        });
    }
    return out;
  }
}

class MyCardsScreen extends StatefulWidget {
  const MyCardsScreen({super.key});

  @override
  State<MyCardsScreen> createState() => _MyCardsScreenState();
}

class _MyCardsScreenState extends State<MyCardsScreen> {
  List<File> _cards = const [];
  bool _loaded = false;

  final _search = TextEditingController();
  String _query = '';
  String _group = '';
  CardSort _sort = CardSort.newest;

  /// The cards picked for deleting. Empty means the screen is in its normal
  /// state; anything in it turns the bar into a selection bar.
  final _picked = <String>{};

  @override
  void initState() {
    super.initState();
    // The web preview has no filesystem to keep cards in; say so instead of
    // crashing on the first directory call.
    if (!kIsWeb) {
      _refresh();
    } else {
      _loaded = true;
    }
    MyCardsMeta.revision.addListener(_onMetaChanged);
  }

  @override
  void dispose() {
    MyCardsMeta.revision.removeListener(_onMetaChanged);
    _search.dispose();
    super.dispose();
  }

  void _onMetaChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _refresh() async {
    await MyCardsMeta.load();
    final cards = await MyCards.list();
    if (mounted) {
      setState(() {
        _cards = cards;
        _loaded = true;
        _picked.removeWhere(
            (name) => !cards.any((f) => MyCards.nameOf(f) == name));
      });
    }
  }

  Future<void> _add() async {
    try {
      final added = await MyCards.add();
      if (added != null) await _refresh();
    } catch (_) {
      _say('تعذّر إضافة الصورة');
    }
  }

  void _say(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(message, textAlign: TextAlign.right),
        backgroundColor: AppColors.blackCard,
        behavior: SnackBarBehavior.floating,
      ));
  }

  Future<void> _share(File file) async {
    await SharePlus.instance.share(ShareParams(files: [XFile(file.path)]));
  }

  // ---- one card ----------------------------------------------------------

  /// Everything a single card can do, on a tap — the long press that used to
  /// be the only way to delete was a gesture nobody had been told about.
  void _actions(File file) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.blackCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 6),
                child: Text(
                  MyCards.labelFor(file),
                  style: const TextStyle(color: AppColors.gold, fontSize: 15),
                ),
              ),
              _sheetItem(Icons.share, 'إرسال', () {
                Navigator.pop(ctx);
                _share(file);
              }),
              _sheetItem(Icons.drive_file_rename_outline, 'تسمية', () {
                Navigator.pop(ctx);
                _rename(file);
              }),
              _sheetItem(Icons.folder_outlined, 'المجموعة', () {
                Navigator.pop(ctx);
                _setGroup(file);
              }),
              _sheetItem(Icons.delete_outline, 'حذف', () {
                Navigator.pop(ctx);
                _confirmDelete([file]);
              }, danger: true),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sheetItem(IconData icon, String label, VoidCallback onTap,
      {bool danger = false}) {
    final tint = danger ? AppColors.error : AppColors.textPrimary;
    return ListTile(
      leading: Icon(icon, color: tint, size: 20),
      title: Text(label, style: TextStyle(color: tint, fontSize: 14)),
      onTap: onTap,
    );
  }

  Future<void> _rename(File file) async {
    final name = MyCards.nameOf(file);
    final value = await _ask(
      title: 'اسم البطاقة',
      initial: MyCardsMeta.titleOf(name),
      hint: 'عيد الفطر ٤٦',
    );
    if (value == null) return;
    await MyCardsMeta.set(name, title: value);
  }

  Future<void> _setGroup(File file) async {
    final name = MyCards.nameOf(file);
    final value = await _ask(
      title: 'المجموعة',
      initial: MyCardsMeta.groupOf(name),
      hint: 'الأعياد',
      suggestions: MyCardsMeta.groups(),
    );
    if (value == null) return;
    await MyCardsMeta.set(name, group: value);
  }

  /// One dialog for both the name and the group; the suggestions are whatever
  /// the reader has already used, so groups stay a short list instead of
  /// twelve spellings of the same word.
  Future<String?> _ask({
    required String title,
    required String initial,
    required String hint,
    List<String> suggestions = const [],
  }) {
    final controller = TextEditingController(text: initial);
    return showDialog<String>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: AppColors.blackCard,
          title: Text(title,
              style: const TextStyle(color: AppColors.gold, fontSize: 16)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: controller,
                autofocus: true,
                textDirection: TextDirection.rtl,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: InputDecoration(
                  hintText: hint,
                  hintStyle: const TextStyle(color: AppColors.textMuted),
                  enabledBorder: const UnderlineInputBorder(
                      borderSide: BorderSide(color: AppColors.goldBorder)),
                  focusedBorder: const UnderlineInputBorder(
                      borderSide: BorderSide(color: AppColors.gold)),
                ),
                onSubmitted: (v) => Navigator.pop(ctx, v),
              ),
              if (suggestions.isNotEmpty) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final s in suggestions)
                      GestureDetector(
                        onTap: () => Navigator.pop(ctx, s),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.goldMuted,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: AppColors.goldBorder),
                          ),
                          child: Text(s,
                              style: const TextStyle(
                                  color: AppColors.textGold, fontSize: 12)),
                        ),
                      ),
                  ],
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('إلغاء',
                  style: TextStyle(color: AppColors.textMuted)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, controller.text),
              child:
                  const Text('حفظ', style: TextStyle(color: AppColors.gold)),
            ),
          ],
        ),
      ),
    );
  }

  /// Deleting someone's own card deserves a question; there is no undo.
  Future<void> _confirmDelete(List<File> files) async {
    if (files.isEmpty) return;
    final many = files.length > 1;
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: AppColors.blackCard,
          title: Text(many ? 'حذف ${files.length} بطاقات؟' : 'حذف البطاقة؟',
              style: const TextStyle(color: AppColors.gold, fontSize: 17)),
          content: const Text('تُحذف من كروتك نهائياً.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('إبقاء',
                  style: TextStyle(color: AppColors.textMuted)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child:
                  const Text('حذف', style: TextStyle(color: AppColors.error)),
            ),
          ],
        ),
      ),
    );
    if (yes != true) return;

    for (final file in files) {
      await MyCards.remove(file);
    }
    _picked.clear();
    await _refresh();
  }

  // ---- the screen --------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final visible = MyCards.arrange(_cards,
        query: _query, group: _group, sort: _sort);
    final selecting = _picked.isNotEmpty;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.black,
        appBar: AppBar(
          title: Text(selecting ? 'اخترت ${_picked.length}' : 'كروتي'),
          backgroundColor: AppColors.black,
          foregroundColor: AppColors.gold,
          leading: selecting
              ? IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => setState(_picked.clear),
                  tooltip: 'إلغاء الاختيار',
                )
              : null,
          actions: [
            if (selecting)
              IconButton(
                icon: const Icon(Icons.delete_outline, color: AppColors.error),
                tooltip: 'حذف المختار',
                onPressed: () => _confirmDelete(visible
                    .where((f) => _picked.contains(MyCards.nameOf(f)))
                    .toList()),
              )
            else if (_cards.isNotEmpty)
              _sortButton(),
          ],
        ),
        floatingActionButton: selecting
            ? null
            : FloatingActionButton.extended(
                onPressed: _add,
                backgroundColor: AppColors.goldDark,
                foregroundColor: AppColors.white,
                icon: const Icon(Icons.add_photo_alternate),
                label: const Text('أضف كرتاً'),
              ),
        body: kIsWeb
            ? const Center(
                child: Padding(
                  padding: EdgeInsets.all(28),
                  child: Text(
                    'كروتك تُحفظ على جوالك — هذا القسم يعمل في التطبيق لا في المتصفح.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 14,
                        height: 1.7),
                  ),
                ),
              )
            : !_loaded
                ? const Center(
                    child: CircularProgressIndicator(color: AppColors.gold))
                : _cards.isEmpty
                    ? _empty()
                    : Column(
                        children: [
                          // The tools only appear once there is enough to sort:
                          // three cards need no search box.
                          if (_cards.length > 5) _searchField(),
                          if (MyCardsMeta.groups().isNotEmpty) _groupChips(),
                          Expanded(
                            child: visible.isEmpty
                                ? _nothingFound()
                                : GridView.builder(
                                    padding: const EdgeInsets.fromLTRB(
                                        16, 12, 16, 90),
                                    gridDelegate:
                                        const SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: 2,
                                      mainAxisSpacing: 14,
                                      crossAxisSpacing: 14,
                                      childAspectRatio: 4 / 5,
                                    ),
                                    itemCount: visible.length,
                                    itemBuilder: (context, i) =>
                                        _tile(visible[i], selecting),
                                  ),
                          ),
                        ],
                      ),
      ),
    );
  }

  Widget _sortButton() {
    return PopupMenuButton<CardSort>(
      tooltip: 'الترتيب',
      icon: const Icon(Icons.sort, size: 21),
      color: AppColors.blackCard,
      position: PopupMenuPosition.under,
      onSelected: (s) => setState(() => _sort = s),
      itemBuilder: (context) => [
        for (final s in CardSort.values)
          PopupMenuItem(
            value: s,
            height: 40,
            child: Row(
              children: [
                if (s == _sort)
                  const Icon(Icons.check, color: AppColors.gold, size: 15)
                else
                  const SizedBox(width: 15),
                const SizedBox(width: 8),
                Text(s.label,
                    style: TextStyle(
                      color: s == _sort ? AppColors.gold : AppColors.textPrimary,
                      fontSize: 13,
                    )),
              ],
            ),
          ),
      ],
    );
  }

  Widget _searchField() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 2),
      child: TextField(
        controller: _search,
        textDirection: TextDirection.rtl,
        style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
        onChanged: (v) => setState(() => _query = v),
        decoration: InputDecoration(
          isDense: true,
          hintText: 'ابحث في كروتك',
          hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 13),
          prefixIcon:
              const Icon(Icons.search, color: AppColors.textMuted, size: 19),
          suffixIcon: _query.isEmpty
              ? null
              : IconButton(
                  icon: const Icon(Icons.clear,
                      color: AppColors.textMuted, size: 17),
                  onPressed: () {
                    _search.clear();
                    setState(() => _query = '');
                  },
                ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.goldBorder),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.gold),
          ),
        ),
      ),
    );
  }

  Widget _groupChips() {
    final groups = MyCardsMeta.groups();
    return SizedBox(
      height: 42,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        children: [
          _chip('الكل', _group.isEmpty, () => setState(() => _group = '')),
          for (final g in groups)
            _chip(g, _group == g,
                () => setState(() => _group = _group == g ? '' : g)),
        ],
      ),
    );
  }

  Widget _chip(String label, bool on, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(left: 6),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: on ? AppColors.goldMuted : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
                color: on ? AppColors.gold : AppColors.goldBorder),
          ),
          child: Text(label,
              style: TextStyle(
                color: on ? AppColors.gold : AppColors.textMuted,
                fontSize: 12,
                fontWeight: on ? FontWeight.bold : FontWeight.normal,
              )),
        ),
      ),
    );
  }

  Widget _nothingFound() => const Center(
        child: Padding(
          padding: EdgeInsets.all(28),
          child: Text(
            'لا بطاقة بهذا الاسم.',
            style: TextStyle(color: AppColors.textMuted, fontSize: 14),
          ),
        ),
      );

  Widget _empty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Text('💌', style: TextStyle(fontSize: 40)),
            SizedBox(height: 12),
            Text(
              'أضف صورة من جوالك وستبقى هنا، جاهزة للإرسال في كل مناسبة.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: AppColors.textSecondary, fontSize: 14, height: 1.7),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tile(File file, bool selecting) {
    final name = MyCards.nameOf(file);
    final chosen = _picked.contains(name);
    final group = MyCardsMeta.groupOf(name);

    return GestureDetector(
      // While choosing, a tap adds to the choice; otherwise it opens what the
      // card can do. Nothing is destroyed by a tap either way.
      onTap: () {
        if (selecting) {
          setState(() =>
              chosen ? _picked.remove(name) : _picked.add(name));
        } else {
          _actions(file);
        }
      },
      onLongPress: () => setState(() => _picked.add(name)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: chosen ? AppColors.gold : AppColors.goldBorder,
            width: chosen ? 2 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.file(file, fit: BoxFit.cover),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 6),
                color: Colors.black.withValues(alpha: 0.6),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      MyCards.labelFor(file),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          color: AppColors.textGold, fontSize: 11),
                    ),
                    if (group.isNotEmpty)
                      Text(
                        group,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: AppColors.textMuted, fontSize: 9),
                      ),
                  ],
                ),
              ),
            ),
            if (selecting)
              Positioned(
                top: 6,
                right: 6,
                child: Icon(
                  chosen ? Icons.check_circle : Icons.circle_outlined,
                  color: chosen ? AppColors.gold : AppColors.white,
                  size: 22,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
