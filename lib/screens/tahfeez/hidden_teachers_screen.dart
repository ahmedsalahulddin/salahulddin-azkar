import 'package:flutter/material.dart';

import '../../constants/theme.dart';
import '../../l10n/strings.dart';
import '../../services/hidden_teachers.dart';
import '../../services/tahfeez_service.dart';
import 'tahfeez_widgets.dart';

/// Everyone the reader hid from the teacher directory, with a way to bring
/// each one back. Reached from Account, so a hidden teacher is never lost.
class HiddenTeachersScreen extends StatefulWidget {
  const HiddenTeachersScreen({super.key});

  @override
  State<HiddenTeachersScreen> createState() => _HiddenTeachersScreenState();
}

class _HiddenTeachersScreenState extends State<HiddenTeachersScreen> {
  /// Fresh profiles for names and pictures; empty until fetched (or if the
  /// fetch fails, in which case the names kept on the device are used).
  Map<String, TahfeezProfile> _profiles = const {};

  @override
  void initState() {
    super.initState();
    HiddenTeachers.ids.addListener(_changed);
    HiddenTeachers.load().then((_) => _changed());
    _fetch();
  }

  @override
  void dispose() {
    HiddenTeachers.ids.removeListener(_changed);
    super.dispose();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  Future<void> _fetch() async {
    try {
      final list = await TahfeezService.teachers();
      if (!mounted) return;
      setState(() => _profiles = {for (final p in list) p.userId: p});
    } catch (_) {
      // Offline: the names saved when hiding are enough.
    }
  }

  @override
  Widget build(BuildContext context) {
    final ids = HiddenTeachers.ids.value.toList();
    return Directionality(
      textDirection: tahfeezDirection(),
      child: Scaffold(
        backgroundColor: AppColors.black,
        appBar: AppBar(
          backgroundColor: AppColors.black,
          foregroundColor: AppColors.gold,
          title: Text(t('tahfeez.hiddenTeachers')),
        ),
        body: ids.isEmpty
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: EmptyNote(
                    icon: Icons.visibility_outlined,
                    text: t('tahfeez.hiddenNone'),
                  ),
                ),
              )
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text(
                    t('tahfeez.hiddenSub'),
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 12,
                      height: 1.6,
                    ),
                  ),
                  const SizedBox(height: 12),
                  for (final id in ids) ...[
                    _row(id),
                    const SizedBox(height: 8),
                  ],
                ],
              ),
      ),
    );
  }

  Widget _row(String id) {
    final p = _profiles[id];
    final name = p?.displayName ?? HiddenTeachers.names[id] ?? '…';
    final photo = p?.photoUrl;
    return TahfeezCard(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: AppColors.goldMuted,
            backgroundImage: photo != null ? NetworkImage(photo) : null,
            child: photo == null
                ? const Icon(Icons.person, color: AppColors.gold, size: 20)
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              name,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          TextButton.icon(
            onPressed: () async {
              await HiddenTeachers.set(id, false);
              if (mounted) showNote(context, '${t('tahfeez.unhidden')} $name');
            },
            icon: const Icon(Icons.visibility, size: 16, color: AppColors.gold),
            label: Text(
              t('tahfeez.unhide'),
              style: const TextStyle(color: AppColors.gold),
            ),
          ),
        ],
      ),
    );
  }
}
