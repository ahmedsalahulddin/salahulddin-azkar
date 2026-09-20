import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../services/auth_service.dart';

/// Official brand marks, drawn from each company's published logo paths.
///
/// Google, Meta and Apple all require their own mark and wording on a sign-in
/// button; substituting a generic icon breaks their branding terms, so these
/// are the real shapes rather than lookalikes.
class _BrandMark {
  static const google = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 48 48">
<path fill="#4285F4" d="M45.12 24.5c0-1.56-.14-3.06-.4-4.5H24v8.51h11.84c-.51 2.75-2.06 5.08-4.39 6.64v5.52h7.11c4.16-3.83 6.56-9.47 6.56-16.17z"/>
<path fill="#34A853" d="M24 46c5.94 0 10.92-1.97 14.56-5.33l-7.11-5.52c-1.97 1.32-4.49 2.1-7.45 2.1-5.73 0-10.58-3.87-12.31-9.07H4.34v5.7C7.96 41.07 15.4 46 24 46z"/>
<path fill="#FBBC05" d="M11.69 28.18C11.25 26.86 11 25.45 11 24s.25-2.86.69-4.18v-5.7H4.34C2.85 17.09 2 20.45 2 24s.85 6.91 2.34 9.88l7.35-5.7z"/>
<path fill="#EA4335" d="M24 10.75c3.23 0 6.13 1.11 8.41 3.29l6.31-6.31C34.91 4.18 29.93 2 24 2 15.4 2 7.96 6.93 4.34 14.12l7.35 5.7c1.73-5.2 6.58-9.07 12.31-9.07z"/>
</svg>''';

  static const facebook = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 48 48">
<path fill="#1877F2" d="M48 24C48 10.75 37.25 0 24 0S0 10.75 0 24c0 11.98 8.78 21.91 20.25 23.71V30.94h-6.09V24h6.09v-5.29c0-6.01 3.58-9.33 9.06-9.33 2.62 0 5.37.47 5.37.47v5.91h-3.03c-2.98 0-3.91 1.85-3.91 3.75V24h6.66l-1.06 6.94h-5.6v16.77C39.22 45.91 48 35.98 48 24z"/>
<path fill="#fff" d="M33.34 30.94 34.4 24h-6.66v-4.49c0-1.9.93-3.75 3.91-3.75h3.03V9.85s-2.75-.47-5.37-.47c-5.48 0-9.06 3.32-9.06 9.33V24h-6.09v6.94h6.09v16.77a24.2 24.2 0 0 0 7.5 0V30.94h5.6z"/>
</svg>''';

  static const apple = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24">
<path fill="#fff" d="M17.05 12.54c-.03-2.85 2.33-4.22 2.44-4.29-1.33-1.95-3.4-2.21-4.14-2.24-1.76-.18-3.44 1.04-4.33 1.04-.9 0-2.27-1.02-3.74-.99-1.92.03-3.7 1.12-4.69 2.84-2 3.47-.51 8.6 1.44 11.41.95 1.38 2.09 2.92 3.58 2.87 1.44-.06 1.98-.93 3.72-.93s2.23.93 3.75.9c1.55-.03 2.53-1.4 3.48-2.79 1.1-1.6 1.55-3.15 1.57-3.23-.03-.02-3.02-1.16-3.05-4.59zM14.2 4.2c.79-.96 1.33-2.29 1.18-3.62-1.14.05-2.53.76-3.35 1.72-.73.85-1.38 2.21-1.21 3.51 1.28.1 2.58-.65 3.38-1.61z"/>
</svg>''';

  static String of(SignInProvider p) => switch (p) {
    SignInProvider.google => google,
    SignInProvider.facebook => facebook,
    SignInProvider.apple => apple,
  };
}

/// A sign-in button in the provider's own colours, as their terms require.
class SignInButton extends StatelessWidget {
  final SignInProvider provider;
  final bool busy;
  final VoidCallback? onPressed;

  const SignInButton({
    super.key,
    required this.provider,
    required this.onPressed,
    this.busy = false,
  });

  // Each brand mandates its own surface: Google on white, Meta on their blue,
  // Apple on black.
  Color get _background => switch (provider) {
    SignInProvider.google => Colors.white,
    SignInProvider.facebook => const Color(0xFF1877F2),
    SignInProvider.apple => Colors.black,
  };

  Color get _foreground => switch (provider) {
    SignInProvider.google => const Color(0xFF1F1F1F),
    _ => Colors.white,
  };

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: SizedBox(
        width: double.infinity,
        height: 46,
        child: ElevatedButton(
          onPressed: busy ? null : onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: _background,
            disabledBackgroundColor: _background.withValues(alpha: 0.6),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: provider == SignInProvider.google
                  ? const BorderSide(color: Color(0xFFDADCE0))
                  : BorderSide.none,
            ),
          ),
          child: busy
              ? SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: _foreground,
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SvgPicture.string(
                      _BrandMark.of(provider),
                      width: 19,
                      height: 19,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      provider.label,
                      style: TextStyle(
                        color: _foreground,
                        fontSize: 14.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
