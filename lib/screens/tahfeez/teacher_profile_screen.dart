import 'package:flutter/material.dart';

import '../../constants/theme.dart';
import '../../l10n/strings.dart';
import '../../services/tahfeez_service.dart';
import 'tahfeez_widgets.dart';

/// What a teacher shows in the directory, and the terms every new
/// enrolment starts on.
class TeacherProfileScreen extends StatefulWidget {
  final TahfeezProfile profile;

  const TeacherProfileScreen({super.key, required this.profile});

  @override
  State<TeacherProfileScreen> createState() => _TeacherProfileScreenState();
}

class _TeacherProfileScreenState extends State<TeacherProfileScreen> {
  late final _bio = TextEditingController(text: widget.profile.bio ?? '');
  late final _city = TextEditingController(text: widget.profile.city ?? '');
  late final _price = TextEditingController(
    text: widget.profile.priceNote ?? '',
  );
  late PlanPeriod _plan = widget.profile.planPeriod;
  late int _free = widget.profile.freeSessions;
  bool _saving = false;

  @override
  void dispose() {
    _bio.dispose();
    _city.dispose();
    _price.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.black,
        appBar: AppBar(
          backgroundColor: AppColors.black,
          foregroundColor: AppColors.gold,
          title: Text(t('tahfeez.teacherProfile')),
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 30),
          children: [
            _label(t('tahfeez.bio')),
            _field(_bio, hint: t('tahfeez.bioHint'), maxLines: 4),
            const SizedBox(height: 14),
            _label(t('tahfeez.city')),
            _field(_city, hint: t('tahfeez.city')),
            const SizedBox(height: 14),
            _label(t('tahfeez.plan')),
            Row(
              children: [
                for (final p in PlanPeriod.values) ...[
                  ChoiceChip(
                    label: Text(t('tahfeez.plan.${p.name}')),
                    selected: _plan == p,
                    selectedColor: AppColors.goldMuted,
                    backgroundColor: AppColors.blackSurface,
                    side: BorderSide(
                      color: _plan == p ? AppColors.gold : AppColors.goldBorder,
                    ),
                    labelStyle: TextStyle(
                      color: _plan == p ? AppColors.gold : AppColors.textMuted,
                      fontWeight: _plan == p
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                    showCheckmark: false,
                    onSelected: (_) => setState(() => _plan = p),
                  ),
                  const SizedBox(width: 8),
                ],
              ],
            ),
            const SizedBox(height: 14),
            _label(t('tahfeez.freeSessions')),
            Row(
              children: [
                _stepButton(
                  Icons.remove,
                  _free > 0 ? () => setState(() => _free--) : null,
                ),
                Container(
                  width: 56,
                  alignment: Alignment.center,
                  child: Text(
                    '$_free',
                    style: const TextStyle(
                      color: AppColors.gold,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                _stepButton(
                  Icons.add,
                  _free < 20 ? () => setState(() => _free++) : null,
                ),
              ],
            ),
            const SizedBox(height: 14),
            _label(t('tahfeez.priceNote')),
            _field(_price, hint: t('tahfeez.priceNoteHint')),
            const SizedBox(height: 6),
            Text(
              t('tahfeez.paidOutside'),
              style: const TextStyle(
                color: AppColors.textMuted,
                fontSize: 11,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            GoldButton(
              label: t('tahfeez.save'),
              icon: Icons.check,
              busy: _saving,
              onPressed: _save,
            ),
          ],
        ),
      ),
    );
  }

  Widget _label(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 6, right: 2),
    child: Text(
      text,
      style: const TextStyle(color: AppColors.textGold, fontSize: 13),
    ),
  );

  Widget _field(
    TextEditingController c, {
    required String hint,
    int maxLines = 1,
  }) {
    return TextField(
      controller: c,
      maxLines: maxLines,
      style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 13),
        isDense: true,
        filled: true,
        fillColor: AppColors.blackCard,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.goldBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.goldBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.gold),
        ),
      ),
    );
  }

  Widget _stepButton(IconData icon, VoidCallback? onTap) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.gold,
        side: const BorderSide(color: AppColors.goldBorder),
        minimumSize: const Size(44, 40),
        padding: EdgeInsets.zero,
      ),
      child: Icon(icon, size: 18),
    );
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await TahfeezService.updateTeacherProfile(
        bio: _bio.text,
        city: _city.text,
        plan: _plan,
        freeSessions: _free,
        priceNote: _price.text,
      );
      if (!mounted) return;
      showNote(context, t('tahfeez.saved'));
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        showNote(context, describeError(e), error: true);
      }
    }
  }
}
