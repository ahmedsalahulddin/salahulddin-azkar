import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../constants/theme.dart';

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
  }

  Future<void> _refresh() async {
    final cards = await MyCards.list();
    if (mounted) {
      setState(() {
        _cards = cards;
        _loaded = true;
      });
    }
  }

  Future<void> _add() async {
    try {
      final added = await MyCards.add();
      if (added != null) await _refresh();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('تعذّر إضافة الصورة', textAlign: TextAlign.right),
          backgroundColor: AppColors.blackCard,
          behavior: SnackBarBehavior.floating,
        ));
      }
    }
  }

  Future<void> _share(File file) async {
    await SharePlus.instance.share(ShareParams(files: [XFile(file.path)]));
  }

  /// Deleting someone's own card deserves a question; there is no undo.
  Future<void> _confirmDelete(File file) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: AppColors.blackCard,
          title: const Text('حذف البطاقة؟',
              style: TextStyle(color: AppColors.gold, fontSize: 17)),
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
    if (yes == true) {
      await MyCards.remove(file);
      await _refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.black,
        appBar: AppBar(
          title: const Text('كروتي'),
          backgroundColor: AppColors.black,
          foregroundColor: AppColors.gold,
        ),
        floatingActionButton: FloatingActionButton.extended(
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
                : GridView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 14,
                      crossAxisSpacing: 14,
                      childAspectRatio: 4 / 5,
                    ),
                    itemCount: _cards.length,
                    itemBuilder: (context, i) => _tile(_cards[i]),
                  ),
      ),
    );
  }

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

  Widget _tile(File file) {
    return GestureDetector(
      onTap: () => _share(file),
      onLongPress: () => _confirmDelete(file),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.goldBorder),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.file(file, fit: BoxFit.cover),
            // What a tap does, said on the card itself.
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 4),
                color: Colors.black.withValues(alpha: 0.55),
                child: const Text(
                  'اضغط للإرسال · مطوّلاً للحذف',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textGold, fontSize: 9.5),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
