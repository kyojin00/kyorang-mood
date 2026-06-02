import 'package:supabase_flutter/supabase_flutter.dart';

/// 가입 결과
enum SignUpResult {
  /// 새로운 가입 — 확인 메일이 발송됨
  newSignUp,

  /// 이미 가입된 이메일 (Supabase가 이메일 열거 방지로 정상 응답을 주지만,
  /// identities가 비어 있는 신호로 중복임을 알 수 있다)
  alreadyExists,
}

/// 인증 서비스.
class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  /// 이메일 인증 후 앱으로 돌아올 딥링크.
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

  /// 이메일 회원가입.
  /// 응답을 분석해 신규/중복을 구분해 반환한다.
  Future<SignUpResult> signUp({
    required String email,
    required String password,
    required String name,
  }) async {
    final res = await _client.auth.signUp(
      email: email.trim(),
      password: password,
      data: {'display_name': name.trim()},
      emailRedirectTo: emailRedirectUrl,
    );

    // Supabase는 이메일 열거 방지를 위해, 이미 가입된 사용자에게도
    // 200 응답을 준다. 다만 그 경우 user.identities가 빈 배열이라
    // 이걸로 중복 여부를 구분할 수 있다.
    final user = res.user;
    final identities = user?.identities;
    final isDuplicate = user == null ||
        identities == null ||
        identities.isEmpty;

    return isDuplicate ? SignUpResult.alreadyExists : SignUpResult.newSignUp;
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