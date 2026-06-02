/// 맞춤 제안의 유형.
///
/// 온보딩에서 분류한 사용자 성향과 대응되며,
/// 기분 기록 시 어떤 종류의 제안을 건넸는지 기록하는 데 사용한다.
enum SuggestionType {
  /// 글귀형 — 위로/공감 문장
  quote,

  /// 휴식형 — 호흡/이완/멈춤 제안
  rest,

  /// 활동형 — 작은 행동 제안 (산책 등)
  activity,

  /// 연결형 — 누군가와 연결되기 (안부 등)
  connect;

  /// 저장용 문자열 키
  String get key => name;

  /// 한글 라벨
  String get label {
    switch (this) {
      case SuggestionType.quote:
        return '글귀';
      case SuggestionType.rest:
        return '휴식';
      case SuggestionType.activity:
        return '활동';
      case SuggestionType.connect:
        return '연결';
    }
  }

  /// 문자열 키로부터 복원. 알 수 없으면 글귀형으로 처리.
  static SuggestionType fromKey(String? key) {
    return SuggestionType.values.firstWhere(
      (e) => e.name == key,
      orElse: () => SuggestionType.quote,
    );
  }
}

/// 기분 기록 한 건.
///
/// 사용자가 하루에 기록하는 기분 데이터의 기본 단위.
/// 기분 값(필수) 외 메모·제안은 선택 사항이다.
class MoodEntry {
  /// 고유 식별자 (저장/조회 키로 사용)
  final String id;

  /// 기록 날짜·시각
  final DateTime date;

  /// 기분 값 (1=아주 나쁨 ~ 5=아주 좋음)
  final int moodLevel;

  /// 사용자가 남긴 한 줄 메모 (선택)
  final String? note;

  /// 이 기록에서 사용자에게 건넨 제안 내용 (선택)
  final String? suggestion;

  /// 건넨 제안의 유형 (선택)
  final SuggestionType? suggestionType;

  /// 제안에 대한 사용자 반응.
  /// null = 반응 없음, true = 도움 됨, false = 별로.
  /// (2차 버전의 추천 보정에 사용할 데이터)
  final bool? suggestionHelpful;

  const MoodEntry({
    required this.id,
    required this.date,
    required this.moodLevel,
    this.note,
    this.suggestion,
    this.suggestionType,
    this.suggestionHelpful,
  });

  /// 날짜를 'yyyy-MM-dd' 형태의 키로 반환 (달력 조회용).
  String get dateKey {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  MoodEntry copyWith({
    String? id,
    DateTime? date,
    int? moodLevel,
    String? note,
    String? suggestion,
    SuggestionType? suggestionType,
    bool? suggestionHelpful,
  }) {
    return MoodEntry(
      id: id ?? this.id,
      date: date ?? this.date,
      moodLevel: moodLevel ?? this.moodLevel,
      note: note ?? this.note,
      suggestion: suggestion ?? this.suggestion,
      suggestionType: suggestionType ?? this.suggestionType,
      suggestionHelpful: suggestionHelpful ?? this.suggestionHelpful,
    );
  }

  /// JSON 직렬화 (Hive 저장 / Supabase 동기화 공용).
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'date': date.toIso8601String(),
      'mood_level': moodLevel,
      'note': note,
      'suggestion': suggestion,
      'suggestion_type': suggestionType?.key,
      'suggestion_helpful': suggestionHelpful,
    };
  }

  /// JSON 복원.
  factory MoodEntry.fromJson(Map<String, dynamic> json) {
    return MoodEntry(
      id: json['id'] as String,
      date: DateTime.parse(json['date'] as String),
      moodLevel: json['mood_level'] as int,
      note: json['note'] as String?,
      suggestion: json['suggestion'] as String?,
      suggestionType: json['suggestion_type'] != null
          ? SuggestionType.fromKey(json['suggestion_type'] as String)
          : null,
      suggestionHelpful: json['suggestion_helpful'] as bool?,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is MoodEntry && other.id == id);

  @override
  int get hashCode => id.hashCode;
}