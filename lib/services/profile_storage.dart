import 'dart:convert';

import 'package:hive_ce/hive.dart';

import '../models/user_profile.dart';

/// 사용자 프로필(온보딩 결과)의 로컬 저장(Hive)을 담당하는 서비스.
///
/// 프로필은 사용자당 하나뿐이므로 고정 키 하나에 저장한다.
/// MoodStorage와 동일하게 박스 타입을 <String>으로 통일한다.
class ProfileStorage {
  ProfileStorage._();

  static final ProfileStorage instance = ProfileStorage._();

  static const String _boxName = 'user_profile';
  static const String _key = 'profile';

  Box<String>? _box;

  Box<String> get _profile {
    final box = _box;
    if (box == null) {
      throw StateError(
        'ProfileStorage가 초기화되지 않았습니다. 앱 시작 시 init()을 먼저 호출하세요.',
      );
    }
    return box;
  }

  /// 박스를 연다. 앱 시작 시 1회 호출.
  Future<void> init() async {
    if (_box != null && _box!.isOpen) return;
    _box = await Hive.openBox<String>(_boxName);
  }

  /// 프로필을 저장(신규/갱신 공용).
  Future<void> save(UserProfile profile) async {
    await _profile.put(_key, jsonEncode(profile.toJson()));
  }

  /// 프로필을 불러온다. 저장된 값이 없으면 빈 프로필을 반환.
  UserProfile load() {
    final raw = _profile.get(_key);
    if (raw == null) return UserProfile.empty();
    return UserProfile.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  /// 온보딩 완료 여부 (첫 화면 분기용 빠른 조회).
  bool get isOnboardingDone => load().onboardingDone;

  /// 프로필 삭제 (디버그/초기화용).
  Future<void> clear() async {
    await _profile.delete(_key);
  }
}