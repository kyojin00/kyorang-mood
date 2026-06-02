import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../theme/app_theme.dart';
import '../../providers/mood_provider.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/mascot.dart';
import '../history/history_screen.dart';
import '../counsel/counsel_screen.dart';
import '../settings/settings_screen.dart';
import 'chat_record_screen.dart';

/// 허브 홈 화면.
///
/// 중앙에 마스코트(고양이)가 떠 있고, 오늘 기분 기록 여부에 따라
/// 포즈와 한마디가 달라진다. 하단의 버튼으로 각 기능에 진입한다.
/// 우상단에 사용자 이름과 설정 버튼을 둔다.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final today = ref.watch(todayEntriesProvider);
    final recorded = today.isNotEmpty;
    final lastMood = recorded ? today.first.moodLevel : null;
    final userName = ref.watch(userNameProvider);

    final tint =
        lastMood != null ? AppTheme.moodColor(lastMood) : AppTheme.accent;

    final MascotPose pose =
        recorded ? MascotPose.front : MascotPose.wave;
    final String message = recorded
        ? '$userName님,\n오늘도 기록해줘서 고마워요.'
        : '${_greeting()}, $userName님.\n오늘 기분은 어때요?';

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Container(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(0, -0.5),
            radius: 1.0,
            colors: [
              tint.withValues(alpha: 0.22),
              AppTheme.background,
            ],
            stops: const [0.0, 0.7],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppTheme.screenPadding),
            child: Column(
              children: [
                const SizedBox(height: 4),
                // 상단 바: 좌측 '교랑무드' / 우측 이름 + 설정
                Row(
                  children: [
                    Text(
                      '교랑무드',
                      style:
                          Theme.of(context).textTheme.titleMedium?.copyWith(
                                color: AppTheme.textSecondary,
                              ),
                    ),
                    const Spacer(),
                    Text(
                      '$userName님',
                      style:
                          Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: AppTheme.textSecondary,
                              ),
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      icon: const Icon(
                        Icons.settings_outlined,
                        size: 22,
                        color: AppTheme.textSecondary,
                      ),
                      visualDensity: VisualDensity.compact,
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const SettingsScreen(),
                        ),
                      ),
                    ),
                  ],
                ),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _speechBubble(context, message),
                      const SizedBox(height: 12),
                      Mascot(pose: pose, size: 200),
                    ],
                  ),
                ),
                Row(
                  children: [
                    Expanded(
                      child: _HubButton(
                        icon: Icons.favorite_outline,
                        label: '기분',
                        accent: true,
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const ChatRecordScreen(),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _HubButton(
                        icon: Icons.chat_bubble_outline,
                        label: '상담',
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const CounselScreen(),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _HubButton(
                        icon: Icons.calendar_today_outlined,
                        label: '돌아보기',
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const HistoryScreen(),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _HubButton(
                        icon: Icons.auto_awesome_outlined,
                        label: '꾸미기',
                        comingSoon: true,
                        onTap: () => _comingSoon(context),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _speechBubble(BuildContext context, String message) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 280),
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.divider, width: 1),
      ),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.5),
      ),
    );
  }

  void _comingSoon(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('곧 만나요'),
        duration: Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  String _greeting() {
    final h = DateTime.now().hour;
    if (h >= 5 && h < 11) return '좋은 아침이에요';
    if (h >= 11 && h < 17) return '좋은 오후예요';
    if (h >= 17 && h < 22) return '좋은 저녁이에요';
    return '편안한 밤이에요';
  }
}

/// 허브의 기능 버튼.
class _HubButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool accent;
  final bool comingSoon;

  const _HubButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.accent = false,
    this.comingSoon = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 84,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          color: accent ? AppTheme.accentDark : AppTheme.surface,
          borderRadius: BorderRadius.circular(AppTheme.radius),
          border: Border.all(
            color: accent ? AppTheme.accent : AppTheme.divider,
            width: 1,
          ),
        ),
        child: Stack(
          children: [
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    icon,
                    size: 24,
                    color: accent ? Colors.white : AppTheme.accentLight,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppTheme.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ],
              ),
            ),
            if (comingSoon)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    color: AppTheme.accentLight,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}