import 'package:flutter/material.dart';

import '../constants/theme.dart';
import '../data/quran_data.dart' show QuranService;
import '../l10n/strings.dart';
import '../services/duas_service.dart';
import '../services/favourites.dart';
import '../widgets/favourite_star.dart';
import '../widgets/speak_button.dart';

/// One category's duas — a plain bulleted list to read, or (when
/// [editable]) a title field plus a line-per-dua editor. Shared by the
/// admin's base-collection editor and a reader's own additions.
class DuaCategoryDetailScreen extends StatefulWidget {
  final DuaCategory category;
  final bool editable;

  const DuaCategoryDetailScreen({
    super.key,
    required this.category,
    required this.editable,
  });

  @override
  State<DuaCategoryDetailScreen> createState() =>
      _DuaCategoryDetailScreenState();
}

class _DuaCategoryDetailScreenState extends State<DuaCategoryDetailScreen> {
  late final _titleController = TextEditingController(
    text: widget.category.title,
  );
  late final _duasController = TextEditingController(
    text: widget.category.duas.join('\n\n'),
  );
  bool _editing = false;

  @override
  void dispose() {
    _titleController.dispose();
    _duasController.dispose();
    // Leaving the screen ends the reading; a voice with no screen behind it
    // has no way to be stopped.
    Tts.stop();
    super.dispose();
  }

  void _saveAndPop() {
    final duas = _duasController.text
        .split('\n\n')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    Navigator.pop(
      context,
      widget.category.copyWith(
        title: _titleController.text.trim().isEmpty
            ? widget.category.title
            : _titleController.text.trim(),
        duas: duas,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.black,
        appBar: AppBar(
          title: Text(widget.category.title),
          backgroundColor: AppColors.black,
          foregroundColor: AppColors.gold,
          actions: [
            if (widget.editable)
              IconButton(
                icon: Icon(_editing ? Icons.check : Icons.edit),
                tooltip: _editing ? 'حفظ' : 'تعديل',
                onPressed: () {
                  if (_editing) {
                    _saveAndPop();
                  } else {
                    setState(() => _editing = true);
                  }
                },
              ),
          ],
        ),
        body: _editing ? _editor() : _reader(),
      ),
    );
  }

  Widget _editor() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _titleController,
            style: const TextStyle(color: AppColors.gold, fontSize: 16),
            decoration: const InputDecoration(
              labelText: 'اسم التصنيف',
              labelStyle: TextStyle(color: AppColors.textMuted),
              enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: AppColors.goldBorder),
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'كل دعاء في سطر، واترك سطرًا فارغًا بين كل دعاء وآخر',
            style: TextStyle(color: AppColors.textMuted, fontSize: 11),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: TextField(
              controller: _duasController,
              maxLines: null,
              expands: true,
              textAlignVertical: TextAlignVertical.top,
              style: const TextStyle(color: AppColors.textPrimary, height: 1.8),
              decoration: InputDecoration(
                filled: true,
                fillColor: AppColors.blackCard,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppColors.goldBorder),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _reader() {
    final duas = widget.category.duas;
    if (duas.isEmpty) {
      return const Center(
        child: Text(
          'لا توجد أدعية هنا بعد',
          style: TextStyle(color: AppColors.textMuted),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: _readAllBar(duas),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: duas.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (_, i) => ValueListenableBuilder<int?>(
              valueListenable: Tts.readingIndex,
              builder: (context, at, _) => _duaCard(duas[i], i, at == i),
            ),
          ),
        ),
      ],
    );
  }

  /// Reads every dua in this category aloud, one after another, without
  /// stopping in between — the same continuous-read pattern already used
  /// for favourites and for library books.
  Widget _readAllBar(List<String> duas) {
    return ValueListenableBuilder<int?>(
      valueListenable: Tts.readingIndex,
      builder: (context, at, _) {
        if (at == null) {
          return GestureDetector(
            onTap: () => Tts.readAll(duas),
            behavior: HitTestBehavior.opaque,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
              decoration: BoxDecoration(
                color: AppColors.goldMuted,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.goldBorder),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.play_arrow, color: AppColors.gold, size: 18),
                  const SizedBox(width: 6),
                  Text(
                    t('misc.readAll'),
                    style: const TextStyle(
                      color: AppColors.gold,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(
                Icons.stop_circle_outlined,
                color: AppColors.gold,
                size: 24,
              ),
              onPressed: Tts.stop,
              tooltip: t('misc.stop'),
            ),
            Text(
              t('misc.readingProgress')
                  .replaceAll('{current}', QuranService.toArabicDigits(at + 1))
                  .replaceAll(
                    '{total}',
                    QuranService.toArabicDigits(duas.length),
                  ),
              style: const TextStyle(color: AppColors.textGold, fontSize: 12),
            ),
            IconButton(
              icon: const Icon(
                Icons.skip_next,
                color: AppColors.textSecondary,
                size: 22,
              ),
              onPressed: Tts.skip,
              tooltip: t('misc.next'),
            ),
          ],
        );
      },
    );
  }

  Widget _duaCard(String text, int index, bool reading) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 6),
      decoration: BoxDecoration(
        color: AppColors.blackCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: reading ? AppColors.gold : AppColors.goldBorder,
          width: reading ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            text,
            textAlign: TextAlign.right,
            style: const TextStyle(
              color: AppColors.textPrimary,
              height: 1.9,
              fontSize: 15,
            ),
          ),
          Row(
            children: [
              SpeakButton(
                id: Favourites.duaId(widget.category.id, index),
                text: text,
              ),
              FavouriteStar(
                id: Favourites.duaId(widget.category.id, index),
                announce: false,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
