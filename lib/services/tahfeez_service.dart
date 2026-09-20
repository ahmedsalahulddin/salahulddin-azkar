import 'dart:async';
import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../l10n/strings.dart';
import 'auth_service.dart';

/// A raised server-side rule, carried by the short code the SQL uses
/// ('max_sessions_per_day', 'no_such_code', …) so screens can word it.
class TahfeezException implements Exception {
  final String code;
  const TahfeezException(this.code);

  @override
  String toString() => 'TahfeezException($code)';
}

enum TahfeezRole { student, teacher }

enum PlanPeriod { week, month }

enum Gender { male, female }

enum TeachesGender { male, female, both }

/// The languages a teacher may list, in the order the picker shows them.
const tahfeezLanguages = <(String code, String name)>[
  ('ar', 'العربية'),
  ('en', 'English'),
  ('fr', 'Français'),
  ('ur', 'اردو'),
  ('id', 'Indonesia'),
  ('ms', 'Bahasa Melayu'),
  ('hi', 'हिन्दी'),
  ('tr', 'Türkçe'),
  ('bn', 'বাংলা'),
  ('ha', 'Hausa'),
];

String languageName(String code) {
  for (final (c, n) in tahfeezLanguages) {
    if (c == code) return n;
  }
  return code;
}

class TahfeezProfile {
  final String userId;
  final String displayName;
  final String? photoUrl;
  final TahfeezRole role;
  final String? teacherCode;
  final String? bio;
  final String? city;
  final PlanPeriod planPeriod;
  final int freeSessions;
  final String? priceNote;
  final List<String> languages;
  final TeachesGender teachesGender;
  final Gender? gender;
  final bool blocked;
  final bool listed;

  /// ISO country code, chosen from [tahfeezCountries]; null if not set.
  final String? country;
  final bool teachesChildren;

  const TahfeezProfile({
    required this.userId,
    required this.displayName,
    this.photoUrl,
    required this.role,
    this.teacherCode,
    this.bio,
    this.city,
    this.planPeriod = PlanPeriod.month,
    this.freeSessions = 0,
    this.priceNote,
    this.languages = const [],
    this.teachesGender = TeachesGender.both,
    this.gender,
    this.blocked = false,
    this.listed = true,
    this.country,
    this.teachesChildren = false,
  });

  bool get isTeacher => role == TahfeezRole.teacher;

  /// Whether a student of [g] (null = undeclared) may ask this teacher.
  bool accepts(Gender? g) =>
      teachesGender == TeachesGender.both ||
      (g != null && g.name == teachesGender.name);

  TahfeezProfile copyWith({
    String? displayName,
    Gender? gender,
    String? country,
  }) => TahfeezProfile(
    userId: userId,
    displayName: displayName ?? this.displayName,
    photoUrl: photoUrl,
    role: role,
    teacherCode: teacherCode,
    bio: bio,
    city: city,
    planPeriod: planPeriod,
    freeSessions: freeSessions,
    priceNote: priceNote,
    languages: languages,
    teachesGender: teachesGender,
    gender: gender ?? this.gender,
    blocked: blocked,
    listed: listed,
    country: country ?? this.country,
    teachesChildren: teachesChildren,
  );

  factory TahfeezProfile.fromJson(Map<String, dynamic> j) => TahfeezProfile(
    userId: j['user_id'] as String,
    displayName: j['display_name'] as String,
    photoUrl: j['photo_url'] as String?,
    role: j['role'] == 'teacher' ? TahfeezRole.teacher : TahfeezRole.student,
    teacherCode: j['teacher_code'] as String?,
    bio: j['bio'] as String?,
    city: j['city'] as String?,
    planPeriod: j['plan_period'] == 'week' ? PlanPeriod.week : PlanPeriod.month,
    freeSessions: (j['free_sessions'] as int?) ?? 0,
    priceNote: j['price_note'] as String?,
    languages: ((j['languages'] as List?) ?? const []).cast<String>(),
    teachesGender: TeachesGender.values.firstWhere(
      (g) => g.name == j['teaches_gender'],
      orElse: () => TeachesGender.both,
    ),
    gender: j['gender'] == null
        ? null
        : Gender.values.firstWhere(
            (g) => g.name == j['gender'],
            orElse: () => Gender.male,
          ),
    blocked: j['blocked'] == true,
    listed: j['listed'] != false,
    country: j['country'] as String?,
    teachesChildren: j['teaches_children'] == true,
  );
}

class TahfeezMessage {
  final String id;
  final String enrollmentId;
  final String senderId;
  final String body;
  final DateTime createdAt;
  final DateTime? reportedAt;
  final String? reportReason;
  final TahfeezProfile? sender;

  const TahfeezMessage({
    required this.id,
    required this.enrollmentId,
    required this.senderId,
    required this.body,
    required this.createdAt,
    this.reportedAt,
    this.reportReason,
    this.sender,
  });

  TahfeezMessage withSender(TahfeezProfile? p) => TahfeezMessage(
    id: id,
    enrollmentId: enrollmentId,
    senderId: senderId,
    body: body,
    createdAt: createdAt,
    reportedAt: reportedAt,
    reportReason: reportReason,
    sender: p,
  );

  factory TahfeezMessage.fromJson(Map<String, dynamic> j) => TahfeezMessage(
    id: j['id'] as String,
    enrollmentId: j['enrollment_id'] as String,
    senderId: j['sender_id'] as String,
    body: j['body'] as String,
    createdAt: DateTime.parse(j['created_at'] as String).toLocal(),
    reportedAt: j['reported_at'] == null
        ? null
        : DateTime.parse(j['reported_at'] as String).toLocal(),
    reportReason: j['report_reason'] as String?,
  );
}

enum EnrollmentStatus { pending, active, rejected }

/// One student's term with one teacher.
class Enrollment {
  final String id;
  final String teacherId;
  final String studentId;
  final EnrollmentStatus status;
  final PlanPeriod? period;
  final DateTime? startsAt;
  final DateTime? endsAt;
  final int freeSessionsLeft;
  final bool paid;
  final String? note;
  final DateTime createdAt;
  final TahfeezProfile? teacher;
  final TahfeezProfile? student;

  const Enrollment({
    required this.id,
    required this.teacherId,
    required this.studentId,
    required this.status,
    this.period,
    this.startsAt,
    this.endsAt,
    required this.freeSessionsLeft,
    required this.paid,
    this.note,
    required this.createdAt,
    this.teacher,
    this.student,
  });

  bool get isPending => status == EnrollmentStatus.pending;

  /// Days until the term ends; negative once it has.
  int get daysLeft {
    final end = endsAt;
    if (end == null) return 0;
    final today = DateTime.now();
    return end.difference(DateTime(today.year, today.month, today.day)).inDays;
  }

  bool get isExpired => status == EnrollmentStatus.active && daysLeft < 0;
  bool get isActive => status == EnrollmentStatus.active && daysLeft >= 0;
  bool get endsSoon => isActive && daysLeft <= 3;

  Enrollment withProfiles({TahfeezProfile? teacher, TahfeezProfile? student}) =>
      Enrollment(
        id: id,
        teacherId: teacherId,
        studentId: studentId,
        status: status,
        period: period,
        startsAt: startsAt,
        endsAt: endsAt,
        freeSessionsLeft: freeSessionsLeft,
        paid: paid,
        note: note,
        createdAt: createdAt,
        teacher: teacher ?? this.teacher,
        student: student ?? this.student,
      );

  factory Enrollment.fromJson(Map<String, dynamic> j) => Enrollment(
    id: j['id'] as String,
    teacherId: j['teacher_id'] as String,
    studentId: j['student_id'] as String,
    status: EnrollmentStatus.values.firstWhere(
      (s) => s.name == j['status'],
      orElse: () => EnrollmentStatus.pending,
    ),
    period: j['period'] == null
        ? null
        : (j['period'] == 'week' ? PlanPeriod.week : PlanPeriod.month),
    startsAt: j['starts_at'] == null
        ? null
        : DateTime.parse(j['starts_at'] as String),
    endsAt: j['ends_at'] == null
        ? null
        : DateTime.parse(j['ends_at'] as String),
    freeSessionsLeft: (j['free_sessions_left'] as int?) ?? 0,
    paid: j['paid'] == true,
    note: j['note'] as String?,
    createdAt: DateTime.parse(j['created_at'] as String),
  );
}

class TeacherRequest {
  final String id;
  final String userId;
  final String? note;
  final DateTime createdAt;
  final TahfeezProfile? profile;

  const TeacherRequest({
    required this.id,
    required this.userId,
    this.note,
    required this.createdAt,
    this.profile,
  });
}

class Halaqa {
  final String id;
  final String teacherId;
  final String name;
  final String inviteCode;

  const Halaqa({
    required this.id,
    required this.teacherId,
    required this.name,
    required this.inviteCode,
  });

  factory Halaqa.fromJson(Map<String, dynamic> j) => Halaqa(
    id: j['id'] as String,
    teacherId: j['teacher_id'] as String,
    name: j['name'] as String,
    inviteCode: j['invite_code'] as String,
  );
}

class HalaqaMember {
  final String halaqaId;
  final String studentId;
  final DateTime joinedAt;
  final TahfeezProfile? profile;

  const HalaqaMember({
    required this.halaqaId,
    required this.studentId,
    required this.joinedAt,
    this.profile,
  });

  String get name => profile?.displayName ?? t('tahfeez.student');
}

/// One weekly slot. [weekday] follows Postgres: 0 = Sunday … 6 = Saturday.
class TahfeezSession {
  final String id;
  final String halaqaId;
  final int weekday;
  final TimeOfDay start;
  final TimeOfDay end;

  const TahfeezSession({
    required this.id,
    required this.halaqaId,
    required this.weekday,
    required this.start,
    required this.end,
  });

  factory TahfeezSession.fromJson(Map<String, dynamic> j) => TahfeezSession(
    id: j['id'] as String,
    halaqaId: j['halaqa_id'] as String,
    weekday: j['weekday'] as int,
    start: _parseTime(j['start_time'] as String),
    end: _parseTime(j['end_time'] as String),
  );

  static TimeOfDay _parseTime(String s) {
    final parts = s.split(':');
    return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
  }

  static String encodeTime(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}:00';
}

enum EvalGrade { excellent, veryGood, good, redo }

/// What a student was assessed on for one of the three points.
class EvalPoint {
  final int fromSurah;
  final int fromAyah;
  final int toSurah;
  final int toAyah;
  final EvalGrade grade;
  final String? note;

  const EvalPoint({
    required this.fromSurah,
    required this.fromAyah,
    required this.toSurah,
    required this.toAyah,
    required this.grade,
    this.note,
  });

  Map<String, dynamic> toJson() => {
    'from_surah': fromSurah,
    'from_ayah': fromAyah,
    'to_surah': toSurah,
    'to_ayah': toAyah,
    'grade': grade.name,
    if (note != null && note!.isNotEmpty) 'note': note,
  };

  factory EvalPoint.fromJson(Map<String, dynamic> j) => EvalPoint(
    fromSurah: j['from_surah'] as int,
    fromAyah: j['from_ayah'] as int,
    toSurah: j['to_surah'] as int,
    toAyah: j['to_ayah'] as int,
    grade: EvalGrade.values.firstWhere(
      (g) => g.name == j['grade'],
      orElse: () => EvalGrade.good,
    ),
    note: j['note'] as String?,
  );
}

class Evaluation {
  final String? id;
  final String sessionId;
  final String studentId;
  final DateTime date;
  final EvalPoint? review;
  final EvalPoint? newHifz;
  final EvalPoint? tafsir;

  const Evaluation({
    this.id,
    required this.sessionId,
    required this.studentId,
    required this.date,
    this.review,
    this.newHifz,
    this.tafsir,
  });

  int get pointCount =>
      (review == null ? 0 : 1) +
      (newHifz == null ? 0 : 1) +
      (tafsir == null ? 0 : 1);

  factory Evaluation.fromJson(Map<String, dynamic> j) => Evaluation(
    id: j['id'] as String,
    sessionId: j['session_id'] as String,
    studentId: j['student_id'] as String,
    date: DateTime.parse(j['on_date'] as String),
    review: _point(j['review']),
    newHifz: _point(j['new_hifz']),
    tafsir: _point(j['tafsir']),
  );

  static EvalPoint? _point(Object? raw) =>
      raw == null ? null : EvalPoint.fromJson(raw as Map<String, dynamic>);

  static String encodeDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

/// One saved run of the Memory Test drill (lib/screens/memorisation_test_screen.dart).
/// Self-administered and self-graded — unlike [Evaluation], nothing here was
/// judged by a teacher — but once saved it is readable by any teacher
/// [tahfeez_related] to the student, alongside their evaluations.
class MemtestResult {
  final String? id;
  final String studentId;
  final int surahNumber;
  final String surahName;

  /// The drill mode's name (TestMode.name) — kept as a string here so this
  /// model does not have to import lib/data/memorisation.dart.
  final String mode;
  final int questionCount;
  final int correctCount;
  final int scorePercent;
  final DateTime createdAt;

  const MemtestResult({
    this.id,
    required this.studentId,
    required this.surahNumber,
    required this.surahName,
    required this.mode,
    required this.questionCount,
    required this.correctCount,
    required this.scorePercent,
    required this.createdAt,
  });

  factory MemtestResult.fromJson(Map<String, dynamic> j) => MemtestResult(
    id: j['id'] as String,
    studentId: j['student_id'] as String,
    surahNumber: j['surah_number'] as int,
    surahName: j['surah_name'] as String,
    mode: j['mode'] as String,
    questionCount: j['question_count'] as int,
    correctCount: j['correct_count'] as int,
    scorePercent: j['score_percent'] as int,
    createdAt: DateTime.parse(j['created_at'] as String),
  );
}

/// All server traffic for the memorisation module. Every call assumes a
/// signed-in reader; the tab does not reach these before sign-in.
class TahfeezService {
  static const maxSessionsPerDay = 8;

  static Future<SupabaseClient> get _client async {
    await AuthService.init();
    return Supabase.instance.client;
  }

  static String get _uid => AuthService.user.value!.id;

  static Never _throw(Object e) {
    if (e is PostgrestException) {
      final msg = e.message;
      for (final code in const [
        'max_sessions_per_day',
        'not_teacher',
        'not_admin',
        'not_pending',
        'no_such_code',
        'own_halaqa',
        'already_teacher',
        'empty_name',
        'not_enrolled',
        'blocked',
        'gender_mismatch',
        'not_party',
      ]) {
        if (msg.contains(code)) throw TahfeezException(code);
      }
      throw TahfeezException(e.code ?? 'server');
    }
    throw TahfeezException('network');
  }

  // ---- profile & role -----------------------------------------------------

  /// Copies the account's current name and photo where a teacher can read
  /// them, then returns the profile with its server-held role, plus whether
  /// this call is what just created it — the caller's cue to offer naming
  /// it right away instead of defaulting silently to the Google name.
  static Future<(TahfeezProfile, bool)> ensureProfile() async {
    final user = AuthService.user.value!;
    try {
      final c = await _client;
      final result = await c.rpc(
        'upsert_tahfeez_profile',
        params: {
          'p_name': user.displayName,
          'p_photo': user.photoUrl,
          'p_device': await deviceId(),
        },
      );
      final row = await c
          .from('tahfeez_profiles')
          .select()
          .eq('user_id', user.id)
          .single();
      final created = result is Map && result['created'] == true;
      return (TahfeezProfile.fromJson(row), created);
    } catch (e) {
      _throw(e);
    }
  }

  static String? _deviceId;

  /// A stable id for this installation's device, so a block can follow the
  /// phone as well as the account. Null where the platform offers none.
  static Future<String?> deviceId() async {
    if (_deviceId != null || kIsWeb) return _deviceId;
    try {
      final info = DeviceInfoPlugin();
      if (Platform.isAndroid) {
        _deviceId = (await info.androidInfo).id;
      } else if (Platform.isIOS) {
        _deviceId = (await info.iosInfo).identifierForVendor;
      }
    } catch (_) {}
    return _deviceId;
  }

  static Future<void> setGender(Gender g) async {
    try {
      final c = await _client;
      await c.rpc('set_tahfeez_gender', params: {'p_gender': g.name});
    } catch (e) {
      _throw(e);
    }
  }

  static Future<void> setCountry(String code) async {
    try {
      final c = await _client;
      await c.rpc('set_tahfeez_country', params: {'p_country': code});
    } catch (e) {
      _throw(e);
    }
  }

  static Future<void> setDisplayName(String name) async {
    try {
      final c = await _client;
      await c.rpc('set_tahfeez_display_name', params: {'p_name': name});
    } catch (e) {
      _throw(e);
    }
  }

  static Future<bool> hasPendingRequest() async {
    try {
      final c = await _client;
      final rows = await c
          .from('tahfeez_teacher_requests')
          .select('id')
          .eq('user_id', _uid)
          .eq('status', 'pending')
          .limit(1);
      return rows.isNotEmpty;
    } catch (e) {
      _throw(e);
    }
  }

  static Future<void> requestTeacherRole(String note) async {
    try {
      final c = await _client;
      await c.rpc('request_teacher_role', params: {'p_note': note});
    } catch (e) {
      _throw(e);
    }
  }

  /// Another person's profile — visible only when the server says the two
  /// are related through a circle, otherwise null.
  static Future<TahfeezProfile?> profileOf(String userId) async {
    try {
      final c = await _client;
      final row = await c
          .from('tahfeez_profiles')
          .select()
          .eq('user_id', userId)
          .maybeSingle();
      return row == null ? null : TahfeezProfile.fromJson(row);
    } catch (e) {
      _throw(e);
    }
  }

  // ---- admin --------------------------------------------------------------

  /// How many teacher requests await the admin — zero for everyone else.
  /// Shown as a badge on the account tab, so the admin sees a new request
  /// the moment they open the app.
  static final pendingBadge = ValueNotifier<int>(0);

  /// Reported messages awaiting the admin.
  static final reportsBadge = ValueNotifier<int>(0);

  /// Both together, for the account tab's icon.
  static final adminBadge = ValueNotifier<int>(0);

  static Future<void> refreshPendingBadge() async {
    final results = await Future.wait([
      pendingRequestCount(),
      reportedMessageCount(),
    ]);
    pendingBadge.value = results[0];
    reportsBadge.value = results[1];
    adminBadge.value = results[0] + results[1];
  }

  static Future<int> reportedMessageCount() async {
    if (AuthService.user.value == null) return 0;
    try {
      final c = await _client;
      final n = await c.rpc('reported_message_count');
      return (n as int?) ?? 0;
    } catch (_) {
      return 0;
    }
  }

  /// Every reported message, newest first, with who sent it.
  static Future<List<TahfeezMessage>> reportedMessages() async {
    try {
      final c = await _client;
      final rows = await c
          .from('tahfeez_messages')
          .select()
          .not('reported_at', 'is', null)
          .order('reported_at', ascending: false);
      final list = rows.map(TahfeezMessage.fromJson).toList();
      final profiles = await _profilesOf(
        c,
        list.map((m) => m.senderId).toSet().toList(),
      );
      return [for (final m in list) m.withSender(profiles[m.senderId])];
    } catch (e) {
      _throw(e);
    }
  }

  static Future<void> blockUser(String userId, String reason) async {
    try {
      final c = await _client;
      await c.rpc('block_user', params: {'p_user': userId, 'p_reason': reason});
    } catch (e) {
      _throw(e);
    }
  }

  static Future<void> unblockUser(String userId) async {
    try {
      final c = await _client;
      await c.rpc('unblock_user', params: {'p_user': userId});
    } catch (e) {
      _throw(e);
    }
  }

  static Future<void> dismissReport(String messageId) async {
    try {
      final c = await _client;
      await c.rpc('dismiss_report', params: {'p_id': messageId});
    } catch (e) {
      _throw(e);
    }
  }

  static Future<int> pendingRequestCount() async {
    if (AuthService.user.value == null) return 0;
    try {
      final c = await _client;
      final n = await c.rpc('pending_teacher_request_count');
      return (n as int?) ?? 0;
    } catch (_) {
      return 0;
    }
  }

  static Future<List<TeacherRequest>> pendingRequests() async {
    try {
      final c = await _client;
      final rows = await c
          .from('tahfeez_teacher_requests')
          .select()
          .eq('status', 'pending')
          .order('created_at');
      final ids = rows.map((r) => r['user_id'] as String).toList();
      final profiles = await _profilesOf(c, ids);
      return rows
          .map(
            (r) => TeacherRequest(
              id: r['id'] as String,
              userId: r['user_id'] as String,
              note: r['note'] as String?,
              createdAt: DateTime.parse(r['created_at'] as String),
              profile: profiles[r['user_id']],
            ),
          )
          .toList();
    } catch (e) {
      _throw(e);
    }
  }

  static Future<void> decideRequest(String id, {required bool approve}) async {
    try {
      final c = await _client;
      await c.rpc(
        'decide_teacher_request',
        params: {'p_id': id, 'p_approve': approve},
      );
    } catch (e) {
      _throw(e);
    }
  }

  static Future<Map<String, TahfeezProfile>> _profilesOf(
    SupabaseClient c,
    List<String> ids,
  ) async {
    if (ids.isEmpty) return const {};
    final rows = await c
        .from('tahfeez_profiles')
        .select()
        .inFilter('user_id', ids);
    return {
      for (final r in rows) r['user_id'] as String: TahfeezProfile.fromJson(r),
    };
  }

  // ---- circles ------------------------------------------------------------

  /// Every circle the reader can see: the ones they teach and the ones they
  /// belong to. Row-level security decides which; the client only splits.
  static Future<List<Halaqa>> visibleHalaqat() async {
    try {
      final c = await _client;
      final rows = await c.from('tahfeez_halaqat').select().order('created_at');
      return rows.map(Halaqa.fromJson).toList();
    } catch (e) {
      _throw(e);
    }
  }

  static Future<Halaqa> createHalaqa(String name) async {
    try {
      final c = await _client;
      final row = await c.rpc('create_halaqa', params: {'p_name': name});
      return Halaqa.fromJson(row as Map<String, dynamic>);
    } catch (e) {
      _throw(e);
    }
  }

  static Future<void> renameHalaqa(String id, String name) async {
    try {
      final c = await _client;
      await c.from('tahfeez_halaqat').update({'name': name}).eq('id', id);
    } catch (e) {
      _throw(e);
    }
  }

  static Future<void> deleteHalaqa(String id) async {
    try {
      final c = await _client;
      await c.from('tahfeez_halaqat').delete().eq('id', id);
    } catch (e) {
      _throw(e);
    }
  }

  /// Returns the joined circle's name.
  static Future<String> joinHalaqa(String code) async {
    try {
      final c = await _client;
      final name = await c.rpc('join_halaqa', params: {'p_code': code});
      return name as String;
    } catch (e) {
      _throw(e);
    }
  }

  static Future<List<HalaqaMember>> members(String halaqaId) async {
    try {
      final c = await _client;
      final rows = await c
          .from('tahfeez_members')
          .select()
          .eq('halaqa_id', halaqaId)
          .order('joined_at');
      final profiles = await _profilesOf(
        c,
        rows.map((r) => r['student_id'] as String).toList(),
      );
      return rows
          .map(
            (r) => HalaqaMember(
              halaqaId: r['halaqa_id'] as String,
              studentId: r['student_id'] as String,
              joinedAt: DateTime.parse(r['joined_at'] as String),
              profile: profiles[r['student_id']],
            ),
          )
          .toList();
    } catch (e) {
      _throw(e);
    }
  }

  /// Student id -> email, for a circle the caller teaches. Restricted by the
  /// tahfeez_halaqa_emails() function itself, not just by RLS on a table —
  /// a display name alone is not enough to find one student among many.
  static Future<Map<String, String>> memberEmails(String halaqaId) async {
    try {
      final c = await _client;
      final rows = await c.rpc(
        'tahfeez_halaqa_emails',
        params: {'p_halaqa_id': halaqaId},
      );
      return {
        for (final r in rows as List)
          (r as Map<String, dynamic>)['student_id'] as String:
              r['email'] as String,
      };
    } catch (_) {
      // A teacher's students still filter by name if emails fail to load.
      return const {};
    }
  }

  static Future<void> removeMember(String halaqaId, String studentId) async {
    try {
      final c = await _client;
      await c
          .from('tahfeez_members')
          .delete()
          .eq('halaqa_id', halaqaId)
          .eq('student_id', studentId);
    } catch (e) {
      _throw(e);
    }
  }

  // ---- timetable ----------------------------------------------------------

  static Future<List<TahfeezSession>> visibleSessions() async {
    try {
      final c = await _client;
      final rows = await c
          .from('tahfeez_sessions')
          .select()
          .order('weekday')
          .order('start_time');
      return rows.map(TahfeezSession.fromJson).toList();
    } catch (e) {
      _throw(e);
    }
  }

  static Future<TahfeezSession> addSession({
    required String halaqaId,
    required int weekday,
    required TimeOfDay start,
    required TimeOfDay end,
  }) async {
    try {
      final c = await _client;
      final row = await c
          .from('tahfeez_sessions')
          .insert({
            'halaqa_id': halaqaId,
            'weekday': weekday,
            'start_time': TahfeezSession.encodeTime(start),
            'end_time': TahfeezSession.encodeTime(end),
          })
          .select()
          .single();
      return TahfeezSession.fromJson(row);
    } catch (e) {
      _throw(e);
    }
  }

  static Future<void> deleteSession(String id) async {
    try {
      final c = await _client;
      await c.from('tahfeez_sessions').delete().eq('id', id);
    } catch (e) {
      _throw(e);
    }
  }

  // ---- directory & enrolment ---------------------------------------------

  /// Every approved teacher, for the directory.
  static Future<List<TahfeezProfile>> teachers() async {
    try {
      final c = await _client;
      final rows = await c
          .from('tahfeez_profiles')
          .select()
          .eq('role', 'teacher')
          .order('display_name');
      return rows.map(TahfeezProfile.fromJson).toList();
    } catch (e) {
      _throw(e);
    }
  }

  static Future<void> updateTeacherProfile({
    required String bio,
    required String city,
    required PlanPeriod plan,
    required int freeSessions,
    required String priceNote,
    required List<String> languages,
    required TeachesGender teaches,
    required bool listed,
    required String? country,
    required bool teachesChildren,
  }) async {
    try {
      final c = await _client;
      await c.rpc(
        'update_teacher_profile',
        params: {
          'p_bio': bio,
          'p_city': city,
          'p_plan': plan.name,
          'p_free': freeSessions,
          'p_price': priceNote,
          'p_languages': languages,
          'p_teaches': teaches.name,
          'p_listed': listed,
          'p_country': country ?? '',
          'p_children': teachesChildren,
        },
      );
    } catch (e) {
      _throw(e);
    }
  }

  static Future<void> requestEnrollment(String teacherId, String note) async {
    try {
      final c = await _client;
      await c.rpc(
        'request_enrollment',
        params: {'p_teacher': teacherId, 'p_note': note},
      );
    } catch (e) {
      _throw(e);
    }
  }

  /// Returns the teacher's name.
  static Future<String> requestEnrollmentByCode(
    String code,
    String note,
  ) async {
    try {
      final c = await _client;
      final name = await c.rpc(
        'request_enrollment_by_code',
        params: {'p_code': code, 'p_note': note},
      );
      return name as String;
    } catch (e) {
      _throw(e);
    }
  }

  /// Every enrolment the reader is party to, with the other side's profile.
  static Future<List<Enrollment>> enrollments() async {
    try {
      final c = await _client;
      final rows = await c
          .from('tahfeez_enrollments')
          .select()
          .order('created_at', ascending: false);
      final list = rows.map(Enrollment.fromJson).toList();
      final ids = <String>{
        for (final e in list) ...[e.teacherId, e.studentId],
      }..remove(_uid);
      final profiles = await _profilesOf(c, ids.toList());
      return [
        for (final e in list)
          e.withProfiles(
            teacher: profiles[e.teacherId],
            student: profiles[e.studentId],
          ),
      ];
    } catch (e) {
      _throw(e);
    }
  }

  static Future<void> decideEnrollment(
    String id, {
    required bool approve,
  }) async {
    try {
      final c = await _client;
      await c.rpc(
        'decide_enrollment',
        params: {'p_id': id, 'p_approve': approve},
      );
    } catch (e) {
      _throw(e);
    }
  }

  static Future<void> renewEnrollment(String id) async {
    try {
      final c = await _client;
      await c.rpc('renew_enrollment', params: {'p_id': id});
    } catch (e) {
      _throw(e);
    }
  }

  static Future<void> setEnrollmentPaid(String id, bool paid) async {
    try {
      final c = await _client;
      await c.rpc('set_enrollment_paid', params: {'p_id': id, 'p_paid': paid});
    } catch (e) {
      _throw(e);
    }
  }

  /// One-line notices addressed to this user (a student withdrawing a
  /// pending request, for now), each returned exactly once.
  static Future<List<String>> takeNotices() async {
    if (AuthService.user.value == null) return const [];
    try {
      final c = await _client;
      final rows = await c.rpc('take_notices') as List;
      return [for (final r in rows) (r as Map)['body'] as String];
    } catch (_) {
      return const [];
    }
  }

  static Future<void> cancelEnrollment(String id) async {
    try {
      final c = await _client;
      await c.rpc('cancel_enrollment', params: {'p_id': id});
    } catch (e) {
      _throw(e);
    }
  }

  static Future<void> assignToHalaqa(String halaqaId, String studentId) async {
    try {
      final c = await _client;
      await c.rpc(
        'assign_to_halaqa',
        params: {'p_halaqa': halaqaId, 'p_student': studentId},
      );
    } catch (e) {
      _throw(e);
    }
  }

  // ---- messages -----------------------------------------------------------

  static Future<List<TahfeezMessage>> messages(String enrollmentId) async {
    try {
      final c = await _client;
      final rows = await c
          .from('tahfeez_messages')
          .select()
          .eq('enrollment_id', enrollmentId)
          .order('created_at')
          .limit(500);
      return rows.map(TahfeezMessage.fromJson).toList();
    } catch (e) {
      _throw(e);
    }
  }

  static Future<TahfeezMessage> sendMessage(
    String enrollmentId,
    String body,
  ) async {
    try {
      final c = await _client;
      final row = await c.rpc(
        'send_message',
        params: {'p_enrollment': enrollmentId, 'p_body': body},
      );
      return TahfeezMessage.fromJson(row as Map<String, dynamic>);
    } catch (e) {
      _throw(e);
    }
  }

  static Future<void> reportMessage(String id, String reason) async {
    try {
      final c = await _client;
      await c.rpc('report_message', params: {'p_id': id, 'p_reason': reason});
    } catch (e) {
      _throw(e);
    }
  }

  /// New messages in one thread as they land. Cancelling the subscription
  /// tears the channel down.
  static Stream<TahfeezMessage> messageStream(String enrollmentId) {
    late final StreamController<TahfeezMessage> controller;
    RealtimeChannel? channel;
    controller = StreamController<TahfeezMessage>(
      onListen: () async {
        final c = await _client;
        channel = c
            .channel('tahfeez_messages:$enrollmentId')
            .onPostgresChanges(
              event: PostgresChangeEvent.insert,
              schema: 'public',
              table: 'tahfeez_messages',
              filter: PostgresChangeFilter(
                type: PostgresChangeFilterType.eq,
                column: 'enrollment_id',
                value: enrollmentId,
              ),
              callback: (payload) {
                if (controller.isClosed) return;
                controller.add(TahfeezMessage.fromJson(payload.newRecord));
              },
            )
            .subscribe();
      },
      onCancel: () async {
        await channel?.unsubscribe();
      },
    );
    return controller.stream;
  }

  // ---- evaluations --------------------------------------------------------

  static Future<List<Evaluation>> evaluationsFor({
    required String sessionId,
    required DateTime date,
  }) async {
    try {
      final c = await _client;
      final rows = await c
          .from('tahfeez_evaluations')
          .select()
          .eq('session_id', sessionId)
          .eq('on_date', Evaluation.encodeDate(date));
      return rows.map(Evaluation.fromJson).toList();
    } catch (e) {
      _throw(e);
    }
  }

  /// Newest first. A student passes their own id; a teacher any of theirs.
  static Future<List<Evaluation>> evaluationsOf(String studentId) async {
    try {
      final c = await _client;
      final rows = await c
          .from('tahfeez_evaluations')
          .select()
          .eq('student_id', studentId)
          .order('on_date', ascending: false)
          .limit(200);
      return rows.map(Evaluation.fromJson).toList();
    } catch (e) {
      _throw(e);
    }
  }

  static Future<void> saveEvaluation(Evaluation e) async {
    try {
      final c = await _client;
      await c.from('tahfeez_evaluations').upsert({
        'session_id': e.sessionId,
        'student_id': e.studentId,
        'on_date': Evaluation.encodeDate(e.date),
        'review': e.review?.toJson(),
        'new_hifz': e.newHifz?.toJson(),
        'tafsir': e.tafsir?.toJson(),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }, onConflict: 'session_id,student_id,on_date');
    } catch (err) {
      _throw(err);
    }
  }

  static Future<void> saveMemtestResult({
    required int surahNumber,
    required String surahName,
    required String mode,
    required int questionCount,
    required int correctCount,
    required int scorePercent,
  }) async {
    try {
      final c = await _client;
      final uid = c.auth.currentUser!.id;
      await c.from('tahfeez_memtest_results').insert({
        'student_id': uid,
        'surah_number': surahNumber,
        'surah_name': surahName,
        'mode': mode,
        'question_count': questionCount,
        'correct_count': correctCount,
        'score_percent': scorePercent,
      });
    } catch (e) {
      _throw(e);
    }
  }

  /// Newest first. A student passes their own id; a related teacher any of
  /// theirs — see the RLS policy in supabase/tahfeez_memtest.sql.
  static Future<List<MemtestResult>> memtestResultsOf(String studentId) async {
    try {
      final c = await _client;
      final rows = await c
          .from('tahfeez_memtest_results')
          .select()
          .eq('student_id', studentId)
          .order('created_at', ascending: false)
          .limit(200);
      return rows.map(MemtestResult.fromJson).toList();
    } catch (e) {
      _throw(e);
    }
  }
}
