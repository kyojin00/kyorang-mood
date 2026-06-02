import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/auth_service.dart';

/// 인증 상태 스트림 프로바이더.
///
/// 로그인/로그아웃 시 자동으로 갱신되어,
/// 앱의 첫 화면 분기(로그인 ↔ 온보딩/홈)에 사용된다.
final authStateProvider = StreamProvider<AuthState>((ref) {
  return AuthService.instance.authStateChanges;
});

/// 현재 로그인 여부.
final isLoggedInProvider = Provider<bool>((ref) {
  // authStateProvider를 watch해 로그인 상태 변화에 반응한다.
  ref.watch(authStateProvider);
  return AuthService.instance.isLoggedIn;
});

/// 현재 사용자 이름 (없으면 '친구').
final userNameProvider = Provider<String>((ref) {
  ref.watch(authStateProvider);
  return AuthService.instance.displayName;
});