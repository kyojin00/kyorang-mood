import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// 가입 결과
enum SignUpResult {
  newSignUp,
  alreadyExists,
}

/// 인증 서비스.
class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  /// 이메일 인증 / 비밀번호 재설정 후 앱으로 돌아올 딥링크.
  static const String emailRedirectUrl = 'kyorang://auth-callback';

  // ── 구글 OAuth Client ID ────────────────────────────────
  // serverClientId 에는 Google Cloud Console에서 발급한 **Web Client ID**를 넣는다.
  static const String _googleWebClientId =
      '54388432481-jthncu9m91ct4p0phcofqd4j5a9im73u.apps.googleusercontent.com';

  SupabaseClient get _client => Supabase.instance.client;

  User? get currentUser => _client.auth.currentUser;
  bool get isLoggedIn => currentUser != null;

  String get displayName {
    final meta = currentUser?.userMetadata;
    final custom = meta?['display_name'] as String?;
    if (custom != null && custom.trim().isNotEmpty) return custom.trim();
    final fullName = (meta?['full_name'] ?? meta?['name']) as String?;
    if (fullName != null && fullName.trim().isNotEmpty) return fullName.trim();
    return '친구';
  }

  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;

  /// 이메일 회원가입. 신규/중복을 구분해 반환한다.
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
    final user = res.user;
    final identities = user?.identities;
    final isDuplicate =
        user == null || identities == null || identities.isEmpty;
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

  /// 구글 로그인.
  Future<void> signInWithGoogle() async {
    final googleSignIn = GoogleSignIn(
      serverClientId: _googleWebClientId,
      scopes: const ['email', 'profile', 'openid'],
    );

    await googleSignIn.signOut();

    final account = await googleSignIn.signIn();
    if (account == null) {
      throw Exception('canceled');
    }

    final auth = await account.authentication;
    final idToken = auth.idToken;
    final accessToken = auth.accessToken;

    if (idToken == null) {
      throw const AuthException(
        '구글 로그인 토큰을 받지 못했어요. 잠시 후 다시 시도해주세요.',
      );
    }

    await _client.auth.signInWithIdToken(
      provider: OAuthProvider.google,
      idToken: idToken,
      accessToken: accessToken,
    );
  }

  Future<void> signOut() async {
    // 구글 세션도 같이 정리 (다른 구글 계정으로 재로그인할 수 있도록)
    try {
      await GoogleSignIn(serverClientId: _googleWebClientId).signOut();
    } catch (_) {
      // 구글 SDK가 없거나 미초기화여도 Supabase 로그아웃은 진행
    }
    try {
      await _client.auth.signOut();
    } catch (_) {
      // 계정 삭제 직후 호출되는 경우 401이 날 수 있음 — 무시.
    }
  }

  /// 계정 삭제.
  ///
  /// 서버 RPC(delete_my_account)를 호출해 auth.users를 삭제한다.
  /// 외래키 액션에 의해 본인의 모든 데이터가 정리된다:
  ///   - 위로 풀에 보낸 메시지는 sender_id가 NULL로 익명화(받은 사람 위로함 보존)
  ///   - 그 외 일기/과제/대화/요청/신고 등은 모두 CASCADE 삭제
  ///
  /// 호출자가 처리 후 별도로 [signOut]을 호출해 세션을 정리해야 한다.
  /// (다이얼로그 보여주기 전에 signOut 하면 화면이 즉시 전환되므로,
  ///  호출 시점은 화면 흐름에서 제어하도록 분리했다.)
  Future<void> deleteAccount() async {
    await _client.rpc('delete_my_account');
  }

  Future<void> updateName(String name) async {
    await _client.auth.updateUser(
      UserAttributes(data: {'display_name': name.trim()}),
    );
  }

  /// 비밀번호 재설정 메일을 발송한다.
  Future<void> sendPasswordReset(String email) async {
    await _client.auth.resetPasswordForEmail(
      email.trim(),
      redirectTo: emailRedirectUrl,
    );
  }

  /// 새 비밀번호를 적용한다.
  Future<void> updatePassword(String newPassword) async {
    await _client.auth.updateUser(
      UserAttributes(password: newPassword),
    );
  }
}