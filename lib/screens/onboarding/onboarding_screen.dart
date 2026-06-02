import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../theme/app_theme.dart';
import '../../models/mood_entry.dart';
import '../../models/user_profile.dart';
import '../../providers/profile_provider.dart';

/// 온보딩 화면.
///
/// 질문 3개로 사용자 성향과 선호 시간대를 파악한다.
/// - 질문 1: 주 신호 (성향에 +2)
/// - 질문 2: 보조 신호 (관련 성향에 +1)
/// - 질문 3: 선호 시간대 (분류와 무관, 비서 기능용)
/// 마지막 답을 고르면 성향을 분류해 프로필에 저장한다.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  /// 현재 질문 단계 (0, 1, 2)
  int _step = 0;

  /// 질문 1 답 (주 신호로 쓰일 성향)
  SuggestionType? _q1;

  /// 질문 2 답 (보조 신호: 성향별 가중치)
  Map<SuggestionType, int>? _q2Weights;

  /// 질문 3 답 (선호 시간대)
  PreferredTime? _q3;

  bool _saving = false;

  // ── 질문 1 선택지 ──
  // 각 선택지가 하나의 성향에 직접 대응한다.
  static const List<(String, SuggestionType)> _q1Options = [
    ('마음에 와닿는 말이나 글을 읽는 것', SuggestionType.quote),
    ('잠시 멈추고 혼자 쉬는 것', SuggestionType.rest),
    ('몸을 움직이거나 뭔가 해보는 것', SuggestionType.activity),
    ('누군가와 이야기하거나 연결되는 것', SuggestionType.connect),
  ];

  // ── 질문 2 선택지 ──
  // 보조 신호. 관련 성향에 가중치 +1.
  static const List<(String, Map<SuggestionType, int>)> _q2Options = [
    ('혼자 있는 게 편하다', {SuggestionType.rest: 1, SuggestionType.quote: 1}),
    ('누군가 곁에 있으면 좋겠다', {SuggestionType.connect: 1}),
    ('뭐든 하면서 잊는 게 낫다', {SuggestionType.activity: 1}),
  ];

  // ── 질문 3 선택지 ──
  static const List<(String, PreferredTime)> _q3Options = [
    ('아침, 하루를 시작할 때', PreferredTime.morning),
    ('저녁, 하루를 마무리할 때', PreferredTime.evening),
    ('힘들 때마다 그때그때', PreferredTime.anytime),
  ];

  /// 점수를 합산해 성향을 분류한다.
  /// 질문 1(+2)을 기준으로 하고, 동점 시 질문 1을 우선한다.
  SuggestionType _classify() {
    final scores = <SuggestionType, int>{
      for (final t in SuggestionType.values) t: 0,
    };
    scores[_q1!] = scores[_q1!]! + 2;
    _q2Weights?.forEach((type, w) {
      scores[type] = scores[type]! + w;
    });

    var best = _q1!;
    var bestScore = scores[_q1!]!;
    for (final t in SuggestionType.values) {
      if (scores[t]! > bestScore) {
        best = t;
        bestScore = scores[t]!;
      }
    }
    return best;
  }

  Future<void> _finish() async {
    if (_saving) return;
    setState(() => _saving = true);

    final persona = _classify();
    await ref.read(profileProvider.notifier).completeOnboarding(
          persona: persona,
          preferredTime: _q3!,
        );
    // 저장 후에는 main의 분기가 자동으로 홈 화면으로 전환한다.
  }

  void _next() {
    if (_step < 2) {
      setState(() => _step++);
    } else {
      _finish();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.screenPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              _buildProgress(),
              const SizedBox(height: 40),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: _buildStep(context),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 진행 표시 (점 3개)
  Widget _buildProgress() {
    return Row(
      children: List.generate(3, (i) {
        final active = i <= _step;
        return Container(
          margin: const EdgeInsets.only(right: 8),
          width: active ? 28 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: active ? AppTheme.accent : AppTheme.surfaceVariant,
            borderRadius: BorderRadius.circular(4),
          ),
        );
      }),
    );
  }

  Widget _buildStep(BuildContext context) {
    switch (_step) {
      case 0:
        return _buildQuestion<SuggestionType>(
          key: const ValueKey(0),
          title: '기분이 가라앉을 때,\n무엇이 가장 도움이 되나요?',
          options: _q1Options,
          selectedValue: _q1,
          onSelect: (value) {
            setState(() => _q1 = value);
            Future.delayed(const Duration(milliseconds: 200), _next);
          },
        );
      case 1:
        return _buildQuestion<Map<SuggestionType, int>>(
          key: const ValueKey(1),
          title: '힘들 때 당신은\n보통 어떤 편인가요?',
          options: _q2Options,
          selectedValue: _q2Weights,
          onSelect: (value) {
            setState(() => _q2Weights = value);
            Future.delayed(const Duration(milliseconds: 200), _next);
          },
        );
      case 2:
      default:
        return _buildQuestion<PreferredTime>(
          key: const ValueKey(2),
          title: '교랑무드를\n주로 언제 열 것 같나요?',
          options: _q3Options,
          selectedValue: _q3,
          onSelect: (value) {
            setState(() => _q3 = value);
            Future.delayed(const Duration(milliseconds: 200), _next);
          },
        );
    }
  }

  /// 질문 한 단계를 그린다. 제네릭으로 선택지 값 타입을 받는다.
  Widget _buildQuestion<T>({
    required Key key,
    required String title,
    required List<(String, T)> options,
    required T? selectedValue,
    required ValueChanged<T> onSelect,
  }) {
    return Column(
      key: key,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 32),
        ...options.map((opt) {
          final label = opt.$1;
          final value = opt.$2;
          final isSelected = selectedValue == value;
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _OptionTile(
              label: label,
              isSelected: isSelected,
              onTap: _saving ? null : () => onSelect(value),
            ),
          );
        }),
      ],
    );
  }
}

/// 온보딩 선택지 한 개.
class _OptionTile extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback? onTap;

  const _OptionTile({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.accentDark : AppTheme.surface,
          borderRadius: BorderRadius.circular(AppTheme.radius),
          border: Border.all(
            color: isSelected ? AppTheme.accent : AppTheme.divider,
            width: 1.5,
          ),
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: AppTheme.textPrimary,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              ),
        ),
      ),
    );
  }
}