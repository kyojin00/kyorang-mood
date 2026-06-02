import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/mood_entry.dart';
import '../models/user_profile.dart';
import '../services/profile_storage.dart';

/// 사용자 프로필을 관리하는 프로바이더.
///
/// 앱 시작 시 저장된 프로필을 즉시 읽어오고,
/// 온보딩 완료 시 성향/선호 시간대를 저장하며 상태를 갱신한다.
final profileProvider =
    NotifierProvider<ProfileNotifier, UserProfile>(ProfileNotifier.new);

class ProfileNotifier extends Notifier<UserProfile> {
  @override
  UserProfile build() {
    return ProfileStorage.instance.load();
  }

  /// 온보딩을 완료하고 결과를 저장한다.
  Future<void> completeOnboarding({
    required SuggestionType persona,
    required PreferredTime preferredTime,
  }) async {
    final profile = UserProfile(
      persona: persona,
      preferredTime: preferredTime,
      onboardingDone: true,
    );
    await ProfileStorage.instance.save(profile);
    state = profile;
  }

  /// 성향만 변경한다 (설정에서 나중에 바꾸는 경우).
  Future<void> updatePersona(SuggestionType persona) async {
    final updated = state.copyWith(persona: persona);
    await ProfileStorage.instance.save(updated);
    state = updated;
  }

  /// 선호 시간대만 변경한다.
  Future<void> updatePreferredTime(PreferredTime time) async {
    final updated = state.copyWith(preferredTime: time);
    await ProfileStorage.instance.save(updated);
    state = updated;
  }

  /// 프로필 초기화 (온보딩 다시 보기 / 디버그용).
  Future<void> reset() async {
    await ProfileStorage.instance.clear();
    state = UserProfile.empty();
  }
}

/// 온보딩 완료 여부 (첫 화면 분기용).
final onboardingDoneProvider = Provider<bool>((ref) {
  return ref.watch(profileProvider).onboardingDone;
});

/// 현재 성향 (= 기본 제안 유형). 온보딩 전이면 null.
final personaProvider = Provider<SuggestionType?>((ref) {
  return ref.watch(profileProvider).persona;
});