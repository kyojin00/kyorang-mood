import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'theme/app_theme.dart';
import 'services/mood_storage.dart';
import 'services/comfort_prefs.dart';
import 'services/comfort_realtime.dart';
import 'services/profile_storage.dart';
import 'providers/profile_provider.dart';
import 'providers/auth_provider.dart';
import 'providers/comfort_provider.dart';
import 'screens/auth/auth_screen.dart';
import 'screens/auth/password_reset_screen.dart';
import 'screens/onboarding/onboarding_screen.dart';
import 'screens/moody/moody_screen.dart';
import 'utils/app_snackbar.dart';

const String _supabaseUrl = 'https://aqnsodvbfieimkjjcebf.supabase.co';
const String _supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImFxbnNvZHZiZmllaW1rampjZWJmIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODAyOTYyNDQsImV4cCI6MjA5NTg3MjI0NH0.a5B6OH0vB_B0ijb8oLr957-ATNf21CLPrI9EPG8BvEw';


/// 비밀번호 재설정 중인지를 앱 전역에서 알리는 프로바이더.
class PasswordRecoveryNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void set(bool value) {
    state = value;
  }
}

final passwordRecoveryProvider =
    NotifierProvider<PasswordRecoveryNotifier, bool>(
  PasswordRecoveryNotifier.new,
);

/// 인증 링크 만료 등 사용자에게 보여줄 에러 메시지를 담는 프로바이더.
class AuthErrorNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void set(String? message) {
    state = message;
  }
}

final authErrorProvider =
    NotifierProvider<AuthErrorNotifier, String?>(AuthErrorNotifier.new);

/// 앱 전역 Navigator 키.
/// 인증 이벤트(비밀번호 재설정 등)가 들어왔을 때, 현재 위에 쌓여 있을 수 있는
/// 라우트(PasswordResetRequestScreen 등)를 깨끗이 비우기 위해 사용한다.
final GlobalKey<NavigatorState> appNavigatorKey =
    GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Hive.initFlutter();
  await MoodStorage.instance.init();
  await ProfileStorage.instance.init();
  await ComfortPrefs.instance.init();

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

class KyorangMoodApp extends ConsumerStatefulWidget {
  const KyorangMoodApp({super.key});

  @override
  ConsumerState<KyorangMoodApp> createState() => _KyorangMoodAppState();
}

class _KyorangMoodAppState extends ConsumerState<KyorangMoodApp> {
  final _appLinks = AppLinks();

  @override
  void initState() {
    super.initState();

    // 1) 들어오는 딥링크 — 메일 링크에 type=recovery가 명시적으로 박혀 있는
    //    경우를 위한 백업. PKCE 플로우에선 보통 ?code=xxx 만 오므로 안 잡힐 수
    //    있으나, 2번 onAuthStateChange의 passwordRecovery 이벤트가 진짜
    //    동작하는 경로다.
    _appLinks.uriLinkStream.listen((uri) {
      _checkRecoveryLink(uri);
    });

    // 2) 앱이 죽어 있다가 링크로 켜진 경우의 초기 URL도 확인.
    _appLinks.getInitialLink().then((uri) {
      if (uri != null) _checkRecoveryLink(uri);
    });

    // 3) Supabase가 던지는 인증 이벤트를 듣는다.
    //    - passwordRecovery: 비밀번호 재설정 링크로 들어와 세션이 만들어진 직후.
    //      이걸 잡아서 플래그를 켜야 _RootScreen이 새 비밀번호 화면을 띄운다.
    //      또한 위에 쌓여있을 수 있는 라우트(PasswordResetRequestScreen 등)를
    //      비워서 NewPasswordScreen이 가려지지 않도록 한다.
    //    - 에러: 만료된 링크 등 사용자에게 안내할 케이스.
    Supabase.instance.client.auth.onAuthStateChange.listen(
      (data) {
        if (data.event == AuthChangeEvent.passwordRecovery) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _enterPasswordRecovery();
          });
        }
      },
      onError: (error) {
        if (error is AuthException) {
          final code = error.code ?? '';
          final msg = error.message.toLowerCase();
          String userMessage;
          if (code == 'otp_expired' ||
              msg.contains('expired') ||
              msg.contains('invalid')) {
            userMessage = '재설정 링크가 만료됐거나 이미 사용됐어요.\n다시 한 번 메일을 받아주세요.';
          } else {
            userMessage = '인증 처리에 실패했어요. 다시 시도해주세요.';
          }
          WidgetsBinding.instance.addPostFrameCallback((_) {
            ref.read(authErrorProvider.notifier).set(userMessage);
          });
        }
      },
    );
  }

  void _checkRecoveryLink(Uri uri) {
    if (uri.scheme != 'kyorang') return;
    final type = uri.queryParameters['type'];
    if (type == 'recovery') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _enterPasswordRecovery();
      });
    }
  }

  /// 비밀번호 재설정 진입 처리.
  /// (1) 위에 쌓여있을 수 있는 라우트를 root까지 비우고
  /// (2) 플래그를 켜서 _RootScreen이 NewPasswordScreen으로 전환되게 한다.
  void _enterPasswordRecovery() {
    // 라우트 정리 — PasswordResetRequestScreen 등이 떠있어도 깨끗이 닫힌다.
    appNavigatorKey.currentState?.popUntil((route) => route.isFirst);
    // 플래그 켜기 — _RootScreen.build에서 recovering 분기가 우선 처리됨.
    ref.read(passwordRecoveryProvider.notifier).set(true);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '교랑무드',
      debugShowCheckedModeBanner: false,
      navigatorKey: appNavigatorKey,
      theme: AppTheme.theme,
      home: const _RootScreen(),
    );
  }
}

/// 루트 분기 화면.
///
/// 로그인 상태에 맞춰 위로 도착 실시간 구독(ComfortRealtime)을 켜고 끈다.
/// 신호가 오면 unreadComfortCountProvider 를 무효화해 뱃지를 즉시 갱신한다.
/// 앱이 백그라운드에 갔다 돌아오면 끊겼을 수 있는 소켓을 재구독한다.
class _RootScreen extends ConsumerStatefulWidget {
  const _RootScreen();

  @override
  ConsumerState<_RootScreen> createState() => _RootScreenState();
}

class _RootScreenState extends ConsumerState<_RootScreen>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // 첫 프레임 후 현재 로그인 상태에 맞춰 구독 시작.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncRealtimeSubscription();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    ComfortRealtime.instance.stop();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // 백그라운드에서 돌아오면 끊겼을 수 있는 실시간 채널을 재구독.
    if (state == AppLifecycleState.resumed) {
      _syncRealtimeSubscription();
    }
  }

  /// 로그인 상태면 위로 채널을 구독, 아니면 해제한다.
  Future<void> _syncRealtimeSubscription() async {
    final loggedIn = Supabase.instance.client.auth.currentUser != null;
    if (loggedIn) {
      await ComfortRealtime.instance.start(
        onReceived: () {
          // 위로 도착 → 뱃지 즉시 갱신
          if (mounted) {
            ref.invalidate(unreadComfortCountProvider);
          }
        },
      );
    } else {
      await ComfortRealtime.instance.stop();
    }
  }

  @override
  Widget build(BuildContext context) {
    // 인증 에러가 있으면 한 번 다이얼로그로 보여주고 비운다.
    ref.listen<String?>(authErrorProvider, (prev, next) {
      if (next != null && next.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          showAppSnack(context, next, duration: const Duration(seconds: 4));
          ref.read(authErrorProvider.notifier).set(null);
        });
      }
    });

    // 로그인 상태가 바뀌면(로그인/로그아웃) 구독을 다시 맞춘다.
    ref.listen<bool>(isLoggedInProvider, (prev, next) {
      _syncRealtimeSubscription();
    });

    final recovering = ref.watch(passwordRecoveryProvider);
    if (recovering) {
      return const NewPasswordScreen();
    }

    final loggedIn = ref.watch(isLoggedInProvider);
    if (!loggedIn) {
      return const AuthScreen();
    }

    final onboardingDone = ref.watch(onboardingDoneProvider);
    return onboardingDone ? const MoodyScreen() : const OnboardingScreen();
  }
}