import 'package:flutter/material.dart';

import '../constants/theme.dart';
import '../services/personal_duas_service.dart';
import '../services/section_config.dart';

/// The hidden personal-duas section's front door — a grid of category
/// cards, each opening onto its own list of duas. Never reachable from a
/// general reader's navigation; the caller only pushes this after checking
/// [PersonalDuasService.categories] returns something or the reader is
/// admin (see account_screen.dart).
class PersonalDuasHomeScreen extends StatefulWidget {
  const PersonalDuasHomeScreen({super.key});

  @override
  State<PersonalDuasHomeScreen> createState() => _PersonalDuasHomeScreenState();
}

class _PersonalDuasHomeScreenState extends State<PersonalDuasHomeScreen> {
  List<PersonalDuaCategory> _categories = [];
  bool _loading = true;
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final results = await Future.wait([
      PersonalDuasService.categories(),
      SectionConfig.isAdmin(),
    ]);
    if (!mounted) return;
    setState(() {
      _categories = (results[0] as List<PersonalDuaCategory>?) ?? [];
      _isAdmin = results[1] as bool;
      _loading = false;
    });
  }

  Future<void> _persist() async {
    await PersonalDuasService.saveCategories(_categories);
  }

  Future<void> _addCategory() async {
    final title = await _promptText(dialogTitle: 'اسم التصنيف الجديد');
    if (title == null || title.trim().isEmpty) return;
    setState(() {
      _categories = [
        ..._categories,
        PersonalDuaCategory(
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
    final updated = await Navigator.push<PersonalDuaCategory>(
      context,
      MaterialPageRoute(
        builder: (_) => PersonalDuaCategoryScreen(
          category: _categories[index],
          isAdmin: _isAdmin,
        ),
      ),
    );
    if (updated == null) return;
    setState(() => _categories[index] = updated);
    await _persist();
  }

  Future<void> _deleteCategory(int index) async {
    setState(() => _categories = [..._categories]..removeAt(index));
    await _persist();
  }

  Future<void> _manageGrants() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.blackCard,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (_) => const _GrantsSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.black,
        appBar: AppBar(
          title: const Text('أدعيتي الخاصة'),
          backgroundColor: AppColors.black,
          foregroundColor: AppColors.gold,
          actions: [
            if (_isAdmin)
              IconButton(
                icon: const Icon(Icons.people_outline),
                tooltip: 'إدارة الصلاحيات',
                onPressed: _manageGrants,
              ),
          ],
        ),
        floatingActionButton: _isAdmin
            ? FloatingActionButton(
                backgroundColor: AppColors.gold,
                foregroundColor: AppColors.black,
                onPressed: _addCategory,
                child: const Icon(Icons.add),
              )
            : null,
        body: _loading
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.gold),
              )
            : _categories.isEmpty
            ? Center(
                child: Text(
                  _isAdmin ? 'اضغط + لإضافة أول تصنيف' : 'لا يوجد محتوى بعد',
                  style: const TextStyle(color: AppColors.textMuted),
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
                    onLongPress: _isAdmin ? () => _confirmDelete(i) : null,
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
    if (ok == true) await _deleteCategory(index);
  }
}

/// One category's duas — a plain bulleted list to read, or (for the admin)
/// a line-per-dua editor with a title field.
class PersonalDuaCategoryScreen extends StatefulWidget {
  final PersonalDuaCategory category;
  final bool isAdmin;

  const PersonalDuaCategoryScreen({
    super.key,
    required this.category,
    required this.isAdmin,
  });

  @override
  State<PersonalDuaCategoryScreen> createState() =>
      _PersonalDuaCategoryScreenState();
}

class _PersonalDuaCategoryScreenState extends State<PersonalDuaCategoryScreen> {
  late final _titleController = TextEditingController(
    text: widget.category.title,
  );
  late final _duasController = TextEditingController(
    text: widget.category.duas.join('\n\n'),
  );
  bool _editing = false;

  @override
  void dispose() {
    _titleController.dispose();
    _duasController.dispose();
    super.dispose();
  }

  void _saveAndPop() {
    final duas = _duasController.text
        .split('\n\n')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    Navigator.pop(
      context,
      widget.category.copyWith(
        title: _titleController.text.trim().isEmpty
            ? widget.category.title
            : _titleController.text.trim(),
        duas: duas,
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
          title: Text(widget.category.title),
          backgroundColor: AppColors.black,
          foregroundColor: AppColors.gold,
          actions: [
            if (widget.isAdmin)
              IconButton(
                icon: Icon(_editing ? Icons.check : Icons.edit),
                tooltip: _editing ? 'حفظ' : 'تعديل',
                onPressed: () {
                  if (_editing) {
                    _saveAndPop();
                  } else {
                    setState(() => _editing = true);
                  }
                },
              ),
          ],
        ),
        body: _editing ? _editor() : _reader(),
      ),
    );
  }

  Widget _editor() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _titleController,
            style: const TextStyle(color: AppColors.gold, fontSize: 16),
            decoration: const InputDecoration(
              labelText: 'اسم التصنيف',
              labelStyle: TextStyle(color: AppColors.textMuted),
              enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: AppColors.goldBorder),
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'كل دعاء في سطر، واترك سطرًا فارغًا بين كل دعاء وآخر',
            style: TextStyle(color: AppColors.textMuted, fontSize: 11),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: TextField(
              controller: _duasController,
              maxLines: null,
              expands: true,
              textAlignVertical: TextAlignVertical.top,
              style: const TextStyle(color: AppColors.textPrimary, height: 1.8),
              decoration: InputDecoration(
                filled: true,
                fillColor: AppColors.blackCard,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppColors.goldBorder),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _reader() {
    final duas = widget.category.duas;
    if (duas.isEmpty) {
      return const Center(
        child: Text(
          'لا توجد أدعية هنا بعد',
          style: TextStyle(color: AppColors.textMuted),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: duas.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (_, i) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.blackCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.goldBorder),
        ),
        child: Text(
          duas[i],
          textAlign: TextAlign.right,
          style: const TextStyle(
            color: AppColors.textPrimary,
            height: 1.9,
            fontSize: 15,
          ),
        ),
      ),
    );
  }
}

class _GrantsSheet extends StatefulWidget {
  const _GrantsSheet();

  @override
  State<_GrantsSheet> createState() => _GrantsSheetState();
}

class _GrantsSheetState extends State<_GrantsSheet> {
  final _emailController = TextEditingController();
  List<PersonalDuaGrant> _grants = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final grants = await PersonalDuasService.grants();
    if (mounted) {
      setState(() {
        _grants = grants;
        _loading = false;
      });
    }
  }

  Future<void> _add() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) return;
    setState(() => _error = null);
    try {
      await PersonalDuasService.grant(email);
      _emailController.clear();
      await _load();
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'تعذّر — تأكد أن البريد مسجّل في التطبيق');
      }
    }
  }

  Future<void> _remove(String userId) async {
    await PersonalDuasService.revoke(userId);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 16,
            bottom: MediaQuery.viewInsetsOf(context).bottom + 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'من يقدر يشوف هذا القسم',
                style: TextStyle(
                  color: AppColors.gold,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _emailController,
                      style: const TextStyle(color: AppColors.textPrimary),
                      decoration: InputDecoration(
                        hintText: 'البريد الإلكتروني',
                        hintStyle: const TextStyle(color: AppColors.textMuted),
                        filled: true,
                        fillColor: AppColors.blackCard,
                        isDense: true,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(
                            color: AppColors.goldBorder,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: _add,
                    icon: const Icon(Icons.add_circle, color: AppColors.gold),
                  ),
                ],
              ),
              if (_error != null) ...[
                const SizedBox(height: 6),
                Text(
                  _error!,
                  style: const TextStyle(color: AppColors.error, fontSize: 12),
                ),
              ],
              const SizedBox(height: 12),
              if (_loading)
                const Center(
                  child: CircularProgressIndicator(color: AppColors.gold),
                )
              else if (_grants.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    'محدش عنده صلاحية دلوقتي',
                    style: TextStyle(color: AppColors.textMuted),
                  ),
                )
              else
                ...(_grants.map(
                  (g) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      g.email ?? g.userId,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 13,
                      ),
                    ),
                    trailing: IconButton(
                      icon: const Icon(
                        Icons.remove_circle_outline,
                        color: AppColors.error,
                      ),
                      onPressed: () => _remove(g.userId),
                    ),
                  ),
                )),
            ],
          ),
        ),
      ),
    );
  }
}
