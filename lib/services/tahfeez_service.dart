import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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

class TahfeezProfile {
  final String userId;
  final String displayName;
  final String? photoUrl;
  final TahfeezRole role;

  const TahfeezProfile({
    required this.userId,
    required this.displayName,
    this.photoUrl,
    required this.role,
  });

  bool get isTeacher => role == TahfeezRole.teacher;

  factory TahfeezProfile.fromJson(Map<String, dynamic> j) => TahfeezProfile(
    userId: j['user_id'] as String,
    displayName: j['display_name'] as String,
    photoUrl: j['photo_url'] as String?,
    role: j['role'] == 'teacher' ? TahfeezRole.teacher : TahfeezRole.student,
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

  String get name => profile?.displayName ?? 'طالب';
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
      ]) {
        if (msg.contains(code)) throw TahfeezException(code);
      }
      throw TahfeezException(e.code ?? 'server');
    }
    throw TahfeezException('network');
  }

  // ---- profile & role -----------------------------------------------------

  /// Copies the account's current name and photo where a teacher can read
  /// them, then returns the profile with its server-held role.
  static Future<TahfeezProfile> ensureProfile() async {
    final user = AuthService.user.value!;
    try {
      final c = await _client;
      await c.rpc(
        'upsert_tahfeez_profile',
        params: {'p_name': user.displayName, 'p_photo': user.photoUrl},
      );
      final row = await c
          .from('tahfeez_profiles')
          .select()
          .eq('user_id', user.id)
          .single();
      return TahfeezProfile.fromJson(row);
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

  static Future<void> refreshPendingBadge() async {
    pendingBadge.value = await pendingRequestCount();
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
}
