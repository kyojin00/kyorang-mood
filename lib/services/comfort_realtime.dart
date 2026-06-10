import 'package:supabase_flutter/supabase_flutter.dart';

/// 교랑무드 · 위로 도착 실시간 구독.
///
/// 요청자 전용 broadcast 채널(comfort:{내 user_id})을 구독해,
/// send_comfort_reply RPC 가 쏜 'comfort_received' 신호를 받는다.
/// 테이블 구독이 아니라 broadcast 라 RLS 와 무관하며, payload 에 발신자
/// 정보가 없어 익명성도 유지된다.
///
/// 사용:
///   await ComfortRealtime.instance.start(onReceived: () { ... });
///   await ComfortRealtime.instance.stop();   // 로그아웃/종료 시
class ComfortRealtime {
  ComfortRealtime._();
  static final ComfortRealtime instance = ComfortRealtime._();

  RealtimeChannel? _channel;
  String? _subscribedUid;

  SupabaseClient get _sb => Supabase.instance.client;

  /// 현재 로그인한 유저의 위로 채널을 구독한다.
  /// [onReceived] 는 위로 도착 신호가 올 때마다 호출된다.
  /// payload 의 본문이 필요하면 [onContent] 로 받는다(없으면 무시).
  ///
  /// 이미 같은 유저로 구독 중이면 아무것도 하지 않는다(중복 구독 방지).
  Future<void> start({
    required void Function() onReceived,
    void Function(String content)? onContent,
  }) async {
    final uid = _sb.auth.currentUser?.id;
    if (uid == null) return; // 로그인 안 됨 → 구독 불가

    // 이미 같은 유저로 듣고 있으면 재구독하지 않음
    if (_channel != null && _subscribedUid == uid) return;

    // 다른 유저로 떠 있던 채널은 정리 후 새로 구독
    await stop();

    final topic = 'comfort:$uid';
    final channel = _sb.channel(topic);

    channel.onBroadcast(
      event: 'comfort_received',
      callback: (payload) {
        onReceived();
        final content = payload['content'];
        if (content is String && onContent != null) {
          onContent(content);
        }
      },
    );

    channel.subscribe();

    _channel = channel;
    _subscribedUid = uid;
  }

  /// 구독을 해제한다. (로그아웃 / 앱 종료 시)
  Future<void> stop() async {
    final ch = _channel;
    _channel = null;
    _subscribedUid = null;
    if (ch != null) {
      await _sb.removeChannel(ch);
    }
  }
}