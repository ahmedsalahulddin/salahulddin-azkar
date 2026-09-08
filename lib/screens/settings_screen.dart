import 'package:flutter/material.dart';
import '../constants/theme.dart';
import '../data/quran_data.dart';
import '../data/adhans.dart';
import '../services/daily_reminders.dart';
import '../services/dhikr_reminder.dart';
import '../services/notification_service.dart';
import '../services/prayer_alerts.dart';
import '../services/prayer_service.dart';
import '../services/prayer_settings.dart';
import 'prayer_alerts_screen.dart';
import '../services/storage_service.dart';

class SettingsScreen extends StatefulWidget {
  /// True when the settings sit inside another screen's scroll view, which is
  /// how they are reached now — the account page carries them.
  final bool embedded;

  const SettingsScreen({super.key, this.embedded = false});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _fontSize = 'medium';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final fs = await StorageService.getFontSize();
    if (mounted) setState(() => _fontSize = fs);
  }

  Future<void> _setFontSize(String size) async {
    setState(() => _fontSize = size);
    await StorageService.setFontSize(size);
  }

  @override
  Widget build(BuildContext context) {
    final previewSize = _fontSize == 'small' ? 18.0 : _fontSize == 'large' ? 28.0 : 22.0;

    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [

                // Font size section
                _sectionTitle('حجم الخط'),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      _fontBtn('صغير', 'small'),
                      const SizedBox(width: 8),
                      _fontBtn('متوسط', 'medium'),
                      const SizedBox(width: 8),
                      _fontBtn('كبير', 'large'),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.blackCard,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.goldBorder),
                  ),
                  child: Text(
                    'سُبْحَانَ اللَّهِ وَبِحَمْدِهِ',
                    style: TextStyle(color: AppColors.textPrimary, fontSize: previewSize),
                    textAlign: TextAlign.center,
                  ),
                ),

                // Everything, quieted at once.
                _muteAll(),

                // Prayer times
                _sectionTitle('حساب مواقيت الصلاة'),
                _prayerMethod(),
                const SizedBox(height: 10),
                _asrSchool(),
                const SizedBox(height: 10),
                _alertsRow(),

                // Notifications
                _sectionTitle('التذكيرات'),
                _notificationHealth(),
                const SizedBox(height: 10),
                _dhikrReminder(),
                const SizedBox(height: 10),
                _verseReminder(),
                const SizedBox(height: 10),
                _adhkarWindow(
                  title: 'أذكار الصباح',
                  note: 'من بعد الفجر وحتى ما قبل الظهر',
                  on: DailyReminders.morningOn,
                  at: DailyReminders.morningAt,
                  window: DailyReminders.morningWindow,
                  apply: (v, t) => DailyReminders.setMorning(on: v, at: t),
                ),
                const SizedBox(height: 10),
                _adhkarWindow(
                  title: 'أذكار المساء',
                  note: 'من بعد العصر وحتى المغرب',
                  on: DailyReminders.eveningOn,
                  at: DailyReminders.eveningAt,
                  window: DailyReminders.eveningWindow,
                  apply: (v, t) => DailyReminders.setEvening(on: v, at: t),
                ),
      ],
    );

    // Embedded, the caller owns the page and its scrolling.
    if (widget.embedded) return body;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.black,
        appBar: AppBar(
          title: const Text('الإعدادات'),
          backgroundColor: AppColors.black,
          foregroundColor: AppColors.gold,
        ),
        body: SafeArea(child: SingleChildScrollView(child: body)),

      ),
    );
  }

  /// Whether anything will actually arrive, and one tap to make it.
  ///
  /// The reminders are the only part of the app whose working cannot be seen
  /// by looking: a prayer alert set for tomorrow's Fajr proves nothing today,
  /// and every switch below can be on while the phone quietly refuses the lot.
  /// So this says what the phone allows, offers to prove it with one that
  /// arrives now, and turns the three the reader asks for most on together —
  /// twelve switches is a wall, not a choice.
  /// Asked once, not on every frame.
  ///
  /// Built inline, this re-queried the system on every rebuild — and each new
  /// future started as "no answer yet", so the card's reading of whether the
  /// phone allows notifications flickered every time anything else changed.
  Future<bool?>? _allowed;

  /// How many alarms the system is holding for us. Null until asked.
  int? _pending;

  Widget _notificationHealth() {
    _allowed ??= NotificationService.allowed();
    if (_pending == null) _countPending();

    return FutureBuilder<bool?>(
      future: _allowed,
      builder: (context, snapshot) {
        // Null means the platform would not say. Treated as probably fine
        // rather than alarming anyone over a question that was not answered.
        final blocked = snapshot.data == false;

        // Rebuilt whenever an alert changes, so the card can say what is
        // currently on. It used to be an action and nothing more: it fired,
        // said so once in a passing message, and then looked exactly as it
        // had before — leaving no way to tell whether it had worked.
        return ValueListenableBuilder<Map<String, AlertMode>>(
          valueListenable: PrayerAlerts.settings,
          builder: (context, _, _) => ValueListenableBuilder<bool>(
            valueListenable: DhikrReminder.enabled,
            builder: (context, dhikrOn, _) =>
                _healthCard(blocked: blocked, dhikrOn: dhikrOn),
          ),
        );
      },
    );
  }

  Future<void> _countPending() async {
    final count = await NotificationService.pending();
    if (mounted && count != _pending) setState(() => _pending = count);
  }

  Widget _healthCard({required bool blocked, required bool dhikrOn}) {
    final prayersOn = PrayerAlerts.anyOn;
    final allOn = prayersOn && dhikrOn;

    return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: allOn && !blocked ? AppColors.goldMuted : AppColors.blackCard,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: blocked
                    ? AppColors.error
                    : allOn
                        ? AppColors.gold
                        : AppColors.goldBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(
                    blocked
                        ? Icons.notifications_off_outlined
                        : allOn
                            ? Icons.check_circle
                            : Icons.notifications_active_outlined,
                    color: blocked ? AppColors.error : AppColors.gold,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      blocked
                          ? 'الجوال يمنع إشعارات التطبيق'
                          : allOn
                              ? 'التنبيهات مُشغّلة'
                              : 'تنبيهات الصلاة والأذكار',
                      style: TextStyle(
                          color: blocked
                              ? AppColors.error
                              : AppColors.textPrimary,
                          fontSize: 14),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                blocked
                    ? 'لن يصل شيء حتى تسمح بها من إعدادات الجوال.'
                    : (prayersOn || dhikrOn) && _pending == 0
                        ? 'الإعدادات مُشغّلة لكن النظام لا يحمل أي تنبيه '
                            'مجدول. افتح الرئيسية مرة ليُعاد ضبطها.'
                        : allOn
                        ? 'مواقيت الصلاة، وتنبيه قبلها بـ'
                            '${QuranService.toArabicDigits(PrayerAlerts.lead.value)}'
                            ' دقيقة، وذكر خلال اليوم.'
                        : prayersOn || dhikrOn
                            ? 'بعضها مُشغّل. اضغط لتشغيل الباقي.'
                            : 'شغّلها كلها بضغطة: مواقيت الصلاة، وتنبيه قبلها، '
                                'وذكر أو دعاء يصلك خلال اليوم.',
                style: const TextStyle(
                    color: AppColors.textMuted, fontSize: 11, height: 1.7),
              ),
              if (!blocked && _pending != null) ...[
                const SizedBox(height: 6),
                Text(
                  // The ground truth, plainly. Every switch can be on and
                  // nothing scheduled, and until now there was no way to see
                  // which of the two was wrong.
                  _pending == 0
                      ? 'لا يوجد تنبيه مجدول الآن'
                      : 'مجدول في النظام: '
                          '${QuranService.toArabicDigits(_pending!)} تنبيه',
                  style: TextStyle(
                    color: _pending == 0 && (prayersOn || dhikrOn)
                        ? AppColors.error
                        : AppColors.textMuted,
                    fontSize: 10.5,
                  ),
                ),
                // Which clock those times were written against. It reads like
                // a detail until it is wrong, and then it is the whole fault:
                // the app announces a reminder for 3:55 and the phone rings at
                // 6:55, with nothing anywhere saying why.
                if (NotificationService.zoneName.isNotEmpty)
                  Text(
                    'التوقيت المعتمد: ${NotificationService.zoneName}',
                    style: const TextStyle(
                        color: AppColors.textMuted, fontSize: 10.5),
                  ),
              ],
              const SizedBox(height: 10),
              Row(
                children: [
                  if (blocked)
                    Expanded(
                      child: _healthButton(
                        'افتح إعدادات التطبيق',
                        Icons.settings,
                        // The app has no notification-settings opener of its
                        // own; geolocator's lands on the app's own page in the
                        // system settings, which is where the switch lives.
                        () => PrayerService.openSettingsFor(
                            LocationStatus.denied),
                      ),
                    )
                  else ...[
                    Expanded(
                      child: _healthButton(
                        allOn ? 'أوقف التنبيهات' : 'شغّل التنبيهات',
                        allOn ? Icons.stop : Icons.play_arrow,
                        allOn ? _turnOffAlerts : _turnOnAlerts,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _healthButton(
                          'جرّب الآن', Icons.notifications, _tryNow),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _healthButton('بعد دقيقة', Icons.schedule,
                          _trySchedule),
                    ),
                  ],
                ],
              ),
            ],
          ),
    );
  }

  Widget _healthButton(String label, IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(
          color: AppColors.goldMuted,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.goldBorder),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: AppColors.gold, size: 16),
            const SizedBox(width: 6),
            Flexible(
              child: Text(label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: AppColors.gold,
                      fontSize: 12,
                      fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _tryNow() async {
    await NotificationService.requestPermission();
    final sent = await NotificationService.sendTest();
    if (!mounted) return;
    _say(sent
        ? 'أُرسل إشعار تجريبي — إن لم يصلك فالجوال يمنعه.'
        : 'تعذّر إرسال الإشعار.');
    // The reader may have just granted the permission, so ask again.
    setState(() => _allowed = NotificationService.allowed());
    await _countPending();
  }

  /// The test that actually proves the reminders work.
  ///
  /// "جرّب الآن" hands a notification straight to the system and so proves
  /// only the permission. Every real reminder is an alarm the system holds
  /// for hours — a different road, with its own ways of failing. This takes
  /// that road, one minute out.
  Future<void> _trySchedule() async {
    await NotificationService.requestPermission();
    final set = await NotificationService.sendScheduledTest();
    if (!mounted) return;
    _say(set
        ? 'سيصلك تنبيه بعد دقيقة. أغلق الشاشة وانتظره.'
        : 'تعذّر جدولة الإشعار: ${NotificationService.lastScheduleError}');
    await _countPending();
  }

  /// The three the reader asked for, together: the call to prayer, the warning
  /// before it, and a dhikr through the day. Sound is left off — an adhan is
  /// chosen deliberately, not switched on for someone.
  Future<void> _turnOnAlerts() async {
    await NotificationService.requestPermission();
    const notify = AlertMode(notify: true);
    await PrayerAlerts.setAll(AlertWhen.before, notify);
    await PrayerAlerts.setAll(AlertWhen.onTime, notify);
    await DhikrReminder.apply(on: true);
    if (!mounted) return;
    _say('شُغّلت تنبيهات الصلاة وقبلها، وتذكير الذكر.');
    await _countPending();
  }

  /// The same three, off again — so the button is a switch and not a one-way
  /// door. The alert settings themselves are left alone below; this only puts
  /// down what it picked up.
  Future<void> _turnOffAlerts() async {
    await PrayerAlerts.setAll(AlertWhen.before, AlertMode.off);
    await PrayerAlerts.setAll(AlertWhen.onTime, AlertMode.off);
    await DhikrReminder.apply(on: false);
    if (!mounted) return;
    _say('أُوقفت التنبيهات.');
    await _countPending();
  }

  void _say(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        // A failure now carries the system's own words, which run long and are
        // the whole point of showing it — four seconds and one line would hide
        // exactly the part worth reading.
        content: Text(message, textAlign: TextAlign.right, maxLines: 6),
        backgroundColor: AppColors.blackCard,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 10),
      ));
  }

  /// Each authority sets its own twilight angles, so this is not a matter of
  /// taste: Makkah's method in Cairo gives the wrong Isha, by a quarter of an
  /// hour or more. Left on automatic it follows the reader across borders.
  Widget _prayerMethod() {
    return ValueListenableBuilder<PrayerMethod>(
      valueListenable: PrayerSettings.method,
      builder: (context, chosen, _) => Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.blackCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.goldBorder),
        ),
        child: PopupMenuButton<PrayerMethod>(
          onSelected: PrayerSettings.setMethod,
          color: AppColors.blackSurface,
          position: PopupMenuPosition.under,
          itemBuilder: (context) => [
            for (final method in PrayerMethod.values)
              PopupMenuItem(
                value: method,
                child: Row(
                  children: [
                    Icon(
                      method == chosen
                          ? Icons.radio_button_checked
                          : Icons.radio_button_unchecked,
                      size: 17,
                      color: method == chosen
                          ? AppColors.gold
                          : AppColors.textMuted,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(method.label,
                              style: const TextStyle(
                                  color: AppColors.textPrimary, fontSize: 13)),
                          Text(method.where,
                              style: const TextStyle(
                                  color: AppColors.textMuted, fontSize: 10)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
          ],
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(chosen.label,
                        style: const TextStyle(
                            color: AppColors.gold, fontSize: 14)),
                    Text(chosen.where,
                        style: const TextStyle(
                            color: AppColors.textMuted, fontSize: 11)),
                  ],
                ),
              ),
              const Icon(Icons.keyboard_arrow_down,
                  color: AppColors.gold, size: 22),
            ],
          ),
        ),
      ),
    );
  }

  /// The two rules for Asr are about forty minutes apart in summer.
  Widget _asrSchool() {
    return ValueListenableBuilder<AsrSchool>(
      valueListenable: PrayerSettings.school,
      builder: (context, chosen, _) => Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.blackCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.goldBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Padding(
              padding: EdgeInsets.only(right: 2, bottom: 8),
              child: Text('وقت العصر',
                  style:
                      TextStyle(color: AppColors.textSecondary, fontSize: 13)),
            ),
            Row(
              children: [
                for (final school in AsrSchool.values)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: GestureDetector(
                        onTap: () => PrayerSettings.setSchool(school),
                        behavior: HitTestBehavior.opaque,
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: school == chosen
                                ? AppColors.goldMuted
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color: school == chosen
                                    ? AppColors.gold
                                    : AppColors.goldBorder),
                          ),
                          child: Column(
                            children: [
                              Text(school.label,
                                  style: TextStyle(
                                      color: school == chosen
                                          ? AppColors.gold
                                          : AppColors.textMuted,
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold)),
                              Text(school.note,
                                  style: const TextStyle(
                                      color: AppColors.textMuted,
                                      fontSize: 10)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// One switch that strips every sound and leaves the notifications.
  ///
  /// First thing in settings because it is what a reader reaches for in a
  /// meeting or a mosque, and hunting through ten rows to silence them one by
  /// one is not something anyone does twice.
  Widget _muteAll() {
    return ValueListenableBuilder<Map<String, AlertMode>>(
      valueListenable: PrayerAlerts.settings,
      builder: (context, _, _) {
        final loud = PrayerAlerts.anySound;
        return Container(
          margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: loud ? AppColors.goldMuted : AppColors.blackCard,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: loud ? AppColors.gold : AppColors.goldBorder),
          ),
          child: Row(
            children: [
              Icon(loud ? Icons.volume_up : Icons.notifications_off,
                  color: AppColors.gold, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('إشعارات بالصوت',
                        style: TextStyle(
                            color: AppColors.textPrimary, fontSize: 14)),
                    Text(
                      loud
                          ? 'بعض التنبيهات تصدر صوتاً'
                          : 'كل التنبيهات صامتة الآن',
                      style: const TextStyle(
                          color: AppColors.textMuted, fontSize: 11),
                    ),
                  ],
                ),
              ),
              Switch(
                value: loud,
                onChanged: (soundOn) => soundOn
                    ? PrayerAlerts.restoreSound()
                    : PrayerAlerts.muteEverything(),
                activeThumbColor: AppColors.gold,
              ),
            ],
          ),
        );
      },
    );
  }

  /// A short dhikr through the day.
  ///
  /// Not one dhikr repeated: the same words at the same hour become furniture
  /// within a week, and a reminder nobody reads is worse than none. The app
  /// rotates the short adhkar so each arrival says something.
  Widget _dhikrReminder() {
    return ValueListenableBuilder<bool>(
      valueListenable: DhikrReminder.enabled,
      builder: (context, on, _) => Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.blackCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.goldBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('ذكر على شاشتك',
                          style: TextStyle(
                              color: AppColors.textPrimary, fontSize: 14)),
                      Text(
                        on
                            ? 'يصلك خلال اليوم، ويتبدّل في كل مرة'
                            : 'مغلق',
                        style: const TextStyle(
                            color: AppColors.textMuted, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: on,
                  onChanged: (v) => DhikrReminder.apply(on: v),
                  activeThumbColor: AppColors.gold,
                ),
              ],
            ),
            if (on) ...[
              const Divider(color: AppColors.goldBorder, height: 20),
              const Text('متى يصلك',
                  style:
                      TextStyle(color: AppColors.textSecondary, fontSize: 12)),
              const SizedBox(height: 6),
              ValueListenableBuilder<DhikrRhythm>(
                valueListenable: DhikrReminder.rhythm,
                builder: (context, beat, _) => Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        for (final choice in DhikrRhythm.values)
                          Expanded(
                            child: Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 3),
                              child: _pill(
                                label: choice.label,
                                on: choice == beat,
                                onTap: () =>
                                    DhikrReminder.apply(beat: choice),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(beat.note,
                        style: const TextStyle(
                            color: AppColors.textMuted, fontSize: 10)),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              ValueListenableBuilder<DhikrRhythm>(
                valueListenable: DhikrReminder.rhythm,
                builder: (context, beat, _) =>
                    beat == DhikrRhythm.beforePrayer
                        ? _dhikrLead()
                        : _dhikrCount(),
              ),
              const SizedBox(height: 8),
              _whenTheyArrive(),
              const SizedBox(height: 10),
              const Text('نوع الذكر',
                  style:
                      TextStyle(color: AppColors.textSecondary, fontSize: 12)),
              const SizedBox(height: 6),
              _dhikrFlavour(),
            ],
          ],
        ),
      ),
    );
  }

  /// One choice in a strip: the same shape for the count, the lead and the
  /// rhythm, so the card reads as one control rather than three.
  Widget _pill({
    required String label,
    required bool on,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: on ? AppColors.goldMuted : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border:
              Border.all(color: on ? AppColors.gold : AppColors.goldBorder),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: on ? AppColors.gold : AppColors.textMuted,
            fontSize: 12,
            fontWeight: on ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  /// How long before the adhan the dhikr arrives — five reminders a day, one
  /// per prayer, so the count strip has nothing to say here.
  Widget _dhikrLead() {
    return ValueListenableBuilder<int>(
      valueListenable: DhikrReminder.lead,
      builder: (context, lead, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('قبل الأذان بـ',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
          const SizedBox(height: 6),
          Row(
            children: [
              for (final choice in DhikrReminder.leadChoices)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: _pill(
                      label: '${QuranService.toArabicDigits(choice)} د',
                      on: choice == lead,
                      onTap: () =>
                          DhikrReminder.apply(minutesBefore: choice),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  /// The hours the reminders will actually land on.
  ///
  /// A count and a window are two numbers whose result nobody can hold in
  /// their head — twelve between three and four is one every five minutes,
  /// all before dawn, which reads on the phone as no reminders at all. The
  /// times are worked out here anyway; showing them costs nothing and makes
  /// that impossible to set by accident.
  Widget _whenTheyArrive() {
    final slots = DhikrReminder.slotMinutes();
    if (slots.isEmpty) {
      return const Text('لا يصلك شيء بهذه الإعدادات',
          style: TextStyle(color: AppColors.error, fontSize: 11));
    }

    String clock(int m) {
      final h = m ~/ 60;
      final hour = h % 12 == 0 ? 12 : h % 12;
      return '${QuranService.toArabicDigits(hour)}:'
          '${QuranService.toArabicDigits(m % 60).padLeft(2, '٠')}'
          '${h >= 12 ? 'م' : 'ص'}';
    }

    final crowded = DhikrReminder.isCrowded;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'يصلك: ${slots.map(clock).join(' · ')}',
          style: const TextStyle(
              color: AppColors.textMuted, fontSize: 10.5, height: 1.7),
        ),
        if (crowded) ...[
          const SizedBox(height: 3),
          Text(
            'بينها ${QuranService.toArabicDigits(DhikrReminder.spacing)} دقائق '
            'فقط — وسّع الساعات أو أنقص العدد.',
            style: const TextStyle(color: AppColors.error, fontSize: 10.5),
          ),
        ],
      ],
    );
  }

  Widget _dhikrCount() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('كم مرة في اليوم',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
        const SizedBox(height: 6),
        ValueListenableBuilder<int>(
          valueListenable: DhikrReminder.perDay,
          builder: (context, count, _) => Row(
            children: [
              for (final choice in DhikrReminder.countChoices)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: _pill(
                      label: QuranService.toArabicDigits(choice),
                      on: choice == count,
                      onTap: () => DhikrReminder.apply(count: choice),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        // Nobody wants a buzz at three in the morning.
        Row(
          children: [
            const Text('بين الساعة',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
            const SizedBox(width: 8),
            _hourPicker(
                DhikrReminder.fromHour, (h) => DhikrReminder.apply(from: h)),
            const SizedBox(width: 8),
            const Text('و',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
            const SizedBox(width: 8),
            _hourPicker(
                DhikrReminder.toHour, (h) => DhikrReminder.apply(to: h)),
          ],
        ),
      ],
    );
  }

  Widget _dhikrFlavour() {
    return ValueListenableBuilder<DhikrFlavour>(
      valueListenable: DhikrReminder.flavour,
      builder: (context, kind, _) => Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          for (final flavour in DhikrFlavour.values)
            GestureDetector(
              onTap: () => DhikrReminder.apply(kind: flavour),
              behavior: HitTestBehavior.opaque,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: flavour == kind
                      ? AppColors.goldMuted
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: flavour == kind
                          ? AppColors.gold
                          : AppColors.goldBorder),
                ),
                child: Text(
                  flavour.label,
                  style: TextStyle(
                    color:
                        flavour == kind ? AppColors.gold : AppColors.textMuted,
                    fontSize: 11.5,
                    fontWeight:
                        flavour == kind ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _hourPicker(ValueNotifier<int> hour, ValueChanged<int> onPick) {
    return ValueListenableBuilder<int>(
      valueListenable: hour,
      builder: (context, value, _) => PopupMenuButton<int>(
        onSelected: onPick,
        color: AppColors.blackSurface,
        position: PopupMenuPosition.under,
        itemBuilder: (context) => [
          for (var h = 0; h < 24; h++)
            PopupMenuItem(
              value: h,
              child: Text('${QuranService.toArabicDigits(h)}:٠٠',
                  style: const TextStyle(
                      color: AppColors.textPrimary, fontSize: 13)),
            ),
        ],
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: AppColors.goldMuted,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.goldBorder),
          ),
          child: Text('${QuranService.toArabicDigits(value)}:٠٠',
              style: const TextStyle(color: AppColors.gold, fontSize: 13)),
        ),
      ),
    );
  }

  /// A verse with its place, twice a day.
  Widget _verseReminder() {
    return ValueListenableBuilder<bool>(
      valueListenable: DailyReminders.verseOn,
      builder: (context, on, _) => _card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _switchRow(
              title: 'آية وتفسيرها على شاشتك',
              subtitle: on ? 'مرتين في اليوم' : 'مغلق',
              value: on,
              onChanged: (v) => DailyReminders.setVerse(on: v),
            ),
            if (on) ...[
              const Divider(color: AppColors.goldBorder, height: 20),
              Row(
                children: [
                  const Text('الأولى',
                      style: TextStyle(
                          color: AppColors.textSecondary, fontSize: 12)),
                  const SizedBox(width: 8),
                  _timePicker(DailyReminders.verseFirst, 0, 24 * 60 - 1,
                      (t) => DailyReminders.setVerse(first: t)),
                  const Spacer(),
                  const Text('الثانية',
                      style: TextStyle(
                          color: AppColors.textSecondary, fontSize: 12)),
                  const SizedBox(width: 8),
                  _timePicker(DailyReminders.verseSecond, 0, 24 * 60 - 1,
                      (t) => DailyReminders.setVerse(second: t)),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Morning or evening adhkar, each held inside the hours they belong to.
  Widget _adhkarWindow({
    required String title,
    required String note,
    required ValueNotifier<bool> on,
    required ValueNotifier<DayTime> at,
    required ({int earliest, int latest}) window,
    required void Function(bool?, DayTime?) apply,
  }) {
    return ValueListenableBuilder<bool>(
      valueListenable: on,
      builder: (context, enabled, _) => _card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _switchRow(
              title: title,
              subtitle: enabled ? note : 'مغلق',
              value: enabled,
              onChanged: (v) => apply(v, null),
            ),
            if (enabled) ...[
              const Divider(color: AppColors.goldBorder, height: 20),
              Row(
                children: [
                  const Text('الوقت',
                      style: TextStyle(
                          color: AppColors.textSecondary, fontSize: 12)),
                  const SizedBox(width: 10),
                  _timePicker(at, window.earliest, window.latest,
                      (t) => apply(null, t)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(note,
                        style: const TextStyle(
                            color: AppColors.textMuted, fontSize: 10)),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _card({required Widget child}) => Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.blackCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.goldBorder),
        ),
        child: child,
      );

  Widget _switchRow({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: const TextStyle(
                      color: AppColors.textPrimary, fontSize: 14)),
              Text(subtitle,
                  style: const TextStyle(
                      color: AppColors.textMuted, fontSize: 11)),
            ],
          ),
        ),
        Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: AppColors.gold),
      ],
    );
  }

  /// Offers only the half-hours inside [earliest, latest] — a picker that
  /// cannot express a time the adhkar are not said at.
  Widget _timePicker(ValueNotifier<DayTime> notifier, int earliest, int latest,
      ValueChanged<DayTime> onPick) {
    return ValueListenableBuilder<DayTime>(
      valueListenable: notifier,
      builder: (context, value, _) => PopupMenuButton<int>(
        onSelected: (m) => onPick(DayTime(m)),
        color: AppColors.blackSurface,
        position: PopupMenuPosition.under,
        itemBuilder: (context) => [
          for (var m = earliest; m <= latest; m += 30)
            PopupMenuItem(
              value: m,
              child: Text(DayTime(m).label,
                  style: const TextStyle(
                      color: AppColors.textPrimary, fontSize: 13)),
            ),
        ],
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: AppColors.goldMuted,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.goldBorder),
          ),
          child: Text(value.label,
              style: const TextStyle(color: AppColors.gold, fontSize: 13)),
        ),
      ),
    );
  }

  /// Opens the grid where each prayer's two alerts are set.
  Widget _alertsRow() {
    return ValueListenableBuilder<Map<String, AlertMode>>(
      valueListenable: PrayerAlerts.settings,
      builder: (context, _, _) {
        final on = AlertPrayer.values
            .expand((p) => AlertWhen.values.map((w) => PrayerAlerts.modeFor(p, w)))
            .where((m) => m != AlertMode.off)
            .length;

        return GestureDetector(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const PrayerAlertsScreen()),
          ),
          behavior: HitTestBehavior.opaque,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            decoration: BoxDecoration(
              color: AppColors.blackCard,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.goldBorder),
            ),
            child: Row(
              children: [
                const Icon(Icons.notifications_active,
                    color: AppColors.gold, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('تنبيهات أوقات الصلاة',
                          style: TextStyle(
                              color: AppColors.textPrimary, fontSize: 14)),
                      Text(
                        on == 0
                            ? 'لا تنبيه مفعّل'
                            : 'مفعّل لـ ${QuranService.toArabicDigits(on)} من عشرة',
                        style: const TextStyle(
                            color: AppColors.textMuted, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_left,
                    color: AppColors.textMuted, size: 20),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Text(title,
          style: const TextStyle(color: AppColors.textGold, fontSize: 16, fontWeight: FontWeight.bold)),
    );
  }

  Widget _fontBtn(String label, String key) {
    final isActive = _fontSize == key;
    return Expanded(
      child: GestureDetector(
        onTap: () => _setFontSize(key),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isActive ? AppColors.goldMuted : AppColors.blackCard,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isActive ? AppColors.gold : AppColors.goldBorder),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isActive ? AppColors.gold : AppColors.textMuted,
              fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }
}
