import 'package:supabase_flutter/supabase_flutter.dart';

/// 인증 서비스.
///
/// 이메일+비밀번호 회원가입/로그인/로그아웃을 다룬다.
/// 가입 시 이름(displayName)을 사용자 메타데이터에 저장해,
/// 상담에서 무디가 그 이름으로 부를 수 있게 한다.
class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  /// 이메일 인증 후 앱으로 돌아올 딥링크.
  /// AndroidManifest의 intent-filter와 일치해야 한다.
  static const String emailRedirectUrl = 'kyorang://auth-callback';

  SupabaseClient get _client => Supabase.instance.client;

  User? get currentUser => _client.auth.currentUser;

  bool get isLoggedIn => currentUser != null;

  String get displayName {
    final name = currentUser?.userMetadata?['display_name'] as String?;
    if (name != null && name.trim().isNotEmpty) return name.trim();
    return '친구';
  }

  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;

  /// 이메일 회원가입. 이름을 메타데이터에 저장하고,
  /// 인증 메일의 링크가 앱으로 돌아오도록 emailRedirectTo를 지정한다.
  Future<void> signUp({
    required String email,
    required String password,
    required String name,
  }) async {
    await _client.auth.signUp(
      email: email.trim(),
      password: password,
      data: {'display_name': name.trim()},
      emailRedirectTo: emailRedirectUrl,
    );
  }

  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    await _client.auth.signInWithPassword(
      email: email.trim(),
      password: password,
    );
  }

  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  Future<void> updateName(String name) async {
    await _client.auth.updateUser(
      UserAttributes(data: {'display_name': name.trim()}),
    );
  }
}