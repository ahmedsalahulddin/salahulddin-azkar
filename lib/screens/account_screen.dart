import 'package:flutter/material.dart';
import '../constants/theme.dart';
import '../services/auth_service.dart';
import '../services/section_config.dart';
import '../widgets/sign_in_buttons.dart';
import 'admin_screen.dart';
import 'settings_screen.dart';

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

  @override
  void initState() {
    super.initState();
    _checkAdmin();
    // Signing in or out changes the answer.
    AuthService.user.addListener(_checkAdmin);
  }

  @override
  void dispose() {
    AuthService.user.removeListener(_checkAdmin);
    super.dispose();
  }

  Future<void> _checkAdmin() async {
    final admin = await SectionConfig.isAdmin();
    if (mounted && admin != _isAdmin) setState(() => _isAdmin = admin);
  }

  Future<void> _signIn(SignInProvider provider) async {
    setState(() => _busyWith = provider);
    final ok = await AuthService.signInWith(provider);
    if (!mounted) return;
    setState(() => _busyWith = null);
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تعذّر تسجيل الدخول — حاول مرة أخرى',
              textDirection: TextDirection.rtl),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _signOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: AppColors.blackCard,
          title: const Text('تسجيل الخروج',
              style: TextStyle(color: AppColors.gold, fontSize: 17)),
          content: const Text(
            'ستبقى أذكارك المحفوظة على هذا الجهاز.',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('إلغاء',
                  style: TextStyle(color: AppColors.textMuted)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('خروج',
                  style: TextStyle(color: AppColors.error)),
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
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.black,
        appBar: AppBar(
          title: const Text('حسابي والإعدادات'),
          backgroundColor: AppColors.black,
          foregroundColor: AppColors.gold,
        ),
        body: ValueListenableBuilder<AppUser?>(
          valueListenable: AuthService.user,
          builder: (context, user, _) => ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _profileCard(user),
              const SizedBox(height: 10),
              // The settings themselves, not a link to them: there is one
              // place the reader goes for anything about themselves or the
              // app, and this is it.
              const SettingsScreen(embedded: true),
              // Only shown to accounts listed in app_admins; a non-admin never
              // learns the screen exists.
              if (_isAdmin) ...[
                const SizedBox(height: 20),
                _sectionTitle('الإدارة'),
                _tile(
                  icon: Icons.dashboard_customize,
                  title: 'إدارة الأقسام',
                  subtitle: 'أظهِر وأخفِ ورتّب أقسام الشاشة الرئيسية',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AdminScreen()),
                  ),
                ),
              ],
              const SizedBox(height: 20),
              _sectionTitle('عن التطبيق'),
              _aboutCard(),
            ],
          ),
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
            user?.displayName ?? 'تقرأ كضيف',
            style: const TextStyle(
                color: AppColors.gold,
                fontSize: 19,
                fontWeight: FontWeight.bold),
          ),
          if (user?.email != null) ...[
            const SizedBox(height: 3),
            Text(user!.email!,
                style: const TextStyle(
                    color: AppColors.textMuted, fontSize: 12)),
          ],
          const SizedBox(height: 16),
          if (user == null) _guestActions() else _signedInActions(),
        ],
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
        const Text(
          'التطبيق يعمل كاملاً بدون حساب،\nوكل ما تحفظه محفوظ على جهازك.',
          textAlign: TextAlign.center,
          style: TextStyle(
              color: AppColors.textSecondary, fontSize: 13, height: 1.7),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.blackSurface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.goldBorder),
          ),
          child: const Text(
            'الدخول بحساب جوجل — قريباً',
            style: TextStyle(color: AppColors.textMuted, fontSize: 12),
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
        const Text(
          'سجّل الدخول لتنتقل مفضلتك وعلاماتك\nوموضع قراءتك بين أجهزتك.',
          textAlign: TextAlign.center,
          style: TextStyle(
              color: AppColors.textSecondary, fontSize: 13, height: 1.7),
        ),
        const SizedBox(height: 14),
        for (final provider in ordered)
          SignInButton(
            provider: provider,
            busy: _busyWith == provider,
            onPressed: _busyWith != null ? null : () => _signIn(provider),
          ),
        const SizedBox(height: 2),
        const Text('اختياري — يمكنك المتابعة كضيف',
            style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
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
            label: const Text('تسجيل الخروج'),
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
                        strokeWidth: 2, color: AppColors.error),
                  )
                : const Icon(Icons.delete_forever, size: 17),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            label: Text(_deleting ? 'جاري الحذف…' : 'حذف الحساب نهائياً'),
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
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: AppColors.blackCard,
          title: const Text('حذف الحساب نهائياً',
              style: TextStyle(color: AppColors.error, fontSize: 17)),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'سيُحذف حسابك وكل ما يخصّه من خوادمنا حذفاً لا رجعة فيه.',
                style: TextStyle(
                    color: AppColors.textPrimary, fontSize: 14, height: 1.7),
              ),
              SizedBox(height: 10),
              Text(
                'أذكارك المحفوظة وعلاماتك على هذا الجهاز تبقى كما هي — '
                'يمحوها حذف التطبيق.',
                style: TextStyle(
                    color: AppColors.textMuted, fontSize: 12, height: 1.7),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('إلغاء',
                  style: TextStyle(color: AppColors.textSecondary)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('متابعة',
                  style: TextStyle(color: AppColors.error)),
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
        content: Text(
          ok
              ? 'تم حذف حسابك'
              : 'تعذّر الحذف — حاول مرة أخرى أو راسلنا',
          textDirection: TextDirection.rtl,
        ),
        backgroundColor: ok ? AppColors.emerald : AppColors.error,
      ),
    );
  }

  Future<bool?> _confirmByTyping() {
    const word = 'حذف';
    final controller = TextEditingController();

    return showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: StatefulBuilder(
          builder: (ctx, setLocal) => AlertDialog(
            backgroundColor: AppColors.blackCard,
            title: const Text('تأكيد أخير',
                style: TextStyle(color: AppColors.error, fontSize: 17)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('اكتب كلمة «حذف» للتأكيد:',
                    style: TextStyle(
                        color: AppColors.textSecondary, fontSize: 13)),
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
                child: const Text('إلغاء',
                    style: TextStyle(color: AppColors.textSecondary)),
              ),
              TextButton(
                onPressed: controller.text.trim() == word
                    ? () => Navigator.pop(ctx, true)
                    : null,
                child: Text('احذف حسابي',
                    style: TextStyle(
                      color: controller.text.trim() == word
                          ? AppColors.error
                          : AppColors.textMuted,
                    )),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) => Padding(
        padding: const EdgeInsets.only(bottom: 8, right: 4),
        child: Text(title,
            style: const TextStyle(
                color: AppColors.textGold,
                fontSize: 15,
                fontWeight: FontWeight.bold)),
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
                  Text(title,
                      style: const TextStyle(
                          color: AppColors.textPrimary, fontSize: 14)),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: const TextStyle(
                          color: AppColors.textMuted, fontSize: 11)),
                ],
              ),
            ),
            const Icon(Icons.chevron_left,
                color: AppColors.textMuted, size: 20),
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
      child: const Column(
        children: [
          Text('الإصدار 1.0.0',
              style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
          SizedBox(height: 8),
          Text(
            'نص المصحف: مجمع الملك فهد لطباعة المصحف الشريف\n'
            'الأذكار: حصن المسلم — سعيد بن علي القحطاني',
            textAlign: TextAlign.center,
            style: TextStyle(
                color: AppColors.textSecondary, fontSize: 11, height: 1.7),
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
      return Icon(Icons.person_outline,
          color: AppColors.gold, size: size * 0.55);
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
