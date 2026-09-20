import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';

import '../services/app_audio.dart';

import '../constants/theme.dart';
import '../l10n/strings.dart';
import '../services/app_locale.dart';
import '../services/playback_speed.dart';

/// A live Qur'an radio station.
class RadioStation {
  final String id;
  final String name;
  final String place;
  final String url;

  /// The name in each of the app's 9 other languages (en, fr, ur, id, ms,
  /// hi, tr, bn, ha), keyed by AppLocale code.
  final Map<String, String> otherNames;

  const RadioStation({
    required this.id,
    required this.name,
    required this.place,
    required this.url,
    this.otherNames = const {},
  });

  /// Arabic name with the selected language's rendering alongside it — same
  /// "Arabic (translated)" convention as tBoth().
  String get bilingualName {
    final code = AppLocale.code;
    if (code == 'ar') return name;
    final other = otherNames[code];
    return other == null || other == name ? name : '$name ($other)';
  }
}

/// Live radio. Every stream here was probed before being listed — a station
/// that answers 404 is worse than no station.
///
/// The player carries a MediaItem, so the broadcast keeps playing when the
/// app is left, with its controls in the notification shade like the
/// recitation.
class RadioScreen extends StatefulWidget {
  const RadioScreen({super.key});

  static const _quranRadioNames = {
    'en': 'Holy Quran Radio',
    'fr': 'Radio du Saint Coran',
    'ur': 'ریڈیو قرآن کریم',
    'id': "Radio Al-Qur'an",
    'ms': 'Radio Al-Quran',
    'hi': 'क़ुरआन रेडियो',
    'tr': "Kur'an Radyosu",
    'bn': 'কুরআন রেডিও',
    'ha': "Rediyon Alkur'ani",
  };

  static const stations = <RadioStation>[
    RadioStation(
      id: 'cairo',
      name: 'إذاعة القرآن الكريم',
      place: 'القاهرة — مصر',
      url: 'https://stream.radiojar.com/8s5u5tpdtwzuv',
      otherNames: _quranRadioNames,
    ),
    RadioStation(
      id: 'saudi',
      name: 'إذاعة القرآن الكريم',
      place: 'السعودية',
      url: 'https://stream.radiojar.com/0tpy1h0kxtzuv',
      otherNames: _quranRadioNames,
    ),
    RadioStation(
      id: 'tarateel',
      name: 'إذاعة تراتيل',
      place: 'تلاوات خاشعة متواصلة',
      url: 'https://backup.qurango.net/radio/tarateel',
      otherNames: {
        'en': 'Tarateel Radio',
        'fr': 'Radio Tarateel',
        'ur': 'ریڈیو تراتیل',
        'id': 'Radio Tarateel',
        'ms': 'Radio Tarateel',
        'hi': 'तरातील रेडियो',
        'tr': 'Tertil Radyosu',
        'bn': 'তারাতিল রেডিও',
        'ha': "Rediyon Tarattilin Alkur'ani",
      },
    ),
    RadioStation(
      id: 'mix',
      name: 'إذاعة القرّاء',
      place: 'تلاوات متنوعة لعدة قرّاء',
      url: 'https://qurango.net/radio/mix',
      otherNames: {
        'en': 'Reciters Radio',
        'fr': 'Radio des Récitateurs',
        'ur': 'قراء ریڈیو',
        'id': 'Radio Para Qari',
        'ms': 'Radio Qari',
        'hi': 'क़ारी रेडियो',
        'tr': 'Kurra Radyosu',
        'bn': 'কারী রেডিও',
        'ha': 'Rediyon Alqarrua',
      },
    ),
    RadioStation(
      id: 'afasy',
      name: 'إذاعة مشاري العفاسي',
      place: 'تلاوات العفاسي على مدار اليوم',
      url: 'https://backup.qurango.net/radio/mishary_alafasi',
      otherNames: {
        'en': 'Mishary Alafasy Radio',
        'fr': 'Radio Mishary Al-Afassy',
        'ur': 'مشاری العفاسی ریڈیو',
        'id': 'Radio Mishari Al-Afasy',
        'ms': 'Radio Mishary Al-Afasy',
        'hi': 'मिशारी अल-अफ़ासी रेडियो',
        'tr': 'Meşârî el-Afâsî Radyosu',
        'bn': 'মিশারি আল-আফাসি রেডিও',
        'ha': 'Rediyon Mishary Alfasy',
      },
    ),
  ];

  @override
  State<RadioScreen> createState() => _RadioScreenState();
}

class _RadioScreenState extends State<RadioScreen> {
  final _player = AppAudio.player;
  String? _playingId;
  String? _loadingId;

  @override
  void initState() {
    super.initState();
    // The broadcast keeps playing when this screen closes — that is what a
    // radio is for — so on return, find it and light its tile again.
    final id = AppAudio.currentId();
    if (id != null && id.startsWith('radio:') && _player.playing) {
      _playingId = id.substring('radio:'.length);
    }
  }

  Future<void> _toggle(RadioStation station) async {
    if (_playingId == station.id) {
      await _player.stop();
      setState(() => _playingId = null);
      return;
    }

    setState(() {
      _loadingId = station.id;
      _playingId = null;
    });
    try {
      await _player.stop();
      await _player.setAudioSource(
        AudioSource.uri(
          Uri.parse(station.url),
          tag: MediaItem(
            id: 'radio:${station.id}',
            title: station.name,
            artist: station.place,
            album: t('misc.radioAlbumLabel'),
          ),
        ),
      );
      // A live stream has no timeline to compress; asking for anything but
      // normal speed only starves the buffer.
      await PlaybackSpeed.apply(live: true);
      _player.play();
      if (mounted) setState(() => _playingId = station.id);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              t('misc.radioConnectFailed').replaceAll('{name}', station.name),
              textAlign: TextAlign.right,
            ),
            backgroundColor: AppColors.blackCard,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loadingId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.black,
        appBar: AppBar(
          title: Text(t('misc.radioTitle')),
          backgroundColor: AppColors.black,
          foregroundColor: AppColors.gold,
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              t('misc.radioLiveInfo'),
              style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
            ),
            const SizedBox(height: 14),
            for (final station in RadioScreen.stations) ...[
              _stationTile(station),
              const SizedBox(height: 10),
            ],
          ],
        ),
      ),
    );
  }

  Widget _stationTile(RadioStation station) {
    final playing = _playingId == station.id;
    final loading = _loadingId == station.id;

    return GestureDetector(
      onTap: loading ? null : () => _toggle(station),
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: playing ? AppColors.goldMuted : AppColors.blackCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: playing ? AppColors.gold : AppColors.goldBorder,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.goldMuted,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.goldBorder),
              ),
              child: loading
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.gold,
                      ),
                    )
                  : Icon(
                      playing ? Icons.stop_rounded : Icons.play_arrow_rounded,
                      color: AppColors.gold,
                      size: 26,
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    station.bilingualName,
                    style: TextStyle(
                      color: playing ? AppColors.gold : AppColors.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    station.place,
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 11.5,
                    ),
                  ),
                ],
              ),
            ),
            if (playing)
              const Icon(Icons.graphic_eq, color: AppColors.gold, size: 20),
          ],
        ),
      ),
    );
  }
}

/// Continuous listening — reciters to be added, and the app's own channel once
/// it exists. Declared honestly rather than opening onto nothing.
