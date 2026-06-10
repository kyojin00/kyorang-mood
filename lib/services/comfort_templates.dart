import 'dart:math';

import '../models/comfort_models.dart';

/// 교랑무드 · 익명 위로 풀에서 "남에게 건네는" 추천 위로 문구 세트.
///
/// 무디(마스코트)가 사용자 본인에게 건네는 suggestion_service 와 달리,
/// 이 문구들은 익명의 한 사람이 또 다른 익명의 한 사람에게 보내는 말이다.
/// - 이름/호칭을 모르므로 "~님" 같은 호칭은 쓰지 않는다.
/// - 따뜻하고 부담 없는 해요체. 가르치거나 평가하지 않는다.
/// - 한 카드에 담길 한두 문장 분량으로 짧게.
///
/// 위로 건네기 화면은 [자유 입력칸 + 추천 문구 칩]이 공존한다.
/// 이 문구들은 "빠른 추천"으로, pickFor()로 대상의 기분/세부 태그에 맞는
/// 후보를 뽑아 칩으로 보여준다. 사용자는 칩을 그대로 보내거나, 직접 써서 보낸다.
/// 선택/입력된 문구는 send_comfort_reply RPC 로 넘어가 받는 사람에게 박제된다.

/// 위로 문구 한 개. id 는 추적용, content 는 실제 전송/박제 문구.
/// 자유 입력으로 보낸 경우 id 는 'custom' 을 쓴다(서비스 계층에서 처리).
class ComfortTemplate {
  final String id;
  final String content;

  const ComfortTemplate(this.id, this.content);
}

class ComfortTemplates {
  ComfortTemplates._();

  static final Random _random = Random();

  /// 기분 구간 판별.
  /// low: 1~2 / mid: 3 / high: 4~5
  static String _band(int level) {
    if (level <= 2) return 'low';
    if (level == 3) return 'mid';
    return 'high';
  }

  // ── 기분 구간별 공통 문구 (태그와 무관하게 늘 쓸 수 있는 위로) ──
  static const Map<String, List<ComfortTemplate>> _byBand = {
    'low': [
      ComfortTemplate('low_c1', '오늘 하루 버텨낸 것만으로 충분해요. 정말 수고 많았어요.'),
      ComfortTemplate('low_c2', '지금 그 마음, 충분히 그럴 수 있어요. 이상한 게 아니에요.'),
      ComfortTemplate('low_c3', '괜찮지 않아도 괜찮아요. 그 마음 그대로 둬도 돼요.'),
      ComfortTemplate('low_c4', '어딘가에서 같은 밤을 보내는 사람이 응원을 보내요. 혼자가 아니에요.'),
      ComfortTemplate('low_c5', '많이 힘들었죠. 그 마음 알아주는 사람이 여기 있어요.'),
      ComfortTemplate('low_c6', '오늘은 그냥 흘려보내도 돼요. 내일의 당신에게 맡겨봐요.'),
    ],
    'mid': [
      ComfortTemplate('mid_c1', '그냥 그런 날도 있죠. 그래도 오늘 하루 잘 지나가고 있어요.'),
      ComfortTemplate('mid_c2', '특별하지 않아도 괜찮아요. 무사히 흘러가는 하루를 응원해요.'),
      ComfortTemplate('mid_c3', '잔잔한 하루 속, 작은 다정함이 함께하길 바라요.'),
      ComfortTemplate('mid_c4', '평범한 하루를 보내는 당신에게도 작은 응원을 보내요.'),
    ],
    'high': [
      ComfortTemplate('high_c1', '좋은 기분이 느껴져요. 그 마음 오래 간직하길 바라요.'),
      ComfortTemplate('high_c2', '오늘의 그 웃음, 내일도 이어지길 응원해요.'),
      ComfortTemplate('high_c3', '밝은 하루를 보내고 있군요. 그 기분 그대로 흘러가길 바라요.'),
    ],
  };

  // ── 세부 태그별 맞춤 문구 ──
  static const Map<ComfortTag, List<ComfortTemplate>> _byTag = {
    // 일 · 진로
    ComfortTag.workCareer: [
      ComfortTemplate('workCareer_1', '길이 안 보여도, 멈춰 선 지금이 잘못된 건 아니에요.'),
      ComfortTemplate('workCareer_2', '방향을 고민하는 그 마음이 이미 앞으로 가고 있다는 증거예요.'),
    ],
    ComfortTag.workPressure: [
      ComfortTemplate('workPressure_1', '그동안 정말 애썼어요. 결과보다, 버텨온 당신이 더 대단해요.'),
      ComfortTemplate('workPressure_2', '버거운 게 당연해요. 잠시 어깨의 힘을 빼도 괜찮아요.'),
    ],
    ComfortTag.workRecognition: [
      ComfortTemplate('workRecog_1', '알아주는 사람이 없어도, 당신의 노력은 사라지지 않아요.'),
      ComfortTemplate('workRecog_2', '잘 해내고 싶은 마음이 컸던 거잖아요. 그 마음이 이미 멋져요.'),
    ],
    // 관계
    ComfortTag.relFamily: [
      ComfortTemplate('relFamily_1', '가까운 사이일수록 더 아프죠. 당신 마음이 먼저예요.'),
      ComfortTemplate('relFamily_2', '가족이라는 이름이 다 짊어질 이유는 되지 않아요.'),
    ],
    ComfortTag.relPartner: [
      ComfortTemplate('relPartner_1', '마음을 많이 쏟았던 만큼 아픈 거예요. 그건 당신이 따뜻한 사람이라서예요.'),
      ComfortTemplate('relPartner_2', '사랑하는 일은 늘 어렵죠. 오늘은 당신을 먼저 아껴줘요.'),
    ],
    ComfortTag.relFriend: [
      ComfortTemplate('relFriend_1', '친구 사이의 일로 마음이 복잡하죠. 그 마음 충분히 이해돼요.'),
      ComfortTemplate('relFriend_2', '멀어지는 게 꼭 당신 탓은 아니에요. 너무 자책하지 말아요.'),
    ],
    ComfortTag.relWork: [
      ComfortTemplate('relWork_1', '매일 봐야 하는 사이라 더 지치죠. 오늘 하루 잘 버텼어요.'),
      ComfortTemplate('relWork_2', '일터의 관계까지 다 안고 가지 않아도 돼요.'),
    ],
    // 불안 · 걱정
    ComfortTag.anxFuture: [
      ComfortTemplate('anxFuture_1', '아직 오지 않은 일까지 짊어지지 않아도 돼요. 지금 이 순간은 괜찮아요.'),
      ComfortTemplate('anxFuture_2', '내일은 내일의 당신이 맡아줄 거예요. 지금은 좀 쉬어요.'),
    ],
    ComfortTag.anxVague: [
      ComfortTemplate('anxVague_1', '이유를 몰라도 불안할 수 있어요. 그 마음 틀린 게 아니에요.'),
      ComfortTemplate('anxVague_2', '걱정이 많다는 건 그만큼 소중한 게 많다는 뜻이에요.'),
    ],
    ComfortTag.anxHealth: [
      ComfortTemplate('anxHealth_1', '몸도 마음도 무거운 날이군요. 오늘은 당신을 살뜰히 챙겨요.'),
      ComfortTemplate('anxHealth_2', '걱정되는 마음 곁에, 응원하는 마음도 함께 둘게요.'),
    ],
    // 지침 · 번아웃
    ComfortTag.fatBody: [
      ComfortTemplate('fatBody_1', '몸이 보내는 신호예요. 잠시 멈추는 것도 용기예요.'),
      ComfortTemplate('fatBody_2', '지칠 만큼 열심히 달려온 거예요. 충분히 쉬어도 돼요.'),
    ],
    ComfortTag.fatMind: [
      ComfortTemplate('fatMind_1', '마음이 지치는 건 그동안 많이 애썼다는 뜻이에요.'),
      ComfortTemplate('fatMind_2', '아무것도 안 하는 시간도 당신에겐 꼭 필요해요.'),
    ],
    ComfortTag.fatMotivation: [
      ComfortTemplate('fatMot_1', '의욕이 없는 날도 있어요. 그런 당신을 다그치지 말아요.'),
      ComfortTemplate('fatMot_2', '오늘은 아무것도 안 해도 괜찮아요. 그저 흘려보내요.'),
    ],
    // 외로움
    ComfortTag.loneAlone: [
      ComfortTemplate('loneAlone_1', '혼자인 것 같은 밤, 이 한마디가 곁에 닿길 바라요.'),
      ComfortTemplate('loneAlone_2', '지금 누군가 당신을 떠올리며 응원을 보내고 있어요.'),
    ],
    ComfortTag.loneUnderstood: [
      ComfortTemplate('loneUnder_1', '아무도 몰라주는 것 같아 서러운 마음, 제가 조금은 알 것 같아요.'),
      ComfortTemplate('loneUnder_2', '말로 다 못 할 마음, 가만히 알아주는 사람이 있어요.'),
    ],
    // 슬픔 · 우울
    ComfortTag.sadReason: [
      ComfortTemplate('sadReason_1', '슬퍼할 이유가 있다면, 충분히 슬퍼해도 괜찮아요.'),
      ComfortTemplate('sadReason_2', '그 마음 억누르지 않아도 돼요. 흘러가게 두어도 괜찮아요.'),
    ],
    ComfortTag.sadVague: [
      ComfortTemplate('sadVague_1', '이유 없이 가라앉는 날도 있죠. 그런 날의 당신도 응원해요.'),
      ComfortTemplate('sadVague_2', '이 우울이 영원하지 않다는 걸, 지나봐서 알아요.'),
    ],
    ComfortTag.sadLoss: [
      ComfortTemplate('sadLoss_1', '무언가를 잃은 마음에, 조용히 곁을 둘게요.'),
      ComfortTemplate('sadLoss_2', '그 자리가 비어 아픈 거예요. 그만큼 소중했다는 뜻이겠죠.'),
    ],
    // 그냥, 그런 날
    ComfortTag.etcJust: [
      ComfortTemplate('etcJust_1', '그냥 그런 날, 그런 마음이 드는 것도 자연스러워요.'),
      ComfortTemplate('etcJust_2', '특별한 이유가 없어도 괜찮아요. 오늘의 당신을 응원해요.'),
    ],
    ComfortTag.etcNoWords: [
      ComfortTemplate('etcNoWords_1', '말로 다 못 할 마음이 있죠. 그 마음 그대로도 괜찮아요.'),
      ComfortTemplate('etcNoWords_2', '설명하지 않아도 돼요. 그냥 곁에 응원을 둘게요.'),
    ],
  };

  /// 위로 보낼 대상의 기분/세부 태그에 맞는 추천 문구 후보를 골라 반환한다.
  ///
  /// - 세부 태그가 있으면 태그 맞춤 문구를 최대 2개 우선 포함(맥락 보장)
  /// - 나머지는 기분 구간 공통 문구로 채움
  /// - 그래도 부족하면 전체 풀에서 보충(폴백)
  /// 반환 순서는 매번 무작위로 섞인다.
  static List<ComfortTemplate> pickFor({
    required int moodLevel,
    ComfortTag? tag,
    int count = 4,
  }) {
    final band = _band(moodLevel);
    final result = <ComfortTemplate>[];
    final seen = <String>{};

    void take(List<ComfortTemplate> from, int max) {
      if (max <= 0) return;
      final copy = List<ComfortTemplate>.from(from)..shuffle(_random);
      var taken = 0;
      for (final t in copy) {
        if (result.length >= count || taken >= max) break;
        if (seen.add(t.id)) {
          result.add(t);
          taken++;
        }
      }
    }

    // 1) 세부 태그 맞춤 문구 우선 (최대 2개)
    if (tag != null) {
      take(_byTag[tag] ?? const [], 2);
    }
    // 2) 기분 구간 공통 문구로 나머지 채움
    take(_byBand[band] ?? const [], count - result.length);
    // 3) 부족하면 전체 풀에서 폴백
    if (result.length < count) {
      final all = <ComfortTemplate>[
        ..._byBand.values.expand((e) => e),
        ..._byTag.values.expand((e) => e),
      ];
      take(all, count - result.length);
    }
    return result;
  }

  /// id 로 문구를 찾는다(없으면 null). 디버그/검증용.
  static ComfortTemplate? byId(String id) {
    for (final list in _byBand.values) {
      for (final t in list) {
        if (t.id == id) return t;
      }
    }
    for (final list in _byTag.values) {
      for (final t in list) {
        if (t.id == id) return t;
      }
    }
    return null;
  }
}