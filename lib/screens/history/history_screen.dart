import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../theme/app_theme.dart';
import '../../models/mood_entry.dart';
import '../../providers/mood_provider.dart';
import 'stats_screen.dart';

/// 돌아보기 화면.
///
/// 월 단위 달력에 매일의 기분을 색으로 칠해 한눈에 보여주고,
/// 날짜를 누르면 그날의 기록(기분/메모/제안)을 아래에 펼친다.
class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  /// 현재 보고 있는 달
  late DateTime _focusedMonth;

  /// 선택한 날짜 (없으면 null)
  DateTime? _selectedDate;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _focusedMonth = DateTime(now.year, now.month);
  }

  void _prevMonth() {
    setState(() {
      _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month - 1);
      _selectedDate = null;
    });
  }

  void _nextMonth() {
    setState(() {
      _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month + 1);
      _selectedDate = null;
    });
  }

  /// 다음 달로 이동 가능한지 (미래 달은 막는다).
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

    // 날짜(일) -> 그날 기록들
    final byDay = <int, List<MoodEntry>>{};
    for (final e in entries) {
      byDay.putIfAbsent(e.date.day, () => []).add(e);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('돌아보기'),
        actions: [
          IconButton(
            icon: const Icon(Icons.bar_chart, size: 22),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => StatsScreen()),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppTheme.screenPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildMonthHeader(context),
              const SizedBox(height: 24),
              _buildWeekdayRow(context),
              const SizedBox(height: 8),
              _buildCalendarGrid(context, byDay),
              const SizedBox(height: 24),
              if (_selectedDate != null)
                _buildDayDetail(context, byDay[_selectedDate!.day] ?? []),
            ],
          ),
        ),
      ),
    );
  }

  // ── 월 네비게이션 ──
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

  // ── 요일 헤더 (일~토) ──
  Widget _buildWeekdayRow(BuildContext context) {
    const labels = ['일', '월', '화', '수', '목', '금', '토'];
    return Row(
      children: labels.map((d) {
        return Expanded(
          child: Center(
            child: Text(
              d,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        );
      }).toList(),
    );
  }

  // ── 날짜 그리드 ──
  Widget _buildCalendarGrid(
    BuildContext context,
    Map<int, List<MoodEntry>> byDay,
  ) {
    final daysInMonth =
        DateTime(_focusedMonth.year, _focusedMonth.month + 1, 0).day;
    // 1일의 요일 (일요일 시작 그리드 기준 앞쪽 빈칸 수)
    final firstWeekday =
        DateTime(_focusedMonth.year, _focusedMonth.month, 1).weekday;
    final leadingBlanks = firstWeekday % 7; // 일=0, 월=1, ... 토=6

    final cells = <Widget>[];
    for (var i = 0; i < leadingBlanks; i++) {
      cells.add(const SizedBox.shrink());
    }
    for (var day = 1; day <= daysInMonth; day++) {
      final dayEntries = byDay[day];
      cells.add(_buildDayCell(context, day, dayEntries));
    }

    return GridView.count(
      crossAxisCount: 7,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 4,
      crossAxisSpacing: 4,
      children: cells,
    );
  }

  Widget _buildDayCell(
    BuildContext context,
    int day,
    List<MoodEntry>? dayEntries,
  ) {
    final hasEntry = dayEntries != null && dayEntries.isNotEmpty;
    // 그날 가장 최근 기록의 기분으로 색을 칠한다.
    final level = hasEntry ? dayEntries.first.moodLevel : null;

    final date = DateTime(_focusedMonth.year, _focusedMonth.month, day);
    final isSelected = _selectedDate != null &&
        _selectedDate!.year == date.year &&
        _selectedDate!.month == date.month &&
        _selectedDate!.day == date.day;
    final isToday = _isToday(date);

    return GestureDetector(
      onTap: hasEntry
          ? () => setState(() => _selectedDate = date)
          : null,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: level != null
                  ? AppTheme.moodColor(level)
                  : Colors.transparent,
              shape: BoxShape.circle,
              border: isSelected
                  ? Border.all(color: AppTheme.textPrimary, width: 2)
                  : (isToday
                      ? Border.all(color: AppTheme.accent, width: 1.5)
                      : null),
            ),
            alignment: Alignment.center,
            child: Text(
              '$day',
              style: TextStyle(
                fontSize: 13,
                color: hasEntry ? AppTheme.background : AppTheme.textTertiary,
                fontWeight: hasEntry ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── 선택한 날 상세 ──
  Widget _buildDayDetail(BuildContext context, List<MoodEntry> dayEntries) {
    final date = _selectedDate!;
    final header = '${date.month}월 ${date.day}일';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            header,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 16),
          ...dayEntries.map((e) => _buildEntryRow(context, e)),
        ],
      ),
    );
  }

  Widget _buildEntryRow(BuildContext context, MoodEntry entry) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 16,
            height: 16,
            margin: const EdgeInsets.only(top: 3),
            decoration: BoxDecoration(
              color: AppTheme.moodColor(entry.moodLevel),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppTheme.moodLabel(entry.moodLevel),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                if (entry.note != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    entry.note!,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
                if (entry.suggestion != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    entry.suggestion!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppTheme.accentLight,
                          height: 1.5,
                        ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }
}