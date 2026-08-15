import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../constants/theme.dart';
import '../services/storage_service.dart';

/// The star that keeps a dhikr, wherever it is read.
///
/// It watches the shared revision rather than only its own state, so a dhikr
/// unstarred in the favourites tab stops being lit in the chapter it came
/// from — the two views are of one list, and should never disagree.
class FavouriteStar extends StatefulWidget {
  final String id;
  final double size;

  /// Shown briefly when a dhikr is kept, so the reader learns where it went.
  final bool announce;

  const FavouriteStar({
    super.key,
    required this.id,
    this.size = 20,
    this.announce = true,
  });

  @override
  State<FavouriteStar> createState() => _FavouriteStarState();
}

class _FavouriteStarState extends State<FavouriteStar> {
  bool _on = false;

  @override
  void initState() {
    super.initState();
    _load();
    StorageService.favouritesRevision.addListener(_load);
  }

  @override
  void dispose() {
    StorageService.favouritesRevision.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    final on = await StorageService.isFavorite(widget.id);
    if (mounted && on != _on) setState(() => _on = on);
  }

  Future<void> _toggle() async {
    HapticFeedback.lightImpact();
    final added = await StorageService.toggleFavorite(widget.id);
    if (!mounted) return;
    setState(() => _on = added);

    if (!widget.announce) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(
          added ? 'أُضيف إلى أذكاري' : 'أُزيل من أذكاري',
          textDirection: TextDirection.rtl,
        ),
        backgroundColor: added ? AppColors.emerald : AppColors.blackCard,
        duration: const Duration(milliseconds: 1400),
      ));
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _toggle,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Icon(
          _on ? Icons.star : Icons.star_border,
          size: widget.size,
          color: _on ? AppColors.gold : AppColors.textMuted,
        ),
      ),
    );
  }
}
