import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../main.dart';
import '../../theme/app_theme.dart';
import '../../services/auth_service.dart';
import '../../widgets/mascot.dart';

/// 비밀번호 재설정 요청 화면.
///
/// 이메일을 받아 재설정 메일을 발송한다.
/// 메일의 링크를 누르면 앱이 열리며 새 비밀번호 화면으로 이어진다.
class PasswordResetRequestScreen extends ConsumerStatefulWidget {
  const PasswordResetRequestScreen({super.key});

  @override
  ConsumerState<PasswordResetRequestScreen> createState() =>
      _PasswordResetRequestScreenState();
}

class _PasswordResetRequestScreenState
    extends ConsumerState<PasswordResetRequestScreen> {
  final _emailController = TextEditingController();
  bool _busy = false;
  String? _info;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      setState(() => _error = '이메일을 입력해주세요.');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
      _info = null;
    });

    try {
      await AuthService.instance.sendPasswordReset(email);
      if (!mounted) return;
      setState(() {
        _info =
            '$email 주소가 가입된 계정이라면\n재설정 메일을 보냈어요.\n메일함의 링크를 눌러 새 비밀번호를 설정해주세요.';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = '잠시 후 다시 시도해주세요.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('비밀번호 재설정'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppTheme.screenPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 16),
              const Center(
                child: Mascot(pose: MascotPose.front, size: 110),
              ),
              const SizedBox(height: 16),
              Text(
                '가입하신 이메일을 알려주세요.\n재설정 링크를 보내드릴게요.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: AppTheme.textSecondary,
                      height: 1.5,
                    ),
              ),
              const SizedBox(height: 32),
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _submit(),
                decoration: const InputDecoration(
                  hintText: 'example@email.com',
                ),
              ),
              if (_info != null) ...[
                const SizedBox(height: 16),
                _infoBox(_info!),
              ],
              if (_error != null) ...[
                const SizedBox(height: 12),
                _errorRow(_error!),
              ],
              const SizedBox(height: 24),
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
                      : const Text('재설정 메일 받기'),
                ),
              ),
            ],
          ),
        ),
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

  Widget _errorRow(String text) {
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

/// 새 비밀번호 입력 화면.
///
/// 비밀번호 재설정 딥링크로 앱이 열려 임시 세션이 만들어진 직후에 표시된다.
/// 새 비번을 받아 적용하면 정식 로그인 상태가 된다.
class NewPasswordScreen extends ConsumerStatefulWidget {
  const NewPasswordScreen({super.key});

  @override
  ConsumerState<NewPasswordScreen> createState() => _NewPasswordScreenState();
}

class _NewPasswordScreenState extends ConsumerState<NewPasswordScreen> {
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _busy = false;
  String? _error;
  bool _done = false;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    final pw = _passwordController.text;
    final confirm = _confirmController.text;

    if (pw.length < 6) {
      setState(() => _error = '비밀번호는 6자 이상이어야 해요.');
      return;
    }
    if (pw != confirm) {
      setState(() => _error = '비밀번호가 일치하지 않아요.');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      await AuthService.instance.updatePassword(pw);
      if (!mounted) return;
      setState(() => _done = true);
      // 잠깐 안내를 보여준 뒤 플래그를 끄면, main.dart의 분기가 자동으로
      // 다음 화면(로그인 또는 홈)으로 보낸다.
      await Future.delayed(const Duration(milliseconds: 1200));
      if (!mounted) return;
      ref.read(passwordRecoveryProvider.notifier).state = false;
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = '변경에 실패했어요. 잠시 후 다시 시도해주세요.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('새 비밀번호'),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppTheme.screenPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 16),
              const Center(
                child: Mascot(pose: MascotPose.wave, size: 110),
              ),
              const SizedBox(height: 16),
              Text(
                _done
                    ? '비밀번호가 변경됐어요.\n이제 새 비밀번호로 로그인할 수 있어요.'
                    : '새 비밀번호를 입력해주세요.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: AppTheme.textSecondary,
                      height: 1.5,
                    ),
              ),
              if (!_done) ...[
                const SizedBox(height: 28),
                TextField(
                  controller: _passwordController,
                  obscureText: true,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    hintText: '새 비밀번호 (6자 이상)',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _confirmController,
                  obscureText: true,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _submit(),
                  decoration: const InputDecoration(
                    hintText: '한 번 더 입력',
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.error_outline,
                          color: AppTheme.error, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _error!,
                          style: const TextStyle(
                              color: AppTheme.error, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 24),
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
                        : const Text('비밀번호 변경'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}