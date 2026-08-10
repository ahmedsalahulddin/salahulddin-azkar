class Dhikr {
  final String id;
  final String categoryId;
  final String text;
  final String source;
  final int repetitions;
  final String? benefit;

  const Dhikr({
    required this.id,
    required this.categoryId,
    required this.text,
    required this.source,
    required this.repetitions,
    this.benefit,
  });

  /// Recitation id from Hisn al-Muslim, for the adhkar whose text matches one
  /// of its entries exactly.
  ///
  /// Only exact matches are listed. Looser matching was tried and produced
  /// dangerous links — the tahlil resolved to the whole morning supplication,
  /// Al-Falaq to Al-Ikhlas, and the evening "بك أمسينا" to its morning
  /// counterpart. Playing the wrong supplication is worse than offering no
  /// audio, so the rest deliberately have none.
  int? get audioId => _audioIds[id];

  bool get hasAudio => audioId != null;

  String? get audioUrl =>
      audioId == null ? null : 'https://www.hisnmuslim.com/audio/ar/$audioId.mp3';
}

const _audioIds = <String, int>{
  'morning-6': 85,
  'evening-3': 216,
  'prayer-3': 240,
  'prayer-5': 241,
  'prayer-7': 100,
  'sleep-1': 105,
  'sleep-2': 104,
  'sleep-3': 240,
  'sleep-5': 241,
};

class AdhkarCategory {
  final String id;
  final String name;
  final String icon;
  final String description;
  int count;

  AdhkarCategory({
    required this.id,
    required this.name,
    required this.icon,
    required this.description,
    this.count = 0,
  });
}

final List<AdhkarCategory> categories = [
  AdhkarCategory(id: 'morning', name: 'أذكار الصباح', icon: '🌅', description: 'تُقال بعد صلاة الفجر حتى طلوع الشمس'),
  AdhkarCategory(id: 'evening', name: 'أذكار المساء', icon: '🌙', description: 'تُقال بعد صلاة العصر حتى المغرب'),
  AdhkarCategory(id: 'after-prayer', name: 'أذكار بعد الصلاة', icon: '🕌', description: 'تُقال بعد التسليم من الصلاة المفروضة'),
  AdhkarCategory(id: 'sleep', name: 'أذكار النوم', icon: '😴', description: 'تُقال قبل النوم'),
  AdhkarCategory(id: 'travel', name: 'أذكار السفر', icon: '✈️', description: 'تُقال عند السفر وركوب الدابة'),
  AdhkarCategory(id: 'ruqyah', name: 'الرقية الشرعية', icon: '📖', description: 'آيات وأدعية للرقية والتحصين'),
  AdhkarCategory(id: 'deceased', name: 'الوفيات', icon: '🕊️', description: 'ادعُ لمن توفاهم الله بالرحمة والمغفرة'),
];

final List<Dhikr> adhkar = const [
  // ===== أذكار الصباح =====
  Dhikr(id: 'morning-1', categoryId: 'morning', text: 'أَصْبَحْنَا وَأَصْبَحَ الْمُلْكُ لِلَّهِ، وَالْحَمْدُ لِلَّهِ، لَا إِلَهَ إِلَّا اللَّهُ وَحْدَهُ لَا شَرِيكَ لَهُ، لَهُ الْمُلْكُ وَلَهُ الْحَمْدُ وَهُوَ عَلَى كُلِّ شَيْءٍ قَدِيرٌ. رَبِّ أَسْأَلُكَ خَيْرَ مَا فِي هَذَا الْيَوْمِ وَخَيْرَ مَا بَعْدَهُ، وَأَعُوذُ بِكَ مِنْ شَرِّ مَا فِي هَذَا الْيَوْمِ وَشَرِّ مَا بَعْدَهُ، رَبِّ أَعُوذُ بِكَ مِنَ الْكَسَلِ وَسُوءِ الْكِبَرِ، رَبِّ أَعُوذُ بِكَ مِنْ عَذَابٍ فِي النَّارِ وَعَذَابٍ فِي الْقَبْرِ.', source: 'صحيح مسلم', repetitions: 1, benefit: 'دعاء شامل لخير اليوم والاستعاذة من شره'),
  Dhikr(id: 'morning-2', categoryId: 'morning', text: 'اللَّهُمَّ بِكَ أَصْبَحْنَا، وَبِكَ أَمْسَيْنَا، وَبِكَ نَحْيَا، وَبِكَ نَمُوتُ، وَإِلَيْكَ النُّشُورُ.', source: 'سنن الترمذي', repetitions: 1, benefit: 'التوكل على الله في جميع الأحوال'),
  Dhikr(id: 'morning-3', categoryId: 'morning', text: 'سُبْحَانَ اللَّهِ وَبِحَمْدِهِ.', source: 'صحيح مسلم', repetitions: 100, benefit: 'من قالها مئة مرة حين يصبح وحين يمسي لم يأت أحد يوم القيامة بأفضل مما جاء به'),
  Dhikr(id: 'morning-4', categoryId: 'morning', text: 'لَا إِلَهَ إِلَّا اللَّهُ وَحْدَهُ لَا شَرِيكَ لَهُ، لَهُ الْمُلْكُ وَلَهُ الْحَمْدُ، وَهُوَ عَلَى كُلِّ شَيْءٍ قَدِيرٌ.', source: 'صحيح البخاري', repetitions: 10, benefit: 'كانت له عدل عشر رقاب، وكُتبت له مئة حسنة، ومُحيت عنه مئة سيئة'),
  Dhikr(id: 'morning-5', categoryId: 'morning', text: 'اللَّهُمَّ إِنِّي أَسْأَلُكَ الْعَفْوَ وَالْعَافِيَةَ فِي الدُّنْيَا وَالْآخِرَةِ، اللَّهُمَّ إِنِّي أَسْأَلُكَ الْعَفْوَ وَالْعَافِيَةَ فِي دِينِي وَدُنْيَايَ وَأَهْلِي وَمَالِي، اللَّهُمَّ اسْتُرْ عَوْرَاتِي وَآمِنْ رَوْعَاتِي، اللَّهُمَّ احْفَظْنِي مِنْ بَيْنِ يَدَيَّ وَمِنْ خَلْفِي وَعَنْ يَمِينِي وَعَنْ شِمَالِي وَمِنْ فَوْقِي، وَأَعُوذُ بِعَظَمَتِكَ أَنْ أُغْتَالَ مِنْ تَحْتِي.', source: 'صحيح ابن ماجه', repetitions: 1, benefit: 'سؤال الله العافية والحفظ من كل جانب'),
  Dhikr(id: 'morning-6', categoryId: 'morning', text: 'اللَّهُمَّ عَالِمَ الْغَيْبِ وَالشَّهَادَةِ فَاطِرَ السَّمَاوَاتِ وَالْأَرْضِ، رَبَّ كُلِّ شَيْءٍ وَمَلِيكَهُ، أَشْهَدُ أَنْ لَا إِلَهَ إِلَّا أَنْتَ، أَعُوذُ بِكَ مِنْ شَرِّ نَفْسِي، وَمِنْ شَرِّ الشَّيْطَانِ وَشِرْكِهِ، وَأَنْ أَقْتَرِفَ عَلَى نَفْسِي سُوءًا أَوْ أَجُرَّهُ إِلَى مُسْلِمٍ.', source: 'سنن الترمذي', repetitions: 1, benefit: 'الاستعاذة من شر النفس والشيطان'),
  Dhikr(id: 'morning-7', categoryId: 'morning', text: 'بِسْمِ اللَّهِ الَّذِي لَا يَضُرُّ مَعَ اسْمِهِ شَيْءٌ فِي الْأَرْضِ وَلَا فِي السَّمَاءِ وَهُوَ السَّمِيعُ الْعَلِيمُ.', source: 'سنن أبي داود', repetitions: 3, benefit: 'من قالها ثلاثاً لم يضره شيء'),
  Dhikr(id: 'morning-8', categoryId: 'morning', text: 'رَضِيتُ بِاللَّهِ رَبًّا، وَبِالْإِسْلَامِ دِينًا، وَبِمُحَمَّدٍ ﷺ نَبِيًّا.', source: 'سنن أبي داود', repetitions: 3, benefit: 'من قالها حين يصبح وحين يمسي كان حقاً على الله أن يرضيه يوم القيامة'),
  Dhikr(id: 'morning-9', categoryId: 'morning', text: 'يَا حَيُّ يَا قَيُّومُ بِرَحْمَتِكَ أَسْتَغِيثُ، أَصْلِحْ لِي شَأْنِي كُلَّهُ، وَلَا تَكِلْنِي إِلَى نَفْسِي طَرْفَةَ عَيْنٍ.', source: 'صحيح الترغيب', repetitions: 1, benefit: 'سؤال الله إصلاح جميع الشؤون'),
  Dhikr(id: 'morning-10', categoryId: 'morning', text: 'أَسْتَغْفِرُ اللَّهَ وَأَتُوبُ إِلَيْهِ.', source: 'صحيح البخاري', repetitions: 100, benefit: 'كان النبي ﷺ يستغفر الله في اليوم أكثر من سبعين مرة'),

  // ===== أذكار المساء =====
  Dhikr(id: 'evening-1', categoryId: 'evening', text: 'أَمْسَيْنَا وَأَمْسَى الْمُلْكُ لِلَّهِ، وَالْحَمْدُ لِلَّهِ، لَا إِلَهَ إِلَّا اللَّهُ وَحْدَهُ لَا شَرِيكَ لَهُ، لَهُ الْمُلْكُ وَلَهُ الْحَمْدُ وَهُوَ عَلَى كُلِّ شَيْءٍ قَدِيرٌ. رَبِّ أَسْأَلُكَ خَيْرَ مَا فِي هَذِهِ اللَّيْلَةِ وَخَيْرَ مَا بَعْدَهَا، وَأَعُوذُ بِكَ مِنْ شَرِّ مَا فِي هَذِهِ اللَّيْلَةِ وَشَرِّ مَا بَعْدَهَا.', source: 'صحيح مسلم', repetitions: 1, benefit: 'دعاء شامل لخير الليلة والاستعاذة من شرها'),
  Dhikr(id: 'evening-2', categoryId: 'evening', text: 'اللَّهُمَّ بِكَ أَمْسَيْنَا، وَبِكَ أَصْبَحْنَا، وَبِكَ نَحْيَا، وَبِكَ نَمُوتُ، وَإِلَيْكَ الْمَصِيرُ.', source: 'سنن الترمذي', repetitions: 1, benefit: 'التوكل على الله في جميع الأحوال'),
  Dhikr(id: 'evening-3', categoryId: 'evening', text: 'أَعُوذُ بِكَلِمَاتِ اللَّهِ التَّامَّاتِ مِنْ شَرِّ مَا خَلَقَ.', source: 'صحيح مسلم', repetitions: 3, benefit: 'من قالها حين يمسي ثلاث مرات لم تضره حُمة تلك الليلة'),
  Dhikr(id: 'evening-4', categoryId: 'evening', text: 'اللَّهُمَّ إِنِّي أَمْسَيْتُ أُشْهِدُكَ وَأُشْهِدُ حَمَلَةَ عَرْشِكَ وَمَلَائِكَتَكَ وَجَمِيعَ خَلْقِكَ أَنَّكَ أَنْتَ اللَّهُ لَا إِلَهَ إِلَّا أَنْتَ وَحْدَكَ لَا شَرِيكَ لَكَ وَأَنَّ مُحَمَّدًا عَبْدُكَ وَرَسُولُكَ.', source: 'سنن أبي داود', repetitions: 4, benefit: 'من قالها أعتقه الله من النار'),
  Dhikr(id: 'evening-5', categoryId: 'evening', text: 'سُبْحَانَ اللَّهِ وَبِحَمْدِهِ.', source: 'صحيح مسلم', repetitions: 100, benefit: 'حُطّت خطاياه وإن كانت مثل زبد البحر'),
  Dhikr(id: 'evening-6', categoryId: 'evening', text: 'اللَّهُمَّ إِنِّي أَسْأَلُكَ الْعَفْوَ وَالْعَافِيَةَ فِي الدُّنْيَا وَالْآخِرَةِ.', source: 'صحيح ابن ماجه', repetitions: 1, benefit: 'ما سُئل الله شيئاً أحب إليه من العافية'),

  // ===== أذكار بعد الصلاة =====
  Dhikr(id: 'prayer-1', categoryId: 'after-prayer', text: 'أَسْتَغْفِرُ اللَّهَ، أَسْتَغْفِرُ اللَّهَ، أَسْتَغْفِرُ اللَّهَ.', source: 'صحيح مسلم', repetitions: 3, benefit: 'يُقال بعد السلام مباشرة'),
  Dhikr(id: 'prayer-2', categoryId: 'after-prayer', text: 'اللَّهُمَّ أَنْتَ السَّلَامُ وَمِنْكَ السَّلَامُ تَبَارَكْتَ يَا ذَا الْجَلَالِ وَالْإِكْرَامِ.', source: 'صحيح مسلم', repetitions: 1, benefit: 'يُقال بعد الاستغفار ثلاثاً'),
  Dhikr(id: 'prayer-3', categoryId: 'after-prayer', text: 'سُبْحَانَ اللَّهِ.', source: 'صحيح مسلم', repetitions: 33, benefit: 'التسبيح بعد كل صلاة'),
  Dhikr(id: 'prayer-4', categoryId: 'after-prayer', text: 'الْحَمْدُ لِلَّهِ.', source: 'صحيح مسلم', repetitions: 33, benefit: 'التحميد بعد كل صلاة'),
  Dhikr(id: 'prayer-5', categoryId: 'after-prayer', text: 'اللَّهُ أَكْبَرُ.', source: 'صحيح مسلم', repetitions: 33, benefit: 'التكبير بعد كل صلاة'),
  Dhikr(id: 'prayer-6', categoryId: 'after-prayer', text: 'لَا إِلَهَ إِلَّا اللَّهُ وَحْدَهُ لَا شَرِيكَ لَهُ، لَهُ الْمُلْكُ وَلَهُ الْحَمْدُ وَهُوَ عَلَى كُلِّ شَيْءٍ قَدِيرٌ.', source: 'صحيح مسلم', repetitions: 1, benefit: 'تمام المئة بعد التسبيح والتحميد والتكبير'),
  Dhikr(id: 'prayer-7', categoryId: 'after-prayer', text: 'آيَة الْكُرْسِيّ: اللَّهُ لَا إِلَٰهَ إِلَّا هُوَ الْحَيُّ الْقَيُّومُ ۚ لَا تَأْخُذُهُ سِنَةٌ وَلَا نَوْمٌ ۚ لَّهُ مَا فِي السَّمَاوَاتِ وَمَا فِي الْأَرْضِ ۗ مَن ذَا الَّذِي يَشْفَعُ عِندَهُ إِلَّا بِإِذْنِهِ ۚ يَعْلَمُ مَا بَيْنَ أَيْدِيهِمْ وَمَا خَلْفَهُمْ ۖ وَلَا يُحِيطُونَ بِشَيْءٍ مِّنْ عِلْمِهِ إِلَّا بِمَا شَاءَ ۚ وَسِعَ كُرْسِيُّهُ السَّمَاوَاتِ وَالْأَرْضَ ۖ وَلَا يَئُودُهُ حِفْظُهُمَا ۚ وَهُوَ الْعَلِيُّ الْعَظِيمُ.', source: 'سورة البقرة: 255', repetitions: 1, benefit: 'من قرأها دبر كل صلاة لم يمنعه من دخول الجنة إلا الموت'),

  // ===== أذكار النوم =====
  Dhikr(id: 'sleep-1', categoryId: 'sleep', text: 'بِاسْمِكَ اللَّهُمَّ أَمُوتُ وَأَحْيَا.', source: 'صحيح البخاري', repetitions: 1, benefit: 'يُقال عند وضع الجنب للنوم'),
  Dhikr(id: 'sleep-2', categoryId: 'sleep', text: 'اللَّهُمَّ قِنِي عَذَابَكَ يَوْمَ تَبْعَثُ عِبَادَكَ.', source: 'سنن أبي داود', repetitions: 1, benefit: 'كان النبي ﷺ يقولها إذا أراد أن ينام'),
  Dhikr(id: 'sleep-3', categoryId: 'sleep', text: 'سُبْحَانَ اللَّهِ.', source: 'صحيح البخاري', repetitions: 33, benefit: 'التسبيح قبل النوم - وصية النبي ﷺ لفاطمة وعلي'),
  Dhikr(id: 'sleep-4', categoryId: 'sleep', text: 'الْحَمْدُ لِلَّهِ.', source: 'صحيح البخاري', repetitions: 33, benefit: 'التحميد قبل النوم'),
  Dhikr(id: 'sleep-5', categoryId: 'sleep', text: 'اللَّهُ أَكْبَرُ.', source: 'صحيح البخاري', repetitions: 34, benefit: 'التكبير قبل النوم'),
  Dhikr(id: 'sleep-6', categoryId: 'sleep', text: 'اللَّهُمَّ رَبَّ السَّمَاوَاتِ السَّبْعِ وَرَبَّ الْأَرْضِ وَرَبَّ الْعَرْشِ الْعَظِيمِ، رَبَّنَا وَرَبَّ كُلِّ شَيْءٍ، فَالِقَ الْحَبِّ وَالنَّوَى، وَمُنْزِلَ التَّوْرَاةِ وَالْإِنْجِيلِ وَالْفُرْقَانِ، أَعُوذُ بِكَ مِنْ شَرِّ كُلِّ شَيْءٍ أَنْتَ آخِذٌ بِنَاصِيَتِهِ.', source: 'صحيح مسلم', repetitions: 1, benefit: 'التحصين الشامل قبل النوم'),

  // ===== أذكار السفر =====
  Dhikr(id: 'travel-1', categoryId: 'travel', text: 'اللَّهُ أَكْبَرُ، اللَّهُ أَكْبَرُ، اللَّهُ أَكْبَرُ. سُبْحَانَ الَّذِي سَخَّرَ لَنَا هَذَا وَمَا كُنَّا لَهُ مُقْرِنِينَ وَإِنَّا إِلَى رَبِّنَا لَمُنقَلِبُونَ.', source: 'صحيح مسلم', repetitions: 1, benefit: 'دعاء ركوب الدابة والسيارة'),
  Dhikr(id: 'travel-2', categoryId: 'travel', text: 'اللَّهُمَّ إِنَّا نَسْأَلُكَ فِي سَفَرِنَا هَذَا الْبِرَّ وَالتَّقْوَى، وَمِنَ الْعَمَلِ مَا تَرْضَى، اللَّهُمَّ هَوِّنْ عَلَيْنَا سَفَرَنَا هَذَا وَاطْوِ عَنَّا بُعْدَهُ، اللَّهُمَّ أَنْتَ الصَّاحِبُ فِي السَّفَرِ وَالْخَلِيفَةُ فِي الْأَهْلِ.', source: 'صحيح مسلم', repetitions: 1, benefit: 'دعاء السفر الشامل'),
  Dhikr(id: 'travel-3', categoryId: 'travel', text: 'اللَّهُمَّ إِنِّي أَعُوذُ بِكَ مِنْ وَعْثَاءِ السَّفَرِ وَكَآبَةِ الْمَنْظَرِ وَسُوءِ الْمُنْقَلَبِ فِي الْمَالِ وَالْأَهْلِ.', source: 'صحيح مسلم', repetitions: 1, benefit: 'الاستعاذة من مشقة السفر'),

  // ===== الرقية الشرعية =====
  Dhikr(id: 'ruqyah-1', categoryId: 'ruqyah', text: 'بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ. الْحَمْدُ لِلَّهِ رَبِّ الْعَالَمِينَ. الرَّحْمَٰنِ الرَّحِيمِ. مَالِكِ يَوْمِ الدِّينِ. إِيَّاكَ نَعْبُدُ وَإِيَّاكَ نَسْتَعِينُ. اهْدِنَا الصِّرَاطَ الْمُسْتَقِيمَ. صِرَاطَ الَّذِينَ أَنْعَمْتَ عَلَيْهِمْ غَيْرِ الْمَغْضُوبِ عَلَيْهِمْ وَلَا الضَّالِّينَ.', source: 'سورة الفاتحة', repetitions: 7, benefit: 'أعظم سورة في القرآن - رقية شافية بإذن الله'),
  Dhikr(id: 'ruqyah-2', categoryId: 'ruqyah', text: 'قُلْ هُوَ اللَّهُ أَحَدٌ. اللَّهُ الصَّمَدُ. لَمْ يَلِدْ وَلَمْ يُولَدْ. وَلَمْ يَكُن لَّهُ كُفُوًا أَحَدٌ.', source: 'سورة الإخلاص', repetitions: 3, benefit: 'تعدل ثلث القرآن'),
  Dhikr(id: 'ruqyah-3', categoryId: 'ruqyah', text: 'قُلْ أَعُوذُ بِرَبِّ الْفَلَقِ. مِن شَرِّ مَا خَلَقَ. وَمِن شَرِّ غَاسِقٍ إِذَا وَقَبَ. وَمِن شَرِّ النَّفَّاثَاتِ فِي الْعُقَدِ. وَمِن شَرِّ حَاسِدٍ إِذَا حَسَدَ.', source: 'سورة الفلق', repetitions: 3, benefit: 'الاستعاذة من شرور المخلوقات'),
  Dhikr(id: 'ruqyah-4', categoryId: 'ruqyah', text: 'قُلْ أَعُوذُ بِرَبِّ النَّاسِ. مَلِكِ النَّاسِ. إِلَٰهِ النَّاسِ. مِن شَرِّ الْوَسْوَاسِ الْخَنَّاسِ. الَّذِي يُوَسْوِسُ فِي صُدُورِ النَّاسِ. مِنَ الْجِنَّةِ وَالنَّاسِ.', source: 'سورة الناس', repetitions: 3, benefit: 'الاستعاذة من الوسواس'),
  Dhikr(id: 'ruqyah-5', categoryId: 'ruqyah', text: 'أَعُوذُ بِكَلِمَاتِ اللَّهِ التَّامَّةِ مِنْ كُلِّ شَيْطَانٍ وَهَامَّةٍ وَمِنْ كُلِّ عَيْنٍ لَامَّةٍ.', source: 'صحيح البخاري', repetitions: 1, benefit: 'كان النبي ﷺ يعوّذ بها الحسن والحسين'),
  Dhikr(id: 'ruqyah-6', categoryId: 'ruqyah', text: 'بِسْمِ اللَّهِ أَرْقِيكَ، مِنْ كُلِّ شَيْءٍ يُؤْذِيكَ، مِنْ شَرِّ كُلِّ نَفْسٍ أَوْ عَيْنِ حَاسِدٍ اللَّهُ يَشْفِيكَ، بِسْمِ اللَّهِ أَرْقِيكَ.', source: 'صحيح مسلم', repetitions: 3, benefit: 'رقية جبريل عليه السلام للنبي ﷺ'),

  // ===== أدعية للمتوفى =====
  Dhikr(id: 'deceased-1', categoryId: 'deceased', text: 'اللَّهُمَّ اغْفِرْ لَهُ وَارْحَمْهُ وَعَافِهِ وَاعْفُ عَنْهُ، وَأَكْرِمْ نُزُلَهُ وَوَسِّعْ مُدْخَلَهُ، وَاغْسِلْهُ بِالْمَاءِ وَالثَّلْجِ وَالْبَرَدِ، وَنَقِّهِ مِنَ الْخَطَايَا كَمَا نَقَّيْتَ الثَّوْبَ الْأَبْيَضَ مِنَ الدَّنَسِ.', source: 'صحيح مسلم', repetitions: 1, benefit: 'من أعظم أدعية الجنازة — دعاء النبي ﷺ'),
  Dhikr(id: 'deceased-2', categoryId: 'deceased', text: 'اللَّهُمَّ اغْفِرْ لِحَيِّنَا وَمَيِّتِنَا، وَشَاهِدِنَا وَغَائِبِنَا، وَصَغِيرِنَا وَكَبِيرِنَا، وَذَكَرِنَا وَأُنْثَانَا. اللَّهُمَّ مَنْ أَحْيَيْتَهُ مِنَّا فَأَحْيِهِ عَلَى الْإِسْلَامِ، وَمَنْ تَوَفَّيْتَهُ مِنَّا فَتَوَفَّهُ عَلَى الْإِيمَانِ.', source: 'سنن الترمذي', repetitions: 1, benefit: 'دعاء شامل للأحياء والأموات'),
  Dhikr(id: 'deceased-3', categoryId: 'deceased', text: 'اللَّهُمَّ إِنَّ فُلَانَ بْنَ فُلَانٍ فِي ذِمَّتِكَ وَحَبْلِ جِوَارِكَ، فَقِهِ مِنْ فِتْنَةِ الْقَبْرِ وَعَذَابِ النَّارِ، وَأَنْتَ أَهْلُ الْوَفَاءِ وَالْحَقِّ، فَاغْفِرْ لَهُ وَارْحَمْهُ إِنَّكَ أَنْتَ الْغَفُورُ الرَّحِيمُ.', source: 'سنن أبي داود', repetitions: 1, benefit: 'يُذكر اسم المتوفى بدل "فلان بن فلان"'),
  Dhikr(id: 'deceased-4', categoryId: 'deceased', text: 'اللَّهُمَّ أَبْدِلْهُ دَارًا خَيْرًا مِنْ دَارِهِ، وَأَهْلًا خَيْرًا مِنْ أَهْلِهِ، وَأَدْخِلْهُ الْجَنَّةَ وَأَعِذْهُ مِنْ عَذَابِ الْقَبْرِ وَمِنْ عَذَابِ النَّارِ.', source: 'صحيح مسلم', repetitions: 1, benefit: 'سؤال الله أن يبدله خيراً في الآخرة'),
  Dhikr(id: 'deceased-5', categoryId: 'deceased', text: 'اللَّهُمَّ لَا تَحْرِمْنَا أَجْرَهُ وَلَا تَفْتِنَّا بَعْدَهُ وَاغْفِرْ لَنَا وَلَهُ.', source: 'صحيح مسلم', repetitions: 1, benefit: 'طلب الأجر والثبات بعد فقد الميت'),
  Dhikr(id: 'deceased-6', categoryId: 'deceased', text: 'اللَّهُمَّ ثَبِّتْهُ عِنْدَ السُّؤَالِ.', source: 'رواه أبو داود', repetitions: 3, benefit: 'كان النبي ﷺ يقف على القبر بعد الدفن ويقول: استغفروا لأخيكم وسلوا له التثبيت'),
];

List<Dhikr> getAdhkarByCategory(String categoryId) {
  return adhkar.where((d) => d.categoryId == categoryId).toList();
}

List<AdhkarCategory> getCategoriesWithCount() {
  return categories.map((cat) {
    cat.count = adhkar.where((d) => d.categoryId == cat.id).length;
    return cat;
  }).toList();
}
