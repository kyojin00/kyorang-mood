import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show AuthException;

import '../../theme/app_theme.dart';
import '../../services/auth_service.dart';
import '../../widgets/mascot.dart';

/// 로그인 / 회원가입 화면.
///
/// 이메일+비밀번호로 로그인하거나 가입한다.
/// 가입 시 이름을 받아 저장하고, 무디가 그 이름으로 부르게 된다.
/// 가입 후 이메일 인증 메일이 발송되면 안내 메시지를 표시한다.
class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  bool _isSignUp = false;
  bool _busy = false;
  String? _error;
  String? _info; // 성공/안내 메시지 (예: "확인 메일을 보냈어요")

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

  Future<void> _submit() async {
    if (_busy) return;
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final name = _nameController.text.trim();

    // 클라이언트 측 기본 검증
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
        await AuthService.instance.signUp(
          email: email,
          password: password,
          name: name,
        );
        // 가입 성공 — 이메일 인증이 켜져 있으면 확인 메일이 발송된다.
        // (Supabase는 이메일 열거 공격 방지를 위해 이미 가입된 이메일도
        //  정상 응답을 주므로, 두 경우를 모두 포괄하는 안내를 보여준다.)
        // 인증 후 자동 로그인 흐름은 main.dart의 분기가 처리한다.
        if (!mounted) return;
        setState(() {
          _info =
              '$email 주소로 확인 메일을 보냈어요.\n메일함의 링크를 눌러 인증을 완료해주세요.\n\n이미 가입한 적이 있다면 아래에서 로그인해주세요.';
          // 인증 후 다시 와서 로그인할 수 있게 모드를 로그인으로 전환
          _isSignUp = false;
          _passwordController.clear();
        });
      } else {
        await AuthService.instance.signIn(
          email: email,
          password: password,
        );
        // 로그인 성공 — main.dart 분기가 홈/온보딩으로 자동 이동
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

  /// Supabase의 AuthException을 사용자 친화 메시지로 바꾼다.
  String _humanizeAuthError(AuthException e) {
    final code = e.code ?? '';
    final msg = e.message.toLowerCase();

    if (_isSignUp) {
      // 가입 시 흔한 케이스
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
      if (code == 'over_email_send_rate_limit' ||
          msg.contains('rate limit')) {
        return '잠시 후 다시 시도해주세요.';
      }
      if (msg.contains('invalid') && msg.contains('email')) {
        return '이메일 형식이 올바르지 않아요.';
      }
      return '가입에 실패했어요. 입력한 내용을 확인해주세요.';
    } else {
      // 로그인 시 흔한 케이스
      if (code == 'invalid_credentials' ||
          msg.contains('invalid login credentials')) {
        return '이메일이나 비밀번호가 맞지 않아요.';
      }
      if (code == 'email_not_confirmed' ||
          msg.contains('email not confirmed')) {
        return '아직 이메일 인증이 안 됐어요. 메일함의 인증 링크를 눌러주세요.';
      }
      return '로그인에 실패했어요. 잠시 후 다시 시도해주세요.';
    }
  }

  void _toggleMode() {
    setState(() {
      _isSignUp = !_isSignUp;
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 24),
              const Center(
                child: Mascot(pose: MascotPose.wave, size: 130),
              ),
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
                  decoration: const InputDecoration(
                    hintText: '무디가 부를 이름',
                  ),
                ),
                const SizedBox(height: 16),
              ],

              _label('이메일'),
              const SizedBox(height: 6),
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  hintText: 'example@email.com',
                ),
              ),
              const SizedBox(height: 16),

              _label('비밀번호'),
              const SizedBox(height: 6),
              TextField(
                controller: _passwordController,
                obscureText: true,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _submit(),
                decoration: const InputDecoration(
                  hintText: '6자 이상',
                ),
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
                  onPressed: _busy ? null : _submit,
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
                onPressed: _busy ? null : _toggleMode,
                child: Text(
                  _isSignUp
                      ? '이미 계정이 있어요 · 로그인'
                      : '처음이신가요? · 회원가입',
                ),
              ),
            ],
          ),
        ),
      ),
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