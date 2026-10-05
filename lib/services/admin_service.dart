import 'package:supabase_flutter/supabase_flutter.dart';

import 'auth_service.dart';

/// One account on the admin list.
class AppAdmin {
  final String userId;
  final String email;
  final DateTime addedAt;

  const AppAdmin({
    required this.userId,
    required this.email,
    required this.addedAt,
  });

  factory AppAdmin.fromRow(Map<String, dynamic> row) => AppAdmin(
    userId: row['user_id'] as String,
    email: row['email'] as String? ?? '',
    addedAt: DateTime.parse(row['added_at'] as String),
  );
}

/// What adding an admin by email came to.
enum AddAdminResult { added, noAccount, failed }

/// Who may run the admin screens, managed from the app itself. Backed by
/// admin_list / admin_add / admin_remove (supabase/app_admins_manage.sql),
/// each of which refuses anyone who is not already an admin.
class AdminService {
  AdminService._();

  static Future<SupabaseClient> get _client async {
    await AuthService.init();
    return Supabase.instance.client;
  }

  static String? get currentUserId => AuthService.user.value?.id;

  /// Null when the list could not be read.
  static Future<List<AppAdmin>?> list() async {
    try {
      final rows = await (await _client).rpc('admin_list') as List;
      return [
        for (final r in rows) AppAdmin.fromRow(r as Map<String, dynamic>),
      ];
    } catch (_) {
      return null;
    }
  }

  static Future<AddAdminResult> add(String email) async {
    try {
      final ok = await (await _client).rpc(
        'admin_add',
        params: {'target_email': email.trim()},
      );
      return ok == true ? AddAdminResult.added : AddAdminResult.noAccount;
    } catch (_) {
      return AddAdminResult.failed;
    }
  }

  static Future<bool> remove(String userId) async {
    try {
      await (await _client).rpc('admin_remove', params: {'target': userId});
      return true;
    } catch (_) {
      return false;
    }
  }
}
