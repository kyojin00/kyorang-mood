import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/chat_message.dart';
import '../services/chat_service.dart';

/// 상담 대화 상태.
class ChatState {
  final List<ChatMessage> messages;
  final bool waiting; // 마스코트 답변 대기 중
  final String? error;

  const ChatState({
    this.messages = const [],
    this.waiting = false,
    this.error,
  });

  ChatState copyWith({
    List<ChatMessage>? messages,
    bool? waiting,
    String? error,
    bool clearError = false,
  }) {
    return ChatState(
      messages: messages ?? this.messages,
      waiting: waiting ?? this.waiting,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

final chatProvider =
    NotifierProvider<ChatNotifier, ChatState>(ChatNotifier.new);

class ChatNotifier extends Notifier<ChatState> {
  @override
  ChatState build() {
    // 첫 인사 메시지로 시작
    return const ChatState(
      messages: [
        ChatMessage(
          role: 'assistant',
          content: '안녕하세요, 저는 무디예요. 오늘 마음은 어때요? 편하게 이야기해도 괜찮아요.',
        ),
      ],
    );
  }

  /// 사용자 메시지를 보내고 마스코트 답변을 받아온다.
  Future<void> send(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || state.waiting) return;

    final userMsg = ChatMessage.user(trimmed);
    final updated = [...state.messages, userMsg];
    state = state.copyWith(messages: updated, waiting: true, clearError: true);

    try {
      final reply = await ChatService.instance.send(updated);
      state = state.copyWith(
        messages: [...state.messages, ChatMessage.assistant(reply)],
        waiting: false,
      );
    } catch (e) {
      state = state.copyWith(
        waiting: false,
        error: '잠시 후 다시 이야기해줄래요?',
      );
    }
  }

  /// 대화 초기화 (다시 시작)
  void reset() {
    state = build();
  }
}