import 'package:flutter/material.dart';

import '../constants/theme.dart';
import '../l10n/strings.dart';
import '../services/admin_service.dart';
import '../services/app_locale.dart';

/// Who else may run the admin screens: add an account by the email it signed
/// in with, or take someone off the list. You can't remove yourself.
///
/// Reachable only for accounts listed in app_admins (see AccountScreen).
class AdminAdminsScreen extends StatefulWidget {
  const AdminAdminsScreen({super.key});

  @override
  State<AdminAdminsScreen> createState() => _AdminAdminsScreenState();
}

class _AdminAdminsScreenState extends State<AdminAdminsScreen> {
  List<AppAdmin>? _admins;
  bool _loading = true;
  bool _adding = false;
  final _email = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final admins = await AdminService.list();
    if (!mounted) return;
    setState(() {
      _admins = admins;
      _loading = false;
    });
  }

  void _say(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _add() async {
    final email = _email.text.trim();
    if (!email.contains('@')) {
      _say(t('admins.badEmail'));
      return;
    }
    setState(() => _adding = true);
    final result = await AdminService.add(email);
    if (!mounted) return;
    setState(() => _adding = false);
    switch (result) {
      case AddAdminResult.added:
        _email.clear();
        _say(t('admins.added'));
        await _load();
      case AddAdminResult.noAccount:
        _say(t('admins.noAccount'));
      case AddAdminResult.failed:
        _say(t('admins.failed'));
    }
  }

  Future<void> _remove(AppAdmin admin) async {
    final sure = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: AppLocale.direction,
        child: AlertDialog(
          backgroundColor: AppColors.blackCard,
          title: Text(
            t('admins.removeTitle'),
            style: const TextStyle(color: AppColors.gold),
          ),
          content: Text(
            t('admins.removeBody').replaceAll('%s', admin.email),
            style: const TextStyle(color: AppColors.textPrimary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(t('admins.cancel')),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(
                t('admins.remove'),
                style: const TextStyle(color: AppColors.error),
              ),
            ),
          ],
        ),
      ),
    );
    if (sure != true) return;
    final ok = await AdminService.remove(admin.userId);
    if (!mounted) return;
    if (ok) {
      setState(
        () =>
            _admins = _admins?.where((a) => a.userId != admin.userId).toList(),
      );
    } else {
      _say(t('admins.failed'));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: AppLocale.direction,
      child: Scaffold(
        backgroundColor: AppColors.black,
        appBar: AppBar(
          title: Text(t('admins.title')),
          backgroundColor: AppColors.black,
          foregroundColor: AppColors.gold,
        ),
        body: _loading
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.gold),
              )
            : RefreshIndicator(
                onRefresh: _load,
                color: AppColors.gold,
                backgroundColor: AppColors.blackCard,
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Text(
                      t('admins.sub'),
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 12,
                        height: 1.6,
                      ),
                    ),
                    const SizedBox(height: 14),
                    _addRow(),
                    const SizedBox(height: 20),
                    if (_admins == null)
                      Text(
                        t('admins.loadFailed'),
                        style: const TextStyle(color: AppColors.textMuted),
                      )
                    else
                      for (final a in _admins!) _card(a),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _addRow() {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            autocorrect: false,
            textDirection: TextDirection.ltr,
            style: const TextStyle(color: AppColors.textPrimary),
            onSubmitted: (_) => _add(),
            decoration: InputDecoration(
              hintText: t('admins.emailHint'),
              hintStyle: const TextStyle(color: AppColors.textMuted),
              filled: true,
              fillColor: AppColors.blackCard,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 12,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: AppColors.gold.withValues(alpha: 0.3),
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: AppColors.gold.withValues(alpha: 0.3),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        FilledButton(
          onPressed: _adding ? null : _add,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.gold,
            foregroundColor: AppColors.black,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          ),
          child: _adding
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.black,
                  ),
                )
              : Text(t('admins.add')),
        ),
      ],
    );
  }

  Widget _card(AppAdmin a) {
    final isMe = a.userId == AdminService.currentUserId;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
      decoration: BoxDecoration(
        color: AppColors.blackCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.admin_panel_settings, color: AppColors.gold),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  a.email,
                  textDirection: TextDirection.ltr,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                  ),
                ),
                if (isMe)
                  Text(
                    t('admins.you'),
                    style: const TextStyle(
                      color: AppColors.textGold,
                      fontSize: 11,
                    ),
                  ),
              ],
            ),
          ),
          if (!isMe)
            IconButton(
              tooltip: t('admins.remove'),
              icon: const Icon(Icons.person_remove, color: AppColors.error),
              onPressed: () => _remove(a),
            ),
        ],
      ),
    );
  }
}
