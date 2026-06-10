/// 교랑무드 · 익명 위로 풀 관련 데이터 모델.
///
/// Supabase RPC 응답을 앱에서 다루기 쉬운 형태로 옮긴다.
/// - ComfortRequest  : 풀에서 꺼내온, 내가 위로를 보낼 대상 (익명)
/// - ReceivedComfort : 내 요청에 도착한, 누군가의 익명 위로
/// 두 모델 모두 sender 정보를 담지 않는다 (익명성 보장).
///
/// 맥락 태그는 2단계 구조:
///   ComfortCategory (대분류) → ComfortTag (세부)
/// 서버 tag 컬럼에는 세부 태그(ComfortTag)의 name 만 저장한다.
/// 세부 태그가 어느 대분류인지는 enum 이 알고 있으므로 컬럼은 하나면 충분하다.

/// 위로 요청 맥락의 대분류 (1단계 선택).
enum ComfortCategory {
  work,
  relationship,
  anxiety,
  fatigue,
  loneliness,
  sadness,
  etc;

  /// 화면에 보여줄 한글 라벨.
  String get label {
    switch (this) {
      case ComfortCategory.work:
        return '일 · 진로';
      case ComfortCategory.relationship:
        return '관계';
      case ComfortCategory.anxiety:
        return '불안 · 걱정';
      case ComfortCategory.fatigue:
        return '지침 · 번아웃';
      case ComfortCategory.loneliness:
        return '외로움';
      case ComfortCategory.sadness:
        return '슬픔 · 우울';
      case ComfortCategory.etc:
        return '그냥, 그런 날';
    }
  }

  /// 대분류를 누르면 보여줄 짧은 안내.
  String get hint {
    switch (this) {
      case ComfortCategory.work:
        return '일이나 진로 때문에 마음이 무거울 때';
      case ComfortCategory.relationship:
        return '사람 사이에서 마음이 힘들 때';
      case ComfortCategory.anxiety:
        return '괜히 불안하고 걱정이 많을 때';
      case ComfortCategory.fatigue:
        return '모든 게 지치고 기운이 없을 때';
      case ComfortCategory.loneliness:
        return '혼자인 것 같아 쓸쓸할 때';
      case ComfortCategory.sadness:
        return '이유 모를 슬픔이 내려앉을 때';
      case ComfortCategory.etc:
        return '딱히 이유는 모르겠는 그런 날';
    }
  }

  /// 이 대분류에 속한 세부 태그들 (정의 순서 유지).
  List<ComfortTag> get tags =>
      ComfortTag.values.where((t) => t.category == this).toList();

  /// 서버 문자열 → 대분류. 알 수 없거나 null 이면 null.
  static ComfortCategory? fromValue(String? raw) {
    if (raw == null) return null;
    for (final c in ComfortCategory.values) {
      if (c.name == raw) return c;
    }
    return null;
  }
}

/// 위로 요청 맥락의 세부 태그 (2단계 선택).
/// 서버 tag 컬럼에 name(예: 'relFamily')을 저장한다.
enum ComfortTag {
  // 일 · 진로
  workCareer,
  workPressure,
  workRecognition,
  // 관계
  relFamily,
  relPartner,
  relFriend,
  relWork,
  // 불안 · 걱정
  anxFuture,
  anxVague,
  anxHealth,
  // 지침 · 번아웃
  fatBody,
  fatMind,
  fatMotivation,
  // 외로움
  loneAlone,
  loneUnderstood,
  // 슬픔 · 우울
  sadReason,
  sadVague,
  sadLoss,
  // 그냥, 그런 날
  etcJust,
  etcNoWords;

  /// 이 세부 태그가 속한 대분류.
  ComfortCategory get category {
    switch (this) {
      case ComfortTag.workCareer:
      case ComfortTag.workPressure:
      case ComfortTag.workRecognition:
        return ComfortCategory.work;
      case ComfortTag.relFamily:
      case ComfortTag.relPartner:
      case ComfortTag.relFriend:
      case ComfortTag.relWork:
        return ComfortCategory.relationship;
      case ComfortTag.anxFuture:
      case ComfortTag.anxVague:
      case ComfortTag.anxHealth:
        return ComfortCategory.anxiety;
      case ComfortTag.fatBody:
      case ComfortTag.fatMind:
      case ComfortTag.fatMotivation:
        return ComfortCategory.fatigue;
      case ComfortTag.loneAlone:
      case ComfortTag.loneUnderstood:
        return ComfortCategory.loneliness;
      case ComfortTag.sadReason:
      case ComfortTag.sadVague:
      case ComfortTag.sadLoss:
        return ComfortCategory.sadness;
      case ComfortTag.etcJust:
      case ComfortTag.etcNoWords:
        return ComfortCategory.etc;
    }
  }

  /// 세부 선택지에 보여줄 한글 라벨.
  String get label {
    switch (this) {
      case ComfortTag.workCareer:
        return '진로가 막막해요';
      case ComfortTag.workPressure:
        return '일이 너무 버거워요';
      case ComfortTag.workRecognition:
        return '인정받지 못하는 것 같아요';
      case ComfortTag.relFamily:
        return '가족과의 일';
      case ComfortTag.relPartner:
        return '연인과의 일';
      case ComfortTag.relFriend:
        return '친구와의 일';
      case ComfortTag.relWork:
        return '직장 사람과의 일';
      case ComfortTag.anxFuture:
        return '미래가 걱정돼요';
      case ComfortTag.anxVague:
        return '막연히 불안해요';
      case ComfortTag.anxHealth:
        return '건강이 염려돼요';
      case ComfortTag.fatBody:
        return '몸이 지쳤어요';
      case ComfortTag.fatMind:
        return '마음이 지쳤어요';
      case ComfortTag.fatMotivation:
        return '아무 의욕이 없어요';
      case ComfortTag.loneAlone:
        return '혼자인 것 같아요';
      case ComfortTag.loneUnderstood:
        return '아무도 몰라주는 것 같아요';
      case ComfortTag.sadReason:
        return '이유 있는 슬픔이에요';
      case ComfortTag.sadVague:
        return '이유 없이 우울해요';
      case ComfortTag.sadLoss:
        return '무언가를 잃었어요';
      case ComfortTag.etcJust:
        return '그냥, 그런 날이에요';
      case ComfortTag.etcNoWords:
        return '말로 표현이 안 돼요';
    }
  }

  /// 서버 저장용 문자열.
  String get value => name;

  /// 서버 문자열 → 세부 태그.
  /// 1) 정확히 일치하는 세부 태그가 있으면 그것.
  /// 2) 옛 대분류 문자열('work' 등)이면 대표 세부 태그로 호환 매핑(레거시 더미용).
  /// 3) 그 외/null 이면 null.
  static ComfortTag? fromValue(String? raw) {
    if (raw == null) return null;
    for (final t in ComfortTag.values) {
      if (t.name == raw) return t;
    }
    // 레거시 대분류 값 호환
    switch (raw) {
      case 'work':
        return ComfortTag.workPressure;
      case 'relationship':
        return ComfortTag.relFriend;
      case 'anxiety':
        return ComfortTag.anxVague;
      case 'fatigue':
        return ComfortTag.fatMind;
      case 'loneliness':
        return ComfortTag.loneAlone;
      case 'sadness':
        return ComfortTag.sadVague;
      case 'etc':
        return ComfortTag.etcJust;
    }
    return null;
  }
}

/// 풀에서 꺼내온, 내가 위로를 보낼 대상.
/// fetch_one_pending_request() 의 반환 1행에 대응한다.
/// requester 정보는 포함하지 않는다(익명).
class ComfortRequest {
  /// 위로 요청 id (위로를 보낼 때 send_comfort_reply 에 넘긴다)
  final String id;

  /// 요청자가 띄운 기분 단계 (1~5)
  final int moodLevel;

  /// 맥락 세부 태그 (없을 수 있음). 카드에는 보통 tag?.category.label 만 노출.
  final ComfortTag? tag;

  /// 요청이 띄워진 시각 (로컬 변환)
  final DateTime createdAt;

  /// 이 요청이 지금까지 받은 위로 수 (공정 분배 표시용)
  final int replyCount;

  const ComfortRequest({
    required this.id,
    required this.moodLevel,
    this.tag,
    required this.createdAt,
    required this.replyCount,
  });

  /// 카드 표시용 대분류 (세부 태그가 있으면 그 대분류, 없으면 null).
  ComfortCategory? get category => tag?.category;

  factory ComfortRequest.fromJson(Map<String, dynamic> json) {
    return ComfortRequest(
      id: json['id'] as String,
      moodLevel: (json['mood_level'] as num).toInt(),
      tag: ComfortTag.fromValue(json['tag'] as String?),
      createdAt:
          DateTime.parse(json['created_at'] as String).toLocal(),
      replyCount: (json['reply_count'] as num?)?.toInt() ?? 0,
    );
  }
}

/// 내 요청에 도착한, 누군가의 익명 위로.
/// get_my_comforts() 의 반환 1행에 대응한다.
/// sender 정보는 포함하지 않는다(익명).
class ReceivedComfort {
  /// 위로(reply) id
  final String replyId;

  /// 위로 본문 (발송 시점 문구가 박제되어 있음)
  final String content;

  /// 도착 시각 (로컬 변환)
  final DateTime createdAt;

  /// 이미 읽은 위로인지 (새로 받은 위로 강조용)
  final bool isRead;

  /// 이 위로가 답으로 달린, 내 요청 당시의 기분 단계
  final int moodLevel;

  /// 내 요청 당시의 맥락 세부 태그 (없을 수 있음)
  final ComfortTag? tag;

  const ReceivedComfort({
    required this.replyId,
    required this.content,
    required this.createdAt,
    required this.isRead,
    required this.moodLevel,
    this.tag,
  });

  /// 표시용 대분류.
  ComfortCategory? get category => tag?.category;

  factory ReceivedComfort.fromJson(Map<String, dynamic> json) {
    return ReceivedComfort(
      replyId: json['reply_id'] as String,
      content: json['content'] as String,
      createdAt:
          DateTime.parse(json['created_at'] as String).toLocal(),
      isRead: json['is_read'] as bool? ?? false,
      moodLevel: (json['mood_level'] as num).toInt(),
      tag: ComfortTag.fromValue(json['tag'] as String?),
    );
  }
}