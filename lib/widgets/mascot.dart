import 'dart:math' as math;

import 'package:flutter/material.dart';

/// 마스코트 포즈 (이미지 종류).
///
/// AI로 생성한 통짜 이미지를 상황에 맞게 보여준다.
/// 새 포즈 이미지를 추가하면 여기에 항목과 경로를 늘리면 된다.
enum MascotPose {
  /// 기본 자세
  defaultPose,

  /// 손 흔드는 (인사/반가움)
  wave,

  /// 정면 (차분/대기)
  front,
}

/// 포즈별 이미지 경로
String _assetFor(MascotPose pose) {
  switch (pose) {
    case MascotPose.defaultPose:
      return 'assets/mascot/cat_default.png';
    case MascotPose.wave:
      return 'assets/mascot/cat_wave.png';
    case MascotPose.front:
      return 'assets/mascot/cat_front.png';
  }
}

/// 교랑무드 마스코트 (이미지 기반).
///
/// AI로 만든 고양이 일러스트를 띄우며, 살짝 둥실거린다.
/// 표정/스킨 변경은 [pose] 또는 [assetOverride]로 다른 이미지를 지정한다.
/// 꾸미기에서 구매한 스킨은 [assetOverride]로 경로를 넘겨 교체한다.
class Mascot extends StatefulWidget {
  /// 보여줄 기본 포즈
  final MascotPose pose;

  /// 직접 지정할 이미지 경로 (꾸미기 스킨 등). 있으면 pose보다 우선.
  final String? assetOverride;

  /// 크기 (가로=세로 기준)
  final double size;

  /// 둥실 애니메이션 사용 여부
  final bool animate;

  const Mascot({
    super.key,
    this.pose = MascotPose.defaultPose,
    this.assetOverride,
    this.size = 180,
    this.animate = true,
  });

  @override
  State<Mascot> createState() => _MascotState();
}

class _MascotState extends State<Mascot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    );
    if (widget.animate) _controller.repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final asset = widget.assetOverride ?? _assetFor(widget.pose);

    final image = Image.asset(
      asset,
      width: widget.size,
      height: widget.size,
      fit: BoxFit.contain,
      // 이미지가 아직 없거나 경로 오류일 때 빈 자리로 처리
      errorBuilder: (context, error, stack) => SizedBox(
        width: widget.size,
        height: widget.size,
      ),
    );

    if (!widget.animate) return image;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final bob = math.sin(_controller.value * 2 * math.pi) * 6;
        return Transform.translate(
          offset: Offset(0, bob),
          child: child,
        );
      },
      child: image,
    );
  }
}