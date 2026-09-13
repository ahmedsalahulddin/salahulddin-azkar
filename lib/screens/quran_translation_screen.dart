import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:http/http.dart' as http;
import 'package:just_audio/just_audio.dart' show ProcessingState;
import 'package:path_provider/path_provider.dart';

import '../constants/theme.dart';
import '../data/quran_data.dart';
import '../services/app_audio.dart';
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
};

Future<List<String>?> _fetchTranslation(String lang, int surahNum) async {
  final dir = await getApplicationDocumentsDirectory();
  final file =
      File('${dir.path}/quran_translations_v2/$lang/$surahNum.json');
  if (await file.exists()) {
    return _parse(await file.readAsString());
  }
  final ed = _edition[lang] ?? 'en.sahih';
  try {
    final res = await http
        .get(Uri.parse('$_apiBase/$surahNum/$ed'))
        .timeout(const Duration(seconds: 20));
    if (res.statusCode != 200) return null;
    await file.parent.create(recursive: true);
    await file.writeAsBytes(res.bodyBytes);
    return _parse(res.body);
  } catch (_) {
    return null;
  }
}

List<String>? _parse(String body) {
  try {
    final json = jsonDecode(body) as Map;
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
  State<QuranTranslationScreen> createState() =>
      _QuranTranslationScreenState();
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

  String get _langName =>
      _langs.firstWhere((l) => l.code == _langCode).name;

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
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 16, 20, 4),
                child: Text('اختر اللغة',
                    style: TextStyle(color: AppColors.gold, fontSize: 15)),
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
                  title: Text(lang.name,
                      style: const TextStyle(
                          color: AppColors.textPrimary, fontSize: 14)),
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
          title: const Text('القرآن الكريم'),
          backgroundColor: AppColors.black,
          foregroundColor: AppColors.gold,
          actions: [
            TextButton.icon(
              icon: const Icon(Icons.language, size: 17),
              label: Text(_langName,
                  style: const TextStyle(fontSize: 13)),
              style: TextButton.styleFrom(foregroundColor: AppColors.gold),
              onPressed: _pickLang,
            ),
          ],
        ),
        body: _loading
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.gold))
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
                          horizontal: 14, vertical: 12),
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
                                  color: AppColors.textMuted, fontSize: 12),
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
                                      fontWeight: FontWeight.w500),
                                ),
                                Text(
                                  '(${info.nameEn})',
                                  style: const TextStyle(
                                      color: AppColors.textMuted,
                                      fontSize: 11),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            '${QuranService.toArabicDigits(info.ayahCount)} آية',
                            style: const TextStyle(
                                color: AppColors.textMuted, fontSize: 11),
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.chevron_left,
                              color: AppColors.textMuted, size: 18),
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
  int _repeatCount = 1; // 1-5: how many times to repeat the Arabic recitation
  int? _speakingAyah;
  int _session = 0; // incremented on each stop to cancel in-flight plays

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
  }

  String get _langName =>
      _langs.firstWhere((l) => l.code == _langCode).name;

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

  // Plays starting from [startIndex] and auto-advances through the surah.
  Future<void> _speakFrom(int startIndex) async {
    await _stopAll();
    if (!_arabicOn && !_transOn) return;
    final s = ++_session;

    final ayahs = _surah?.ayahs ?? [];
    for (int i = startIndex; i < ayahs.length; i++) {
      if (s != _session || !mounted) return;

      final ayah = ayahs[i];
      final trans = (_translation != null && i < _translation!.length)
          ? _translation![i]
          : null;

      if (mounted) {
        setState(() => _speakingAyah = ayah.number);
        _scrollToAyah(i, ayah.number);
      }

      // 1. Arabic recitation — repeated _repeatCount times
      if (_arabicOn && _reciter.isPerAyah) {
        final url = RecitationService.urlFor(
          reciterId: _reciter.id,
          surah: widget.info.number,
          ayah: ayah.number,
        );
        for (int r = 0; r < _repeatCount; r++) {
          if (s != _session || !mounted) return;
          try {
            await AppAudio.player.stop();
            if (s != _session || !mounted) return;
            await AppAudio.player.setUrl(url);
            if (s != _session || !mounted) return;
            await AppAudio.player.play();
            await for (final state
                in AppAudio.player.processingStateStream) {
              if (s != _session || !mounted) return;
              if (state == ProcessingState.completed ||
                  state == ProcessingState.idle) { break; }
            }
          } catch (_) {}
        }
      }

      // 2. Translation TTS
      if (s != _session || !mounted) return;
      if (_transOn && trans != null) {
        bool done = false;
        _tts.setCompletionHandler(() { done = true; });
        _tts.setCancelHandler(() { done = true; });
        await _tts.speak(trans);
        while (!done && s == _session && mounted) {
          await Future<void>.delayed(const Duration(milliseconds: 100));
        }
      }
    }

    if (s == _session && mounted) setState(() => _speakingAyah = null);
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
        final pos = ((listIndex + bannerOffset) * avgCardHeight + 8)
            .clamp(0.0, _scrollController.position.maxScrollExtent);
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
    final surah = await QuranService.surah(widget.info.number);
    if (!mounted) return;
    setState(() {
      _surah = surah;
      _loadingArabic = false;
    });
  }

  Future<void> _loadTranslation() async {
    final trans = await _fetchTranslation(_langCode, widget.info.number);
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
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 16, 20, 4),
                child: Text('اختر اللغة',
                    style: TextStyle(color: AppColors.gold, fontSize: 15)),
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
                  title: Text(lang.name,
                      style: const TextStyle(
                          color: AppColors.textPrimary, fontSize: 14)),
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
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 16, 20, 4),
                child: Text('اختر المقرئ',
                    style: TextStyle(color: AppColors.gold, fontSize: 15)),
              ),
              for (final r in RecitationService.reciters
                  .where((r) => r.mp3quranPath == null))
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
                  title: Text(r.name,
                      style: const TextStyle(
                          color: AppColors.textPrimary, fontSize: 14)),
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
          title: Text(widget.info.name),
          backgroundColor: AppColors.black,
          foregroundColor: AppColors.gold,
          actions: [
            // Reciter name — always visible
            TextButton(
              onPressed: _pickReciter,
              child: Text(
                _reciter.name,
                style: const TextStyle(
                    color: AppColors.textGold, fontSize: 11),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            // Arabic audio toggle
            IconButton(
              tooltip: 'صوت المقرئ',
              icon: Icon(
                Icons.record_voice_over,
                color: _arabicOn ? AppColors.gold : AppColors.textMuted,
                size: 22,
              ),
              onPressed: () => setState(() => _arabicOn = !_arabicOn),
            ),
            // Repeat counter for Arabic (1→2→3→4→5→1)
            GestureDetector(
              onTap: _arabicOn
                  ? () => setState(() { _repeatCount = _repeatCount % 5 + 1; })
                  : null,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                margin: const EdgeInsets.symmetric(vertical: 14),
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
                    color: _arabicOn
                        ? AppColors.gold
                        : AppColors.textMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 4),
            // Translation TTS toggle
            IconButton(
              tooltip: 'صوت الترجمة',
              icon: Icon(
                Icons.translate,
                color: _transOn ? AppColors.gold : AppColors.textMuted,
                size: 22,
              ),
              onPressed: () => setState(() => _transOn = !_transOn),
            ),
            // Language selector
            TextButton.icon(
              icon: const Icon(Icons.language, size: 17),
              label: Text(_langName,
                  style: const TextStyle(fontSize: 13)),
              style: TextButton.styleFrom(foregroundColor: AppColors.gold),
              onPressed: _pickLang,
            ),
          ],
        ),
        body: _loading
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.gold))
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
          const Expanded(
            child: Text(
              'تعذّر تحميل الترجمة — تحقق من الاتصال.',
              style: TextStyle(color: AppColors.textMuted, fontSize: 12),
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
            child: const Text('أعد',
                style: TextStyle(color: AppColors.gold, fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Widget _ayahCard(Ayah ayah, String? trans, int index) {
    final speaking = _speakingAyah == ayah.number;
    final anySpeaking = _speakingAyah != null;
    final canPlay = _arabicOn || (_transOn && trans != null);
    final key = _ayahKeys.putIfAbsent(ayah.number, GlobalKey.new);
    return Container(
      key: key,
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.blackCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: speaking ? AppColors.gold : AppColors.goldBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
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
              if (canPlay)
                GestureDetector(
                  onTap: () => anySpeaking && speaking
                      ? _stopAll()
                      : _speakFrom(index),
                  child: Icon(
                    speaking
                        ? Icons.stop_circle_outlined
                        : Icons.play_circle_outline,
                    color: speaking ? AppColors.gold : AppColors.textMuted,
                    size: 22,
                  ),
                ),
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
