import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../constants/theme.dart';
import '../l10n/strings.dart';

/// sunnah.com's collection slug → the app's own book id, so a link can be
/// labelled with the book's name in the reader's language.
const _bookIdOf = {
  'nawawi40': 'nawawi',
  'qudsi40': 'qudsi',
  'bukhari': 'bukhari',
  'muslim': 'muslim',
  'abudawud': 'abudawud',
  'tirmidhi': 'tirmidhi',
  'nasai': 'nasai',
  'ibnmajah': 'ibnmajah',
  'malik': 'malik',
};

/// The app's book id → sunnah.com collection slug. Only collections whose
/// numbering was checked against sunnah.com belong here; a book missing from
/// this map gets no link, since a wrong number would open a different hadith.
/// Muslim is left out (the source numbers it 1–7563 in sequence, sunnah.com
/// uses Abd al-Baqi's 1–3033), and so is Malik (sunnah.com has no
/// per-hadith numbering for it).
const sunnahSlugOfBook = {
  'nawawi': 'nawawi40',
  'qudsi': 'qudsi40',
  'bukhari': 'bukhari',
  'abudawud': 'abudawud',
  'tirmidhi': 'tirmidhi',
  'nasai': 'nasai',
  'ibnmajah': 'ibnmajah',
};

Uri sunnahUri(String ref) => Uri.parse('https://sunnah.com/$ref');

Future<void> openSunnah(BuildContext context, String ref) async {
  final messenger = ScaffoldMessenger.of(context);
  bool ok;
  try {
    ok = await launchUrl(sunnahUri(ref), mode: LaunchMode.externalApplication);
  } catch (_) {
    ok = false;
  }
  if (!ok) {
    messenger.showSnackBar(SnackBar(content: Text(t('sunnah.openFailed'))));
  }
}

/// One chip per verified sunnah.com reference ("bukhari:3868"), under a small
/// "Read the hadith on sunnah.com" caption.
class SunnahLinks extends StatelessWidget {
  final List<String> refs;
  final bool isArabic;

  const SunnahLinks({super.key, required this.refs, required this.isArabic});

  String _label(String ref) {
    final parts = ref.split(':');
    final bookId = _bookIdOf[parts.first];
    final name = bookId == null ? parts.first : t('book.$bookId');
    return '$name ${parts.last}';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          t('sunnah.readOn'),
          textAlign: isArabic ? TextAlign.right : TextAlign.left,
          style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
        ),
        const SizedBox(height: 6),
        // The chips line up under the source line, which follows the
        // story's language rather than the app's.
        Directionality(
          textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
          child: Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final ref in refs)
                InkWell(
                  onTap: () => openSunnah(context, ref),
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.goldMuted,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.goldBorder),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _label(ref),
                          style: const TextStyle(
                            color: AppColors.textGold,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.open_in_new,
                          color: AppColors.textGold,
                          size: 13,
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
