/// 상담 대화의 메시지 한 개.
///
/// role은 'user'(사용자) 또는 'assistant'(마스코트).
/// API로 보낼 때와 화면에 표시할 때 모두 사용한다.
class ChatMessage {
  final String role;
  final String content;

  const ChatMessage({required this.role, required this.content});

  /// 사용자 메시지
  factory ChatMessage.user(String content) =>
      ChatMessage(role: 'user', content: content);

  /// 마스코트(assistant) 메시지
  factory ChatMessage.assistant(String content) =>
      ChatMessage(role: 'assistant', content: content);

  bool get isUser => role == 'user';

  /// Edge Function으로 보낼 형태
  Map<String, String> toApiJson() => {'role': role, 'content': content};
}