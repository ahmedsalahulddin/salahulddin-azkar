import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

import '../constants/theme.dart';
import '../data/quran_data.dart';
import '../services/app_audio.dart';
import '../services/continuous_listening.dart';
import '../services/recitation_service.dart';
import '../widgets/speed_button.dart';

// surahJuz[i] = juz where surah (i+1) starts.
const _surahJuz = [
  1, 1, 3, 4, 6, 7, 8, 9, 10, 11, // 1-10
  11, 12, 13, 13, 14, 14, 15, 15, 16, 16, // 11-20
  17, 17, 18, 18, 18, 19, 19, 20, 20, 21, // 21-30
  21, 21, 21, 22, 22, 22, 23, 23, 23, 24, // 31-40
  24, 25, 25, 25, 25, 26, 26, 26, 26, 26, // 41-50
  26, 27, 27, 27, 27, 27, 27, 28, 28, 28, // 51-60
  28, 28, 28, 28, 28, 28, 29, 29, 29, 29, // 61-70
  29, 29, 29, 29, 29, 29, 29, 30, 30, 30, // 71-80
  30, 30, 30, 30, 30, 30, 30, 30, 30, 30, // 81-90
  30, 30, 30, 30, 30, 30, 30, 30, 30, 30, // 91-100
  30, 30, 30, 30, 30, 30, 30, 30, 30, 30, // 101-110
  30, 30, 30, 30, // 111-114
];

class ListeningScreen extends StatefulWidget {
  const ListeningScreen({super.key});

  @override
  State<ListeningScreen> createState() => _ListeningScreenState();
}

class _ListeningScreenState extends State<ListeningScreen> {
  List<SurahInfo> _index = const [];
  bool _loading = true;

  final _listController = ScrollController();
  static const _rowHeight = 47.0;

  // Filter state
  int? _juzFilter; // null = all juz
  int _startAyah = 1;

  @override
  void initState() {
    super.initState();
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

  // ─── Helpers ───────────────────────────────────────────────────────────────

  List<SurahInfo> get _visible => _juzFilter == null
      ? _index
      : _index
          .where((s) =>
              s.number <= _surahJuz.length &&
              _surahJuz[s.number - 1] == _juzFilter)
          .toList();

  void _followRecitation({bool animate = true}) {
    if (!mounted || !_listController.hasClients) return;
    if (_juzFilter != null) return; // user is browsing a specific juz

    final visible = _visible;
    final idx = visible.indexWhere(
        (s) => s.number == ContinuousListening.surah.value);
    if (idx < 0) return;

    final target =
        (idx * _rowHeight - MediaQuery.of(context).size.height / 3)
            .clamp(0.0, _listController.position.maxScrollExtent);

    if (animate) {
      _listController.animateTo(target,
          duration: const Duration(milliseconds: 350), curve: Curves.easeOut);
    } else {
      _listController.jumpTo(target);
    }
  }

  void _scrollToIndex(int idx) {
    if (!_listController.hasClients) return;
    final target =
        (idx * _rowHeight - MediaQuery.of(context).size.height / 4)
            .clamp(0.0, _listController.position.maxScrollExtent);
    _listController.animateTo(target,
        duration: const Duration(milliseconds: 350), curve: Curves.easeOut);
  }

  // ─── Pickers ───────────────────────────────────────────────────────────────

  void _pickJuz() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.blackCard,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text('اختر الجزء',
                          style:
                              TextStyle(color: AppColors.gold, fontSize: 15)),
                    ),
                    if (_juzFilter != null)
                      TextButton(
                        onPressed: () {
                          Navigator.pop(ctx);
                          setState(() => _juzFilter = null);
                          WidgetsBinding.instance.addPostFrameCallback(
                              (_) => _followRecitation(animate: false));
                        },
                        child: const Text('الكل',
                            style: TextStyle(
                                color: AppColors.textMuted, fontSize: 12)),
                      ),
                  ],
                ),
              ),
              SizedBox(
                height: 340,
                child: GridView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 5,
                    childAspectRatio: 1.6,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                  ),
                  itemCount: 30,
                  itemBuilder: (_, i) {
                    final juz = i + 1;
                    final selected = _juzFilter == juz;
                    return GestureDetector(
                      onTap: () {
                        Navigator.pop(ctx);
                        setState(() => _juzFilter = juz);
                        WidgetsBinding.instance
                            .addPostFrameCallback((_) => _scrollToIndex(0));
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: selected
                              ? AppColors.goldMuted
                              : AppColors.blackSurface,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: selected
                                ? AppColors.gold
                                : AppColors.goldBorder,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            QuranService.toArabicDigits(juz),
                            style: TextStyle(
                              color: selected
                                  ? AppColors.gold
                                  : AppColors.textPrimary,
                              fontSize: 13,
                              fontWeight: selected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _pickSurah() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.blackCard,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.4,
          maxChildSize: 0.9,
          expand: false,
          builder: (_, sc) => Column(
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Text('اختر السورة',
                    style:
                        TextStyle(color: AppColors.gold, fontSize: 15)),
              ),
              Expanded(
                child: ListView.builder(
                  controller: sc,
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
                  itemExtent: 44,
                  itemCount: _index.length,
                  itemBuilder: (_, i) {
                    final info = _index[i];
                    final on =
                        info.number == ContinuousListening.surah.value;
                    return GestureDetector(
                      onTap: () {
                        Navigator.pop(ctx);
                        setState(() {
                          _juzFilter = null;
                        });
                        ContinuousListening.play(info.number,
                            fromAyah: _startAyah);
                      },
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 4),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: on
                              ? AppColors.goldMuted
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: on
                                ? AppColors.gold
                                : AppColors.goldBorder,
                          ),
                        ),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 30,
                              child: Text(
                                QuranService.toArabicDigits(info.number),
                                style: TextStyle(
                                    color: on
                                        ? AppColors.gold
                                        : AppColors.textMuted,
                                    fontSize: 11),
                              ),
                            ),
                            Expanded(
                              child: Text(info.name,
                                  style: TextStyle(
                                    color: on
                                        ? AppColors.gold
                                        : AppColors.textPrimary,
                                    fontSize: 14,
                                    fontWeight: on
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                  )),
                            ),
                            Text(
                              '${QuranService.toArabicDigits(info.ayahCount)} آية',
                              style: const TextStyle(
                                  color: AppColors.textMuted, fontSize: 10),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _pickAyah() {
    final surahNum = ContinuousListening.surah.value;
    final info = ContinuousListening.infoFor(surahNum);
    if (info == null) return;
    final total = info.ayahCount;

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.blackCard,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: DraggableScrollableSheet(
          initialChildSize: 0.55,
          minChildSize: 0.3,
          maxChildSize: 0.85,
          expand: false,
          builder: (_, sc) => Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Text(
                  'ابدأ من أي آية — ${info.name}',
                  style: const TextStyle(
                      color: AppColors.gold, fontSize: 15),
                ),
              ),
              Expanded(
                child: GridView.builder(
                  controller: sc,
                  padding:
                      const EdgeInsets.fromLTRB(16, 4, 16, 24),
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 6,
                    childAspectRatio: 1.4,
                    crossAxisSpacing: 6,
                    mainAxisSpacing: 6,
                  ),
                  itemCount: total,
                  itemBuilder: (_, i) {
                    final ayah = i + 1;
                    final selected = _startAyah == ayah;
                    return GestureDetector(
                      onTap: () {
                        Navigator.pop(ctx);
                        setState(() => _startAyah = ayah);
                        ContinuousListening.play(surahNum,
                            fromAyah: ayah);
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: selected
                              ? AppColors.goldMuted
                              : AppColors.blackSurface,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: selected
                                ? AppColors.gold
                                : AppColors.goldBorder,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            QuranService.toArabicDigits(ayah),
                            style: TextStyle(
                              color: selected
                                  ? AppColors.gold
                                  : AppColors.textPrimary,
                              fontSize: 12,
                              fontWeight: selected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _pickReciter() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.blackCard,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 16, 20, 4),
                child: Text('اختر القارئ',
                    style:
                        TextStyle(color: AppColors.gold, fontSize: 15)),
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

  // ─── Build ─────────────────────────────────────────────────────────────────

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
                  _filterBar(),
                  Expanded(child: _surahList()),
                ],
              ),
      ),
    );
  }

  Widget _filterBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: ValueListenableBuilder<Reciter>(
        valueListenable: ContinuousListening.reciter,
        builder: (context2, reciter, child2) => Row(
          children: [
            _chip(
              label: _juzFilter == null
                  ? 'الجزء'
                  : 'جزء ${QuranService.toArabicDigits(_juzFilter!)}',
              icon: Icons.filter_list,
              active: _juzFilter != null,
              onTap: _pickJuz,
            ),
            const SizedBox(width: 6),
            _chip(
              label: 'السورة',
              icon: Icons.menu_book_outlined,
              onTap: _pickSurah,
            ),
            const SizedBox(width: 6),
            _chip(
              label: _startAyah == 1
                  ? 'الآية'
                  : 'من ${QuranService.toArabicDigits(_startAyah)}',
              icon: Icons.format_list_numbered,
              active: _startAyah != 1,
              onTap: _pickAyah,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: _chip(
                label: _shortName(reciter.name),
                icon: Icons.person_outline,
                onTap: _pickReciter,
                expand: true,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
    bool active = false,
    bool expand = false,
  }) {
    Widget inner = GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
        decoration: BoxDecoration(
          color: active ? AppColors.goldMuted : AppColors.blackCard,
          borderRadius: BorderRadius.circular(10),
          border:
              Border.all(color: active ? AppColors.gold : AppColors.goldBorder),
        ),
        child: Row(
          mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
          children: [
            Icon(icon,
                color: active ? AppColors.gold : AppColors.textMuted, size: 13),
            const SizedBox(width: 4),
            if (expand)
              Expanded(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: active ? AppColors.gold : AppColors.textSecondary,
                    fontSize: 11,
                  ),
                ),
              )
            else
              Text(
                label,
                style: TextStyle(
                  color: active ? AppColors.gold : AppColors.textSecondary,
                  fontSize: 11,
                ),
              ),
            const SizedBox(width: 2),
            Icon(Icons.keyboard_arrow_down,
                color: active ? AppColors.gold : AppColors.textMuted, size: 12),
          ],
        ),
      ),
    );
    return inner;
  }

  /// Shortens a long reciter name to fit the chip.
  String _shortName(String name) {
    final parts = name.split(' ');
    return parts.length <= 2 ? name : parts.sublist(parts.length - 2).join(' ');
  }

  Widget _nowPlaying() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 14, 16, 8),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      decoration: BoxDecoration(
        color: AppColors.blackCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.goldBorder),
      ),
      child: Column(
        children: [
          ValueListenableBuilder<int>(
            valueListenable: ContinuousListening.surah,
            builder: (context3, number, child3) => Column(
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
                  builder: (context4, ayah, child4) {
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
          const SizedBox(height: 6),
          ValueListenableBuilder<Reciter>(
            valueListenable: ContinuousListening.reciter,
            builder: (context5, rec, child5) => Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.skip_previous,
                      color: AppColors.textSecondary, size: 28),
                  onPressed: ContinuousListening.skipPrevious,
                  tooltip: 'السورة السابقة',
                ),
                Opacity(
                  opacity: rec.isPerAyah ? 1.0 : 0.3,
                  child: IconButton(
                    icon: const Icon(Icons.fast_rewind,
                        color: AppColors.gold, size: 24),
                    onPressed: rec.isPerAyah
                        ? ContinuousListening.skipPreviousAyah
                        : null,
                    tooltip: 'الآية السابقة',
                  ),
                ),
                _playButton(),
                Opacity(
                  opacity: rec.isPerAyah ? 1.0 : 0.3,
                  child: IconButton(
                    icon: const Icon(Icons.fast_forward,
                        color: AppColors.gold, size: 24),
                    onPressed: rec.isPerAyah
                        ? ContinuousListening.skipNextAyah
                        : null,
                    tooltip: 'الآية التالية',
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.skip_next,
                      color: AppColors.textSecondary, size: 28),
                  onPressed: ContinuousListening.skipNext,
                  tooltip: 'السورة التالية',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _playButton() {
    return StreamBuilder<PlayerState>(
      stream: AppAudio.player.playerStateStream,
      builder: (_, snapshot) {
        final state = snapshot.data;
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
    final visible = _visible;
    return ValueListenableBuilder<int>(
      valueListenable: ContinuousListening.surah,
      builder: (context6, current, child6) {
        if (visible.isEmpty) {
          return Center(
            child: Text(
              'لا توجد سور في هذا الجزء',
              style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
            ),
          );
        }
        return ListView.builder(
          controller: _listController,
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
          itemExtent: _rowHeight,
          itemCount: visible.length,
          itemBuilder: (_, i) {
            final info = visible[i];
            final on = info.number == current;

            return GestureDetector(
              onTap: () =>
                  ContinuousListening.play(info.number, fromAyah: _startAyah),
              child: Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: on ? AppColors.goldMuted : AppColors.blackCard,
                  borderRadius: BorderRadius.circular(12),
                  border:
                      Border.all(color: on ? AppColors.gold : AppColors.goldBorder),
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
                          color: on ? AppColors.gold : AppColors.textPrimary,
                          fontSize: 15,
                          fontWeight:
                              on ? FontWeight.bold : FontWeight.normal,
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
        );
      },
    );
  }
}
