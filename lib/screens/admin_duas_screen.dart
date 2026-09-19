import 'package:flutter/material.dart';

import '../constants/theme.dart';
import '../services/duas_service.dart';
import 'dua_category_detail_screen.dart';

/// Where the admin edits the shared base dua collection — every reader
/// sees exactly this, on the home screen, without a new app build.
/// Reachable only from the admin section (see account_screen.dart); the
/// write policy on duas_base also rejects anyone else server-side.
class AdminDuasScreen extends StatefulWidget {
  const AdminDuasScreen({super.key});

  @override
  State<AdminDuasScreen> createState() => _AdminDuasScreenState();
}

class _AdminDuasScreenState extends State<AdminDuasScreen> {
  List<DuaCategory> _categories = [];
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final cats = await DuasService.base();
    if (!mounted) return;
    setState(() {
      _categories = cats;
      _loading = false;
    });
  }

  Future<void> _persist() async {
    setState(() => _saving = true);
    try {
      await DuasService.saveBase(_categories);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _addCategory() async {
    final title = await _promptText(dialogTitle: 'اسم التصنيف الجديد');
    if (title == null || title.trim().isEmpty) return;
    setState(() {
      _categories = [
        ..._categories,
        DuaCategory(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          title: title.trim(),
          icon: '🤲',
          duas: const [],
        ),
      ];
    });
    await _persist();
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

  Future<void> _openCategory(int index) async {
    final updated = await Navigator.push<DuaCategory>(
      context,
      MaterialPageRoute(
        builder: (_) => DuaCategoryDetailScreen(
          category: _categories[index],
          editable: true,
        ),
      ),
    );
    if (updated == null) return;
    setState(() => _categories[index] = updated);
    await _persist();
  }

  Future<void> _confirmDelete(int index) async {
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
            _categories[index].title,
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
      setState(() => _categories = [..._categories]..removeAt(index));
      await _persist();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.black,
        appBar: AppBar(
          title: Text(
            _saving ? 'أدعية العامة (جارٍ الحفظ...)' : 'الأدعية العامة',
          ),
          backgroundColor: AppColors.black,
          foregroundColor: AppColors.gold,
        ),
        floatingActionButton: FloatingActionButton(
          backgroundColor: AppColors.gold,
          foregroundColor: AppColors.black,
          onPressed: _addCategory,
          child: const Icon(Icons.add),
        ),
        body: _loading
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.gold),
              )
            : _categories.isEmpty
            ? const Center(
                child: Text(
                  'اضغط + لإضافة أول تصنيف',
                  style: TextStyle(color: AppColors.textMuted),
                ),
              )
            : GridView.builder(
                padding: const EdgeInsets.all(14),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 1.1,
                ),
                itemCount: _categories.length,
                itemBuilder: (context, i) {
                  final cat = _categories[i];
                  return GestureDetector(
                    onTap: () => _openCategory(i),
                    onLongPress: () => _confirmDelete(i),
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
              ),
      ),
    );
  }
}
