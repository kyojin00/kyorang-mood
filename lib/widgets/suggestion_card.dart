import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// 맞춤 제안 카드.
///
/// 기록 확인 화면에서 성향에 맞는 제안을 보여주고,
/// 사용자가 "도움이 됐는지"를 표시할 수 있게 한다.
/// (반응은 부모가 저장하며, 추후 추천 보정에 사용한다.)
class SuggestionCard extends StatelessWidget {
  /// 보여줄 제안 문구
  final String suggestion;

  /// 사용자 반응. null = 아직 답 안 함, true = 도움 됨, false = 별로.
  final bool? helpful;

  /// 반응을 눌렀을 때 호출 (true/false 전달)
  final ValueChanged<bool> onReact;

  const SuggestionCard({
    super.key,
    required this.suggestion,
    required this.helpful,
    required this.onReact,
  });

  bool get _answered => helpful != null;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(color: AppTheme.divider, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '당신을 위한 한마디',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppTheme.accentLight,
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 12),
          Text(
            suggestion,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  height: 1.7,
                ),
          ),
          const SizedBox(height: 20),
          const Divider(height: 1),
          const SizedBox(height: 12),
          _answered ? _buildAnswered(context) : _buildButtons(context),
        ],
      ),
    );
  }

  // 반응 전: 두 개의 버튼
  Widget _buildButtons(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _ReactButton(
            label: '도움이 됐어요',
            onTap: () => onReact(true),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _ReactButton(
            label: '그냥 그래요',
            onTap: () => onReact(false),
          ),
        ),
      ],
    );
  }

  // 반응 후: 짧은 확인 문구
  Widget _buildAnswered(BuildContext context) {
    final message = helpful == true ? '도움이 되었다니 다행이에요.' : '알려줘서 고마워요.';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Text(
        message,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppTheme.textSecondary,
            ),
      ),
    );
  }
}

class _ReactButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _ReactButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppTheme.surfaceVariant,
          borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.w500,
              ),
        ),
      ),
    );
  }
}