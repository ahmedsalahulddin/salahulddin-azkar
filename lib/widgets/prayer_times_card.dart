import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/theme.dart';
import '../l10n/strings.dart';
import '../services/app_locale.dart';
import '../services/prayer_service.dart';
import '../screens/city_picker_screen.dart';
import '../services/prayer_place.dart';
import '../services/prayer_settings.dart';
import 'jumuah_sheet.dart';
import 'rotating_verse.dart';
import 'sky_arch.dart';

class PrayerTimesCard extends StatefulWidget {
  const PrayerTimesCard({super.key});

  @override
  State<PrayerTimesCard> createState() => _PrayerTimesCardState();
}

class _PrayerTimesCardState extends State<PrayerTimesCard> {
  PrayerData? _data;
  bool _failed = false;
  bool _locating = false;
  Duration _remaining = Duration.zero;
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _firstLoad();
    // The method and the Asr school change the times themselves, and the card
    // is kept alive by the IndexedStack behind the tabs — so without this it
    // goes on showing whatever it worked out when the app started. The school
    // moves Asr and nothing else, which is why the fault looked like "Asr is
    // wrong" rather than "the settings do nothing".
    PrayerSettings.method.addListener(_reload);
    PrayerSettings.school.addListener(_reload);
    PrayerPlace.current.addListener(_reload);
    PrayerService.locateRequests.addListener(_locateRequested);
  }

  void _locateRequested() => _load(ask: true);

  @override
  void dispose() {
    PrayerSettings.method.removeListener(_reload);
    PrayerSettings.school.removeListener(_reload);
    PrayerPlace.current.removeListener(_reload);
    PrayerService.locateRequests.removeListener(_locateRequested);
    _ticker?.cancel();
    super.dispose();
  }

  void _reload() => _load();

  static const _askedKey = 'prayer_location_asked_once';

  /// The first time the card ever loads, it asks for the location itself —
  /// otherwise a fresh install (every iPhone, so far) showed Riyadh's times
  /// until the reader happened to tap the marker, and read them as wrong.
  /// After that one ask it never raises the dialog on its own again.
  Future<void> _firstLoad() async {
    var ask = false;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!(prefs.getBool(_askedKey) ?? false)) {
        await prefs.setBool(_askedKey, true);
        ask = true;
      }
    } catch (_) {
      // Without storage, behave as before: wait for the marker.
    }
    await _load(ask: ask);
  }

  Future<void> _load({bool ask = false}) async {
    try {
      final data = await PrayerService.load(ask: ask);
      if (!mounted) return;
      setState(() {
        _data = data;
        _failed = false;
        _remaining = data.nextTime.difference(DateTime.now());
      });
      _startTicker();
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  /// The marker opens the city picker: a city by name, or the phone's own
  /// location — and choosing that is the reader asking for it, so the
  /// permission dialog may come up then.
  Future<void> _chooseCity() async {
    final choice = await Navigator.of(context).push<CityChoice>(
      MaterialPageRoute(builder: (_) => const CityPickerScreen()),
    );
    if (choice == CityChoice.myLocation && mounted) await _locateMe();
  }

  /// Tapping the marker is the reader asking for their own location, so this is
  /// where we may raise the permission dialog — and where we say what happened
  /// either way, rather than quietly showing Riyadh again.
  Future<void> _locateMe() async {
    if (_locating) return;
    setState(() => _locating = true);
    await _load(ask: true);
    if (!mounted) return;
    setState(() => _locating = false);

    final status = _data?.status;
    if (status == null) return;

    if (status == LocationStatus.blocked ||
        status == LocationStatus.serviceOff) {
      await _offerSettings(status);
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(status.explanation, textAlign: TextAlign.right),
        backgroundColor: AppColors.blackCard,
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: status.isMine ? 3 : 6),
        // No location: a city by name is the other way to the right times.
        action: status.isMine
            ? null
            : SnackBarAction(
                label: t('place.title'),
                textColor: AppColors.gold,
                onPressed: _chooseCity,
              ),
      ),
    );
  }

  /// A blocked permission cannot be re-asked from inside the app — only the
  /// system settings page can undo it, so we offer to open it directly.
  Future<void> _offerSettings(LocationStatus status) async {
    final go = await showDialog<int>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: AppColors.blackCard,
          title: Text(
            t('adh.locationDialogTitle'),
            style: const TextStyle(color: AppColors.gold, fontSize: 17),
          ),
          content: Text(
            '${status.explanation}.\n${t('adh.openSettingsInstructions')}',
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14,
              height: 1.6,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, 2),
              child: Text(
                t('place.title'),
                style: const TextStyle(color: AppColors.gold),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, 0),
              child: Text(
                t('adh.laterButton'),
                style: const TextStyle(color: AppColors.textMuted),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, 1),
              child: Text(
                t('adh.openSettingsButton'),
                style: const TextStyle(color: AppColors.gold),
              ),
            ),
          ],
        ),
      ),
    );
    if (go == 1) await PrayerService.openSettingsFor(status);
    if (go == 2 && mounted) await _chooseCity();
  }

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      final data = _data;
      if (data == null) return;
      final left = data.nextTime.difference(DateTime.now());
      // Prayer time arrived — recompute so the next prayer rolls over.
      if (left.isNegative) {
        _ticker?.cancel();
        _load();
        return;
      }
      if (mounted) setState(() => _remaining = left);
    });
  }

  @override
  Widget build(BuildContext context) {
    final data = _data;
    if (data == null || _failed) {
      return SizedBox(
        height: 200,
        child: Center(
          child: Text(
            _failed
                ? t('adh.prayerCalcFailedMsg')
                : t('adh.prayerCalcLoadingMsg'),
            style: const TextStyle(color: AppColors.textMuted, fontSize: 14),
          ),
        ),
      );
    }

    // The sky panel carries the countdown and the location inside its dome —
    // no caption needed, the marked prayer on the path says which one it is.
    // Under the panel: the verse, then the six times in one row.
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          SkyArch(
            data: data,
            now: DateTime.now(),
            aboveDome: const RotatingVerse(dense: true),
            inDome: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _locationChip(data.status),
                const SizedBox(height: 3),
                Text(
                  PrayerService.formatCountdown(_remaining),
                  textDirection: TextDirection.ltr,
                  style: const TextStyle(
                    color: AppColors.textGold,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
            footer: const VerseCitation(),
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: data.prayers.map(_prayerColumn).toList(),
            ),
          ),
          if (data.prayers.any((p) => p.isJumuah)) ...[
            const SizedBox(height: 10),
            _jumuahChip(),
          ],
        ],
      ),
    );
  }

  /// Fridays only: the day named, and a door to its sunnahs.
  Widget _jumuahChip() {
    return GestureDetector(
      onTap: () => showJumuahSheet(context),
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.jumuahMuted,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: AppColors.jumuahBorder),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.wb_sunny_outlined,
              size: 15,
              color: AppColors.jumuah,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                t('jumuah.dayChip'),
                style: const TextStyle(
                  color: AppColors.jumuah,
                  fontSize: 12.5,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 4),
            // The home screen stays right-to-left in every language, so this
            // matches the shelves' «See all» arrows rather than the language.
            const Icon(Icons.chevron_left, size: 16, color: AppColors.jumuah),
          ],
        ),
      ),
    );
  }

  /// One prayer in the strip: name, time under it, an arrow over the next.
  /// Jumu'ah wears Friday's green.
  Widget _prayerColumn(PrayerInfo p) {
    final color = p.isJumuah
        ? AppColors.jumuah
        : p.isNext
        ? AppColors.gold
        : AppColors.textMuted;
    return Column(
      children: [
        Icon(
          Icons.arrow_drop_down,
          size: 16,
          color: p.isNext ? color : Colors.transparent,
        ),
        Text(
          p.displayName,
          style: TextStyle(
            color: color,
            fontSize: 12,
            fontWeight: p.isNext || p.isJumuah
                ? FontWeight.bold
                : FontWeight.normal,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          PrayerService.formatPrayerTime(p.time),
          // "5:36 PM" reads left to right; inside the card's RTL layout it
          // would otherwise come out as "PM 5:36".
          textDirection: AppLocale.direction,
          style: TextStyle(
            color: p.isJumuah
                ? AppColors.jumuah
                : p.isNext
                ? AppColors.textGold
                : AppColors.textMuted,
            fontSize: 11,
          ),
        ),
      ],
    );
  }

  /// The marker is a button: pressing it goes and finds the reader. While the
  /// times are still Riyadh's it says so and invites the tap, because a reader
  /// in Cairo has no other clue that the times below are not theirs.
  Widget _locationChip(LocationStatus status) {
    final mine = status.isMine;
    final tint = mine ? AppColors.textMuted : AppColors.gold;

    return GestureDetector(
      // Not located yet: the tap finds the reader. Located (or a city
      // chosen): it opens the city picker.
      onTap: mine ? _chooseCity : _locateMe,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: mine ? Colors.transparent : AppColors.goldMuted,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
            color: mine ? Colors.transparent : AppColors.goldBorder,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_locating)
              const SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(
                  strokeWidth: 1.6,
                  color: AppColors.gold,
                ),
              )
            else
              Icon(
                status == LocationStatus.chosen
                    ? Icons.location_city
                    : mine
                    ? Icons.my_location
                    : Icons.location_searching,
                size: 13,
                color: tint,
              ),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                _locating
                    ? t('adh.locatingMessage')
                    : mine
                    ? status.label
                    : t(
                        'adh.locationHintTemplate',
                      ).replaceFirst('%s', status.label),
                textDirection: AppLocale.direction,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: _locating ? AppColors.textGold : tint,
                  fontSize: 11,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
