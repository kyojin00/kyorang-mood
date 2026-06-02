import 'mood_entry.dart';

/// 사용자가 앱을 주로 여는 시간대.
///
/// 온보딩 질문 3의 답으로, 추후 '비서' 기능(알림/브리핑) 타이밍에 사용한다.
/// (성향 분류에는 영향을 주지 않는다.)
enum PreferredTime {
  /// 아침 — 하루 시작
  morning,

  /// 저녁 — 하루 마무리
  evening,

  /// 그때그때 — 힘들 때마다
  anytime;

  String get key => name;

  String get label {
    switch (this) {
      case PreferredTime.morning:
        return '아침';
      case PreferredTime.evening:
        return '저녁';
      case PreferredTime.anytime:
        return '그때그때';
    }
  }

  static PreferredTime fromKey(String? key) {
    return PreferredTime.values.firstWhere(
      (e) => e.name == key,
      orElse: () => PreferredTime.anytime,
    );
  }
}

/// 사용자 프로필.
///
/// 온보딩 결과를 담는다.
/// - persona: 사용자 성향. SuggestionType을 재사용하며,
///   "이 사람에게 주로 건넬 제안 유형"을 뜻한다.
/// - preferredTime: 앱을 주로 여는 시간대 (비서 기능용).
/// - onboardingDone: 온보딩 완료 여부. 첫 화면 분기에 사용.
class UserProfile {
  /// 성향 (= 기본 제안 유형). 온보딩 전이면 null.
  final SuggestionType? persona;

  /// 선호 시간대
  final PreferredTime? preferredTime;

  /// 온보딩 완료 여부
  final bool onboardingDone;

  const UserProfile({
    this.persona,
    this.preferredTime,
    this.onboardingDone = false,
  });

  /// 아직 온보딩을 하지 않은 초기 상태.
  factory UserProfile.empty() => const UserProfile();

  UserProfile copyWith({
    SuggestionType? persona,
    PreferredTime? preferredTime,
    bool? onboardingDone,
  }) {
    return UserProfile(
      persona: persona ?? this.persona,
      preferredTime: preferredTime ?? this.preferredTime,
      onboardingDone: onboardingDone ?? this.onboardingDone,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'persona': persona?.key,
      'preferred_time': preferredTime?.key,
      'onboarding_done': onboardingDone,
    };
  }

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      persona: json['persona'] != null
          ? SuggestionType.fromKey(json['persona'] as String)
          : null,
      preferredTime: json['preferred_time'] != null
          ? PreferredTime.fromKey(json['preferred_time'] as String)
          : null,
      onboardingDone: json['onboarding_done'] as bool? ?? false,
    );
  }
}