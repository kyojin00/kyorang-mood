import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/chat_message.dart';

/// 상담 서비스.
///
/// 대화 기록을 Supabase Edge Function('mood-chat')으로 보내고
/// 마스코트(GPT-4o)의 답변을 받아온다.
/// OpenAI 키는 서버(함수)에만 있으므로 앱에는 노출되지 않는다.
class ChatService {
  ChatService._();
  static final ChatService instance = ChatService._();

  static const String _functionName = 'mood-chat';

  /// 대화 기록을 보내고 마스코트의 답변 문자열을 반환한다.
  /// 실패 시 예외를 던지므로 호출 측에서 try-catch로 처리한다.
  Future<String> send(List<ChatMessage> messages) async {
    final client = Supabase.instance.client;

    final res = await client.functions.invoke(
      _functionName,
      body: {
        'messages': messages.map((m) => m.toApiJson()).toList(),
      },
    );

    final data = res.data;
    if (data is Map && data['reply'] is String) {
      final reply = (data['reply'] as String).trim();
      if (reply.isNotEmpty) return reply;
    }
    if (data is Map && data['error'] is String) {
      throw Exception(data['error'] as String);
    }
    throw Exception('답변을 받지 못했어요.');
  }
}