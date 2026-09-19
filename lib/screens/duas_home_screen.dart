import 'package:flutter/material.dart';

import '../constants/theme.dart';
import '../services/auth_service.dart';
import '../services/duas_service.dart';
import '../widgets/sign_in_buttons.dart' show SignInButton;
import 'dua_category_detail_screen.dart';

/// The public dua card, reached from the home screen — the shared base
/// collection (same for every reader) plus, for a signed-in reader, their
/// own additions on top, synced to their account like favourites and
/// bookmarks. A guest sees the base collection and a sign-in prompt where
/// their own section would be.
class DuasHomeScreen extends StatefulWidget {
  const DuasHomeScreen({super.key});

  @override
  State<DuasHomeScreen> createState() => _DuasHomeScreenState();
}

class _DuasHomeScreenState extends State<DuasHomeScreen> {
  List<DuaCategory> _base = [];
  List<DuaCategory> _mine = [];
  bool _loading = true;
  SignInProvider? _signingInWith;

  @override
  void initState() {
    super.initState();
    AuthService.user.addListener(_load);
    _load();
  }

  @override
  void dispose() {
    AuthService.user.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    final results = await Future.wait([DuasService.base(), DuasService.mine()]);
    if (!mounted) return;
    setState(() {
      _base = results[0];
      _mine = results[1];
      _loading = false;
    });
  }

  Future<void> _persistMine() async {
    await DuasService.saveMine(_mine);
  }

  Future<void> _addMyCategory() async {
    if (AuthService.user.value == null) {
      _promptSignIn();
      return;
    }
    final title = await _promptText(dialogTitle: 'اسم التصنيف الجديد');
    if (title == null || title.trim().isEmpty) return;
    setState(() {
      _mine = [
        ..._mine,
        DuaCategory(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          title: title.trim(),
          icon: '🤲',
          duas: const [],
        ),
      ];
    });
    await _persistMine();
  }

  void _promptSignIn() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.blackCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (_) => Directionality(
        textDirection: TextDirection.rtl,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'سجّل دخولك لإضافة أدعيتك الخاصة',
                  style: TextStyle(color: AppColors.gold, fontSize: 15),
                ),
                const SizedBox(height: 4),
                const Text(
                  'هتلاقيها معاك في أي جهاز تدخل بنفس حسابك منه',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                ),
                const SizedBox(height: 16),
                ValueListenableBuilder<Set<SignInProvider>>(
                  valueListenable: AuthService.availableProviders,
                  builder: (context, providers, _) => StatefulBuilder(
                    builder: (context, setSheetState) => Column(
                      children: [
                        for (final provider in SignInProvider.values.where(
                          providers.contains,
                        ))
                          SignInButton(
                            provider: provider,
                            busy: _signingInWith == provider,
                            onPressed: _signingInWith != null
                                ? null
                                : () async {
                                    setSheetState(
                                      () => _signingInWith = provider,
                                    );
                                    await AuthService.signInWith(provider);
                                    if (!context.mounted) return;
                                    setSheetState(() => _signingInWith = null);
                                    Navigator.pop(context);
                                  },
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<String?> _promptText({
    required String dialogTitle,
    String initial = '',
  }) {
    final controller = TextEditingController(text: initial);
    return showDialog<String>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: AppColors.blackCard,
          title: Text(
            dialogTitle,
            style: const TextStyle(color: AppColors.gold),
          ),
          content: TextField(
            controller: controller,
            autofocus: true,
            style: const TextStyle(color: AppColors.textPrimary),
            decoration: const InputDecoration(
              enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: AppColors.goldBorder),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text(
                'إلغاء',
                style: TextStyle(color: AppColors.textMuted),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, controller.text),
              child: const Text('حفظ', style: TextStyle(color: AppColors.gold)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openBase(int index) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            DuaCategoryDetailScreen(category: _base[index], editable: false),
      ),
    );
  }

  Future<void> _openMine(int index) async {
    final updated = await Navigator.push<DuaCategory>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            DuaCategoryDetailScreen(category: _mine[index], editable: true),
      ),
    );
    if (updated == null) return;
    setState(() => _mine[index] = updated);
    await _persistMine();
  }

  Future<void> _deleteMine(int index) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: AppColors.blackCard,
          title: const Text(
            'حذف التصنيف؟',
            style: TextStyle(color: AppColors.gold),
          ),
          content: Text(
            _mine[index].title,
            style: const TextStyle(color: AppColors.textSecondary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text(
                'إلغاء',
                style: TextStyle(color: AppColors.textMuted),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text(
                'حذف',
                style: TextStyle(color: AppColors.error),
              ),
            ),
          ],
        ),
      ),
    );
    if (ok == true) {
      setState(() => _mine = [..._mine]..removeAt(index));
      await _persistMine();
    }
  }

  @override
  Widget build(BuildContext context) {
    final signedIn = AuthService.user.value != null;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.black,
        appBar: AppBar(
          title: const Text('الأدعية'),
          backgroundColor: AppColors.black,
          foregroundColor: AppColors.gold,
        ),
        floatingActionButton: FloatingActionButton(
          backgroundColor: AppColors.gold,
          foregroundColor: AppColors.black,
          onPressed: _addMyCategory,
          tooltip: 'أضف تصنيفًا خاصًا بك',
          child: const Icon(Icons.add),
        ),
        body: _loading
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.gold),
              )
            : ListView(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 90),
                children: [
                  if (_base.isNotEmpty) ...[
                    _sectionTitle('الأدعية'),
                    _grid(_base, onTap: _openBase),
                    const SizedBox(height: 22),
                  ],
                  _sectionTitle('أدعيتي الخاصة'),
                  if (!signedIn)
                    _signInHint()
                  else if (_mine.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Text(
                        'اضغط + لإضافة أول تصنيف خاص بك',
                        style: TextStyle(color: AppColors.textMuted),
                      ),
                    )
                  else
                    _grid(_mine, onTap: _openMine, onLongPress: _deleteMine),
                ],
              ),
      ),
    );
  }

  Widget _sectionTitle(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Text(
      text,
      style: const TextStyle(
        color: AppColors.gold,
        fontSize: 16,
        fontWeight: FontWeight.bold,
      ),
    ),
  );

  Widget _signInHint() {
    return GestureDetector(
      onTap: _promptSignIn,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.blackCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.goldBorder),
        ),
        child: const Text(
          'سجّل دخولك لتضيف أدعيتك الخاصة وتلاقيها معاك في أي جهاز',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.textMuted, fontSize: 13),
        ),
      ),
    );
  }

  Widget _grid(
    List<DuaCategory> cats, {
    required void Function(int) onTap,
    void Function(int)? onLongPress,
  }) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.1,
      ),
      itemCount: cats.length,
      itemBuilder: (context, i) {
        final cat = cats[i];
        return GestureDetector(
          onTap: () => onTap(i),
          onLongPress: onLongPress == null ? null : () => onLongPress(i),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [AppColors.navyLight, AppColors.navy],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.goldBorder),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(cat.icon, style: const TextStyle(fontSize: 30)),
                const SizedBox(height: 10),
                Text(
                  cat.title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${cat.duas.length} دعاء',
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
