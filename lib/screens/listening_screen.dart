import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

import '../constants/theme.dart';
import '../data/quran_data.dart';
import '../services/app_audio.dart';
import '../services/continuous_listening.dart';
import '../services/recitation_service.dart';
import '../widgets/speed_button.dart';

/// The Mushaf, read straight through.
///
/// The card promised continuous listening and opened a note saying it was
/// coming. This is the thing itself: a reciter, a place to start, and a
/// recitation that carries on into the next surah on its own.
class ListeningScreen extends StatefulWidget {
  const ListeningScreen({super.key});

  @override
  State<ListeningScreen> createState() => _ListeningScreenState();
}

class _ListeningScreenState extends State<ListeningScreen> {
  List<SurahInfo> _index = const [];
  bool _loading = true;

  final _listController = ScrollController();

  /// Every row is the same height, which is what lets the list be scrolled to
  /// a surah by arithmetic rather than by rendering the 114 above it.
  static const _rowHeight = 47.0;

  @override
  void initState() {
    super.initState();
    // Stop anything that was playing from another screen so the reader is not
    // hearing the Mushaf or a surah while browsing where to start listening.
    if (AppAudio.player.playing &&
        !AppAudio.ownsCurrent(ContinuousListening.owner)) {
      AppAudio.player.stop();
    }
    _load();
  }

  Future<void> _load() async {
    await ContinuousListening.load();
    final index = await QuranService.index();
    if (!mounted) return;
    setState(() {
      _index = index;
      _loading = false;
    });
    // Opening at Yusuf and being shown Al-Fatiha means scrolling past eleven
    // surahs to see where you are. The list follows the recitation instead,
    // including when it moves on by itself.
    ContinuousListening.surah.addListener(_followRecitation);
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _followRecitation(animate: false));
  }

  @override
  void dispose() {
    ContinuousListening.surah.removeListener(_followRecitation);
    _listController.dispose();
    super.dispose();
  }

  void _followRecitation({bool animate = true}) {
    if (!mounted || !_listController.hasClients) return;

    // A third of a screen above it, so the surahs around it are visible and
    // the current one is not pinned to the very top.
    final target = ((ContinuousListening.surah.value - 1) * _rowHeight -
            MediaQuery.of(context).size.height / 3)
        .clamp(0.0, _listController.position.maxScrollExtent);

    if (animate) {
      _listController.animateTo(target,
          duration: const Duration(milliseconds: 350), curve: Curves.easeOut);
    } else {
      _listController.jumpTo(target);
    }
  }

  void _pickReciter() {
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
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 16, 20, 4),
                child: Text('اختر القارئ',
                    style: TextStyle(color: AppColors.gold, fontSize: 15)),
              ),
              for (final r in RecitationService.reciters)
                ListTile(
                  leading: Icon(
                    r.id == ContinuousListening.reciter.value.id
                        ? Icons.radio_button_checked
                        : Icons.radio_button_unchecked,
                    color: r.id == ContinuousListening.reciter.value.id
                        ? AppColors.gold
                        : AppColors.textMuted,
                    size: 19,
                  ),
                  title: Text(r.name,
                      style: const TextStyle(
                          color: AppColors.textPrimary, fontSize: 14)),
                  onTap: () {
                    Navigator.pop(ctx);
                    ContinuousListening.setReciter(r);
                  },
                ),
              const SizedBox(height: 8),
            ],
          ),
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
        appBar: AppBar(
          title: const Text('الاستماع الدائم'),
          backgroundColor: AppColors.black,
          foregroundColor: AppColors.gold,
          actions: const [SpeedButton(showLabel: false)],
        ),
        body: _loading
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.gold))
            : Column(
                children: [
                  _nowPlaying(),
                  const Padding(
                    padding: EdgeInsets.fromLTRB(16, 4, 16, 6),
                    child: Text(
                      'تنتقل التلاوة إلى السورة التالية وحدها، وتكمل حتى تُغلقها.',
                      textAlign: TextAlign.center,
                      style:
                          TextStyle(color: AppColors.textMuted, fontSize: 11),
                    ),
                  ),
                  Expanded(child: _surahList()),
                ],
              ),
      ),
    );
  }

  Widget _nowPlaying() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 14, 16, 6),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
      decoration: BoxDecoration(
        color: AppColors.blackCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.goldBorder),
      ),
      child: Column(
        children: [
          GestureDetector(
            onTap: _pickReciter,
            child: ValueListenableBuilder<Reciter>(
              valueListenable: ContinuousListening.reciter,
              builder: (context, reciter, _) => Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(reciter.name,
                      style: const TextStyle(
                          color: AppColors.textGold, fontSize: 13)),
                  const SizedBox(width: 4),
                  const Icon(Icons.keyboard_arrow_down,
                      color: AppColors.textMuted, size: 18),
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),
          ValueListenableBuilder<int>(
            valueListenable: ContinuousListening.surah,
            builder: (context, number, _) => Column(
              children: [
                Text(
                  ContinuousListening.nameFor(number),
                  style: const TextStyle(
                      color: AppColors.gold,
                      fontSize: 22,
                      fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 2),
                ValueListenableBuilder<int>(
                  valueListenable: ContinuousListening.ayah,
                  builder: (context, ayah, _) {
                    final total =
                        ContinuousListening.infoFor(number)?.ayahCount ?? 0;
                    return Text(
                      'الآية ${QuranService.toArabicDigits(ayah)}'
                      ' من ${QuranService.toArabicDigits(total)}',
                      style: const TextStyle(
                          color: AppColors.textMuted, fontSize: 12),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.skip_previous,
                    color: AppColors.textSecondary, size: 30),
                onPressed: ContinuousListening.skipPrevious,
                tooltip: 'السورة السابقة',
              ),
              _playButton(),
              IconButton(
                icon: const Icon(Icons.skip_next,
                    color: AppColors.textSecondary, size: 30),
                onPressed: ContinuousListening.skipNext,
                tooltip: 'السورة التالية',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _playButton() {
    return StreamBuilder<PlayerState>(
      stream: AppAudio.player.playerStateStream,
      builder: (context, snapshot) {
        final state = snapshot.data;
        // Playing *this* recitation, not merely playing: the radio and the
        // Mushaf share the one player, and the button must not offer to pause
        // something this screen does not own.
        final mine = AppAudio.ownsCurrent(ContinuousListening.owner);
        final playing = (state?.playing ?? false) && mine;
        final loading = mine &&
            (state?.processingState == ProcessingState.loading ||
                state?.processingState == ProcessingState.buffering);

        return IconButton(
          iconSize: 54,
          icon: loading
              ? const SizedBox(
                  width: 30,
                  height: 30,
                  child: CircularProgressIndicator(
                      strokeWidth: 2.5, color: AppColors.gold),
                )
              : Icon(
                  playing ? Icons.pause_circle_filled : Icons.play_circle_fill,
                  color: AppColors.gold,
                  size: 54,
                ),
          onPressed: ContinuousListening.toggle,
        );
      },
    );
  }

  Widget _surahList() {
    return ValueListenableBuilder<int>(
      valueListenable: ContinuousListening.surah,
      builder: (context, current, _) => ListView.builder(
        controller: _listController,
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
        itemExtent: _rowHeight,
        itemCount: _index.length,
        itemBuilder: (context, i) {
          final info = _index[i];
          final on = info.number == current;

          return GestureDetector(
            onTap: () => ContinuousListening.play(info.number),
            child: Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: on ? AppColors.goldMuted : AppColors.blackCard,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: on ? AppColors.gold : AppColors.goldBorder),
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 30,
                    child: Text(
                      QuranService.toArabicDigits(info.number),
                      style: TextStyle(
                          color: on ? AppColors.gold : AppColors.textMuted,
                          fontSize: 12),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      info.name,
                      style: TextStyle(
                        color:
                            on ? AppColors.gold : AppColors.textPrimary,
                        fontSize: 15,
                        fontWeight: on ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ),
                  Text(
                    '${QuranService.toArabicDigits(info.ayahCount)} آية',
                    style: const TextStyle(
                        color: AppColors.textMuted, fontSize: 11),
                  ),
                  if (on) ...[
                    const SizedBox(width: 8),
                    const Icon(Icons.graphic_eq,
                        color: AppColors.gold, size: 16),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
