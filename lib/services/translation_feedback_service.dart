import 'package:supabase_flutter/supabase_flutter.dart';

import 'app_locale.dart';
import 'auth_service.dart';

/// A note a reader left after switching the app's language — what they
/// wrote, which language they were on, and whether the admin has read it.
class TranslationFeedback {
  final int id;
  final String appLang;
  final String message;
  final bool isRead;
  final DateTime createdAt;

  const TranslationFeedback({
    required this.id,
    required this.appLang,
    required this.message,
    required this.isRead,
    required this.createdAt,
  });

  factory TranslationFeedback.fromRow(Map<String, dynamic> row) =>
      TranslationFeedback(
        id: row['id'] as int,
        appLang: row['app_lang'] as String,
        message: row['message'] as String,
        isRead: row['is_read'] as bool? ?? false,
        createdAt: DateTime.parse(row['created_at'] as String),
      );
}

/// The note a reader can leave the admin from the language-switch dialog,
/// and the admin's own inbox for reading them.
class TranslationFeedbackService {
  static Future<SupabaseClient> get _client async {
    await AuthService.init();
    return Supabase.instance.client;
  }

  /// Anyone can send one — signed in or a guest.
  static Future<bool> submit(String message) async {
    final trimmed = message.trim();
    if (trimmed.isEmpty) return false;
    try {
      final c = await _client;
      await c.from('translation_feedback').insert({
        'app_lang': AppLocale.code,
        'message': trimmed,
        if (c.auth.currentUser != null) 'user_id': c.auth.currentUser!.id,
      });
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Admin-only — the read policy on translation_feedback rejects anyone
  /// else.
  static Future<List<TranslationFeedback>> list() async {
    try {
      final c = await _client;
      final rows = await c
          .from('translation_feedback')
          .select()
          .order('created_at', ascending: false);
      return (rows as List)
          .map((r) => TranslationFeedback.fromRow(r as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  static Future<void> markRead(int id) async {
    try {
      final c = await _client;
      await c
          .from('translation_feedback')
          .update({'is_read': true})
          .eq('id', id);
    } catch (_) {
      // Not fatal — the admin can still read the message either way.
    }
  }

  static Future<void> delete(int id) async {
    try {
      final c = await _client;
      await c.from('translation_feedback').delete().eq('id', id);
    } catch (_) {
      // Nothing to show for a failed delete — the row just stays.
    }
  }
}
