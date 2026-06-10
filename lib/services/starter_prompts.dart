import 'dart:math';

import 'chat_service.dart';

/// 사용자가 빈 종이 앞에서 멈추지 않게, 무디가 던지는 시작점 풀.
///
/// - 각 시간대마다 8개의 한 줄 풀이 있고, 매번 그중 3개를 무작위로 뽑는다.
/// - 답이 아니라 "시작점"이다. 사용자가 누르면 입력란에 채워지고 이어 쓸 수 있다.
/// - 무디의 친구 같은 비서 톤을 유지한다.
class StarterPrompts {
  static const Map<SessionKind, List<String>> _pool = {
    SessionKind.morning: [
      '잘 잔 것 같아',
      '아직 몸이 무거워',
      '오늘은 좀 떨려',
      '마음이 가벼운 하루야',
      '뭔가 한참 생각이 많아',
      '평소랑 비슷한 아침이야',
      '오늘은 좀 미루고 싶어',
      '괜찮은 하루가 될 것 같아',
    ],
    SessionKind.night: [
      '오늘 좋았어',
      '그냥 그런 하루였어',
      '좀 지친 하루였어',
      '뭔가 답답해',
      '의외로 괜찮았어',
      '잠이 잘 안 올 것 같아',
      '오늘 한 가지 잘한 게 있어',
      '내일이 좀 걱정돼',
    ],
    SessionKind.free: [
      '잠깐 쉬고 있어',
      '뭐 하지 싶어',
      '마음이 좀 복잡해',
      '괜찮은 하루야',
      '집중이 잘 안 돼',
      '뭔가 허전해',
      '갑자기 생각나서 왔어',
      '여유가 좀 있는 시간',
    ],
  };

  /// 해당 세션의 풀에서 [count]개를 무작위로 뽑아 돌려준다.
  /// 같은 호출에서 중복은 없다.
  static List<String> pickFor(SessionKind session, {int count = 3}) {
    final pool = _pool[session] ?? _pool[SessionKind.free]!;
    final n = count.clamp(1, pool.length);
    final shuffled = [...pool]..shuffle(Random());
    return shuffled.take(n).toList();
  }
}