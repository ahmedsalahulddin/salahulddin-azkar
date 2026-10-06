import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../constants/theme.dart';
import '../l10n/strings.dart';
import '../services/account_lang.dart';
import '../services/hidden_teachers.dart';
import '../services/support_service.dart';
import '../services/app_locale.dart';
import '../services/auth_service.dart';
import '../services/sync_service.dart';
import '../services/section_config.dart';
import '../services/tahfeez_service.dart';
import '../services/update_checker.dart';
import '../widgets/contact_dialog.dart';
import '../widgets/profile_header.dart';
import '../widgets/sign_in_buttons.dart';
import 'admin_admins_screen.dart';
import 'admin_duas_screen.dart';
import 'admin_screen.dart';
import 'support/admin_inbox_screen.dart';
import 'support/my_messages_screen.dart';
import 'downloads_screen.dart';
import 'tahfeez/hidden_teachers_screen.dart';
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
  final _checkingUpdate = ValueNotifier<bool>(false);
  TahfeezProfile? _tahfeezProfile;

  @override
  void initState() {
    super.initState();
    HiddenTeachers.load();
    SupportService.refreshMyUnread();
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
    if (admin) SupportService.allThreads();
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
    _checkingUpdate.value = true;
    final result = await UpdateChecker.check();
    if (!mounted) return;
    _checkingUpdate.value = false;

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

  /// Choose a picture from the phone, or go back to the provider's one.
  Future<void> _changePhoto() async {
    final user = AuthService.user.value;
    if (user == null) return;
    final choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.blackCard,
      builder: (ctx) => Directionality(
        textDirection: AccountLang.direction,
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(14),
                child: Text(
                  t('account.photoTitle'),
                  style: const TextStyle(color: AppColors.gold, fontSize: 15),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library, color: AppColors.gold),
                title: Text(
                  t('account.photoPick'),
                  style: const TextStyle(color: AppColors.textPrimary),
                ),
                onTap: () => Navigator.pop(ctx, 'pick'),
              ),
              if (user.hasCustomPhoto)
                ListTile(
                  leading: const Icon(
                    Icons.restore,
                    color: AppColors.textMuted,
                  ),
                  title: Text(
                    t('account.photoRemove'),
                    style: const TextStyle(color: AppColors.textPrimary),
                  ),
                  onTap: () => Navigator.pop(ctx, 'remove'),
                ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
    if (choice == null || !mounted) return;
    bool ok;
    if (choice == 'pick') {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 85,
      );
      if (picked == null) return;
      ok = await AuthService.setAvatar(await picked.readAsBytes());
    } else {
      ok = await AuthService.clearAvatar();
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok ? t('account.photoSaved') : t('account.photoFail')),
        backgroundColor: AppColors.blackCard,
        behavior: SnackBarBehavior.floating,
      ),
    );
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
                if (user == null)
                  _profileCard(null)
                else
                  ProfileHeader(
                    user: user,
                    nameChip: _tahfeezNameRow(),
                    onChangePhoto: _changePhoto,
                    onSignOut: _signOut,
                    onDelete: _deleteAccount,
                    deleting: _deleting,
                    showSync: SyncService.available,
                  ),
                const SizedBox(height: 16),
                _groupGrid(),
                if (user != null) ...[
                  const SizedBox(height: 12),
                  ValueListenableBuilder<int>(
                    valueListenable: SupportService.myUnread,
                    builder: (_, unread, _) => _groupRow(
                      icon: Icons.forum_outlined,
                      title: t('support.myTitle'),
                      subtitle: t('support.myRowSub'),
                      badge: unread,
                      onTap: () => _push(const MyMessagesScreen()),
                    ),
                  ),
                  const SizedBox(height: 10),
                  ValueListenableBuilder<Set<String>>(
                    valueListenable: HiddenTeachers.ids,
                    builder: (_, hidden, _) => _groupRow(
                      icon: Icons.visibility_off_outlined,
                      title: hidden.isEmpty
                          ? t('tahfeez.hiddenTeachers')
                          : '${t('tahfeez.hiddenTeachers')} (${hidden.length})',
                      subtitle: t('tahfeez.hiddenRowSub'),
                      onTap: () => _push(const HiddenTeachersScreen()),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                _groupRow(
                  icon: Icons.menu_book_outlined,
                  title: t('account.guideTitle'),
                  subtitle: t('account.guideSub'),
                  onTap: () => launchUrl(
                    Uri.parse(
                      'https://azkar.salahulddin.com/guide?lang=${AppLocale.code}',
                    ),
                    mode: LaunchMode.externalApplication,
                  ),
                ),
                const SizedBox(height: 10),
                _groupRow(
                  icon: Icons.info_outline,
                  title: t('account.aboutSection'),
                  subtitle: '${t('account.version')} $_version',
                  onTap: () => _openGroup(t('account.aboutSection'), [
                    _aboutCard(),
                    const SizedBox(height: 10),
                    _contactLink(),
                    const SizedBox(height: 10),
                    _sourcesLink(),
                  ]),
                ),
                if (_isAdmin) ...[
                  const SizedBox(height: 10),
                  ValueListenableBuilder<int>(
                    valueListenable: TahfeezService.adminBadge,
                    builder: (_, n, _) => _groupRow(
                      icon: Icons.admin_panel_settings_outlined,
                      title: t('account.adminSection'),
                      subtitle: t('acct.group.admin.sub'),
                      badge: n,
                      onTap: () =>
                          _openGroup(t('account.adminSection'), _adminTiles()),
                    ),
                  ),
                ],
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
  Widget _contactLink() {
    return GestureDetector(
      onTap: () => showContactDialog(context),
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
            const Icon(Icons.mail_outline, color: AppColors.gold, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    t('contact.button'),
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    t('contact.buttonSub'),
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_left, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }

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
          const SizedBox(height: 16),
          _guestActions(),
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
        // On iPhone sign-in waits for Sign in with Apple; promising Google
        // "soon" there reads to App Review as an unfinished feature.
        if (defaultTargetPlatform != TargetPlatform.iOS)
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

  /// Everything a reader sets, as four tiles that each open their own
  /// screen — instead of one page several screens long.
  Widget _groupGrid() {
    final groups = [
      (
        Icons.mosque_outlined,
        t('acct.group.prayer'),
        t('acct.group.prayer.sub'),
        () => _push(const SettingsScreen(section: SettingsSection.prayer)),
      ),
      (
        Icons.notifications_active_outlined,
        t('settings.reminders'),
        t('acct.group.reminders.sub'),
        () => _push(const SettingsScreen(section: SettingsSection.reminders)),
      ),
      (
        Icons.download_for_offline_outlined,
        t('acct.group.downloads'),
        t('acct.group.downloads.sub'),
        () => _push(const DownloadsScreen()),
      ),
      (
        Icons.text_fields,
        t('settings.fontSize'),
        t('acct.group.display.sub'),
        () => _push(const SettingsScreen(section: SettingsSection.display)),
      ),
    ];
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.0,
      children: [
        for (final (icon, title, sub, onTap) in groups)
          GestureDetector(
            onTap: onTap,
            behavior: HitTestBehavior.opaque,
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
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.all(9),
                    decoration: const BoxDecoration(
                      color: AppColors.goldMuted,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, color: AppColors.gold, size: 22),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        sub,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 11,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  /// A full-width group: About, and Admin for the admin.
  Widget _groupRow({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    int badge = 0,
  }) {
    return GestureDetector(
      onTap: onTap,
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
            Badge(
              isLabelVisible: badge > 0,
              label: Text('$badge'),
              backgroundColor: AppColors.error,
              child: Icon(icon, color: AppColors.gold, size: 22),
            ),
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
                      fontWeight: FontWeight.w600,
                    ),
                  ),
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
            Icon(Icons.chevron_left, color: AppColors.textMuted, size: 20),
          ],
        ),
      ),
    );
  }

  void _push(Widget screen) =>
      Navigator.push(context, MaterialPageRoute(builder: (_) => screen));

  /// A group whose contents live on this screen (About, Admin), shown on a
  /// page of its own.
  void _openGroup(String title, List<Widget> children) => _push(
    Directionality(
      textDirection: AccountLang.direction,
      child: Scaffold(
        backgroundColor: AppColors.black,
        appBar: AppBar(
          title: Text(title),
          backgroundColor: AppColors.black,
          foregroundColor: AppColors.gold,
        ),
        body: ListView(padding: const EdgeInsets.all(16), children: children),
      ),
    ),
  );

  List<Widget> _adminTiles() => [
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
        MaterialPageRoute(builder: (_) => const AdminDuasScreen()),
      ),
    ),
    const SizedBox(height: 8),
    _tile(
      icon: Icons.admin_panel_settings,
      title: t('admins.title'),
      subtitle: t('admins.rowSub'),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const AdminAdminsScreen()),
      ),
    ),
    const SizedBox(height: 8),
    ValueListenableBuilder<int>(
      valueListenable: SupportService.adminOpen,
      builder: (_, open, _) => _tile(
        icon: Icons.mark_email_unread_outlined,
        title: open > 0
            ? '${t('support.inboxTitle')} ($open)'
            : t('support.inboxTitle'),
        subtitle: t('support.inboxSub'),
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AdminInboxScreen()),
          );
          SupportService.allThreads();
        },
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
            MaterialPageRoute(builder: (_) => const TeacherRequestsScreen()),
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
        title: n > 0 ? '${t('tahfeez.reports')} ($n)' : t('tahfeez.reports'),
        subtitle: t('tahfeez.reportsSub'),
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ReportsScreen()),
          );
          TahfeezService.refreshPendingBadge();
        },
      ),
    ),
  ];

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
          if (UpdateChecker.offered) ...[
            const SizedBox(height: 6),
            ValueListenableBuilder<bool>(
              valueListenable: _checkingUpdate,
              builder: (context, checking, _) => TextButton.icon(
                onPressed: checking ? null : _checkForUpdate,
                icon: checking
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ),
          ],
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
