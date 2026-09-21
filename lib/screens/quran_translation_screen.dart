import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:http/http.dart' as http;
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:path_provider/path_provider.dart';

import '../constants/theme.dart';
import '../data/quran_data.dart';
import '../l10n/strings.dart';
import '../services/app_audio.dart';
import '../services/connectivity_check.dart';
import '../services/recitation_downloads.dart';
import '../services/recitation_service.dart';

class _Lang {
  final String code;
  final String name;
  const _Lang(this.code, this.name);
}

const _langs = [
  _Lang('en', 'English'),
  _Lang('fr', 'Français'),
  _Lang('tr', 'Türkçe'),
  _Lang('ur', 'اردو'),
  _Lang('de', 'Deutsch'),
  _Lang('es', 'Español'),
  _Lang('ru', 'Русский'),
  _Lang('id', 'Indonesia'),
  _Lang('ms', 'Bahasa Melayu'),
  _Lang('bn', 'বাংলা'),
  _Lang('hi', 'हिन्दी'),
  _Lang('ha', 'Hausa'),
];

const _apiBase = 'https://api.alquran.cloud/v1/surah';

const _edition = {
  'en': 'en.sahih',
  'fr': 'fr.hamidullah',
  'tr': 'tr.diyanet',
  'ur': 'ur.maududi',
  'de': 'de.aburida',
  'es': 'es.asad',
  'ru': 'ru.kuliev',
  'id': 'id.indonesian',
  'ms': 'ms.basmeih',
  'hi': 'hi.hindi',
  'ha': 'ha.gumi',
};

const _ttsLocale = {
  'en': 'en-US',
  'fr': 'fr-FR',
  'tr': 'tr-TR',
  'ur': 'ur-PK',
  'de': 'de-DE',
  'es': 'es-ES',
  'ru': 'ru-RU',
  'id': 'id-ID',
  'ms': 'ms-MY',
  'bn': 'bn-BD',
  'hi': 'hi-IN',
  'ha': 'ha-NG',
};

/// Bengali has no King Fahd Complex edition on alquran.cloud, so it is
/// fetched from quran.com instead — resource 213 is Dr. Abu Bakr
/// Muhammad Zakaria's translation, the one the Complex (the Saudi
/// government's Quran-printing body) itself published and distributed,
/// the same standard the app already holds every other language to.
const _quranComResourceId = {'bn': 213};

Future<List<String>?> _fetchTranslation(String lang, int surahNum) async {
  // path_provider has no web implementation — getApplicationDocumentsDirectory()
  // throws MissingPluginException there, which used to take this whole call
  // down before it ever reached the HTTP fetch below. The web build fetches
  // fresh every time instead of caching to disk.
  final file = kIsWeb
      ? null
      : File(
          '${(await getApplicationDocumentsDirectory()).path}/quran_translations_v2/$lang/$surahNum.json',
        );
  if (file != null && await file.exists()) {
    return _parse(await file.readAsString(), lang);
  }
  final resourceId = _quranComResourceId[lang];
  try {
    final uri = resourceId != null
        ? Uri.parse(
            'https://api.quran.com/api/v4/quran/translations/$resourceId'
            '?chapter_number=$surahNum',
          )
        : Uri.parse('$_apiBase/$surahNum/${_edition[lang] ?? 'en.sahih'}');
    final res = await http.get(uri).timeout(const Duration(seconds: 20));
    if (res.statusCode != 200) return null;
    if (file != null) {
      await file.parent.create(recursive: true);
      await file.writeAsBytes(res.bodyBytes);
    }
    return _parse(res.body, lang);
  } catch (_) {
    return null;
  }
}

List<String>? _parse(String body, String lang) {
  try {
    final json = jsonDecode(body) as Map;
    if (_quranComResourceId.containsKey(lang)) {
      // quran.com's Zakaria text carries footnote markers like "[১]" —
      // meaningless without the footnotes themselves, which this app
      // doesn't fetch, so they're stripped rather than left dangling.
      return (json['translations'] as List)
          .map(
            (e) => ((e as Map)['text'] as String)
                .replaceAll(RegExp(r'\[[^\]]*\]'), '')
                .trim(),
          )
          .toList();
    }
    final data = json['data'] as Map;
    return (data['ayahs'] as List)
        .map((e) => (e as Map)['text'] as String)
        .toList();
  } catch (_) {
    return null;
  }
}

/// Surah list with a language picker — tap a surah to read it with translation.
class QuranTranslationScreen extends StatefulWidget {
  const QuranTranslationScreen({super.key});

  @override
  State<QuranTranslationScreen> createState() => _QuranTranslationScreenState();
}

class _QuranTranslationScreenState extends State<QuranTranslationScreen> {
  List<SurahInfo> _index = const [];
  bool _loading = true;
  String _langCode = 'en';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final index = await QuranService.index();
    if (!mounted) return;
    setState(() {
      _index = index;
      _loading = false;
    });
  }

  String get _langName => _langs.firstWhere((l) => l.code == _langCode).name;

  void _pickLang() {
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
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
                child: Text(
                  t('qs.chooseLanguage'),
                  style: const TextStyle(color: AppColors.gold, fontSize: 15),
                ),
              ),
              for (final lang in _langs)
                ListTile(
                  leading: Icon(
                    lang.code == _langCode
                        ? Icons.radio_button_checked
                        : Icons.radio_button_unchecked,
                    color: lang.code == _langCode
                        ? AppColors.gold
                        : AppColors.textMuted,
                    size: 19,
                  ),
                  title: Text(
                    lang.name,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 14,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    setState(() => _langCode = lang.code);
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
          title: Text(t('qs.quranTitle')),
          backgroundColor: AppColors.black,
          foregroundColor: AppColors.gold,
          actions: [
            TextButton.icon(
              icon: const Icon(Icons.language, size: 17),
              label: Text(_langName, style: const TextStyle(fontSize: 13)),
              style: TextButton.styleFrom(foregroundColor: AppColors.gold),
              onPressed: _pickLang,
            ),
          ],
        ),
        body: _loading
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.gold),
              )
            : ListView.builder(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
                itemCount: _index.length,
                itemBuilder: (context, i) {
                  final info = _index[i];
                  return GestureDetector(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) => _QuranTranslationSurahScreen(
                          info: info,
                          langCode: _langCode,
                        ),
                      ),
                    ),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.blackCard,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.goldBorder),
                      ),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 34,
                            child: Text(
                              QuranService.toArabicDigits(info.number),
                              style: const TextStyle(
                                color: AppColors.textMuted,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  info.name,
                                  style: const TextStyle(
                                    color: AppColors.textPrimary,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                Text(
                                  '(${info.nameEn})',
                                  style: const TextStyle(
                                    color: AppColors.textMuted,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            '${QuranService.toArabicDigits(info.ayahCount)} ${t('qs.ayahUnit')}',
                            style: const TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 11,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(
                            Icons.chevron_left,
                            color: AppColors.textMuted,
                            size: 18,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}

/// Arabic text + translation for one surah, loaded in parallel.
class _QuranTranslationSurahScreen extends StatefulWidget {
  final SurahInfo info;
  final String langCode;

  const _QuranTranslationSurahScreen({
    required this.info,
    required this.langCode,
  });

  @override
  State<_QuranTranslationSurahScreen> createState() =>
      _QuranTranslationSurahScreenState();
}

class _QuranTranslationSurahScreenState
    extends State<_QuranTranslationSurahScreen> {
  /// The surah on screen — starts at [_info] but moves on to the next
  /// one when playback finishes it, so this can't stay tied to the widget's
  /// own (immutable) construction argument.
  late SurahInfo _info = widget.info;
  List<SurahInfo> _quranIndex = const [];
  Surah? _surah;
  List<String>? _translation;
  bool _loadingArabic = true;
  bool _loadingTranslation = true;
  bool _translationFailed = false;

  // Audio
  final _tts = FlutterTts();
  Reciter _reciter = RecitationService.defaultReciter;
  bool _arabicOn = true;
  bool _transOn = true;
  int _repeatCount = 1; // 1-5: surah-wide repeat for continuous playback
  final Map<int, int> _ayahRepeat = {}; // per-ayah repeat, defaults to 1
  int? _speakingAyah;
  int _session = 0; // incremented on each stop to cancel in-flight plays
  bool _audioErrorShown = false;

  // Scroll
  final _scrollController = ScrollController();
  final Map<int, GlobalKey> _ayahKeys = {};

  // Language — can be changed from within this screen
  late String _langCode;

  @override
  void initState() {
    super.initState();
    _langCode = widget.langCode;
    _initTts();
    Future.wait([_loadArabic(), _loadTranslation()]);
    QuranService.index().then((i) {
      if (mounted) _quranIndex = i;
    });
  }

  String get _langName => _langs.firstWhere((l) => l.code == _langCode).name;

  Future<void> _initTts() async {
    final locale = _ttsLocale[_langCode] ?? 'en-US';
    await _tts.setLanguage(locale);
    await _tts.setSpeechRate(0.45);
  }

  Future<void> _stopAll() async {
    _session++;
    await AppAudio.player.stop();
    await _tts.stop();
    if (mounted) setState(() => _speakingAyah = null);
  }

  bool _cancelled(int s) => s != _session || !mounted;

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  // just_audio_background refuses any source without a MediaItem tag, so a
  // bare setUrl() throws before a byte is fetched.
  Future<void> _playArabicOnce(Ayah ayah, int s) async {
    final uri = await RecitationDownloads.sourceFor(
      reciter: _reciter,
      surah: _info.number,
      ayah: ayah.number,
    );
    await AppAudio.player.stop();
    if (_cancelled(s)) return;
    await AppAudio.player.setAudioSource(
      AudioSource.uri(
        uri,
        tag: MediaItem(
          id: 'trans:${_reciter.id}:${_info.number}:${ayah.number}',
          title:
              '${_info.name} — ${t('qs.ayahWord')} ${QuranService.toArabicDigits(ayah.number)}',
          artist: _reciter.displayName,
          album: t('qs.quranTitle'),
        ),
      ),
    );
    if (_cancelled(s)) return;
    await AppAudio.player.play();
    await for (final st in AppAudio.player.processingStateStream) {
      if (_cancelled(s)) return;
      if (st == ProcessingState.completed || st == ProcessingState.idle) {
        break;
      }
    }
  }

  // Plays the Arabic [times] times; returns false if playback failed.
  Future<bool> _playArabic(Ayah ayah, int times, int s) async {
    for (int r = 0; r < times; r++) {
      if (_cancelled(s)) return false;
      try {
        await _playArabicOnce(ayah, s);
      } catch (_) {
        if (!_audioErrorShown) {
          _audioErrorShown = true;
          final online = await ConnectivityCheck.online;
          _toast(
            online
                ? t('qs.recitationPlaybackFailed')
                : t('qs.recitationNeedsInternet'),
          );
        }
        return false;
      }
    }
    return true;
  }

  Future<void> _speakTranslation(String trans, int s) async {
    bool done = false;
    _tts.setCompletionHandler(() {
      done = true;
    });
    _tts.setCancelHandler(() {
      done = true;
    });
    _tts.setErrorHandler((_) {
      done = true;
    });
    await _tts.speak(trans);
    while (!done && !_cancelled(s)) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
  }

  void _markSpeaking(int index, Ayah ayah) {
    if (!mounted) return;
    setState(() => _speakingAyah = ayah.number);
    _scrollToAyah(index, ayah.number);
  }

  void _clearSpeaking(int s) {
    if (s == _session && mounted) setState(() => _speakingAyah = null);
  }

  // Continuous playback from [startIndex] through the surah, using the
  // app-bar settings (reciter on/off, surah-wide repeat, translation on/off).
  Future<void> _speakFrom(int startIndex) async {
    await _stopAll();
    if (!_arabicOn && !_transOn) return;
    final s = ++_session;

    final ayahs = _surah?.ayahs ?? [];
    for (int i = startIndex; i < ayahs.length; i++) {
      if (_cancelled(s)) return;
      final ayah = ayahs[i];
      final trans = (_translation != null && i < _translation!.length)
          ? _translation![i]
          : null;
      _markSpeaking(i, ayah);

      if (_arabicOn && _reciter.isPerAyah) {
        await _playArabic(ayah, _repeatCount, s);
      }
      if (_cancelled(s)) return;
      if (_transOn && trans != null) await _speakTranslation(trans, s);
    }
    if (_cancelled(s)) return;
    _clearSpeaking(s);
    // Reaching the end of the surah's ayahs, rather than being cancelled out
    // from under it, means playback ran to completion — carry on into the
    // next surah instead of falling silent, the same as every other Quran
    // card in the app now does.
    await _advanceToNextSurah(s);
  }

  Future<void> _advanceToNextSurah(int s) async {
    if (_cancelled(s) || _quranIndex.isEmpty) return;
    final nextNumber = _info.number >= 114 ? 1 : _info.number + 1;
    final nextInfo = _quranIndex
        .where((x) => x.number == nextNumber)
        .firstOrNull;
    if (nextInfo == null) return;
    final surah = await QuranService.surah(nextNumber);
    final trans = await _fetchTranslation(_langCode, nextNumber);
    if (_cancelled(s) || !mounted) return;
    setState(() {
      _info = nextInfo;
      _surah = surah;
      _translation = trans;
      _translationFailed = trans == null;
      _ayahKeys.clear();
    });
    await _speakFrom(0);
  }

  // One ayah only, repeated as many times as its own card counter says.
  Future<void> _playAyahArabic(int index, Ayah ayah) async {
    await _stopAll();
    final s = ++_session;
    _markSpeaking(index, ayah);
    await _playArabic(ayah, _ayahRepeat[ayah.number] ?? 1, s);
    _clearSpeaking(s);
  }

  Future<void> _playAyahTranslation(int index, Ayah ayah, String trans) async {
    await _stopAll();
    final s = ++_session;
    _markSpeaking(index, ayah);
    await _speakTranslation(trans, s);
    _clearSpeaking(s);
  }

  void _scrollToAyah(int listIndex, int ayahNumber) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final ctx = _ayahKeys[ayahNumber]?.currentContext;
      if (ctx != null) {
        Scrollable.ensureVisible(
          ctx,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeInOut,
          alignment: 0.15,
        );
      } else if (_scrollController.hasClients) {
        // Item not built yet — jump to estimated position to force it into view
        final bannerOffset = _translationFailed ? 1 : 0;
        const avgCardHeight = 220.0;
        final pos = ((listIndex + bannerOffset) * avgCardHeight + 8).clamp(
          0.0,
          _scrollController.position.maxScrollExtent,
        );
        _scrollController.animateTo(
          pos,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    AppAudio.player.stop();
    _tts.stop();
    super.dispose();
  }

  Future<void> _loadArabic() async {
    final surah = await QuranService.surah(_info.number);
    if (!mounted) return;
    setState(() {
      _surah = surah;
      _loadingArabic = false;
    });
  }

  Future<void> _loadTranslation() async {
    final trans = await _fetchTranslation(_langCode, _info.number);
    if (!mounted) return;
    setState(() {
      _translation = trans;
      _loadingTranslation = false;
      _translationFailed = trans == null;
    });
  }

  bool get _loading => _loadingArabic || _loadingTranslation;

  void _pickLang() {
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
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
                child: Text(
                  t('qs.chooseLanguage'),
                  style: const TextStyle(color: AppColors.gold, fontSize: 15),
                ),
              ),
              for (final lang in _langs)
                ListTile(
                  leading: Icon(
                    lang.code == _langCode
                        ? Icons.radio_button_checked
                        : Icons.radio_button_unchecked,
                    color: lang.code == _langCode
                        ? AppColors.gold
                        : AppColors.textMuted,
                    size: 19,
                  ),
                  title: Text(
                    lang.name,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 14,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    if (lang.code == _langCode) return;
                    setState(() {
                      _langCode = lang.code;
                      _translation = null;
                      _loadingTranslation = true;
                      _translationFailed = false;
                    });
                    _initTts();
                    _loadTranslation();
                  },
                ),
              const SizedBox(height: 8),
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
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
                child: Text(
                  t('qs.chooseReciter'),
                  style: const TextStyle(color: AppColors.gold, fontSize: 15),
                ),
              ),
              for (final r in RecitationService.reciters.where(
                (r) => r.mp3quranPath == null,
              ))
                ListTile(
                  leading: Icon(
                    r.id == _reciter.id
                        ? Icons.radio_button_checked
                        : Icons.radio_button_unchecked,
                    color: r.id == _reciter.id
                        ? AppColors.gold
                        : AppColors.textMuted,
                    size: 19,
                  ),
                  title: Text(
                    r.displayName,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 14,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    setState(() => _reciter = r);
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
          title: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(_info.name),
              const SizedBox(width: 6),
              Text(
                '(${_info.nameEn})',
                textDirection: TextDirection.ltr,
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          centerTitle: true,
          backgroundColor: AppColors.black,
          foregroundColor: AppColors.gold,
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(44),
            child: _controlsBar(),
          ),
        ),
        body: _loading
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.gold),
              )
            : ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.fromLTRB(14, 8, 14, 32),
                itemCount:
                    (_surah?.ayahs.length ?? 0) + (_translationFailed ? 1 : 0),
                itemBuilder: (context, i) {
                  if (_translationFailed && i == 0) {
                    return _errorBanner();
                  }
                  final offset = _translationFailed ? 1 : 0;
                  final idx = i - offset;
                  final ayah = _surah!.ayahs[idx];
                  final trans =
                      (_translation != null && idx < _translation!.length)
                      ? _translation![idx]
                      : null;
                  return _ayahCard(ayah, trans, idx);
                },
              ),
      ),
    );
  }

  // Surah-wide playback settings: reciter, Arabic on/off, repeat, TTS on/off,
  // language. The per-ayah buttons on each card use their own counters.
  Widget _controlsBar() {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.goldBorder)),
      ),
      child: Row(
        children: [
          Flexible(
            child: TextButton(
              onPressed: _pickReciter,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 6),
              ),
              child: Text(
                _reciter.displayName,
                style: const TextStyle(color: AppColors.textGold, fontSize: 12),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          const Spacer(),
          IconButton(
            tooltip: t('qs.reciterVoiceTooltip'),
            visualDensity: VisualDensity.compact,
            icon: Icon(
              Icons.record_voice_over,
              color: _arabicOn ? AppColors.gold : AppColors.textMuted,
              size: 22,
            ),
            onPressed: () => setState(() => _arabicOn = !_arabicOn),
          ),
          GestureDetector(
            onTap: _arabicOn
                ? () => setState(() {
                    _repeatCount = _repeatCount % 5 + 1;
                  })
                : null,
            behavior: HitTestBehavior.opaque,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                border: Border.all(
                  color: _arabicOn
                      ? AppColors.goldBorder
                      : AppColors.textMuted.withValues(alpha: 0.3),
                ),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '×$_repeatCount',
                style: TextStyle(
                  color: _arabicOn ? AppColors.gold : AppColors.textMuted,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          IconButton(
            tooltip: t('qs.translationVoiceTooltip'),
            visualDensity: VisualDensity.compact,
            icon: Icon(
              Icons.translate,
              color: _transOn ? AppColors.gold : AppColors.textMuted,
              size: 22,
            ),
            onPressed: () => setState(() => _transOn = !_transOn),
          ),
          TextButton.icon(
            icon: const Icon(Icons.language, size: 16),
            label: Text(_langName, style: const TextStyle(fontSize: 12)),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.gold,
              padding: const EdgeInsets.symmetric(horizontal: 6),
            ),
            onPressed: _pickLang,
          ),
        ],
      ),
    );
  }

  Widget _errorBanner() {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.blackCard,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.goldBorder),
      ),
      child: Row(
        children: [
          const Icon(Icons.wifi_off, color: AppColors.textMuted, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              t('qs.translationLoadFailed'),
              style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
            ),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                _loadingTranslation = true;
                _translationFailed = false;
              });
              _loadTranslation();
            },
            child: Text(
              t('qs.retryLabel'),
              style: const TextStyle(color: AppColors.gold, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _cardButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
          child: Icon(icon, color: AppColors.textMuted, size: 20),
        ),
      ),
    );
  }

  Widget _ayahCard(Ayah ayah, String? trans, int index) {
    final speaking = _speakingAyah == ayah.number;
    final canPlay = _arabicOn || (_transOn && trans != null);
    final repeat = _ayahRepeat[ayah.number] ?? 1;
    final key = _ayahKeys.putIfAbsent(ayah.number, GlobalKey.new);
    return Container(
      key: key,
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.blackCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: speaking ? AppColors.gold : AppColors.goldBorder,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: AppColors.goldMuted,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.goldBorder),
                ),
                child: Text(
                  QuranService.toArabicDigits(ayah.number),
                  style: const TextStyle(color: AppColors.gold, fontSize: 12),
                ),
              ),
              const Spacer(),
              // Per-ayah: reciter once/N times, its own counter, translation.
              if (_reciter.isPerAyah) ...[
                _cardButton(
                  icon: Icons.record_voice_over,
                  tooltip: t('qs.playReciterTooltip'),
                  onTap: () => _playAyahArabic(index, ayah),
                ),
                GestureDetector(
                  onTap: () => setState(() {
                    _ayahRepeat[ayah.number] = repeat % 5 + 1;
                  }),
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.goldBorder),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '×$repeat',
                      style: TextStyle(
                        color: repeat > 1
                            ? AppColors.gold
                            : AppColors.textMuted,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
              if (trans != null)
                _cardButton(
                  icon: Icons.translate,
                  tooltip: t('qs.playTranslationTooltip'),
                  onTap: () => _playAyahTranslation(index, ayah, trans),
                ),
              if (canPlay) ...[
                Container(
                  width: 1,
                  height: 18,
                  margin: const EdgeInsets.symmetric(horizontal: 6),
                  color: AppColors.goldBorder,
                ),
                // Continuous playback from here, per the app-bar settings.
                GestureDetector(
                  onTap: () => speaking ? _stopAll() : _speakFrom(index),
                  behavior: HitTestBehavior.opaque,
                  child: Icon(
                    speaking
                        ? Icons.stop_circle_outlined
                        : Icons.play_circle_outline,
                    color: speaking ? AppColors.gold : AppColors.textMuted,
                    size: 22,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 10),
          Text(
            ayah.text,
            textAlign: TextAlign.right,
            textDirection: TextDirection.rtl,
            style: const TextStyle(
              fontFamily: 'AmiriQuran',
              color: AppColors.textPrimary,
              fontSize: 22,
              height: 2.0,
            ),
          ),
          if (trans != null) ...[
            const SizedBox(height: 10),
            const Divider(color: AppColors.goldBorder, height: 1),
            const SizedBox(height: 10),
            Text(
              trans,
              textDirection: TextDirection.ltr,
              textAlign: TextAlign.left,
              style: TextStyle(
                color: speaking ? AppColors.textGold : AppColors.textSecondary,
                fontSize: 14,
                height: 1.6,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
