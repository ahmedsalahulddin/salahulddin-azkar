import 'package:flutter/material.dart';
import 'dart:async';

import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import '../constants/theme.dart';
import '../l10n/strings.dart';
import '../services/app_audio.dart';
import '../services/playback_speed.dart';
import '../data/adhkar_data.dart';
import 'dhikr_text.dart';
import 'favourite_star.dart';

class AdhkarCard extends StatefulWidget {
  final Dhikr dhikr;
  final FontSizeOption fontSize;
  final VoidCallback? onTasbih;

  const AdhkarCard({
    super.key,
    required this.dhikr,
    required this.fontSize,
    this.onTasbih,
  });

  @override
  State<AdhkarCard> createState() => _AdhkarCardState();
}

class _AdhkarCardState extends State<AdhkarCard> {
  bool _showBenefit = false;

  bool _isPlaying = false;

  StreamSubscription<PlayerState>? _stateSub;

  String get _tagId => 'dhikr:${widget.dhikr.categoryId}:${widget.dhikr.id}';

  @override
  void dispose() {
    _stateSub?.cancel();
    super.dispose();
  }

  /// All cards share the app's one player; a card recognises its own sound by
  /// the tag it loaded, so another card taking over simply unlights this one.
  Future<void> _toggleAudio() async {
    final url = widget.dhikr.audioUrl;
    if (url == null) return;
    HapticFeedback.lightImpact();

    final player = AppAudio.player;

    if (_isPlaying) {
      await player.pause();
      if (mounted) setState(() => _isPlaying = false);
      return;
    }

    setState(() => _isPlaying = true);
    _stateSub ??= player.playerStateStream.listen((state) {
      if (!mounted) return;
      final mine = AppAudio.currentId() == _tagId;
      if (!mine || state.processingState == ProcessingState.completed) {
        setState(() => _isPlaying = false);
      }
    });

    try {
      if (AppAudio.currentId() != _tagId) {
        await player.stop();
        await player.setAudioSource(
          AudioSource.uri(
            Uri.parse(url),
            tag: MediaItem(
              id: _tagId,
              title: t('adh.mediaItemTitle'),
              album: t('adh.mediaItemAlbum'),
            ),
          ),
        );
      }
      await PlaybackSpeed.apply();
      await player.play();
    } catch (_) {
      if (mounted) setState(() => _isPlaying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dhikr = widget.dhikr;
    final dhikrSize = AppFontSizes.dhikr(widget.fontSize);
    final sourceSize = AppFontSizes.source(widget.fontSize);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.blackCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.goldBorder),
      ),
      child: IntrinsicHeight(
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: Row(
            children: [
              // Side icons
              Container(
                width: 44,
                decoration: const BoxDecoration(
                  color: AppColors.goldMuted,
                  borderRadius: BorderRadius.only(
                    topRight: Radius.circular(15),
                    bottomRight: Radius.circular(15),
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 4),
                    // The shared star, so a dhikr unstarred in أذكاري stops
                    // being lit here too — the card used to read the list once
                    // and then never look again.
                    FavouriteStar(
                      id: widget.dhikr.id,
                      size: 22,
                      announce: false,
                    ),
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: widget.onTasbih,
                      child: Text(
                        '${dhikr.repetitions}',
                        style: const TextStyle(
                          color: AppColors.gold,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    // Only the adhkar with a verified recitation get a button.
                    if (dhikr.hasAudio) ...[
                      const SizedBox(height: 12),
                      GestureDetector(
                        onTap: _toggleAudio,
                        child: Icon(
                          _isPlaying ? Icons.pause_circle : Icons.volume_up,
                          color: _isPlaying
                              ? AppColors.gold
                              : AppColors.textMuted,
                          size: 20,
                        ),
                      ),
                    ],
                    if (dhikr.benefit != null) ...[
                      const SizedBox(height: 12),
                      GestureDetector(
                        onTap: () =>
                            setState(() => _showBenefit = !_showBenefit),
                        child: Icon(
                          _showBenefit ? Icons.info : Icons.info_outline,
                          color: AppColors.textMuted,
                          size: 20,
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                  ],
                ),
              ),
              // Content
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      DhikrText(
                        arabic: dhikr.text,
                        english: dhikr.english,
                        moreTranslations: adhkarTranslationsFor(dhikr.id),
                        fontSize: dhikrSize,
                        color: AppColors.textPrimary,
                      ),
                      if (_showBenefit) ...[
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.only(top: 8),
                          decoration: const BoxDecoration(
                            border: Border(
                              top: BorderSide(color: AppColors.goldBorder),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                '📖 ${dhikr.source}',
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: sourceSize,
                                ),
                                textAlign: TextAlign.right,
                              ),
                              if (dhikr.benefit != null) ...[
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: AppColors.emeraldMuted,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    '✨ ${dhikr.benefit}',
                                    style: TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: sourceSize,
                                    ),
                                    textAlign: TextAlign.right,
                                    textDirection: TextDirection.rtl,
                                  ),
                                ),
                              ],
                              if (dhikr.repetitions > 1) ...[
                                const SizedBox(height: 8),
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: GestureDetector(
                                    onTap: () {
                                      HapticFeedback.mediumImpact();
                                      widget.onTasbih?.call();
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 14,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppColors.goldMuted,
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(
                                          color: AppColors.goldBorder,
                                        ),
                                      ),
                                      child: Text(
                                        t('adh.tasbihCounterTitle'),
                                        style: const TextStyle(
                                          color: AppColors.gold,
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ],
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
