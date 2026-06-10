import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show AuthException;

import '../../theme/app_theme.dart';
import '../../services/auth_service.dart';
import '../../widgets/mascot.dart';
import 'password_reset_screen.dart';

/// 로그인 / 회원가입 화면.
///
/// 두 단계 흐름:
///   1) 랜딩 — "구글로 시작하기" / "이메일로 시작하기" 두 큰 버튼.
///   2) 이메일 폼 — 두 번째 버튼을 누르면 펼쳐지는 이메일+비번 흐름(로그인/가입 전환).
///
/// 구글 로그인은 즉시 처리(랜딩에서 한 번에). 이메일 흐름은 폼 진입 후 토글.
class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

enum _AuthStage {
  landing,    // "구글로 시작하기" / "이메일로 시작하기" 두 버튼
  emailForm,  // 이메일+비번 입력 폼(로그인/가입 토글)
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  _AuthStage _stage = _AuthStage.landing;
  bool _isSignUp = false;
  bool _busy = false;
  String? _error;
  String? _info;

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // ── 구글 로그인 ──────────────────────────────────────────
  Future<void> _signInWithGoogle() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
      _info = null;
    });
    try {
      await AuthService.instance.signInWithGoogle();
      // 성공하면 main.dart의 분기가 자동으로 홈/온보딩으로 이동.
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() => _error = '구글 로그인에 실패했어요.\n(${e.message})');
    } catch (e) {
      if (!mounted) return;
      // 사용자가 취소했거나 네트워크 오류 등
      final msg = e.toString();
      if (msg.contains('canceled') || msg.contains('cancelled')) {
        // 취소는 에러 표시 없이 조용히 통과
      } else {
        setState(() => _error = '구글 로그인에 실패했어요. 잠시 후 다시 시도해주세요.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // ── 이메일 폼 제출 ──────────────────────────────────────
  Future<void> _submitEmail() async {
    if (_busy) return;
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final name = _nameController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      setState(() {
        _error = '이메일과 비밀번호를 입력해주세요.';
        _info = null;
      });
      return;
    }
    if (_isSignUp && name.isEmpty) {
      setState(() {
        _error = '무디가 부를 이름을 알려주세요.';
        _info = null;
      });
      return;
    }
    if (password.length < 6) {
      setState(() {
        _error = '비밀번호는 6자 이상이어야 해요.';
        _info = null;
      });
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
      _info = null;
    });

    try {
      if (_isSignUp) {
        final result = await AuthService.instance.signUp(
          email: email,
          password: password,
          name: name,
        );
        if (!mounted) return;

        if (result == SignUpResult.alreadyExists) {
          setState(() {
            _error = '이미 가입된 이메일이에요. 아래에서 로그인해주세요.';
            _isSignUp = false;
            _passwordController.clear();
          });
        } else {
          setState(() {
            _info = '$email 주소로 확인 메일을 보냈어요.\n메일함의 링크를 눌러 인증을 완료해주세요.';
            _isSignUp = false;
            _passwordController.clear();
          });
        }
      } else {
        await AuthService.instance.signIn(
          email: email,
          password: password,
        );
      }
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() => _error = _humanizeAuthError(e));
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = '잠시 후 다시 시도해주세요.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _humanizeAuthError(AuthException e) {
    final code = e.code ?? '';
    final msg = e.message.toLowerCase();

    if (_isSignUp) {
      if (code == 'user_already_exists' ||
          code == 'email_exists' ||
          msg.contains('already registered') ||
          msg.contains('already exists') ||
          msg.contains('user already')) {
        return '이미 가입된 이메일이에요. 로그인해보세요.';
      }
      if (code == 'weak_password' || msg.contains('password')) {
        return '비밀번호가 너무 약해요. 좀 더 길고 복잡하게 만들어주세요.';
      }
      if (code == 'over_email_send_rate_limit' || msg.contains('rate limit')) {
        return '잠시 후 다시 시도해주세요.';
      }
      if (msg.contains('invalid') && msg.contains('email')) {
        return '이메일 형식이 올바르지 않아요.';
      }
      return '가입에 실패했어요. 입력한 내용을 확인해주세요.';
    } else {
      if (code == 'invalid_credentials' ||
          msg.contains('invalid login credentials')) {
        return '이메일이나 비밀번호가 맞지 않아요.';
      }
      if (code == 'email_not_confirmed' || msg.contains('email not confirmed')) {
        return '아직 이메일 인증이 안 됐어요. 메일함의 인증 링크를 눌러주세요.';
      }
      return '로그인에 실패했어요. 잠시 후 다시 시도해주세요.';
    }
  }

  void _toggleSignUp() {
    setState(() {
      _isSignUp = !_isSignUp;
      _error = null;
      _info = null;
    });
  }

  void _goLanding() {
    setState(() {
      _stage = _AuthStage.landing;
      _isSignUp = false;
      _error = null;
      _info = null;
      _passwordController.clear();
    });
  }

  void _goEmailForm() {
    setState(() {
      _stage = _AuthStage.emailForm;
      _error = null;
      _info = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppTheme.screenPadding),
          child: _stage == _AuthStage.landing
              ? _buildLanding()
              : _buildEmailForm(),
        ),
      ),
    );
  }

  // ── 랜딩(두 큰 버튼) ──────────────────────────────────
  Widget _buildLanding() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 60),
        const Center(child: Mascot(pose: MascotPose.wave, size: 150)),
        const SizedBox(height: 24),
        Text(
          '교랑무드 시작하기',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 8),
        Text(
          '오늘 하루의 마음을 무디와 함께 기록해요',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppTheme.textSecondary,
              ),
        ),
        const SizedBox(height: 56),

        // 구글로 시작하기
        SizedBox(
          height: 56,
          child: ElevatedButton.icon(
            onPressed: _busy ? null : _signInWithGoogle,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFF1A1A1A),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
              ),
              elevation: 0,
            ),
            icon: _busy
                ? const SizedBox.shrink()
                : Image.network(
                    'https://www.gstatic.com/marketing-cms/assets/images/d5/dc/cfe9ce8b4425b410b49b7f2dd3f3/g.webp=s48-fcrop64=1,00000000ffffffff-rw',
                    width: 22,
                    height: 22,
                    errorBuilder: (_, __, ___) => const Icon(
                      Icons.g_mobiledata,
                      size: 28,
                      color: Color(0xFF4285F4),
                    ),
                  ),
            label: _busy
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Color(0xFF1A1A1A),
                    ),
                  )
                : const Text(
                    '구글로 시작하기',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 12),

        // 이메일로 시작하기
        SizedBox(
          height: 56,
          child: ElevatedButton.icon(
            onPressed: _busy ? null : _goEmailForm,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.surface,
              foregroundColor: AppTheme.textPrimary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                side: BorderSide(color: AppTheme.divider),
              ),
              elevation: 0,
            ),
            icon: Icon(
              Icons.mail_outline_rounded,
              size: 20,
              color: AppTheme.textPrimary,
            ),
            label: const Text(
              '이메일로 시작하기',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),

        if (_error != null) ...[
          const SizedBox(height: 20),
          _errorBox(_error!),
        ],

        const SizedBox(height: 32),
        Text(
          '가입을 진행하면 서비스 이용약관과\n개인정보 처리방침에 동의하는 것으로 간주돼요.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppTheme.textTertiary,
            fontSize: 11,
            height: 1.5,
          ),
        ),
      ],
    );
  }

  // ── 이메일 폼 ──────────────────────────────────────
  Widget _buildEmailForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 뒤로가기
        Align(
          alignment: Alignment.centerLeft,
          child: IconButton(
            onPressed: _busy ? null : _goLanding,
            icon: Icon(Icons.arrow_back, color: AppTheme.textPrimary),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ),
        const SizedBox(height: 16),
        const Center(child: Mascot(pose: MascotPose.wave, size: 110)),
        const SizedBox(height: 8),
        Text(
          _isSignUp ? '교랑무드 시작하기' : '다시 만나서 반가워요',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 32),

        if (_isSignUp) ...[
          _label('이름'),
          const SizedBox(height: 6),
          TextField(
            controller: _nameController,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(hintText: '무디가 부를 이름'),
          ),
          const SizedBox(height: 16),
        ],

        _label('이메일'),
        const SizedBox(height: 6),
        TextField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
          decoration: const InputDecoration(hintText: 'example@email.com'),
        ),
        const SizedBox(height: 16),

        _label('비밀번호'),
        const SizedBox(height: 6),
        TextField(
          controller: _passwordController,
          obscureText: true,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _submitEmail(),
          decoration: const InputDecoration(hintText: '6자 이상'),
        ),

        if (_info != null) ...[
          const SizedBox(height: 16),
          _infoBox(_info!),
        ],
        if (_error != null) ...[
          const SizedBox(height: 16),
          _errorBox(_error!),
        ],

        const SizedBox(height: 28),
        SizedBox(
          height: 54,
          child: ElevatedButton(
            onPressed: _busy ? null : _submitEmail,
            child: _busy
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Text(_isSignUp ? '가입하기' : '로그인'),
          ),
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: _busy ? null : _toggleSignUp,
          child: Text(
            _isSignUp ? '이미 계정이 있어요 · 로그인' : '처음이신가요? · 회원가입',
          ),
        ),
        if (!_isSignUp)
          TextButton(
            onPressed: _busy
                ? null
                : () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const PasswordResetRequestScreen(),
                      ),
                    ),
            child: const Text(
              '비밀번호를 잊으셨나요?',
              style: TextStyle(color: AppTheme.textTertiary, fontSize: 13),
            ),
          ),
      ],
    );
  }

  Widget _label(String text) {
    return Text(
      text,
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: AppTheme.textSecondary,
            fontWeight: FontWeight.w600,
          ),
    );
  }

  Widget _infoBox(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppTheme.accentDark.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
        border: Border.all(color: AppTheme.accent, width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.mark_email_read_outlined,
              color: AppTheme.accentLight, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.textPrimary,
                    height: 1.5,
                  ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _errorBox(String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.error_outline, color: AppTheme.error, size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(color: AppTheme.error, fontSize: 13),
          ),
        ),
      ],
    );
  }
}