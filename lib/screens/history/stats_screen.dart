import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../theme/app_theme.dart';
import '../../models/mood_entry.dart';
import '../../providers/mood_provider.dart';

/// 통계 화면.
///
/// 선택한 달의 기분 데이터를 요약/그래프/분포로 보여준다.
/// - 요약: 기록한 일수, 평균 기분
/// - 추이: 날짜별 기분(그날 평균)을 선그래프로
/// - 분포: 기분 1~5단계가 각각 몇 번이었는지
class StatsScreen extends ConsumerStatefulWidget {
  const StatsScreen({super.key});

  @override
  ConsumerState<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends ConsumerState<StatsScreen> {
  late DateTime _focusedMonth;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _focusedMonth = DateTime(now.year, now.month);
  }

  void _prevMonth() {
    setState(() {
      _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month - 1);
    });
  }

  void _nextMonth() {
    setState(() {
      _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month + 1);
    });
  }

  bool get _canGoNext {
    final now = DateTime.now();
    final next = DateTime(_focusedMonth.year, _focusedMonth.month + 1);
    return !next.isAfter(DateTime(now.year, now.month));
  }

  @override
  Widget build(BuildContext context) {
    final entries = ref.watch(monthEntriesProvider(
      (year: _focusedMonth.year, month: _focusedMonth.month),
    ));

    // 날짜(일) -> 그날 기분 평균
    final byDayAvg = <int, double>{};
    final byDayCount = <int, int>{};
    final distribution = <int, int>{for (var i = 1; i <= 5; i++) i: 0};

    for (final e in entries) {
      byDayAvg.update(e.date.day, (v) => v + e.moodLevel,
          ifAbsent: () => e.moodLevel.toDouble());
      byDayCount.update(e.date.day, (v) => v + 1, ifAbsent: () => 1);
      distribution.update(e.moodLevel, (v) => v + 1, ifAbsent: () => 1);
    }
    byDayAvg.updateAll((day, sum) => sum / byDayCount[day]!);

    final recordedDays = byDayAvg.length;
    final avgMood = entries.isEmpty
        ? 0.0
        : entries.map((e) => e.moodLevel).reduce((a, b) => a + b) /
            entries.length;

    final daysInMonth =
        DateTime(_focusedMonth.year, _focusedMonth.month + 1, 0).day;

    return Scaffold(
      appBar: AppBar(title: const Text('이번 달 기분')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppTheme.screenPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildMonthHeader(context),
              const SizedBox(height: 24),
              if (entries.isEmpty)
                _buildEmpty(context)
              else ...[
                _buildSummary(context, recordedDays, avgMood),
                const SizedBox(height: 32),
                Text('기분 추이',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 16),
                _buildTrendChart(byDayAvg, daysInMonth),
                const SizedBox(height: 32),
                Text('기분 분포',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 16),
                _buildDistribution(context, distribution, entries.length),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMonthHeader(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(
          icon: const Icon(Icons.chevron_left),
          onPressed: _prevMonth,
        ),
        Text(
          '${_focusedMonth.year}년 ${_focusedMonth.month}월',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        IconButton(
          icon: const Icon(Icons.chevron_right),
          onPressed: _canGoNext ? _nextMonth : null,
          color: _canGoNext ? null : AppTheme.textTertiary,
        ),
      ],
    );
  }

  Widget _buildEmpty(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 60),
      alignment: Alignment.center,
      child: Text(
        '이 달의 기록이 아직 없어요',
        style: Theme.of(context).textTheme.bodyMedium,
      ),
    );
  }

  // ── 요약 카드 ──
  Widget _buildSummary(BuildContext context, int days, double avg) {
    return Row(
      children: [
        Expanded(
          child: _summaryCard(context, '$days일', '기록한 날'),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _summaryCard(
            context,
            avg.toStringAsFixed(1),
            '평균 기분',
          ),
        ),
      ],
    );
  }

  Widget _summaryCard(BuildContext context, String value, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radius),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: AppTheme.accentLight,
                ),
          ),
          const SizedBox(height: 4),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }

  // ── 추이 선그래프 ──
  Widget _buildTrendChart(Map<int, double> byDayAvg, int daysInMonth) {
    return Container(
      height: 180,
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(8, 16, 8, 8),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radius),
      ),
      child: CustomPaint(
        painter: _TrendPainter(
          byDayAvg: byDayAvg,
          daysInMonth: daysInMonth,
        ),
      ),
    );
  }

  // ── 기분 분포 ──
  Widget _buildDistribution(
    BuildContext context,
    Map<int, int> dist,
    int total,
  ) {
    return Column(
      // 좋음(5)부터 위로
      children: [5, 4, 3, 2, 1].map((level) {
        final count = dist[level] ?? 0;
        final ratio = total == 0 ? 0.0 : count / total;
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            children: [
              SizedBox(
                width: 56,
                child: Text(
                  AppTheme.moodLabel(level),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              Expanded(
                child: Stack(
                  children: [
                    Container(
                      height: 14,
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceVariant,
                        borderRadius: BorderRadius.circular(7),
                      ),
                    ),
                    FractionallySizedBox(
                      widthFactor: ratio == 0 ? 0.001 : ratio,
                      child: Container(
                        height: 14,
                        decoration: BoxDecoration(
                          color: AppTheme.moodColor(level),
                          borderRadius: BorderRadius.circular(7),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 28,
                child: Text(
                  '$count',
                  textAlign: TextAlign.right,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

/// 월간 기분 추이를 그리는 페인터.
/// 가로축은 1~말일, 세로축은 기분 1~5. 기록 있는 날을 선으로 잇는다.
class _TrendPainter extends CustomPainter {
  final Map<int, double> byDayAvg;
  final int daysInMonth;

  _TrendPainter({required this.byDayAvg, required this.daysInMonth});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // 가로 격자선 (기분 1~5 기준, 5칸)
    final gridPaint = Paint()
      ..color = AppTheme.divider
      ..strokeWidth = 1;
    for (var i = 0; i < 5; i++) {
      final y = h * (i / 4.0);
      canvas.drawLine(Offset(0, y), Offset(w, y), gridPaint);
    }

    if (byDayAvg.isEmpty) return;

    // day -> 좌표 변환
    Offset toOffset(int day, double mood) {
      final x = daysInMonth <= 1
          ? w / 2
          : w * ((day - 1) / (daysInMonth - 1));
      // 기분 1(아래) ~ 5(위)
      final y = h * (1 - (mood - 1) / 4.0);
      return Offset(x, y);
    }

    final sortedDays = byDayAvg.keys.toList()..sort();
    final points = sortedDays.map((d) => toOffset(d, byDayAvg[d]!)).toList();

    // 선
    final linePaint = Paint()
      ..color = AppTheme.accentLight
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    if (points.length > 1) {
      final path = Path()..moveTo(points.first.dx, points.first.dy);
      for (var i = 1; i < points.length; i++) {
        path.lineTo(points[i].dx, points[i].dy);
      }
      canvas.drawPath(path, linePaint);
    }

    // 점
    final dotPaint = Paint()..color = AppTheme.accentLight;
    final dotCore = Paint()..color = AppTheme.background;
    for (final p in points) {
      canvas.drawCircle(p, 4.5, dotPaint);
      canvas.drawCircle(p, 2, dotCore);
    }
  }

  @override
  bool shouldRepaint(_TrendPainter old) =>
      old.byDayAvg != byDayAvg || old.daysInMonth != daysInMonth;
}