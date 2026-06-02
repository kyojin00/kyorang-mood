import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../services/auth_service.dart';

/// 설정 화면.
///
/// 사용자 정보, 로그아웃, 그리고 추후 추가될 메뉴(이름 변경,
/// 성향 다시 진단, 알림, 약관, 계정 삭제 등)를 모은다.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final name = ref.watch(userNameProvider);
    final email = AuthService.instance.currentUser?.email ?? '';

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('설정'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.screenPadding,
            vertical: 8,
          ),
          children: [
            // 사용자 정보 카드
            _UserCard(name: name, email: email),

            const SizedBox(height: 24),
            _SectionLabel('계정'),
            _SettingsItem(
              icon: Icons.badge_outlined,
              label: '이름 변경',
              subtitle: '무디가 부를 이름을 바꿔요',
              comingSoon: true,
              onTap: () => _showComingSoon(context),
            ),
            _SettingsItem(
              icon: Icons.psychology_outlined,
              label: '성향 다시 진단',
              subtitle: '맞춤 제안의 기준을 다시 정해요',
              comingSoon: true,
              onTap: () => _showComingSoon(context),
            ),

            const SizedBox(height: 16),
            _SectionLabel('알림'),
            _SettingsItem(
              icon: Icons.notifications_none,
              label: '알림 설정',
              subtitle: '하루 한 번 기분 기록 알림',
              comingSoon: true,
              onTap: () => _showComingSoon(context),
            ),

            const SizedBox(height: 16),
            _SectionLabel('정보'),
            _SettingsItem(
              icon: Icons.description_outlined,
              label: '이용약관',
              comingSoon: true,
              onTap: () => _showComingSoon(context),
            ),
            _SettingsItem(
              icon: Icons.shield_outlined,
              label: '개인정보 처리방침',
              comingSoon: true,
              onTap: () => _showComingSoon(context),
            ),
            _SettingsItem(
              icon: Icons.info_outline,
              label: '앱 정보',
              subtitle: '버전 1.0.0',
              onTap: () {},
            ),

            const SizedBox(height: 24),
            // 로그아웃 (강조)
            _SettingsItem(
              icon: Icons.logout,
              label: '로그아웃',
              danger: true,
              onTap: () => _confirmLogout(context, ref),
            ),
            _SettingsItem(
              icon: Icons.delete_outline,
              label: '계정 삭제',
              danger: true,
              comingSoon: true,
              onTap: () => _showComingSoon(context),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  void _showComingSoon(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('곧 만나요'),
        duration: Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _confirmLogout(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Text('로그아웃할까요?'),
        content: const Text('다시 로그인하면 이어서 사용할 수 있어요.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text(
              '로그아웃',
              style: TextStyle(color: AppTheme.error),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    await AuthService.instance.signOut();
    // 로그아웃되면 main.dart의 분기가 자동으로 로그인 화면으로 보낸다.
    // 설정 화면은 그 위에 떠 있으니 닫아준다.
    if (context.mounted) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }
}

class _UserCard extends StatelessWidget {
  final String name;
  final String email;

  const _UserCard({required this.name, required this.email});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(color: AppTheme.divider, width: 1),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: const BoxDecoration(
              color: AppTheme.accentDark,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              name.isNotEmpty ? name.characters.first : '?',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$name님',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                if (email.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    email,
                    style: Theme.of(context).textTheme.bodySmall,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
      child: Text(
        text,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppTheme.textTertiary,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}

class _SettingsItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? subtitle;
  final VoidCallback onTap;
  final bool comingSoon;
  final bool danger;

  const _SettingsItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.subtitle,
    this.comingSoon = false,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = danger ? AppTheme.error : AppTheme.textPrimary;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
            child: Row(
              children: [
                Icon(icon, size: 22, color: color),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: TextStyle(
                          color: color,
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle!,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ],
                  ),
                ),
                if (comingSoon)
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: AppTheme.accentLight,
                      shape: BoxShape.circle,
                    ),
                  )
                else if (!danger)
                  const Icon(
                    Icons.chevron_right,
                    color: AppTheme.textTertiary,
                    size: 20,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}