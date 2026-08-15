import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';

import '../services/app_audio.dart';

import '../constants/theme.dart';
import '../services/playback_speed.dart';

/// A live Qur'an radio station.
class RadioStation {
  final String id;
  final String name;
  final String place;
  final String url;

  const RadioStation({
    required this.id,
    required this.name,
    required this.place,
    required this.url,
  });
}

/// Live radio. Every stream here was probed before being listed — a station
/// that answers 404 is worse than no station.
///
/// The player carries a MediaItem, so the broadcast keeps playing when the
/// app is left, with its controls in the notification shade like the
/// recitation.
class RadioScreen extends StatefulWidget {
  const RadioScreen({super.key});

  static const stations = <RadioStation>[
    RadioStation(
      id: 'cairo',
      name: 'إذاعة القرآن الكريم',
      place: 'القاهرة — مصر',
      url: 'https://stream.radiojar.com/8s5u5tpdtwzuv',
    ),
    RadioStation(
      id: 'saudi',
      name: 'إذاعة القرآن الكريم',
      place: 'السعودية',
      url: 'https://stream.radiojar.com/0tpy1h0kxtzuv',
    ),
    RadioStation(
      id: 'tarateel',
      name: 'إذاعة تراتيل',
      place: 'تلاوات خاشعة متواصلة',
      url: 'https://backup.qurango.net/radio/tarateel',
    ),
    RadioStation(
      id: 'mix',
      name: 'إذاعة القرّاء',
      place: 'تلاوات متنوعة لعدة قرّاء',
      url: 'https://qurango.net/radio/mix',
    ),
    RadioStation(
      id: 'afasy',
      name: 'إذاعة مشاري العفاسي',
      place: 'تلاوات العفاسي على مدار اليوم',
      url: 'https://backup.qurango.net/radio/mishary_alafasi',
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
      await _player.setAudioSource(AudioSource.uri(
        Uri.parse(station.url),
        tag: MediaItem(
          id: 'radio:${station.id}',
          title: station.name,
          artist: station.place,
          album: 'الإذاعة',
        ),
      ));
      // A live stream has no timeline to compress; asking for anything but
      // normal speed only starves the buffer.
      await PlaybackSpeed.apply(live: true);
      _player.play();
      if (mounted) setState(() => _playingId = station.id);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('تعذّر الاتصال بـ${station.name}',
              textAlign: TextAlign.right),
          backgroundColor: AppColors.blackCard,
          behavior: SnackBarBehavior.floating,
        ));
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
          title: const Text('الإذاعة'),
          backgroundColor: AppColors.black,
          foregroundColor: AppColors.gold,
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'بث مباشر. يستمر التشغيل خارج التطبيق، وتجد أزرار التحكم في '
              'شريط الإشعارات.',
              style: TextStyle(color: AppColors.textMuted, fontSize: 12),
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
              color: playing ? AppColors.gold : AppColors.goldBorder),
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
                          strokeWidth: 2, color: AppColors.gold),
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
                  Text(station.name,
                      style: TextStyle(
                          color: playing
                              ? AppColors.gold
                              : AppColors.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 2),
                  Text(station.place,
                      style: const TextStyle(
                          color: AppColors.textMuted, fontSize: 11.5)),
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
class ListeningScreen extends StatelessWidget {
  const ListeningScreen({super.key});

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
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('🎧', style: TextStyle(fontSize: 40)),
                const SizedBox(height: 14),
                const Text(
                  'مصاحف كاملة لمقرئين تختار منهم، وربط بقناة التطبيق — يُضاف '
                  'تباعاً.\nإلى حين ذلك، الإذاعات الخمس في قسم الإذاعة تبث على '
                  'مدار الساعة.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 14,
                      height: 1.8),
                ),
                const SizedBox(height: 18),
                OutlinedButton.icon(
                  onPressed: () => Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (_) => const RadioScreen()),
                  ),
                  icon: const Icon(Icons.radio, size: 18),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.gold,
                    side: const BorderSide(color: AppColors.goldBorder),
                  ),
                  label: const Text('إلى الإذاعة'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
