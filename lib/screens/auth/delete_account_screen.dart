import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;

import '../../main.dart' show appNavigatorKey;
import '../../theme/app_theme.dart';
import '../../providers/profile_provider.dart';
import '../../services/auth_service.dart';
import '../../services/mood_storage.dart';
import '../../services/comfort_prefs.dart';
import '../../widgets/mascot.dart';

/// 계정 삭제 화면.
///
/// 흐름:
///   1) 사용자가 "삭제"를 직접 타이핑하면 활성화되는 빨간 버튼.
///   2) 버튼을 누르면 서버 RPC로 auth.users 삭제 + 로컬 캐시 정리 + 프로필 reset.
///   3) signOut으로 세션 정리 → _RootScreen이 내부 화면을 AuthScreen으로 바꿈.
///   4) 라우트 스택을 root까지 비워 위에 쌓인 Settings/DeleteAccount 화면을 제거.
///   5) AuthScreen 위에 "계정이 삭제됐어요" 다이얼로그를 root navigator로 띄움.
///      → 사용자가 확인 누르면 AuthScreen만 남는다.
class DeleteAccountScreen extends ConsumerStatefulWidget {
  const DeleteAccountScreen({super.key});

  @override
  ConsumerState<DeleteAccountScreen> createState() =>
      _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends ConsumerState<DeleteAccountScreen> {
  static const String _confirmKeyword = '삭제';

  final _confirmController = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _confirmController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _confirmController.dispose();
    super.dispose();
  }

  bool get _canConfirm =>
      !_busy && _confirmController.text.trim() == _confirmKeyword;

  Future<void> _delete() async {
    if (!_canConfirm) return;

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      // 1) 서버에서 계정 삭제 (auth.users + 외래키 cascade로 모든 데이터)
      await AuthService.instance.deleteAccount();

      // 2) 로컬 캐시 정리 + 프로필 state 리셋 (재가입 시 온보딩 다시 뜨도록)
      await _clearLocalCaches();

      // 3) 세션 정리 → _RootScreen 내부 화면이 AuthScreen으로 자동 전환
      await AuthService.instance.signOut();

      // 4) 위에 쌓인 라우트(SettingsScreen, DeleteAccountScreen)를 root까지 비움.
      //    이게 없으면 _RootScreen 내부는 AuthScreen이 됐어도 사용자 눈엔
      //    여전히 DeleteAccountScreen이 보인다.
      appNavigatorKey.currentState?.popUntil((route) => route.isFirst);

      // 5) AuthScreen 위에 "삭제됐어요" 다이얼로그
      await _showDeletedDialog();
    } on PostgrestException catch (e) {
      if (!mounted) return;
      setState(() => _error = '삭제에 실패했어요.\n(${e.message})');
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = '잠시 후 다시 시도해주세요.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// 모든 로컬 Hive 박스를 비우고 profile state도 리셋한다.
  /// ProfileNotifier.reset()이 Storage clear + state 갱신을 함께 처리한다.
  Future<void> _clearLocalCaches() async {
    try {
      await MoodStorage.instance.clear();
    } catch (_) {}
    try {
      // Storage.clear() + state를 UserProfile.empty()로 리셋 →
      // onboardingDoneProvider가 false가 되어 재가입 시 온보딩이 다시 뜬다.
      await ref.read(profileProvider.notifier).reset();
    } catch (_) {}
    try {
      await ComfortPrefs.instance.clear();
    } catch (_) {}
  }

  /// 삭제 완료 안내 다이얼로그.
  /// root navigator의 context를 사용하므로 DeleteAccountScreen이
  /// 이미 unmount 되었어도 안전하게 표시된다.
  Future<void> _showDeletedDialog() async {
    final rootCtx = appNavigatorKey.currentContext;
    if (rootCtx == null) return;

    await showDialog<void>(
      context: rootCtx,
      barrierDismissible: false,
      builder: (dialogCtx) {
        return AlertDialog(
          backgroundColor: AppTheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            '계정이 삭제됐어요',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          content: const Text(
            '그동안 함께해줘서 고마워요.\n언제든 다시 돌아와도 좋아요.',
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 14,
              height: 1.5,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(),
              style: TextButton.styleFrom(
                foregroundColor: AppTheme.accentLight,
              ),
              child: const Text('확인'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('계정 삭제'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppTheme.screenPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 12),
              const Center(child: Mascot(pose: MascotPose.front, size: 110)),
              const SizedBox(height: 16),
              Text(
                '정말 떠나시는 거예요?',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 24),

              _warningBox(),

              const SizedBox(height: 24),
              Text(
                '계속하시려면 아래에 "$_confirmKeyword"라고 입력해주세요.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppTheme.textSecondary,
                    ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _confirmController,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _delete(),
                decoration: const InputDecoration(
                  hintText: _confirmKeyword,
                ),
              ),

              if (_error != null) ...[
                const SizedBox(height: 16),
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

              const SizedBox(height: 28),

              // 삭제 버튼 (위험 컬러)
              SizedBox(
                height: 54,
                child: ElevatedButton(
                  onPressed: _canConfirm ? _delete : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.error,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor:
                        AppTheme.error.withValues(alpha: 0.3),
                    disabledForegroundColor: Colors.white70,
                  ),
                  child: _busy
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          '계정 영구 삭제',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 48,
                child: TextButton(
                  onPressed: _busy ? null : () => Navigator.of(context).pop(),
                  child: Text(
                    '돌아갈게요',
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _warningBox() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: AppTheme.error.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
        border: Border.all(
          color: AppTheme.error.withValues(alpha: 0.5),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.warning_amber_rounded,
                  color: AppTheme.error, size: 22),
              const SizedBox(width: 8),
              Text(
                '삭제하면 되돌릴 수 없어요',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: AppTheme.error,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _bullet('지금까지 쓴 일기와 무디와의 대화가 모두 사라져요.'),
          _bullet('받은 위로와 띄운 위로 요청도 함께 사라져요.'),
          _bullet('같은 이메일로 다시 가입할 수는 있지만, 이전 기록은 복구되지 않아요.'),
          _bullet('진행 중인 구독이 있다면 별도로 해지해주세요. (스토어에서)'),
        ],
      ),
    );
  }

  Widget _bullet(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '• ',
            style: TextStyle(color: AppTheme.error, fontWeight: FontWeight.bold),
          ),
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
}