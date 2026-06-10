import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../theme/app_theme.dart';
import '../../models/comfort_models.dart';
import '../../providers/comfort_provider.dart';
import '../../services/mood_comfort_service.dart';
import 'give_comfort_screen.dart';
import '../../utils/app_snackbar.dart';

/// 내 위로함 화면.
///
/// 내가 띄운 마음에 도착한 익명의 위로들을 모아 보여준다.
/// - 진입 시 myComfortsProvider 가 조회 + 읽음 처리를 함께 수행
/// - 안 읽은 위로는 강조 표시, 무디 폴백은 별도 톤
/// - 보낸 사람 정보는 없음(익명)
/// - 상단 "위로 건네기" 액션으로 풀의 다른 마음에 위로를 보낼 수 있다.
/// - 위로 카드의 ⋮ 메뉴로 부적절한 위로를 신고할 수 있다.
class MyComfortsScreen extends ConsumerWidget {
  const MyComfortsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncItems = ref.watch(myComfortsProvider);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.background,
        elevation: 0,
        title: Text('내 위로함',
            style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w700)),
        iconTheme: IconThemeData(color: AppTheme.textPrimary),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: TextButton.icon(
              onPressed: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const GiveComfortScreen(),
                  ),
                );
                ref.invalidate(comfortGivingProvider);
              },
              icon: Icon(
                Icons.volunteer_activism_rounded,
                size: 18,
                color: AppTheme.accentLight,
              ),
              label: Text(
                '위로 건네기',
                style: TextStyle(
                  color: AppTheme.accentLight,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              style: TextButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              ),
            ),
          ),
        ],
      ),
      body: asyncItems.when(
        loading: () =>
            const Center(child: CircularProgressIndicator(strokeWidth: 2)),
        error: (e, _) => _buildError(ref),
        data: (items) {
          final onlyMudi = items.length == 1 && items.first.isFromMudi;
          return RefreshIndicator(
            color: AppTheme.accentLight,
            backgroundColor: AppTheme.surface,
            onRefresh: () =>
                ref.read(myComfortsProvider.notifier).refresh(),
            child: onlyMudi
                ? _buildEmptyWithMudi(context, items.first)
                : _buildList(context, ref, items),
          );
        },
      ),
    );
  }

  Widget _buildList(
      BuildContext context, WidgetRef ref, List<ComfortItem> items) {
    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      itemCount: items.length + 1,
      itemBuilder: (ctx, i) {
        if (i == 0) return _buildHeader(items);
        return _buildComfortCard(context, ref, items[i - 1]);
      },
    );
  }

  Widget _buildHeader(List<ComfortItem> items) {
    final realCount = items.where((e) => !e.isFromMudi).length;
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$realCount개의 마음이 도착했어요',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '이름도 얼굴도 모르는 누군가가\n당신에게 건넨 위로예요.',
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 13,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildComfortCard(
      BuildContext context, WidgetRef ref, ComfortItem item) {
    final c = item.comfort;
    final isMudi = item.isFromMudi;
    final isNew = !c.isRead && !isMudi;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(18, 14, 8, 18),
      decoration: BoxDecoration(
        color: isMudi
            ? AppTheme.surfaceVariant.withOpacity(0.6)
            : AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isNew ? AppTheme.accent : AppTheme.divider,
          width: isNew ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isMudi ? Icons.pets_rounded : Icons.favorite_rounded,
                size: 16,
                color: isMudi
                    ? AppTheme.textSecondary
                    : AppTheme.accentLight,
              ),
              const SizedBox(width: 6),
              Text(
                isMudi ? '무디의 한마디' : '익명의 위로',
                style: TextStyle(
                  color: isMudi
                      ? AppTheme.textSecondary
                      : AppTheme.accentLight,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              if (isNew)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppTheme.accent,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text(
                    'NEW',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              // ⋮ 메뉴 — 신고. 무디 폴백 카드엔 표시하지 않는다.
              if (!isMudi)
                _MoreMenuButton(
                  onReport: () => _ReportSheet.show(context, ref, c.replyId),
                )
              else
                const SizedBox(width: 10),
            ],
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.only(right: 10),
            child: Text(
              c.content,
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 15,
                height: 1.6,
              ),
            ),
          ),
          if (!isMudi) ...[
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.only(right: 10),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppTheme.moodColor(c.moodLevel)
                          .withOpacity(0.25),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '그날의 기분 · ${AppTheme.moodLabel(c.moodLevel)}',
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    _timeAgo(c.createdAt),
                    style: TextStyle(
                      color: AppTheme.textTertiary,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEmptyWithMudi(BuildContext context, ComfortItem mudi) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 40, 20, 32),
      children: [
        Center(
          child: Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppTheme.surfaceVariant,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.pets_rounded,
                color: AppTheme.accentLight, size: 30),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          '아직 도착한 위로가 없어요',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 17,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          '마음을 띄우면 누군가의 위로가\n이곳에 조용히 도착할 거예요.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 13.5,
            height: 1.6,
          ),
        ),
        const SizedBox(height: 24),
        Center(
          child: TextButton.icon(
            onPressed: () async {
              await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const GiveComfortScreen(),
                ),
              );
            },
            icon: Icon(
              Icons.volunteer_activism_rounded,
              size: 18,
              color: AppTheme.accentLight,
            ),
            label: Text(
              '먼저 누군가에게 위로 건네기',
              style: TextStyle(
                color: AppTheme.accentLight,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        // 무디 폴백 카드 — 메뉴 없음
        Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppTheme.surfaceVariant.withOpacity(0.6),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.divider),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.pets_rounded,
                      size: 16, color: AppTheme.textSecondary),
                  const SizedBox(width: 6),
                  Text(
                    '무디의 한마디',
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                mudi.comfort.content,
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 15,
                  height: 1.6,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildError(WidgetRef ref) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_rounded,
                size: 48, color: AppTheme.textTertiary),
            const SizedBox(height: 20),
            Text(
              '위로함을 불러오지 못했어요',
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 20),
            TextButton(
              onPressed: () =>
                  ref.read(myComfortsProvider.notifier).refresh(),
              child: Text(
                '다시 시도',
                style: TextStyle(
                  color: AppTheme.accentLight,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _timeAgo(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 1) return '방금';
    if (diff.inHours < 1) return '${diff.inMinutes}분 전';
    if (diff.inDays < 1) return '${diff.inHours}시간 전';
    if (diff.inDays < 7) return '${diff.inDays}일 전';
    return '${time.month}월 ${time.day}일';
  }
}

/// 위로 카드 우상단 ⋮ 메뉴. 현재는 신고만 있다.
class _MoreMenuButton extends StatelessWidget {
  final VoidCallback onReport;

  const _MoreMenuButton({required this.onReport});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: '',
      icon: Icon(
        Icons.more_vert_rounded,
        size: 18,
        color: AppTheme.textTertiary,
      ),
      padding: EdgeInsets.zero,
      color: AppTheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: AppTheme.divider),
      ),
      onSelected: (v) {
        if (v == 'report') onReport();
      },
      itemBuilder: (_) => [
        PopupMenuItem<String>(
          value: 'report',
          child: Row(
            children: [
              Icon(Icons.flag_outlined,
                  size: 16, color: AppTheme.textSecondary),
              const SizedBox(width: 8),
              Text(
                '신고하기',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// 신고 사유 선택 시트. 사유를 고르고 "신고하기"를 누르면 RPC 호출.
/// 성공하면 시트 닫고 위로함 새로고침(서버가 신고한 위로 제외하고 돌려줌).
class _ReportSheet extends ConsumerStatefulWidget {
  final String replyId;
  const _ReportSheet({required this.replyId});

  static Future<void> show(
      BuildContext context, WidgetRef ref, String replyId) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ReportSheet(replyId: replyId),
    );
  }

  @override
  ConsumerState<_ReportSheet> createState() => _ReportSheetState();
}

class _ReportSheetState extends ConsumerState<_ReportSheet> {
  String? _reason; // 사유 value
  bool _sending = false;

  // 사유 선택지: (value, label)
  static const List<MapEntry<String, String>> _reasons = [
    MapEntry('abusive', '욕설 · 혐오 표현'),
    MapEntry('spam', '스팸 · 광고 · 외부 유도'),
    MapEntry('inappropriate', '부적절한 내용'),
    MapEntry('other', '기타'),
  ];

  Future<void> _submit() async {
    if (_reason == null || _sending) return;
    setState(() => _sending = true);
    try {
      await MoodComfortService.instance.reportComfort(
        replyId: widget.replyId,
        reason: _reason,
      );
      if (!mounted) return;
      Navigator.of(context).pop();
      // 위로함 갱신 — 신고된 위로는 서버에서 제외되어 사라진다.
      ref.read(myComfortsProvider.notifier).refresh();
      ref.invalidate(unreadComfortCountProvider);
      showAppSnack(context, '신고가 접수됐어요. 해당 위로는 숨겨졌어요.');
    } catch (e) {
      if (!mounted) return;
      showAppSnack(context, e.toString());
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: AppTheme.divider,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text(
                '이 위로를 신고할게요',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '신고하면 이 위로는 위로함에서 즉시 사라져요.\n같은 발신자가 누적 신고되면 자동으로 발송이 제한돼요.',
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 12.5,
                  height: 1.55,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                '신고 사유',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              ..._reasons.map((r) {
                final selected = _reason == r.key;
                return GestureDetector(
                  onTap: () => setState(() => _reason = r.key),
                  child: Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: selected
                          ? AppTheme.accent.withOpacity(0.15)
                          : AppTheme.surfaceVariant,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color:
                            selected ? AppTheme.accent : AppTheme.divider,
                        width: selected ? 1.5 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          selected
                              ? Icons.radio_button_checked_rounded
                              : Icons.radio_button_unchecked_rounded,
                          size: 18,
                          color: selected
                              ? AppTheme.accentLight
                              : AppTheme.textTertiary,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          r.value,
                          style: TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 50,
                      child: TextButton(
                        onPressed: _sending
                            ? null
                            : () => Navigator.of(context).pop(),
                        style: TextButton.styleFrom(
                          backgroundColor: AppTheme.surfaceVariant,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: Text(
                          '취소',
                          style: TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: SizedBox(
                      height: 50,
                      child: ElevatedButton(
                        onPressed:
                            (_reason != null && !_sending) ? _submit : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.accent,
                          disabledBackgroundColor: AppTheme.surfaceVariant,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: _sending
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white),
                                ),
                              )
                            : const Text(
                                '신고하기',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}