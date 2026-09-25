import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../constants/theme.dart';
import '../l10n/strings.dart';
import '../services/account_lang.dart';
import '../services/app_locale.dart';
import '../services/auth_service.dart';
import '../services/sync_service.dart';
import '../services/section_config.dart';
import '../services/tahfeez_service.dart';
import '../services/update_checker.dart';
import '../widgets/sign_in_buttons.dart';
import 'admin_duas_screen.dart';
import 'admin_screen.dart';
import 'admin_translation_feedback_screen.dart';
import 'tahfeez/reports_screen.dart';
import 'tahfeez/tahfeez_widgets.dart';
import 'tahfeez/teacher_requests_screen.dart';
import 'settings_screen.dart';
import 'sources_screen.dart';

/// The account and settings entry point behind the avatar.
///
/// Signing in is optional and stays optional: everything in the app works as a
/// guest, and an account only exists to carry favourites, bookmarks and
/// reading position across devices.
class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  SignInProvider? _busyWith;
  bool _deleting = false;
  bool _isAdmin = false;
  String _version = '';
  bool _checkingUpdate = false;
  TahfeezProfile? _tahfeezProfile;

  @override
  void initState() {
    super.initState();
    _onAuthChanged();
    AuthService.user.addListener(_onAuthChanged);
    PackageInfo.fromPlatform().then((i) {
      if (mounted) setState(() => _version = i.version);
    });
  }

  @override
  void dispose() {
    AuthService.user.removeListener(_onAuthChanged);
    super.dispose();
  }

  void _onAuthChanged() {
    _checkAdmin();
    _loadTahfeezName();
  }

  Future<void> _checkAdmin() async {
    final admin = await SectionConfig.isAdmin();
    if (mounted && admin != _isAdmin) setState(() => _isAdmin = admin);
  }

  /// Silent on failure — the row is created lazily here too, for someone
  /// who wants to pick their Tahfeez name before ever opening that tab.
  Future<void> _loadTahfeezName() async {
    if (AuthService.user.value == null) {
      if (mounted) setState(() => _tahfeezProfile = null);
      return;
    }
    try {
      final (profile, _) = await TahfeezService.ensureProfile();
      if (mounted) setState(() => _tahfeezProfile = profile);
    } catch (_) {
      // Offline, or the reader has yet to sign in properly — the row just
      // stays hidden until the next successful load.
    }
  }

  Future<void> _editTahfeezName() async {
    final current =
        _tahfeezProfile?.displayName ??
        AuthService.user.value?.displayName ??
        '';
    final name = await promptText(
      context,
      title: t('tahfeez.editName'),
      subtitle: t('tahfeez.editNameNote'),
      hint: t('tahfeez.editNameHint'),
      initial: current,
      confirmLabel: t('tahfeez.save'),
    );
    if (name == null || name.isEmpty || !mounted) return;
    try {
      await TahfeezService.setDisplayName(name);
      if (!mounted) return;
      setState(
        () => _tahfeezProfile = _tahfeezProfile?.copyWith(displayName: name),
      );
      showNote(context, t('tahfeez.nameUpdated'));
    } catch (e) {
      if (mounted) showNote(context, describeError(e), error: true);
    }
  }

  Future<void> _checkForUpdate() async {
    setState(() => _checkingUpdate = true);
    final result = await UpdateChecker.check();
    if (!mounted) return;
    setState(() => _checkingUpdate = false);

    if (result.failed) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(t('account.updateCheckFailed'))));
      return;
    }

    if (!result.available) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(t('account.updateUpToDate'))));
      return;
    }

    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: AccountLang.direction,
        child: AlertDialog(
          backgroundColor: AppColors.blackCard,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: AppColors.goldBorder),
          ),
          title: Text(
            t('account.updateAvailable'),
            style: const TextStyle(
              color: AppColors.gold,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(
            result.latestVersion == null
                ? t('account.updateAvailableBody')
                : '${t('account.updateAvailableBody')} (${result.latestVersion})',
            style: const TextStyle(color: AppColors.textSecondary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(
                t('account.cancel'),
                style: const TextStyle(color: AppColors.textMuted),
              ),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(ctx);
                if (result.source == UpdateSource.playStore) {
                  await UpdateChecker.startPlayStoreUpdate();
                } else {
                  await launchUrl(
                    Uri.parse(UpdateChecker.downloadPageUrl),
                    mode: LaunchMode.externalApplication,
                  );
                }
              },
              child: Text(
                result.source == UpdateSource.playStore
                    ? t('account.updateNow')
                    : t('account.updateDownload'),
                style: const TextStyle(
                  color: AppColors.gold,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _signIn(SignInProvider provider) async {
    setState(() => _busyWith = provider);
    final ok = await AuthService.signInWith(provider);
    if (!mounted) return;
    setState(() => _busyWith = null);
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(t('account.signInFail')),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _signOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: AccountLang.direction,
        child: AlertDialog(
          backgroundColor: AppColors.blackCard,
          title: Text(
            t('account.signOut'),
            style: const TextStyle(color: AppColors.gold, fontSize: 17),
          ),
          content: Text(
            t('account.signOutMsg'),
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(
                t('account.cancel'),
                style: const TextStyle(color: AppColors.textMuted),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(
                t('account.signOutConfirm'),
                style: const TextStyle(color: AppColors.error),
              ),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true) return;
    await AuthService.signOut();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppLocale.locale,
      builder: (context2, child2) => Directionality(
        textDirection: AccountLang.direction,
        child: Scaffold(
          backgroundColor: AppColors.black,
          appBar: AppBar(
            title: Text(t('account.title')),
            backgroundColor: AppColors.black,
            foregroundColor: AppColors.gold,
          ),
          body: ValueListenableBuilder<AppUser?>(
            valueListenable: AuthService.user,
            builder: (context, user, _) => ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _profileCard(user),
                if (SyncService.available) ...[
                  const SizedBox(height: 12),
                  _syncCard(),
                ],
                const SizedBox(height: 10),
                const SettingsScreen(embedded: true),
                if (_isAdmin) ...[
                  const SizedBox(height: 20),
                  _sectionTitle(t('account.adminSection')),
                  _tile(
                    icon: Icons.dashboard_customize,
                    title: t('account.adminTitle'),
                    subtitle: t('account.adminSub'),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const AdminScreen()),
                    ),
                  ),
                  const SizedBox(height: 8),
                  _tile(
                    icon: Icons.volunteer_activism,
                    title: t('account.adminDuasTitle'),
                    subtitle: t('account.adminDuasSub'),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const AdminDuasScreen(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  _tile(
                    icon: Icons.mark_email_unread_outlined,
                    title: t('admin.feedback.title'),
                    subtitle: t('admin.feedback.sub'),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const AdminTranslationFeedbackScreen(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  ValueListenableBuilder<int>(
                    valueListenable: TahfeezService.pendingBadge,
                    builder: (_, n, _) => _tile(
                      icon: Icons.how_to_reg,
                      title: n > 0
                          ? '${t('account.teacherRequestsTitle')} ($n)'
                          : t('account.teacherRequestsTitle'),
                      subtitle: t('account.teacherRequestsSub'),
                      onTap: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const TeacherRequestsScreen(),
                          ),
                        );
                        TahfeezService.refreshPendingBadge();
                      },
                    ),
                  ),
                  const SizedBox(height: 8),
                  ValueListenableBuilder<int>(
                    valueListenable: TahfeezService.reportsBadge,
                    builder: (_, n, _) => _tile(
                      icon: Icons.flag_outlined,
                      title: n > 0
                          ? '${t('tahfeez.reports')} ($n)'
                          : t('tahfeez.reports'),
                      subtitle: t('tahfeez.reportsSub'),
                      onTap: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const ReportsScreen(),
                          ),
                        );
                        TahfeezService.refreshPendingBadge();
                      },
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                _sectionTitle(t('account.aboutSection')),
                _aboutCard(),
                const SizedBox(height: 10),
                _sourcesLink(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Whose work the app is carrying, one tap from where anyone would look.
  ///
  /// Not buried at the bottom of a legal page: the reader trusting a text has
  /// a right to see whose text it is.
  Widget _sourcesLink() {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const SourcesScreen()),
      ),
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: AppColors.blackCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.goldBorder),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.menu_book_outlined,
              color: AppColors.gold,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    t('account.sources'),
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    t('account.sourcesSub'),
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_left,
              color: AppColors.textMuted,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  /// Sync, said plainly: what travels, and when it last did.
  Widget _syncCard() {
    return ValueListenableBuilder<bool>(
      valueListenable: SyncService.syncing,
      builder: (context, busy, _) => ValueListenableBuilder<DateTime?>(
        valueListenable: SyncService.lastSynced,
        builder: (context, at, _) => Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.blackCard,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.goldBorder),
          ),
          child: Row(
            children: [
              const Icon(Icons.cloud_sync, color: AppColors.gold, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t('account.sync'),
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      at == null
                          ? t('account.syncNever')
                          : '${t('account.syncLast')} ${_clock(at)}',
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.gold,
                      ),
                    )
                  : TextButton(
                      onPressed: () async {
                        final ok = await SyncService.sync();
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              ok
                                  ? t('account.syncDone')
                                  : t('account.syncFail'),
                            ),
                            backgroundColor: AppColors.blackCard,
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      },
                      child: Text(
                        t('account.syncNow'),
                        style: const TextStyle(color: AppColors.gold),
                      ),
                    ),
            ],
          ),
        ),
      ),
    );
  }

  String _clock(DateTime at) {
    final h = at.hour % 12 == 0 ? 12 : at.hour % 12;
    final m = at.minute.toString().padLeft(2, '0');
    return '$h:$m ${at.hour >= 12 ? t('account.pm') : t('account.am')}';
  }

  Widget _profileCard(AppUser? user) {
    return Container(
      padding: const EdgeInsets.all(20),
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
          UserAvatar(user: user, size: 68),
          const SizedBox(height: 12),
          Text(
            user?.displayName ?? t('account.guest'),
            style: const TextStyle(
              color: AppColors.gold,
              fontSize: 19,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (user?.email != null) ...[
            const SizedBox(height: 3),
            Text(
              user!.email!,
              style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
            ),
          ],
          if (user != null) ...[const SizedBox(height: 10), _tahfeezNameRow()],
          const SizedBox(height: 16),
          if (user == null) _guestActions() else _signedInActions(),
        ],
      ),
    );
  }

  Widget _tahfeezNameRow() {
    final name = _tahfeezProfile?.displayName;
    return GestureDetector(
      onTap: _editTahfeezName,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: AppColors.blackSurface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.goldBorder),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.badge_outlined,
              size: 14,
              color: AppColors.textMuted,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                name == null
                    ? t('tahfeez.editName')
                    : '${t('tahfeez.displayedAs')} $name',
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                ),
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.edit, size: 12, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }

  Widget _guestActions() {
    return ValueListenableBuilder<Set<SignInProvider>>(
      valueListenable: AuthService.availableProviders,
      builder: (context, providers, _) =>
          providers.isEmpty || !AuthService.isConfigured
          ? _guestOnlyNote()
          : _signInPrompt(providers),
    );
  }

  /// Shown while no provider is switched on for the project — an honest note
  /// beats a button that could only fail.
  Widget _guestOnlyNote() {
    return Column(
      children: [
        Text(
          t('account.guestNote'),
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 13,
            height: 1.7,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.blackSurface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.goldBorder),
          ),
          child: Text(
            t('account.signInSoon'),
            style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
          ),
        ),
      ],
    );
  }

  Widget _signInPrompt(Set<SignInProvider> providers) {
    // Keep a stable order regardless of what the project reports first.
    final ordered = SignInProvider.values.where(providers.contains);

    return Column(
      children: [
        Text(
          t('account.signInPrompt'),
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 13,
            height: 1.7,
          ),
        ),
        const SizedBox(height: 14),
        for (final provider in ordered)
          SignInButton(
            provider: provider,
            busy: _busyWith == provider,
            onPressed: _busyWith != null ? null : () => _signIn(provider),
          ),
        const SizedBox(height: 2),
        Text(
          t('account.optional'),
          style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
        ),
      ],
    );
  }

  Widget _signedInActions() {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _deleting ? null : _signOut,
            icon: const Icon(Icons.logout, size: 17),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.textMuted,
              side: const BorderSide(color: AppColors.goldBorder),
              padding: const EdgeInsets.symmetric(vertical: 11),
            ),
            label: Text(t('account.signOut')),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: TextButton.icon(
            onPressed: _deleting ? null : _deleteAccount,
            icon: _deleting
                ? const SizedBox(
                    width: 15,
                    height: 15,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.error,
                    ),
                  )
                : const Icon(Icons.delete_forever, size: 17),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            label: Text(
              _deleting ? t('account.deleting') : t('account.delete'),
            ),
          ),
        ),
      ],
    );
  }

  /// Two-step on purpose: the reader confirms, then types the word, because a
  /// mis-tap here cannot be undone.
  Future<void> _deleteAccount() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: AccountLang.direction,
        child: AlertDialog(
          backgroundColor: AppColors.blackCard,
          title: Text(
            t('account.deleteTitle'),
            style: const TextStyle(color: AppColors.error, fontSize: 17),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                t('account.deleteMsg'),
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 14,
                  height: 1.7,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                t('account.deleteNote'),
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 12,
                  height: 1.7,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(
                t('account.cancel'),
                style: const TextStyle(color: AppColors.textSecondary),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(
                t('account.continue'),
                style: const TextStyle(color: AppColors.error),
              ),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true || !mounted) return;

    final typed = await _confirmByTyping();
    if (typed != true || !mounted) return;

    setState(() => _deleting = true);
    final ok = await AuthService.deleteAccount();
    if (!mounted) return;
    setState(() => _deleting = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok ? t('account.deleteDone') : t('account.deleteFail')),
        backgroundColor: ok ? AppColors.emerald : AppColors.error,
      ),
    );
  }

  Future<bool?> _confirmByTyping() {
    final word = t('account.deleteWord');
    final controller = TextEditingController();

    return showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: AccountLang.direction,
        child: StatefulBuilder(
          builder: (ctx, setLocal) => AlertDialog(
            backgroundColor: AppColors.blackCard,
            title: Text(
              t('account.lastConfirm'),
              style: const TextStyle(color: AppColors.error, fontSize: 17),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t('account.deleteConfirm'),
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: controller,
                  autofocus: true,
                  textAlign: TextAlign.center,
                  onChanged: (_) => setLocal(() {}),
                  style: const TextStyle(color: AppColors.textPrimary),
                  decoration: const InputDecoration(
                    enabledBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: AppColors.goldBorder),
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(
                  t('account.cancel'),
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
              ),
              TextButton(
                onPressed: controller.text.trim() == word
                    ? () => Navigator.pop(ctx, true)
                    : null,
                child: Text(
                  t('account.deleteBtn'),
                  style: TextStyle(
                    color: controller.text.trim() == word
                        ? AppColors.error
                        : AppColors.textMuted,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) => Padding(
    padding: const EdgeInsets.only(bottom: 8, right: 4),
    child: Text(
      title,
      style: const TextStyle(
        color: AppColors.textGold,
        fontSize: 15,
        fontWeight: FontWeight.bold,
      ),
    ),
  );

  Widget _tile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.blackCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.goldBorder),
        ),
        child: Row(
          children: [
            Icon(icon, color: AppColors.gold, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_left,
              color: AppColors.textMuted,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Widget _aboutCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.blackCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.goldBorder),
      ),
      child: Column(
        children: [
          Text(
            '${t('account.version')} $_version',
            style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
          ),
          const SizedBox(height: 6),
          TextButton.icon(
            onPressed: _checkingUpdate ? null : _checkForUpdate,
            icon: _checkingUpdate
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.gold,
                    ),
                  )
                : const Icon(Icons.system_update, size: 16),
            label: Text(
              t('account.checkUpdate'),
              style: const TextStyle(fontSize: 12),
            ),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.gold,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            t('account.aboutText'),
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 11,
              height: 1.7,
            ),
          ),
        ],
      ),
    );
  }
}

/// The reader's picture, their initials, or a plain guest mark.
class UserAvatar extends StatelessWidget {
  final AppUser? user;
  final double size;

  const UserAvatar({super.key, required this.user, this.size = 34});

  @override
  Widget build(BuildContext context) {
    final photo = user?.photoUrl;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.goldMuted,
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.goldBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: photo != null
          ? Image.network(
              photo,
              fit: BoxFit.cover,
              // A broken avatar must never break the bar it sits in.
              errorBuilder: (_, _, _) => _fallback(),
            )
          : _fallback(),
    );
  }

  Widget _fallback() {
    if (user == null) {
      return Icon(
        Icons.person_outline,
        color: AppColors.gold,
        size: size * 0.55,
      );
    }
    return Center(
      child: Text(
        user!.initials,
        style: TextStyle(
          color: AppColors.gold,
          fontSize: size * 0.38,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
