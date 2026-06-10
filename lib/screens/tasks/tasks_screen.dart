import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../theme/app_theme.dart';
import '../../services/task_service.dart';
import '../../widgets/mascot.dart';

/// 무디가 챙기는 일정 화면.
///
/// 사용자가 일기에 적은 것에서 무디가 자동 추출한 일정,
/// 또는 사용자가 직접 추가한 일정을 보여준다.
/// 항목을 탭하면 완료/취소 메뉴.
class TasksScreen extends ConsumerStatefulWidget {
  const TasksScreen({super.key});

  @override
  ConsumerState<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends ConsumerState<TasksScreen> {
  List<Task> _tasks = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await TaskService.instance.fetchPending();
      if (!mounted) return;
      setState(() {
        _tasks = list;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '일정을 가져오지 못했어요.';
      });
    }
  }

  /// 일정을 날짜별로 묶기 (오늘/내일/이번 주/그 이후/언젠가)
  Map<String, List<Task>> _groupByDate() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final endOfWeek = today.add(Duration(days: 7 - today.weekday + 1));

    final groups = <String, List<Task>>{
      '오늘': [],
      '내일': [],
      '이번 주': [],
      '다가오는': [],
      '언젠가': [],
    };

    for (final t in _tasks) {
      final d = t.dueAt != null
          ? DateTime(t.dueAt!.year, t.dueAt!.month, t.dueAt!.day)
          : t.dueDate;
      if (d == null) {
        groups['언젠가']!.add(t);
      } else if (d.isAtSameMomentAs(today)) {
        groups['오늘']!.add(t);
      } else if (d.isAtSameMomentAs(tomorrow)) {
        groups['내일']!.add(t);
      } else if (d.isAfter(today) && d.isBefore(endOfWeek)) {
        groups['이번 주']!.add(t);
      } else if (d.isAfter(today)) {
        groups['다가오는']!.add(t);
      } else {
        // 이미 지난 pending — "다가오는"에 같이 (사용자가 "안 했어" 처리 안 한 경우)
        groups['다가오는']!.add(t);
      }
    }

    // 빈 그룹 제거
    groups.removeWhere((_, v) => v.isEmpty);
    return groups;
  }

  Future<void> _showTaskMenu(Task task) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: AppTheme.divider,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 8),
                  child: Text(
                    task.title,
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const Divider(color: AppTheme.divider, height: 1),
                ListTile(
                  leading: const Icon(Icons.check_circle_outline_rounded,
                      color: Color(0xFF8FCBA1)),
                  title: const Text('끝냈어요',
                      style: TextStyle(color: AppTheme.textPrimary)),
                  onTap: () => Navigator.of(ctx).pop('done'),
                ),
                ListTile(
                  leading: const Icon(Icons.cancel_outlined,
                      color: Color(0xFFE08A8A)),
                  title: const Text('취소됐어요',
                      style: TextStyle(color: AppTheme.textPrimary)),
                  onTap: () => Navigator.of(ctx).pop('cancel'),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );

    if (action == 'done') {
      try {
        await TaskService.instance.complete(task.id);
        await _load();
      } catch (_) {}
    } else if (action == 'cancel') {
      try {
        await TaskService.instance.cancel(task.id);
        await _load();
      } catch (_) {}
    }
  }

  Future<void> _showAddDialog() async {
    final controller = TextEditingController();
    DateTime? selectedDate;

    final added = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setS) {
          return AlertDialog(
            backgroundColor: AppTheme.surface,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Text(
              '새 일정',
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: controller,
                  autofocus: true,
                  maxLength: 80,
                  style: const TextStyle(
                      color: AppTheme.textPrimary, fontSize: 15),
                  decoration: const InputDecoration(
                    hintText: '예: 치과 가기',
                    counterText: '',
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextButton.icon(
                        icon: const Icon(Icons.calendar_today_outlined,
                            size: 18),
                        label: Text(
                          selectedDate == null
                              ? '날짜 (선택)'
                              : '${selectedDate!.month}월 ${selectedDate!.day}일',
                        ),
                        onPressed: () async {
                          final now = DateTime.now();
                          final picked = await showDatePicker(
                            context: ctx,
                            initialDate: selectedDate ?? now,
                            firstDate: now.subtract(const Duration(days: 30)),
                            lastDate:
                                now.add(const Duration(days: 365 * 2)),
                          );
                          if (picked != null) setS(() => selectedDate = picked);
                        },
                      ),
                    ),
                    if (selectedDate != null)
                      IconButton(
                        icon: const Icon(Icons.close, size: 18),
                        onPressed: () => setS(() => selectedDate = null),
                      ),
                  ],
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                style: TextButton.styleFrom(
                    foregroundColor: AppTheme.textTertiary),
                child: const Text('취소'),
              ),
              TextButton(
                onPressed: () async {
                  final title = controller.text.trim();
                  if (title.isEmpty) return;
                  try {
                    await TaskService.instance.add(
                      title: title,
                      dueDate: selectedDate,
                    );
                    if (ctx.mounted) Navigator.of(ctx).pop(true);
                  } catch (_) {
                    if (ctx.mounted) Navigator.of(ctx).pop(false);
                  }
                },
                style: TextButton.styleFrom(
                    foregroundColor: AppTheme.accentLight),
                child: const Text('저장'),
              ),
            ],
          );
        });
      },
    );

    if (added == true) await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Column(
            children: [
              const SizedBox(height: 8),
              _TopBar(
                onClose: () => Navigator.of(context).maybePop(),
                onAdd: _showAddDialog,
              ),
              const SizedBox(height: 18),
              Expanded(
                child: _loading
                    ? const _LoadingPaper()
                    : _error != null
                        ? _ErrorPaper(message: _error!, onRetry: _load)
                        : _tasks.isEmpty
                            ? const _EmptyPaper()
                            : _TasksPaper(
                                groups: _groupByDate(),
                                onTap: _showTaskMenu,
                              ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 상단: 무디 + 라벨 + 뒤로/추가 버튼
class _TopBar extends StatelessWidget {
  final VoidCallback onClose;
  final VoidCallback onAdd;
  const _TopBar({required this.onClose, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.topCenter,
      children: [
        Column(
          children: [
            const Mascot(pose: MascotPose.front, size: 64),
            const SizedBox(height: 8),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: AppTheme.surface.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: AppTheme.divider.withValues(alpha: 0.5),
                  width: 1,
                ),
              ),
              child: const Text(
                '챙기는 일정',
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.2,
                ),
              ),
            ),
          ],
        ),
        Positioned(
          left: 0,
          top: 4,
          child: _SmallIconButton(
              icon: Icons.arrow_back_rounded, onTap: onClose),
        ),
        Positioned(
          right: 0,
          top: 4,
          child: _SmallIconButton(
              icon: Icons.add_rounded, onTap: onAdd),
        ),
      ],
    );
  }
}

class _SmallIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _SmallIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(
            icon,
            color: AppTheme.textSecondary.withValues(alpha: 0.7),
            size: 22,
          ),
        ),
      ),
    );
  }
}

/// 종이 카드 베이스
class _PaperCard extends StatelessWidget {
  final Widget child;
  const _PaperCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFCF4ED), Color(0xFFF5E6E0)],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: const Color(0xFFE8C5C0).withValues(alpha: 0.5),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 28,
            offset: const Offset(0, 14),
          ),
          BoxShadow(
            color: const Color(0xFFE8A5B8).withValues(alpha: 0.15),
            blurRadius: 40,
            offset: const Offset(0, 0),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: child,
      ),
    );
  }
}

/// 로딩 종이
class _LoadingPaper extends StatelessWidget {
  const _LoadingPaper();

  @override
  Widget build(BuildContext context) {
    return _PaperCard(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Text(
            '일정을 가져오는 중이에요…',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'GowunDodum',
              color: const Color(0xFF8A6878).withValues(alpha: 0.85),
              fontSize: 14,
              fontStyle: FontStyle.italic,
              height: 1.8,
            ),
          ),
        ),
      ),
    );
  }
}

class _ErrorPaper extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorPaper({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return _PaperCard(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'GowunDodum',
                  color: const Color(0xFF8A6878).withValues(alpha: 0.85),
                  fontSize: 14,
                  fontStyle: FontStyle.italic,
                ),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: onRetry,
                child: const Text('다시 시도'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyPaper extends StatelessWidget {
  const _EmptyPaper();

  @override
  Widget build(BuildContext context) {
    return _PaperCard(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '챙기는 일정이 없어요.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'GowunDodum',
                  color: const Color(0xFF6B4855).withValues(alpha: 0.85),
                  fontSize: 15,
                  fontStyle: FontStyle.italic,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                '일기에 일정을 말씀하시면\n무디가 알아서 챙겨드려요.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'GowunDodum',
                  color: const Color(0xFF9E7C8A).withValues(alpha: 0.75),
                  fontSize: 13,
                  height: 1.8,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 일정 목록 종이
class _TasksPaper extends StatelessWidget {
  final Map<String, List<Task>> groups;
  final void Function(Task) onTap;

  const _TasksPaper({required this.groups, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return _PaperCard(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(22, 26, 22, 24),
        children: [
          for (final entry in groups.entries) ...[
            _GroupLabel(text: entry.key),
            for (final task in entry.value)
              _TaskItem(task: task, onTap: () => onTap(task)),
            const SizedBox(height: 16),
          ],
        ],
      ),
    );
  }
}

class _GroupLabel extends StatelessWidget {
  final String text;
  const _GroupLabel({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 10, top: 6),
      child: Text(
        text,
        style: const TextStyle(
          fontFamily: 'GowunDodum',
          color: Color(0xFF9E7C8A),
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

class _TaskItem extends StatelessWidget {
  final Task task;
  final VoidCallback onTap;
  const _TaskItem({required this.task, required this.onTap});

  String _timeLabel() {
    if (task.hasTime) {
      final t = task.dueAt!;
      final h = t.hour;
      final m = t.minute;
      final ampm = h < 12 ? '오전' : '오후';
      final hh = h % 12 == 0 ? 12 : h % 12;
      final mm = m.toString().padLeft(2, '0');
      return '$ampm $hh:$mm';
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final time = _timeLabel();
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 11),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 7,
                height: 7,
                margin: const EdgeInsets.only(right: 12, top: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFC76B86).withValues(alpha: 0.6),
                  shape: BoxShape.circle,
                ),
              ),
              Expanded(
                child: Text(
                  task.title,
                  style: const TextStyle(
                    fontFamily: 'GowunDodum',
                    color: Color(0xFF3D2438),
                    fontSize: 15.5,
                    fontWeight: FontWeight.w500,
                    height: 1.4,
                  ),
                ),
              ),
              if (time.isNotEmpty)
                Text(
                  time,
                  style: TextStyle(
                    fontFamily: 'GowunDodum',
                    color: const Color(0xFF9E7C8A).withValues(alpha: 0.85),
                    fontSize: 12.5,
                    fontStyle: FontStyle.italic,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}