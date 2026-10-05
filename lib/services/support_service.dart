import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app_locale.dart';
import 'auth_service.dart';

/// What a request is about — chosen by the reader when they write, and
/// shown to the admin as a label.
enum SupportCategory {
  edit,
  teacher,
  problem,
  suggestion,
  translation,
  contact,
  other,
}

SupportCategory _category(String? name) => SupportCategory.values.firstWhere(
  (c) => c.name == name,
  orElse: () => SupportCategory.other,
);

/// One conversation between a reader and the admins.
@immutable
class SupportThread {
  final String id;
  final String? userId;
  final SupportCategory category;
  final bool resolved;
  final bool starred;

  /// Unread for whoever is looking: the reader in "My messages", the admins
  /// in the inbox.
  final bool unread;
  final DateTime createdAt;
  final DateTime lastMessageAt;

  /// Admin inbox only.
  final String? email;
  final String? name;
  final String? lastBody;
  final int messageCount;

  const SupportThread({
    required this.id,
    this.userId,
    required this.category,
    required this.resolved,
    this.starred = false,
    this.unread = false,
    required this.createdAt,
    required this.lastMessageAt,
    this.email,
    this.name,
    this.lastBody,
    this.messageCount = 0,
  });

  SupportThread copyWith({bool? resolved, bool? starred, bool? unread}) =>
      SupportThread(
        id: id,
        userId: userId,
        category: category,
        resolved: resolved ?? this.resolved,
        starred: starred ?? this.starred,
        unread: unread ?? this.unread,
        createdAt: createdAt,
        lastMessageAt: lastMessageAt,
        email: email,
        name: name,
        lastBody: lastBody,
        messageCount: messageCount,
      );

  factory SupportThread.fromRow(
    Map<String, dynamic> r, {
    required bool admin,
  }) => SupportThread(
    id: r['id'] as String,
    userId: r['user_id'] as String?,
    category: _category(r['category'] as String?),
    resolved: r['status'] == 'resolved',
    starred: r['starred'] == true,
    unread: admin ? r['admin_unread'] == true : r['user_unread'] == true,
    createdAt: DateTime.parse(r['created_at'] as String),
    lastMessageAt: DateTime.parse(r['last_message_at'] as String),
    email: r['email'] as String?,
    name: r['name'] as String?,
    lastBody: r['last_body'] as String?,
    messageCount: (r['message_count'] as num?)?.toInt() ?? 0,
  );
}

@immutable
class SupportMessage {
  final int id;
  final bool fromAdmin;
  final String body;
  final DateTime createdAt;

  const SupportMessage({
    required this.id,
    required this.fromAdmin,
    required this.body,
    required this.createdAt,
  });

  factory SupportMessage.fromRow(Map<String, dynamic> r) => SupportMessage(
    id: (r['id'] as num).toInt(),
    fromAdmin: r['from_admin'] == true,
    body: r['body'] as String,
    createdAt: DateTime.parse(r['created_at'] as String),
  );
}

/// Requests and replies between readers and the admins
/// (supabase/support_messages.sql).
class SupportService {
  SupportService._();

  static Future<SupabaseClient> get _client async {
    await AuthService.init();
    return Supabase.instance.client;
  }

  /// Unread replies waiting for the reader, for the badge in Account.
  static final myUnread = ValueNotifier<int>(0);

  /// Open requests and unread ones waiting for the admins.
  static final adminOpen = ValueNotifier<int>(0);

  /// Starts a request. Anyone may write, signed in or not. Returns the new
  /// thread's id, or null if it did not go through.
  static Future<String?> open(SupportCategory category, String body) async {
    final text = body.trim();
    if (text.isEmpty) return null;
    try {
      final id = await (await _client).rpc(
        'support_open',
        params: {
          'p_category': category.name,
          'p_body': text,
          'p_lang': AppLocale.code,
        },
      );
      return id as String?;
    } catch (_) {
      return null;
    }
  }

  /// The reader's own requests, newest activity first.
  static Future<List<SupportThread>?> myThreads() async {
    final uid = AuthService.user.value?.id;
    if (uid == null) return const [];
    try {
      final rows = await (await _client)
          .from('support_threads')
          .select()
          .eq('user_id', uid)
          .order('last_message_at', ascending: false);
      final list = [
        for (final r in rows) SupportThread.fromRow(r, admin: false),
      ];
      myUnread.value = list.where((t) => t.unread).length;
      return list;
    } catch (_) {
      return null;
    }
  }

  /// Every request, for the admins.
  static Future<List<SupportThread>?> allThreads() async {
    try {
      final rows = await (await _client).rpc('support_admin_threads') as List;
      final list = [
        for (final r in rows)
          SupportThread.fromRow(
            Map<String, dynamic>.from(r as Map),
            admin: true,
          ),
      ];
      adminOpen.value = list.where((t) => !t.resolved).length;
      return list;
    } catch (_) {
      return null;
    }
  }

  static Future<List<SupportMessage>?> messages(String threadId) async {
    try {
      final rows = await (await _client)
          .from('support_messages')
          .select()
          .eq('thread_id', threadId)
          .order('created_at');
      return [for (final r in rows) SupportMessage.fromRow(r)];
    } catch (_) {
      return null;
    }
  }

  static Future<bool> reply(String threadId, String body) =>
      _call('support_reply', {'p_thread': threadId, 'p_body': body.trim()});

  static Future<bool> setResolved(String threadId, bool resolved) => _call(
    'support_set_status',
    {'p_thread': threadId, 'p_resolved': resolved},
  );

  static Future<bool> setStarred(String threadId, bool starred) => _call(
    'support_set_starred',
    {'p_thread': threadId, 'p_starred': starred},
  );

  static Future<bool> markRead(String threadId) =>
      _call('support_mark_read', {'p_thread': threadId});

  /// Refreshes the reader's badge quietly, e.g. when Account opens.
  static Future<void> refreshMyUnread() async {
    await myThreads();
  }

  static Future<bool> _call(String fn, Map<String, dynamic> params) async {
    try {
      await (await _client).rpc(fn, params: params);
      return true;
    } catch (_) {
      return false;
    }
  }
}
