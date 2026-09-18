import 'package:flutter/material.dart';

import '../../constants/theme.dart';
import '../../l10n/strings.dart';
import '../../services/tahfeez_service.dart';
import 'tahfeez_widgets.dart';

/// Every approved teacher, with a way to ask any of them — or to type a
/// teacher's code straight in.
class TeachersDirectoryScreen extends StatefulWidget {
  /// The reader's current enrolments, keyed by teacher id, so a teacher
  /// already asked shows their status instead of the button.
  final Map<String, Enrollment> enrollments;

  const TeachersDirectoryScreen({super.key, required this.enrollments});

  @override
  State<TeachersDirectoryScreen> createState() =>
      _TeachersDirectoryScreenState();
}

class _TeachersDirectoryScreenState extends State<TeachersDirectoryScreen> {
  List<TahfeezProfile> _teachers = const [];
  late final Map<String, Enrollment> _enrollments = Map.of(widget.enrollments);
  bool _loading = true;
  bool _changed = false;
  String _query = '';
  final _codeController = TextEditingController();
  bool _joining = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final list = await TahfeezService.teachers();
      if (!mounted) return;
      setState(() {
        _teachers = list;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      showNote(context, describeError(e), error: true);
    }
  }

  List<TahfeezProfile> get _visible {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return _teachers;
    return _teachers.where((p) {
      return p.displayName.toLowerCase().contains(q) ||
          (p.city?.toLowerCase().contains(q) ?? false) ||
          (p.teacherCode?.toLowerCase().contains(q) ?? false);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.pop(context, _changed);
      },
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          backgroundColor: AppColors.black,
          appBar: AppBar(
            backgroundColor: AppColors.black,
            foregroundColor: AppColors.gold,
            title: Text(t('tahfeez.directory')),
          ),
          body: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: TextField(
                  onChanged: (v) => setState(() => _query = v),
                  style: const TextStyle(color: AppColors.textPrimary),
                  decoration: InputDecoration(
                    hintText: t('tahfeez.searchTeachers'),
                    hintStyle: const TextStyle(color: AppColors.textMuted),
                    prefixIcon: const Icon(
                      Icons.search,
                      color: AppColors.textMuted,
                    ),
                    isDense: true,
                    filled: true,
                    fillColor: AppColors.blackCard,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.goldBorder),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.goldBorder),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: _loading
                    ? const Center(
                        child: CircularProgressIndicator(color: AppColors.gold),
                      )
                    : ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          if (_visible.isEmpty)
                            EmptyNote(
                              icon: Icons.person_search,
                              text: t('tahfeez.noTeachers'),
                            )
                          else
                            for (final p in _visible) ...[
                              _teacherCard(p),
                              const SizedBox(height: 10),
                            ],
                          const SizedBox(height: 10),
                          _codeCard(),
                          const SizedBox(height: 30),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _teacherCard(TahfeezProfile p) {
    final photo = p.photoUrl;
    final e = _enrollments[p.userId];
    return TahfeezCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: AppColors.goldMuted,
                backgroundImage: photo != null ? NetworkImage(photo) : null,
                child: photo == null
                    ? const Icon(Icons.person, color: AppColors.gold)
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      p.displayName,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (p.city != null)
                      Text(
                        p.city!,
                        style: const TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
              ),
              if (p.teacherCode != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.goldMuted,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    p.teacherCode!,
                    textDirection: TextDirection.ltr,
                    style: const TextStyle(
                      color: AppColors.gold,
                      fontSize: 13,
                      letterSpacing: 2,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          if (p.bio != null) ...[
            const SizedBox(height: 10),
            Text(
              p.bio!,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
                height: 1.6,
              ),
            ),
          ],
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _chip(Icons.event_repeat, t('tahfeez.plan.${p.planPeriod.name}')),
              if (p.freeSessions > 0)
                _chip(
                  Icons.card_giftcard,
                  '${p.freeSessions} ${t('tahfeez.freeSessions')}',
                ),
              if (p.priceNote != null)
                _chip(Icons.payments_outlined, p.priceNote!),
            ],
          ),
          const SizedBox(height: 12),
          if (e == null)
            GoldButton(
              label: t('tahfeez.requestJoin'),
              icon: Icons.person_add_alt_1,
              onPressed: () => _request(p),
            )
          else
            Row(
              children: [
                Icon(
                  e.isPending
                      ? Icons.hourglass_top
                      : e.isActive
                      ? Icons.check_circle
                      : Icons.info_outline,
                  size: 16,
                  color: e.isActive ? AppColors.success : AppColors.goldLight,
                ),
                const SizedBox(width: 6),
                Text(
                  t(
                    'tahfeez.status.${e.isExpired ? 'expired' : e.status.name}',
                  ),
                  style: TextStyle(
                    color: e.isActive ? AppColors.success : AppColors.goldLight,
                    fontSize: 13,
                  ),
                ),
                if (e.status == EnrollmentStatus.rejected) ...[
                  const Spacer(),
                  TextButton(
                    onPressed: () => _request(p),
                    child: Text(
                      t('tahfeez.requestJoin'),
                      style: const TextStyle(color: AppColors.gold),
                    ),
                  ),
                ],
              ],
            ),
        ],
      ),
    );
  }

  Widget _chip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.blackSurface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.goldBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: AppColors.gold),
          const SizedBox(width: 4),
          Text(
            text,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _request(TahfeezProfile p) async {
    final note = await promptText(
      context,
      title: '${t('tahfeez.requestJoin')} — ${p.displayName}',
      hint: t('tahfeez.requestJoinNote'),
      confirmLabel: t('tahfeez.requestJoin'),
      maxLines: 2,
    );
    if (note == null || !mounted) return;
    try {
      await TahfeezService.requestEnrollment(p.userId, note);
      if (!mounted) return;
      showNote(context, '${t('tahfeez.requestJoinSent')} ${p.displayName}');
      _changed = true;
      // Reflect the request locally; the tab reloads the real row on return.
      setState(() {
        _enrollments[p.userId] = Enrollment(
          id: '',
          teacherId: p.userId,
          studentId: '',
          status: EnrollmentStatus.pending,
          freeSessionsLeft: 0,
          paid: false,
          createdAt: DateTime.now(),
        );
      });
    } catch (e) {
      if (mounted) showNote(context, describeError(e), error: true);
    }
  }

  Widget _codeCard() {
    return TahfeezCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            t('tahfeez.joinByCode'),
            style: const TextStyle(
              color: AppColors.textGold,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _codeController,
                  textCapitalization: TextCapitalization.characters,
                  textDirection: TextDirection.ltr,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    letterSpacing: 3,
                    fontWeight: FontWeight.bold,
                  ),
                  decoration: InputDecoration(
                    hintText: t('tahfeez.teacherCodeHint'),
                    hintStyle: const TextStyle(
                      color: AppColors.textMuted,
                      letterSpacing: 0,
                      fontWeight: FontWeight.normal,
                    ),
                    isDense: true,
                    filled: true,
                    fillColor: AppColors.blackSurface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: AppColors.goldBorder),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: AppColors.goldBorder),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _joining ? null : _joinByCode,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.gold,
                  foregroundColor: AppColors.black,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: Text(
                  t('tahfeez.requestJoin'),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _joinByCode() async {
    final code = _codeController.text.trim();
    if (code.isEmpty) return;
    setState(() => _joining = true);
    try {
      final name = await TahfeezService.requestEnrollmentByCode(code, '');
      if (!mounted) return;
      _codeController.clear();
      FocusScope.of(context).unfocus();
      showNote(context, '${t('tahfeez.requestJoinSent')} $name');
      _changed = true;
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) showNote(context, describeError(e), error: true);
    } finally {
      if (mounted) setState(() => _joining = false);
    }
  }
}
