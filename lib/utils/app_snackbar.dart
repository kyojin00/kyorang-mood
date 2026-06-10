import 'package:flutter/material.dart';

/// 앱 전체에서 일관된 스타일의 하단 알림(SnackBar)을 보여준다.
///
/// 다크 테마 배경과 대비되도록 흰 배경 + 진한 텍스트로 가독성 확보.
/// floating behavior 로 둥근 카드 모양으로 뜨고, 새 메시지가 오면
/// 이전 메시지는 즉시 사라진다(겹치지 않게).
///
/// 사용법:
///   showAppSnack(context, '따뜻한 마음을 전했어요.');
void showAppSnack(
  BuildContext context,
  String message, {
  Duration duration = const Duration(seconds: 2),
}) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;

  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(
    SnackBar(
      content: Text(
        message,
        style: const TextStyle(
          color: Color(0xFF1A1A1A),
          fontSize: 14,
          fontWeight: FontWeight.w600,
          height: 1.4,
        ),
      ),
      backgroundColor: Colors.white,
      behavior: SnackBarBehavior.floating,
      elevation: 8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
      ),
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      duration: duration,
    ),
  );
}