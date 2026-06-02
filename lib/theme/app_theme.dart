import 'package:flutter/material.dart';

/// 교랑무드 앱 전역 테마.
///
/// 교랑 브랜드의 다크 퍼플 톤을 유지하되, 기분 앱 특성에 맞춰
/// 차분하고 따뜻한 정서를 위한 색상/텍스트 스타일을 정의한다.
/// 모든 화면은 색상을 하드코딩하지 않고 이 클래스를 통해 가져다 쓴다.
class AppTheme {
  AppTheme._();

  // ─────────────────────────────────────────────
  // 브랜드 기본 색상
  // ─────────────────────────────────────────────

  /// 메인 배경 (교랑 패밀리 공통 다크 배경)
  static const Color background = Color(0xFF060610);

  /// 카드/표면 배경 (배경보다 살짝 밝은 톤)
  static const Color surface = Color(0xFF12121F);

  /// 표면 위 한 단계 더 밝은 톤 (입력창, 선택 요소 등)
  static const Color surfaceVariant = Color(0xFF1C1C2E);

  /// 브랜드 액센트 (교랑 퍼플)
  static const Color accent = Color(0xFF7C3AED);

  /// 액센트 밝은 변형 (강조, 하이라이트)
  static const Color accentLight = Color(0xFF9F67FF);

  /// 액센트 어두운 변형 (눌림 상태 등)
  static const Color accentDark = Color(0xFF5B21B6);

  // ─────────────────────────────────────────────
  // 텍스트 색상
  // ─────────────────────────────────────────────

  /// 기본 텍스트 (제목, 본문)
  static const Color textPrimary = Color(0xFFF5F5FA);

  /// 보조 텍스트 (설명, 부가 정보)
  static const Color textSecondary = Color(0xFFA0A0B8);

  /// 흐린 텍스트 (placeholder, 비활성)
  static const Color textTertiary = Color(0xFF6B6B82);

  // ─────────────────────────────────────────────
  // 상태 색상
  // ─────────────────────────────────────────────

  static const Color error = Color(0xFFEF4444);
  static const Color success = Color(0xFF22C55E);
  static const Color divider = Color(0xFF26263A);

  // ─────────────────────────────────────────────
  // 기분 단계별 색상 (1=아주 나쁨 ~ 5=아주 좋음)
  //
  // 돌아보기 달력에서 그날의 기분을 색으로 칠하는 데 사용한다.
  // 어두운 톤 → 밝고 따뜻한 톤으로 자연스럽게 이어지도록 구성.
  // ─────────────────────────────────────────────

  /// 아주 나쁨
  static const Color mood1 = Color(0xFF3B3654);

  /// 나쁨
  static const Color mood2 = Color(0xFF5B4B8A);

  /// 보통
  static const Color mood3 = Color(0xFF7C6FD6);

  /// 좋음
  static const Color mood4 = Color(0xFFB089F0);

  /// 아주 좋음
  static const Color mood5 = Color(0xFFE9B8F5);

  /// 기분 값(1~5)에 해당하는 색상을 반환한다.
  /// 범위를 벗어나면 '보통'(mood3) 색을 반환한다.
  static Color moodColor(int level) {
    switch (level) {
      case 1:
        return mood1;
      case 2:
        return mood2;
      case 3:
        return mood3;
      case 4:
        return mood4;
      case 5:
        return mood5;
      default:
        return mood3;
    }
  }

  /// 기분 값(1~5)에 해당하는 한글 라벨을 반환한다.
  static String moodLabel(int level) {
    switch (level) {
      case 1:
        return '아주 나쁨';
      case 2:
        return '나쁨';
      case 3:
        return '보통';
      case 4:
        return '좋음';
      case 5:
        return '아주 좋음';
      default:
        return '보통';
    }
  }

  // ─────────────────────────────────────────────
  // 공통 디자인 토큰
  // ─────────────────────────────────────────────

  /// 기본 모서리 둥글기
  static const double radius = 16.0;

  /// 작은 모서리 둥글기
  static const double radiusSmall = 10.0;

  /// 기본 화면 좌우 여백
  static const double screenPadding = 24.0;

  // ─────────────────────────────────────────────
  // ThemeData
  // ─────────────────────────────────────────────

  static ThemeData get theme {
    final base = ThemeData.dark(useMaterial3: true);

    return base.copyWith(
      scaffoldBackgroundColor: background,
      colorScheme: const ColorScheme.dark(
        surface: surface,
        primary: accent,
        secondary: accentLight,
        error: error,
        onSurface: textPrimary,
        onPrimary: Colors.white,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: background,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: textPrimary),
        titleTextStyle: TextStyle(
          color: textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
        ),
        margin: EdgeInsets.zero,
      ),
      dividerColor: divider,
      textTheme: const TextTheme(
        headlineMedium: TextStyle(
          color: textPrimary,
          fontSize: 24,
          fontWeight: FontWeight.w700,
          height: 1.3,
        ),
        titleLarge: TextStyle(
          color: textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w600,
          height: 1.4,
        ),
        titleMedium: TextStyle(
          color: textPrimary,
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
        bodyLarge: TextStyle(
          color: textPrimary,
          fontSize: 16,
          height: 1.6,
        ),
        bodyMedium: TextStyle(
          color: textSecondary,
          fontSize: 14,
          height: 1.6,
        ),
        bodySmall: TextStyle(
          color: textTertiary,
          fontSize: 12,
          height: 1.5,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radius),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: accentLight,
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceVariant,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        hintStyle: const TextStyle(color: textTertiary, fontSize: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: const BorderSide(color: accent, width: 1.5),
        ),
      ),
    );
  }
}