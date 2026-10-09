import 'package:flutter/material.dart';

import '../constants/theme.dart';
import '../l10n/strings.dart';
import '../services/app_locale.dart';

/// One sunnah of Friday: what to do, the hadith it rests on (in Arabic, as
/// narrated), and where it is found.
class _Sunnah {
  final String key;
  final String hadith;
  final String source;

  const _Sunnah(this.key, this.hadith, this.source);
}

/// Sahih narrations only, from al-Bukhari and Muslim unless noted.
const _sunnahs = <_Sunnah>[
  _Sunnah(
    'jumuah.ghusl',
    '«إذا جاء أحدكم الجمعة فليغتسل»',
    'البخاري (877) ومسلم (844)',
  ),
  _Sunnah(
    'jumuah.perfume',
    '«لا يغتسل رجل يوم الجمعة، ويتطهر ما استطاع من طهر، ويدّهن من دهنه، '
        'أو يمس من طيب بيته، ثم يخرج فلا يفرّق بين اثنين، ثم يصلي ما كُتب له، '
        'ثم ينصت إذا تكلم الإمام، إلا غُفر له ما بينه وبين الجمعة الأخرى»',
    'البخاري (883)',
  ),
  _Sunnah(
    'jumuah.early',
    '«من اغتسل يوم الجمعة غسل الجنابة ثم راح فكأنما قرّب بدنة…»',
    'البخاري (881) ومسلم (850)',
  ),
  _Sunnah(
    'jumuah.listen',
    '«إذا قلت لصاحبك يوم الجمعة: أنصت، والإمام يخطب، فقد لغوت»',
    'البخاري (934) ومسلم (851)',
  ),
  _Sunnah(
    'jumuah.kahf',
    '«من قرأ سورة الكهف يوم الجمعة أضاء له من النور ما بين الجمعتين»',
    'الحاكم والبيهقي، وصححه الألباني في صحيح الجامع (6470)',
  ),
  _Sunnah(
    'jumuah.salawat',
    '«إن من أفضل أيامكم يوم الجمعة… فأكثروا عليّ من الصلاة فيه، '
        'فإن صلاتكم معروضة عليّ»',
    'أبو داود (1047)، وصححه الألباني',
  ),
  _Sunnah(
    'jumuah.hour',
    '«فيه ساعة لا يوافقها عبد مسلم وهو قائم يصلي يسأل الله تعالى شيئاً '
        'إلا أعطاه إياه»',
    'البخاري (935) ومسلم (852)',
  ),
  _Sunnah(
    'jumuah.fajr',
    'كان النبي ﷺ يقرأ في الفجر يوم الجمعة: «الم تنزيل» السجدة، '
        'و«هل أتى على الإنسان»',
    'البخاري (891) ومسلم (880)',
  ),
];

/// The sunnahs of Friday, opened from the prayer-times card on Fridays.
Future<void> showJumuahSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.blackCard,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => Directionality(
      textDirection: AppLocale.direction,
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.75,
        maxChildSize: 0.92,
        builder: (ctx, scroll) => ListView(
          controller: scroll,
          padding: const EdgeInsets.fromLTRB(18, 10, 18, 28),
          children: [
            Center(
              child: Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.jumuahBorder,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              t('jumuah.sheetTitle'),
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.jumuah,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 14),
            for (final s in _sunnahs)
              Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.jumuahMuted,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.jumuahBorder),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      t(s.key),
                      style: const TextStyle(
                        color: AppColors.jumuah,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      s.hadith,
                      textDirection: TextDirection.rtl,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 14,
                        height: 1.8,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      s.source,
                      textDirection: TextDirection.rtl,
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    ),
  );
}
