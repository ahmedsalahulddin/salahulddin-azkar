import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter/foundation.dart' show kIsWeb;

import '../constants/theme.dart';
import '../data/greeting_cards.dart';
import '../services/my_cards_meta.dart';
import '../widgets/greeting_card_view.dart';
import 'my_cards_screen.dart';

/// The cards on one shelf.
class CardsScreen extends StatefulWidget {
  final CardShelf shelf;

  const CardsScreen({super.key, required this.shelf});

  @override
  State<CardsScreen> createState() => _CardsScreenState();
}

class _CardsScreenState extends State<CardsScreen> {
  /// The reader's own pictures filed on this shelf, newest first.
  List<File> _mine = const [];

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) _refresh();
  }

  Future<void> _refresh() async {
    await MyCardsMeta.load();
    final all = await MyCards.list();
    final mine = all
        .where((f) => MyCardsMeta.shelfOf(MyCards.nameOf(f)) == widget.shelf.id)
        .toList();
    if (mounted) setState(() => _mine = mine);
  }

  /// Adds pictures to this shelf, asking once what they are.
  ///
  /// The question is asked before the gallery rather than after, because it
  /// decides what the reader is about to look for: a plain photograph to be
  /// written on, or a card someone already made.
  Future<void> _add() async {
    final style = await _askStyle();
    if (style == null) return;

    try {
      final files = await MyCards.addTo(widget.shelf.id, style);
      if (files == 0) return;
      await _refresh();
      if (mounted && files > 1) _toast('أُضيفت $files صور');
    } catch (_) {
      if (mounted) _toast('تعذّر إضافة الصور');
    }
  }

  Future<CardStyle?> _askStyle() {
    return showModalBottomSheet<CardStyle>(
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
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 16, 20, 2),
                child: Text('الصورة التي ستضيفها',
                    style: TextStyle(color: AppColors.gold, fontSize: 15)),
              ),
              for (final style in CardStyle.values)
                ListTile(
                  leading: Icon(
                    style == CardStyle.background
                        ? Icons.edit_note
                        : Icons.image_outlined,
                    color: AppColors.gold,
                    size: 21,
                  ),
                  title: Text(style.label,
                      style: const TextStyle(
                          color: AppColors.textPrimary, fontSize: 14)),
                  subtitle: Text(style.note,
                      style: const TextStyle(
                          color: AppColors.textMuted, fontSize: 11)),
                  onTap: () => Navigator.pop(ctx, style),
                ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(message, textAlign: TextAlign.right),
        backgroundColor: AppColors.blackCard,
        behavior: SnackBarBehavior.floating,
      ));
  }

  /// Removing one of the reader's own pictures. The built-in cards cannot be
  /// removed, so this is only ever offered on theirs.
  Future<void> _confirmDelete(File file) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: AppColors.blackCard,
          title: const Text('حذف الصورة؟',
              style: TextStyle(color: AppColors.gold, fontSize: 17)),
          content: const Text('تُحذف من هذا الرفّ نهائياً.',
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
    await MyCards.remove(file);
    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final cards = GreetingCards.of(widget.shelf);
    // The reader's own come first: they are the ones being looked for.
    final total = _mine.length + cards.length;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.black,
        appBar: AppBar(
          title: Text(widget.shelf.title),
          backgroundColor: AppColors.black,
          foregroundColor: AppColors.gold,
        ),
        floatingActionButton: kIsWeb
            ? null
            : FloatingActionButton.extended(
                onPressed: _add,
                backgroundColor: AppColors.goldDark,
                foregroundColor: AppColors.white,
                icon: const Icon(Icons.add_photo_alternate),
                label: const Text('أضف صورة'),
              ),
        body: GridView.builder(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 14,
            crossAxisSpacing: 14,
            childAspectRatio: GreetingCardView.aspectRatio,
          ),
          itemCount: total,
          itemBuilder: (context, i) => i < _mine.length
              ? _ownCard(context, _mine[i])
              : _preview(context, cards[i - _mine.length]),
        ),
      ),
    );
  }

  /// One of the reader's own pictures, opened as a card and held to delete.
  Widget _ownCard(BuildContext context, File file) {
    final style = MyCardsMeta.styleOf(MyCards.nameOf(file));

    return FutureBuilder<ResolvedCard>(
      // Its greeting and verse come from the shelf's first card: a picture
      // being written on still needs words, and these are the shelf's own.
      future: GreetingCards.resolve(GreetingCards.of(widget.shelf).first),
      builder: (context, snapshot) {
        final resolved = snapshot.data;
        return GestureDetector(
          onTap: resolved == null
              ? null
              : () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => CardViewerScreen(
                        resolved: resolved,
                        background: file,
                        bare: style == CardStyle.asIs,
                      ),
                    ),
                  ),
          onLongPress: () => _confirmDelete(file),
          child: Stack(
            fit: StackFit.expand,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: resolved == null
                    ? Image.file(file, fit: BoxFit.cover)
                    : GreetingCardView(
                        resolved: resolved,
                        background: file,
                        bare: style == CardStyle.asIs,
                      ),
              ),
              // Marked as the reader's own, and how it behaves.
              Positioned(
                top: 6,
                right: 6,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    style == CardStyle.asIs ? 'صورتك' : 'صورتك · يُكتب عليها',
                    style: const TextStyle(
                        color: AppColors.textGold, fontSize: 8.5),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _preview(BuildContext context, GreetingCard card) {
    return FutureBuilder<ResolvedCard>(
      future: GreetingCards.resolve(card),
      builder: (context, snapshot) {
        final resolved = snapshot.data;
        return GestureDetector(
          onTap: resolved == null
              ? null
              : () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => CardViewerScreen(resolved: resolved)),
                  ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: resolved == null
                ? const ColoredBox(color: AppColors.blackCard)
                : GreetingCardView(resolved: resolved),
          ),
        );
      },
    );
  }
}

/// One card, full size, with the button that sends it.
class CardViewerScreen extends StatefulWidget {
  /// How wide the shared card is, in pixels. At the card's four-by-five that
  /// is 2048 × 2560 — comfortably above what a messaging app downscales to,
  /// so its own pass still leaves the writing sharp.
  static const exportWidth = 2048.0;

  /// The multiple of the on-screen card that reaches [exportWidth].
  ///
  /// Floored at three so a large tablet still exports better than the layout,
  /// and capped at eight so a small one cannot ask for an image too big to
  /// hold in memory.
  static double exportRatio(double layoutWidth) {
    if (layoutWidth <= 0) return 3;
    return (exportWidth / layoutWidth).clamp(3.0, 8.0).toDouble();
  }

  final ResolvedCard resolved;

  /// A picture the reader added, standing in for the drawn ground.
  final File? background;

  /// True when that picture is a finished card: it is sent as it is, and only
  /// the signature is laid over it.
  final bool bare;

  const CardViewerScreen({
    super.key,
    required this.resolved,
    this.background,
    this.bare = false,
  });

  @override
  State<CardViewerScreen> createState() => _CardViewerScreenState();
}

class _CardViewerScreenState extends State<CardViewerScreen> {
  static const _senderKey = '@noor_card_sender';

  /// Seven words, as agreed — a line, not a letter.
  static const _noteWordLimit = 7;

  final _exportKey = GlobalKey();
  final _name = TextEditingController();
  final _note = TextEditingController();
  bool _sending = false;

  /// The signature's cell on the card's three-by-four grid.
  int _signColumn = 1;
  int _signRow = 3;

  @override
  void initState() {
    super.initState();
    // The sender's name is theirs across every card; typing it once is enough.
    SharedPreferences.getInstance().then((prefs) {
      final saved = prefs.getString(_senderKey);
      if (saved != null && mounted) _name.text = saved;
    });
    _name.addListener(() => setState(() {}));
    _note.addListener(_capNote);
  }

  /// Holds the note to its word budget as it is typed, rather than rejecting
  /// it later.
  void _capNote() {
    final words = _note.text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty);
    if (words.length > _noteWordLimit) {
      final capped = words.take(_noteWordLimit).join(' ');
      _note.value = TextEditingValue(
        text: capped,
        selection: TextSelection.collapsed(offset: capped.length),
      );
    }
    setState(() {});
  }

  @override
  void dispose() {
    _name.dispose();
    _note.dispose();
    super.dispose();
  }

  /// Renders the card and hands it to the share sheet as a picture.
  ///
  /// Sending the text alone would lose the whole point of a card, and asking
  /// the reader to screenshot it would hand them the status bar as well.
  Future<void> _share() async {
    if (_sending) return;
    setState(() => _sending = true);
    try {
      final boundary = _exportKey.currentContext!.findRenderObject()
          as RenderRepaintBoundary;

      // Sized to a fixed width rather than to a multiple of the screen.
      //
      // Three times the layout size meant the card came out at whatever the
      // phone happened to be: about 1080 across on a wide handset, under 900
      // on a small one. Then the messaging app re-encodes what it is sent —
      // downscaling and compressing it as a photograph — and Arabic at that
      // size does not survive the second pass: the letters blur and the
      // vowels go first.
      //
      // Handing it a much larger original leaves the text legible after that
      // pass. The ratio is capped so an unusually large screen cannot ask for
      // an image too big to hold.
      final image =
          await boundary.toImage(pixelRatio: CardViewerScreen.exportRatio(boundary.size.width));
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      if (bytes == null) throw StateError('empty image');

      final dir = await getTemporaryDirectory();
      final name = widget.background == null
          ? widget.resolved.card.id
          : widget.background!.path.split('/').last.split('.').first;
      final file = File('${dir.path}/$name.png');
      await file.writeAsBytes(bytes.buffer.asUint8List());

      await SharePlus.instance.share(ShareParams(
        files: [XFile(file.path)],
        text: widget.resolved.card.greeting,
      ));

      // Remember the signature for the next card.
      if (_name.text.trim().isNotEmpty) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_senderKey, _name.text.trim());
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('تعذّر تجهيز البطاقة', textAlign: TextAlign.right),
          backgroundColor: AppColors.blackCard,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  /// Twelve cells, three across and four down — tap one and the signature
  /// moves to that part of the card, live in the preview above.
  Widget _placementPicker() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('مكان التوقيع',
            style: TextStyle(color: AppColors.textMuted, fontSize: 10)),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: AppColors.blackSurface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.goldBorder),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var row = 0; row < 4; row++)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var column = 0; column < 3; column++)
                      GestureDetector(
                        onTap: () => setState(() {
                          _signColumn = column;
                          _signRow = row;
                        }),
                        child: Container(
                          width: 16,
                          height: 13,
                          margin: const EdgeInsets.all(1.5),
                          decoration: BoxDecoration(
                            color: column == _signColumn && row == _signRow
                                ? AppColors.gold
                                : AppColors.blackCard,
                            borderRadius: BorderRadius.circular(3),
                            border: Border.all(
                                color: AppColors.goldBorder, width: 0.5),
                          ),
                        ),
                      ),
                  ],
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _field(TextEditingController controller, String hint,
      {int? maxLength}) {
    return TextField(
      controller: controller,
      maxLength: maxLength,
      textAlign: TextAlign.right,
      style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 12),
        counterText: '',
        filled: true,
        fillColor: AppColors.blackSurface,
        isDense: true,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.goldBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.goldBorder),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.black,
        resizeToAvoidBottomInset: true,
        appBar: AppBar(
          title: Text(widget.resolved.card.greeting,
              style: const TextStyle(fontSize: 16)),
          backgroundColor: AppColors.black,
          foregroundColor: AppColors.gold,
        ),
        body: SafeArea(
          top: false,
          child: Column(
          children: [
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    // What gets exported is this very widget, so the card the
                    // reader sends is the card they were looking at.
                    child: RepaintBoundary(
                      key: _exportKey,
                      child: GreetingCardView(
                        resolved: widget.resolved,
                        background: widget.background,
                        bare: widget.bare,
                        forSharing: true,
                        senderName: _name.text,
                        senderNote: _note.text,
                        signColumn: _signColumn,
                        signRow: _signRow,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _placementPicker(),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      children: [
                        _field(_name, 'اسمك على البطاقة', maxLength: 24),
                        const SizedBox(height: 6),
                        _field(_note, 'جملة منك (حتى ٧ كلمات)'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _sending ? null : _share,
                  icon: _sending
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: AppColors.white))
                      : const Icon(Icons.share, size: 18),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.goldDark,
                    foregroundColor: AppColors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  label: Text(_sending ? 'جاري التجهيز…' : 'إرسال البطاقة'),
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
