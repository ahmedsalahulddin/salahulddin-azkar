import 'package:flutter/material.dart';
import '../constants/theme.dart';
import '../services/section_config.dart';

/// Turns home-screen sections on and off, and reorders them, without shipping
/// a new build.
///
/// Reachable only for accounts listed in app_admins.
class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  List<SectionSetting> _sections = [];
  bool _loading = true;
  bool _saving = false;
  bool _dirty = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    await SectionConfig.refresh();
    if (!mounted) return;
    setState(() {
      _sections = SectionConfig.settings.value.values.toList()
        ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
      _loading = false;
    });
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final ok = await SectionConfig.save(_sections);
    if (!mounted) return;
    setState(() {
      _saving = false;
      if (ok) _dirty = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok ? 'تم الحفظ — سيظهر التغيير للجميع' : 'تعذّر الحفظ — حاول مجدداً',
          textDirection: TextDirection.rtl,
        ),
        backgroundColor: ok ? AppColors.emerald : AppColors.error,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hiddenCount = _sections.where((s) => !s.enabled).length;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.black,
        appBar: AppBar(
          title: const Text('إدارة الأقسام'),
          backgroundColor: AppColors.black,
          foregroundColor: AppColors.gold,
          actions: [
            if (_dirty)
              TextButton(
                onPressed: _saving ? null : _save,
                child: Text(_saving ? 'جاري الحفظ…' : 'حفظ',
                    style: const TextStyle(
                        color: AppColors.gold, fontWeight: FontWeight.bold)),
              ),
          ],
        ),
        body: _loading
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.gold))
            : Column(
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    color: AppColors.blackCard,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          hiddenCount == 0
                              ? 'كل الأقسام ظاهرة'
                              : '$hiddenCount قسم مخفي',
                          style: const TextStyle(
                              color: AppColors.textGold, fontSize: 13),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'اسحب لإعادة الترتيب · التغيير يصل الجميع بلا تحديث',
                          style: TextStyle(
                              color: AppColors.textMuted, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ReorderableListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: _sections.length,
                      onReorder: (from, to) => setState(() {
                        if (to > from) to--;
                        _sections.insert(to, _sections.removeAt(from));
                        _dirty = true;
                      }),
                      itemBuilder: (context, i) => _tile(_sections[i], i),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _tile(SectionSetting s, int index) {
    return Container(
      key: ValueKey(s.key),
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.blackCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: s.enabled ? AppColors.goldBorder : AppColors.blackSurface),
      ),
      child: Row(
        children: [
          const Icon(Icons.drag_handle, color: AppColors.textMuted, size: 20),
          const SizedBox(width: 10),
          Text('${index + 1}',
              style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(s.title,
                    style: TextStyle(
                      color: s.enabled
                          ? AppColors.textPrimary
                          : AppColors.textMuted,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    )),
                Text(s.key,
                    style: const TextStyle(
                        color: AppColors.textMuted, fontSize: 10)),
              ],
            ),
          ),
          Switch(
            value: s.enabled,
            activeThumbColor: AppColors.gold,
            activeTrackColor: AppColors.emerald,
            inactiveTrackColor: AppColors.blackSurface,
            onChanged: (v) => setState(() {
              _sections[index] = s.copyWith(enabled: v);
              _dirty = true;
            }),
          ),
        ],
      ),
    );
  }
}
