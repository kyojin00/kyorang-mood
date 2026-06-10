import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/chat_message.dart';

/// 무디와의 대화 세션 종류.
///
/// 시간대에 따라 무디의 톤이 달라진다.
enum SessionKind {
  /// 아침 — 하루를 같이 시작
  morning,

  /// 밤 — 하루를 같이 마무리
  night,

  /// 그 외 시간 — 가볍게 들어줌
  free,
}

extension SessionKindX on SessionKind {
  String get apiValue {
    switch (this) {
      case SessionKind.morning:
        return 'morning';
      case SessionKind.night:
        return 'night';
      case SessionKind.free:
        return 'free';
    }
  }
}

/// 일일 호출 한도 초과 시 던지는 예외.
class ChatLimitReachedException implements Exception {
  final String message;
  final int limit;
  final int used;

  ChatLimitReachedException({
    required this.message,
    required this.limit,
    required this.used,
  });
}

/// 무디와의 대화를 보내고 받아오는 서비스.
class ChatService {
  ChatService._();
  static final ChatService instance = ChatService._();

  static const String _functionName = 'mood-chat';

  /// 현재 시간대에 맞는 세션을 반환한다.
  /// - 05:00 ~ 11:59 → morning
  /// - 20:00 ~ 04:59 → night
  /// - 그 외 (낮)    → free
  SessionKind currentSession({DateTime? now}) {
    final t = now ?? DateTime.now();
    final h = t.hour;
    if (h >= 5 && h < 12) return SessionKind.morning;
    if (h >= 20 || h < 5) return SessionKind.night;
    return SessionKind.free;
  }

  /// 현재 사용자 기준 "오늘" 날짜 (YYYY-MM-DD).
  /// 자정 이후 새벽은 그 전날의 밤으로 묶기 위해 05:00을 경계로 한다.
  String currentLocalDate({DateTime? now}) {
    final t = now ?? DateTime.now();
    // 새벽 0~5시는 전날의 밤으로 본다
    final adjusted = t.hour < 5 ? t.subtract(const Duration(days: 1)) : t;
    final y = adjusted.year.toString().padLeft(4, '0');
    final m = adjusted.month.toString().padLeft(2, '0');
    final d = adjusted.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  /// 한 줄 보내고 무디의 답 받기.
  ///
  /// session과 localDate를 명시 안 하면 현재 시간 기준으로 자동 결정한다.
  Future<String> send(
    String content, {
    SessionKind? session,
    String? localDate,
  }) async {
    final client = Supabase.instance.client;
    final s = session ?? currentSession();
    final d = localDate ?? currentLocalDate();

    final res = await client.functions.invoke(
      _functionName,
      body: {
        'content': content,
        'session_kind': s.apiValue,
        'local_date': d,
      },
    );

    final data = res.data;

    // 한도 초과
    if (data is Map && data['error'] == 'limit_reached') {
      throw ChatLimitReachedException(
        message: (data['message'] as String?) ??
            '오늘은 충분히 이야기했어요. 내일 다시 만나요.',
        limit: (data['limit'] as int?) ?? 30,
        used: (data['used'] as int?) ?? 0,
      );
    }

    if (data is Map && data['reply'] is String) {
      final reply = (data['reply'] as String).trim();
      if (reply.isNotEmpty) return reply;
    }
    if (data is Map && data['error'] is String) {
      throw Exception(data['error'] as String);
    }
    throw Exception('답변을 받지 못했어요.');
  }

  /// DB에서 사용자의 최근 대화를 가져온다 (오래된 → 최근 순).
  /// 화면이 켜졌을 때 무디의 첫 인사를 결정하거나, 이전 흐름을 보여줄 때 쓴다.
  Future<List<ChatMessage>> recentMessages({int limit = 20}) async {
    final client = Supabase.instance.client;
    final userId = client.auth.currentUser?.id;
    if (userId == null) return [];

    final rows = await client
        .from('daily_conversation')
        .select('role, content, created_at')
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .limit(limit);

    final list = (rows as List)
        .map((r) => ChatMessage(
              role: r['role'] as String,
              content: r['content'] as String,
            ))
        .toList()
        .reversed
        .toList(); // 오래된 → 최근

    return list;
  }

  /// 특정 날짜(local_date)의 모든 대화를 시간순으로 가져온다.
  /// 어제 페이지·그저께 페이지 등을 채울 때 쓴다.
  Future<List<ChatMessage>> messagesOfDate(String localDate) async {
    final client = Supabase.instance.client;
    final userId = client.auth.currentUser?.id;
    if (userId == null) return [];

    final rows = await client
        .from('daily_conversation')
        .select('role, content, created_at')
        .eq('user_id', userId)
        .eq('local_date', localDate)
        .order('created_at', ascending: true);

    return (rows as List)
        .map((r) => ChatMessage(
              role: r['role'] as String,
              content: r['content'] as String,
            ))
        .toList();
  }

  /// 오늘 기준 N일치의 local_date 목록을 만든다 (오래된 → 오늘 순).
  /// 예: daysAgo=7이면 7일 전 ~ 오늘까지 8개 (또는 7개로 조정 가능).
  List<String> recentDates({int daysAgo = 6, DateTime? now}) {
    final t = now ?? DateTime.now();
    // currentLocalDate와 같은 로직 (새벽 0~5시는 전날로 보정)
    final base = t.hour < 5 ? t.subtract(const Duration(days: 1)) : t;
    final today = DateTime(base.year, base.month, base.day);
    return List.generate(daysAgo + 1, (i) {
      final d = today.subtract(Duration(days: daysAgo - i));
      final y = d.year.toString().padLeft(4, '0');
      final m = d.month.toString().padLeft(2, '0');
      final day = d.day.toString().padLeft(2, '0');
      return '$y-$m-$day';
    });
  }
}