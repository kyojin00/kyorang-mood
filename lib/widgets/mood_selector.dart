import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// 기분 선택 위젯.
///
/// 1~5단계의 기분을 색 원 + 미니멀한 표정선으로 표현하고,
/// 사용자가 하나를 탭해 고를 수 있게 한다.
/// 표정은 이미지 없이 CustomPainter로 직접 그려 에셋이 필요 없다.
class MoodSelector extends StatelessWidget {
  final int? selected;
  final ValueChanged<int> onSelected;

  const MoodSelector({
    super.key,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(5, (i) {
        final level = i + 1;
        final isSelected = selected == level;
        return _MoodCircle(
          level: level,
          isSelected: isSelected,
          dimmed: selected != null && !isSelected,
          onTap: () => onSelected(level),
        );
      }),
    );
  }
}

class _MoodCircle extends StatelessWidget {
  final int level;
  final bool isSelected;
  final bool dimmed;
  final VoidCallback onTap;

  const _MoodCircle({
    required this.level,
    required this.isSelected,
    required this.dimmed,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = AppTheme.moodColor(level);
    final size = isSelected ? 60.0 : 52.0;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: dimmed ? color.withValues(alpha: 0.35) : color,
              shape: BoxShape.circle,
              border: isSelected
                  ? Border.all(color: AppTheme.textPrimary, width: 2.5)
                  : null,
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: color.withValues(alpha: 0.5),
                        blurRadius: 16,
                        spreadRadius: 1,
                      ),
                    ]
                  : null,
            ),
            child: CustomPaint(
              painter: MoodFacePainter(
                level: level,
                color: AppTheme.background,
                opacity: dimmed ? 0.5 : 1.0,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            AppTheme.moodLabel(level),
            style: TextStyle(
              fontSize: 11,
              color:
                  isSelected ? AppTheme.textPrimary : AppTheme.textTertiary,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }
}

/// 기분 표정만 그리는 재사용 위젯.
///
/// 원(배경 색)은 호출하는 쪽에서 그리고, 이 위젯은 그 위에 표정선만 얹는다.
/// 큰 기분 원 등 다른 화면에서도 동일한 표정을 쓸 수 있다.
class MoodFace extends StatelessWidget {
  /// 기분 값 (1~5)
  final int level;

  /// 표정 선 색
  final Color color;

  /// 위젯 크기 (가로=세로)
  final double size;

  const MoodFace({
    super.key,
    required this.level,
    required this.color,
    this.size = 56,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: MoodFacePainter(level: level, color: color),
      ),
    );
  }
}

/// 기분 단계에 따라 표정선을 그리는 페인터.
///
/// 두 눈(점)과 입(곡선)을 그린다.
/// 입꼬리가 level 1(찡그림) → level 5(웃음)로 점점 올라간다.
class MoodFacePainter extends CustomPainter {
  final int level;
  final Color color;
  final double opacity;

  MoodFacePainter({
    required this.level,
    required this.color,
    this.opacity = 1.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: opacity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.04
      ..strokeCap = StrokeCap.round;

    final w = size.width;
    final h = size.height;

    // 두 눈 (작은 점)
    final eyeY = h * 0.4;
    final eyeR = w * 0.045;
    final dotPaint = Paint()
      ..color = color.withValues(alpha: opacity)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(w * 0.36, eyeY), eyeR, dotPaint);
    canvas.drawCircle(Offset(w * 0.64, eyeY), eyeR, dotPaint);

    // 입 (곡선). level이 높을수록 위로 볼록한 웃는 입.
    final mouthY = h * 0.62;
    final startX = w * 0.34;
    final endX = w * 0.66;

    // -1.0(찡그림) ~ +1.0(웃음)
    final curve = (level - 3) / 2.0;
    final controlY = mouthY + (curve * h * 0.18);

    final path = Path()
      ..moveTo(startX, mouthY)
      ..quadraticBezierTo(w * 0.5, controlY, endX, mouthY);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(MoodFacePainter old) =>
      old.level != level || old.opacity != opacity || old.color != color;
}