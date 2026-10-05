import 'package:flutter/material.dart';

import '../constants/theme.dart';
import '../l10n/strings.dart';
import '../services/auth_service.dart';
import '../services/sync_service.dart';
import '../screens/account_screen.dart' show UserAvatar;

/// The signed-in reader at the top of Account, in one compact row: their
/// picture (tap to change it), name and email, and sync as the familiar two
/// circling arrows — no words, the icon spins while it works and a tap says
/// how it went. Sign out and delete sit on a slim line underneath.
class ProfileHeader extends StatelessWidget {
  final AppUser user;
  final Widget? nameChip;
  final VoidCallback onChangePhoto;
  final VoidCallback onSignOut;
  final VoidCallback onDelete;
  final bool deleting;

  /// Whether to show the sync button at all (SyncService.available).
  final bool showSync;

  const ProfileHeader({
    super.key,
    required this.user,
    required this.onChangePhoto,
    required this.onSignOut,
    required this.onDelete,
    this.nameChip,
    this.deleting = false,
    this.showSync = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 6),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.navyLight, AppColors.navy],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.goldBorder),
      ),
      child: Column(
        children: [
          Row(
            children: [
              _EditableAvatar(user: user, onTap: onChangePhoto),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.gold,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (user.email != null)
                      Text(
                        user.email!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textDirection: TextDirection.ltr,
                        style: const TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 11,
                        ),
                      ),
                    if (nameChip != null) ...[
                      const SizedBox(height: 6),
                      nameChip!,
                    ],
                  ],
                ),
              ),
              if (showSync) ...[const SizedBox(width: 8), const SyncButton()],
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Flexible(
                child: TextButton.icon(
                  onPressed: deleting ? null : onSignOut,
                  icon: const Icon(Icons.logout, size: 15),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.textMuted,
                  ),
                  label: Text(
                    t('account.signOut'),
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ),
              const Spacer(),
              Flexible(
                child: TextButton(
                  onPressed: deleting ? null : onDelete,
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.error.withValues(alpha: 0.8),
                  ),
                  child: deleting
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.error,
                          ),
                        )
                      : Text(
                          t('account.delete'),
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12),
                        ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// The picture with a small camera badge, so it reads as changeable.
class _EditableAvatar extends StatelessWidget {
  final AppUser user;
  final VoidCallback onTap;

  const _EditableAvatar({required this.user, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 60,
        height: 60,
        child: Stack(
          children: [
            UserAvatar(user: user, size: 58),
            PositionedDirectional(
              bottom: 0,
              end: 0,
              child: Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: AppColors.gold,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.navy, width: 2),
                ),
                child: const Icon(
                  Icons.photo_camera,
                  size: 12,
                  color: AppColors.black,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Sync as an icon alone: two arrows chasing each other. Spins while
/// syncing; a tap syncs and the snackbar says when it last did.
class SyncButton extends StatefulWidget {
  const SyncButton({super.key});

  @override
  State<SyncButton> createState() => _SyncButtonState();
}

class _SyncButtonState extends State<SyncButton>
    with SingleTickerProviderStateMixin {
  late final _spin = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  @override
  void initState() {
    super.initState();
    SyncService.syncing.addListener(_follow);
    _follow();
  }

  @override
  void dispose() {
    SyncService.syncing.removeListener(_follow);
    _spin.dispose();
    super.dispose();
  }

  void _follow() {
    if (SyncService.syncing.value) {
      _spin.repeat();
    } else {
      _spin
        ..stop()
        ..value = 0;
    }
  }

  String _clock(DateTime at) {
    final h = at.hour % 12 == 0 ? 12 : at.hour % 12;
    final m = at.minute.toString().padLeft(2, '0');
    return '$h:$m ${at.hour >= 12 ? t('account.pm') : t('account.am')}';
  }

  Future<void> _sync() async {
    if (SyncService.syncing.value) return;
    final ok = await SyncService.sync();
    if (!mounted) return;
    final at = SyncService.lastSynced.value;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? (at == null
                    ? t('account.syncDone')
                    : '${t('account.syncDone')} · ${_clock(at)}')
              : t('account.syncFail'),
        ),
        backgroundColor: AppColors.blackCard,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final at = SyncService.lastSynced.value;
    return Tooltip(
      message: at == null
          ? t('account.syncNever')
          : '${t('account.syncLast')} ${_clock(at)}',
      child: InkResponse(
        onTap: _sync,
        radius: 26,
        child: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.gold.withValues(alpha: 0.12),
            border: Border.all(color: AppColors.goldBorder),
          ),
          child: RotationTransition(
            turns: _spin,
            child: const Icon(Icons.sync, color: AppColors.gold, size: 24),
          ),
        ),
      ),
    );
  }
}
