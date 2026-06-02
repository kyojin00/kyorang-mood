import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'theme/app_theme.dart';
import 'services/mood_storage.dart';
import 'services/profile_storage.dart';
import 'providers/profile_provider.dart';
import 'providers/auth_provider.dart';
import 'screens/auth/auth_screen.dart';
import 'screens/onboarding/onboarding_screen.dart';
import 'screens/home/home_screen.dart';

/// 교랑무드 Supabase 프로젝트 설정.
const String _supabaseUrl = 'https://aqnsodvbfieimkjjcebf.supabase.co';
const String _supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImFxbnNvZHZiZmllaW1rampjZWJmIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODAyOTYyNDQsImV4cCI6MjA5NTg3MjI0NH0.a5B6OH0vB_B0ijb8oLr957-ATNf21CLPrI9EPG8BvEw';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Hive.initFlutter();
  await MoodStorage.instance.init();
  await ProfileStorage.instance.init();

  // Supabase 초기화 + 딥링크 인증 흐름(PKCE) 활성화.
  // 사용자가 이메일 인증 링크(kyorang://auth-callback?...)를 누르면
  // SDK가 자동으로 토큰을 읽어 로그인 세션을 만든다.
  await Supabase.initialize(
    url: _supabaseUrl,
    anonKey: _supabaseAnonKey,
    authOptions: const FlutterAuthClientOptions(
      authFlowType: AuthFlowType.pkce,
    ),
  );

  runApp(
    const ProviderScope(
      child: KyorangMoodApp(),
    ),
  );
}

class KyorangMoodApp extends StatelessWidget {
  const KyorangMoodApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '교랑무드',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme,
      home: const _RootScreen(),
    );
  }
}

/// 루트 분기 화면.
///
/// 1) 로그인 안 함        → 로그인/회원가입 화면
/// 2) 로그인했으나 온보딩 전 → 온보딩
/// 3) 로그인 + 온보딩 완료  → 홈
///
/// 사용자가 이메일 인증 링크를 눌러 앱이 열리면 Supabase SDK가
/// 자동으로 세션을 만들고, 그 변화가 isLoggedInProvider에 반영되어
/// 화면이 자동으로 다음 단계로 넘어간다.
class _RootScreen extends ConsumerWidget {
  const _RootScreen();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loggedIn = ref.watch(isLoggedInProvider);
    if (!loggedIn) {
      return const AuthScreen();
    }

    final onboardingDone = ref.watch(onboardingDoneProvider);
    return onboardingDone ? const HomeScreen() : const OnboardingScreen();
  }
}