import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../theme/app_theme.dart';
import '../../models/chat_message.dart';
import '../../providers/auth_provider.dart';
import '../../providers/comfort_provider.dart';
import '../../services/chat_service.dart';
import '../../services/comfort_prefs.dart';
import '../../services/starter_prompts.dart';
import '../../widgets/mascot.dart';
import '../../widgets/raise_comfort_sheet.dart';
import '../comfort/my_comforts_screen.dart';
import '../settings/settings_screen.dart';

/// 교랑무드 메인 화면 — 일기장 (7일치 PageView).
///
/// 가장 오른쪽이 오늘(최신), 좌로 스와이프하면 어제·그저께가 펼쳐진다.
/// 오늘 페이지에서만 글을 쓸 수 있고 옛날 페이지는 읽기 전용.
class MoodyScreen extends ConsumerStatefulWidget {
  const MoodyScreen({super.key});

  @override
  ConsumerState<MoodyScreen> createState() => _MoodyScreenState();
}

class _MoodyScreenState extends ConsumerState<MoodyScreen> {
  // 7일치 날짜 (오래된 → 오늘 순, 길이 7)
  late final List<String> _dates;
  // 각 날짜별 대화 캐시
  final Map<String, List<ChatMessage>> _cache = {};
  // 각 날짜별 로딩 상태
  final Map<String, bool> _loading = {};

  // 현재 보이는 페이지 인덱스
  late int _currentIndex;
  late final PageController _pageController;

  // 오늘 페이지 글쓰기 상태
  bool _sending = false;
  bool _limitReached = false;
  bool _writing = false;
  String? _errorOnce;
  final _textController = TextEditingController();
  final _focusNode = FocusNode();

  // 무디 답변 직후 "마음 띄우기" 제안 칩 노출 여부 (하루 1회)
  bool _showRaiseHint = false;

  // 이번 세션 진입 시 뽑힌 시작 칩들 (오늘 페이지에서만 사용)
  late List<String> _starterChips;

  String get _todayDate => _dates.last;

  @override
  void initState() {
    super.initState();
    _dates = ChatService.instance.recentDates(daysAgo: 6); // 7일
    _currentIndex = _dates.length - 1; // 오늘
    _pageController = PageController(initialPage: _currentIndex);
    _starterChips = StarterPrompts.pickFor(
      ChatService.instance.currentSession(),
      count: 3,
    );

    WidgetsBinding.instance.addPostFrameCallback((_) => _loadInitial());
  }

  @override
  void dispose() {
    _textController.dispose();
    _focusNode.dispose();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _loadInitial() async {
    // 오늘 페이지 먼저 채움: 무디 인사 + DB에 있을 수 있는 오늘의 기존 대화
    final name = ref.read(userNameProvider);
    final session = ChatService.instance.currentSession();
    final today = _todayDate;

    setState(() => _loading[today] = true);

    List<ChatMessage> existing = [];
    try {
      existing = await ChatService.instance.messagesOfDate(today);
    } catch (_) {}

    if (!mounted) return;

    final firstList = <ChatMessage>[];
    if (existing.isEmpty) {
      // 오늘 첫 진입 — 무디 인사만
      firstList.add(ChatMessage.assistant(_opener(session, name)));
    } else {
      // 이미 오늘 적은 게 있음
      firstList.addAll(existing);
    }

    setState(() {
      _cache[today] = firstList;
      _loading[today] = false;
    });

    // 어제·옛날 페이지는 사용자가 스와이프할 때 그때 로드
  }

  Future<void> _loadDate(String date) async {
    if (_cache.containsKey(date) || _loading[date] == true) return;
    setState(() => _loading[date] = true);
    List<ChatMessage> msgs = [];
    try {
      msgs = await ChatService.instance.messagesOfDate(date);
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _cache[date] = msgs;
      _loading[date] = false;
    });
  }

  String _opener(SessionKind session, String name) {
    switch (session) {
      case SessionKind.morning:
        return '좋은 아침이에요, $name님.\n오늘은 어떻게 시작해요?';
      case SessionKind.night:
        return '오늘 하루 어땠어요, $name님?\n편하게 한 줄 남겨주세요.';
      case SessionKind.free:
        return '$name님, 다시 왔네요.\n지금 마음은 어때요?';
    }
  }

  String _placeholderFor(SessionKind session) {
    switch (session) {
      case SessionKind.morning:
        return '오늘의 첫 마음을 두고 가요…';
      case SessionKind.night:
        return '하루의 마지막 한 조각을 남겨요…';
      case SessionKind.free:
        return '지금 마음 한 줄을 두고 가요…';
    }
  }

  /// 날짜 문자열(YYYY-MM-DD)에서 라벨 만들기.
  /// 오늘 페이지면 시간대 포함, 옛날 페이지면 날짜만.
  String _labelForDate(String date) {
    final parts = date.split('-');
    final y = int.parse(parts[0]);
    final m = int.parse(parts[1]);
    final d = int.parse(parts[2]);
    final dt = DateTime(y, m, d);
    const weekdays = ['월', '화', '수', '목', '금', '토', '일'];
    final wd = weekdays[dt.weekday - 1];

    if (date == _todayDate) {
      final session = ChatService.instance.currentSession();
      final when = session == SessionKind.morning
          ? '아침'
          : session == SessionKind.night
              ? '밤'
              : '낮';
      return '$m월 $d일 $wd요일 · $when';
    } else {
      return '$m월 $d일 $wd요일';
    }
  }

  /// 시간대별 종이 톤. 옛날 페이지는 조금 더 가라앉은 톤.
  List<Color> _paperColors(String date) {
    if (date != _todayDate) {
      // 옛날 페이지 — 살짝 더 차분한 베이지
      return [const Color(0xFFF6EDE3), const Color(0xFFEDDED1)];
    }
    final session = ChatService.instance.currentSession();
    switch (session) {
      case SessionKind.morning:
        return [const Color(0xFFFEF7EE), const Color(0xFFF7E9DE)];
      case SessionKind.night:
        return [const Color(0xFFF8EBE3), const Color(0xFFEEDAD2)];
      case SessionKind.free:
        return [const Color(0xFFFCF4ED), const Color(0xFFF5E6E0)];
    }
  }

  void _startWriting() {
    if (_sending || _limitReached) return;
    setState(() => _writing = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  /// 시작 칩을 누르면 그 글이 입력 영역에 채워지고 키보드가 올라온다.
  /// 사용자는 그대로 보내거나 이어 써서 보낼 수 있다.
  void _startFromChip(String text) {
    if (_sending || _limitReached) return;
    _textController.text = text;
    _textController.selection = TextSelection.fromPosition(
      TextPosition(offset: text.length),
    );
    setState(() => _writing = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  void _cancelWriting() {
    setState(() {
      _writing = false;
      _textController.clear();
    });
    FocusScope.of(context).unfocus();
  }

  /// "마음 띄우기" 시트를 연다. 띄우기에 성공하면 제안 칩을 거둔다.
  Future<void> _openRaiseSheet() async {
    final raised = await RaiseComfortSheet.show(context);
    if (!mounted) return;
    if (raised == true) {
      setState(() => _showRaiseHint = false);
    }
  }

  Future<void> _save() async {
    final text = _textController.text.trim();
    if (text.isEmpty || _sending || _limitReached) return;

    _textController.clear();
    FocusScope.of(context).unfocus();

    final today = _todayDate;
    setState(() {
      _cache[today] = [...(_cache[today] ?? []), ChatMessage.user(text)];
      _writing = false;
      _sending = true;
      _errorOnce = null;
    });

    try {
      final reply = await ChatService.instance.send(text);
      if (!mounted) return;

      // 오늘 아직 제안 칩을 안 보여줬으면 이번 답변 아래에 노출한다.
      final showHint = !ComfortPrefs.instance.wasRaiseHintShownToday();

      setState(() {
        _cache[today] = [
          ...(_cache[today] ?? []),
          ChatMessage.assistant(reply),
        ];
        _sending = false;
        if (showHint) _showRaiseHint = true;
      });

      if (showHint) {
        // 노출 사실 기록 — 칩을 누르든 무시하든 오늘은 다시 뜨지 않는다.
        await ComfortPrefs.instance.markRaiseHintShown();
      }
    } on ChatLimitReachedException catch (e) {
      if (!mounted) return;
      setState(() {
        _cache[today] = [
          ...(_cache[today] ?? []),
          ChatMessage.assistant(e.message),
        ];
        _sending = false;
        _limitReached = true;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _sending = false;
        _errorOnce = '잠시 후 다시 남겨주세요.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentDate = _dates[_currentIndex];

    // 안읽은 위로 수 (뱃지). 실패/로딩 시 0으로 안전 처리.
    final unread = ref.watch(unreadComfortCountProvider).maybeWhen(
          data: (n) => n,
          orElse: () => 0,
        );

    return Scaffold(
      backgroundColor: AppTheme.background,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 14),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Stack(
                alignment: Alignment.topCenter,
                children: [
                  _TopBar(label: _labelForDate(currentDate)),
                  // 우상단 — 설정 메뉴
                  Positioned(
                    right: 0,
                    top: 4,
                    child: _MenuButton(
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const SettingsScreen(),
                          ),
                        );
                      },
                    ),
                  ),
                  // 좌상단 — 위로함(하트) + 안읽음 뱃지. 설정(우상단)과 좌우로 분리.
                  Positioned(
                    left: 0,
                    top: 4,
                    child: _ComfortButton(
                      unread: unread,
                      onTap: () async {
                        await Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const MyComfortsScreen(),
                          ),
                        );
                        // 위로함을 보고 돌아오면 읽음 처리 결과를 뱃지에 반영
                        if (mounted) {
                          ref.invalidate(unreadComfortCountProvider);
                        }
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: _dates.length,
                  onPageChanged: (i) {
                    setState(() => _currentIndex = i);
                    _loadDate(_dates[i]);
                  },
                  itemBuilder: (context, i) {
                    final date = _dates[i];
                    final isToday = date == _todayDate;
                    final messages = _cache[date] ?? const <ChatMessage>[];
                    final loading = _loading[date] == true;
                    final hasUserMessage =
                        messages.any((m) => m.isUser);
                    final showChips = isToday &&
                        !loading &&
                        !hasUserMessage &&
                        !_limitReached &&
                        !_writing;
                    final showRaiseHint = isToday &&
                        _showRaiseHint &&
                        !_sending &&
                        !_writing;

                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: _DiaryCard(
                        entries: messages,
                        loading: loading,
                        isToday: isToday,
                        sending: isToday && _sending,
                        writing: isToday && _writing,
                        limitReached: isToday && _limitReached,
                        textController: _textController,
                        focusNode: _focusNode,
                        onTapEmpty: isToday ? _startWriting : () {},
                        onSave: _save,
                        onCancel: _cancelWriting,
                        placeholder: _placeholderFor(
                            ChatService.instance.currentSession()),
                        paperColors: _paperColors(date),
                        starterChips: showChips ? _starterChips : const [],
                        onChipTap: _startFromChip,
                        showRaiseHint: showRaiseHint,
                        onRaiseTap: _openRaiseSheet,
                      ),
                    );
                  },
                ),
              ),
              if (_errorOnce != null && _currentIndex == _dates.length - 1)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    _errorOnce!,
                    style: const TextStyle(
                        color: AppTheme.textTertiary, fontSize: 12),
                  ),
                ),
              // 페이지 인디케이터 (작은 점들)
              const SizedBox(height: 10),
              _PageDots(
                count: _dates.length,
                current: _currentIndex,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 상단: 무디 + 둥근 라벨 칩
class _TopBar extends StatelessWidget {
  final String label;
  const _TopBar({required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Mascot(pose: MascotPose.front, size: 64),
        const SizedBox(height: 8),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 280),
          child: Container(
            key: ValueKey(label),
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
            child: Text(
              label,
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.2,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// 페이지 인디케이터 — 작은 점들
class _PageDots extends StatelessWidget {
  final int count;
  final int current;
  const _PageDots({required this.count, required this.current});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (i) {
        final active = i == current;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: active ? 18 : 6,
          height: 6,
          decoration: BoxDecoration(
            color: active
                ? AppTheme.accentLight.withValues(alpha: 0.7)
                : AppTheme.textTertiary.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(3),
          ),
        );
      }),
    );
  }
}

/// 일기장 카드
class _DiaryCard extends StatelessWidget {
  final List<ChatMessage> entries;
  final bool loading;
  final bool isToday;
  final bool sending;
  final bool writing;
  final bool limitReached;
  final TextEditingController textController;
  final FocusNode focusNode;
  final VoidCallback onTapEmpty;
  final VoidCallback onSave;
  final VoidCallback onCancel;
  final String placeholder;
  final List<Color> paperColors;
  final List<String> starterChips;
  final ValueChanged<String> onChipTap;
  final bool showRaiseHint;
  final VoidCallback onRaiseTap;

  const _DiaryCard({
    required this.entries,
    required this.loading,
    required this.isToday,
    required this.sending,
    required this.writing,
    required this.limitReached,
    required this.textController,
    required this.focusNode,
    required this.onTapEmpty,
    required this.onSave,
    required this.onCancel,
    required this.placeholder,
    required this.paperColors,
    required this.starterChips,
    required this.onChipTap,
    required this.showRaiseHint,
    required this.onRaiseTap,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: paperColors,
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
            color: const Color(0xFFE8A5B8).withValues(alpha: 0.18),
            blurRadius: 40,
            offset: const Offset(0, 0),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Stack(
          children: [
            Positioned(
              top: -40,
              left: -20,
              right: -20,
              child: Container(
                height: 120,
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment.topCenter,
                    radius: 0.8,
                    colors: [
                      const Color(0xFFFFE8D6).withValues(alpha: 0.6),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            if (loading)
              const Center(child: _LoadingDots())
            else
              SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(26, 30, 26, 26),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (entries.isEmpty && !isToday)
                      _EmptyDay()
                    else
                      for (var i = 0; i < entries.length; i++)
                        _DiaryEntry(
                          key: ValueKey('entry_${i}_${entries[i].content.hashCode}'),
                          message: entries[i],
                          animateWriting: isToday &&
                              i == entries.length - 1 &&
                              !entries[i].isUser &&
                              !loading,
                        ),
                    if (sending) const _SendingDots(),
                    // 무디 인사 다음에 시작 칩 — 사용자가 아직 글을 안 적었을 때만
                    if (starterChips.isNotEmpty)
                      _StarterChips(
                        chips: starterChips,
                        onTap: onChipTap,
                      ),
                    // 무디 답변 직후 "마음 띄우기" 제안 칩 — 하루 1회
                    if (showRaiseHint)
                      _RaiseHintChip(onTap: onRaiseTap),
                    if (isToday && writing && !limitReached)
                      _WriterBox(
                        controller: textController,
                        focusNode: focusNode,
                        onSave: onSave,
                        onCancel: onCancel,
                        placeholder: placeholder,
                      )
                    else if (isToday && !limitReached)
                      _EmptyTapArea(
                          onTap: onTapEmpty, placeholder: placeholder)
                    else if (isToday && limitReached)
                      const _LimitedNote(),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// 옛날 페이지에 그날 기록이 없을 때
class _EmptyDay extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Center(
        child: Text(
          '이 날은 만나지 못했네요.',
          style: TextStyle(
            fontFamily: 'GowunDodum',
            color: const Color(0xFF9E7C8A).withValues(alpha: 0.75),
            fontSize: 14,
            fontStyle: FontStyle.italic,
            letterSpacing: 0.2,
          ),
        ),
      ),
    );
  }
}

/// 페이지 로딩 중 점셋
class _LoadingDots extends StatefulWidget {
  const _LoadingDots();

  @override
  State<_LoadingDots> createState() => _LoadingDotsState();
}

class _LoadingDotsState extends State<_LoadingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        final t = _ctrl.value;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            final phase = (t - i * 0.2) % 1.0;
            final opacity = (1 - (phase - 0.5).abs() * 2).clamp(0.2, 1.0);
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Opacity(
                opacity: opacity,
                child: const Text(
                  '·',
                  style: TextStyle(
                    color: Color(0xFF8A6878),
                    fontSize: 22,
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}

/// 한 항목
class _DiaryEntry extends StatefulWidget {
  final ChatMessage message;
  final bool animateWriting;

  const _DiaryEntry({
    super.key,
    required this.message,
    this.animateWriting = false,
  });

  @override
  State<_DiaryEntry> createState() => _DiaryEntryState();
}

class _DiaryEntryState extends State<_DiaryEntry>
    with TickerProviderStateMixin {
  late final AnimationController _fadeCtrl;
  late final Animation<double> _fade;
  AnimationController? _writeCtrl;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );
    _fade = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _fadeCtrl.forward();

    if (widget.animateWriting && !widget.message.isUser) {
      final len = widget.message.content.length;
      final ms = (len * 60).clamp(600, 6000);
      _writeCtrl = AnimationController(
        vsync: this,
        duration: Duration(milliseconds: ms),
      );
      _writeCtrl!.forward();
    }
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    _writeCtrl?.dispose();
    super.dispose();
  }

  void _skipWriting() {
    if (_writeCtrl != null && _writeCtrl!.isAnimating) {
      _writeCtrl!.value = 1.0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isUser = widget.message.isUser;
    final full = widget.message.content;

    final textStyle = TextStyle(
      fontFamily: 'GowunDodum',
      color: isUser
          ? const Color(0xFF3D2438)
          : const Color(0xFF6B4855).withValues(alpha: 0.85),
      fontSize: isUser ? 16.5 : 14,
      fontStyle: isUser ? FontStyle.normal : FontStyle.italic,
      height: 1.8,
      fontWeight: FontWeight.w400,
      letterSpacing: isUser ? 0.1 : 0.15,
    );

    Widget content;
    if (_writeCtrl != null) {
      content = GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _skipWriting,
        child: AnimatedBuilder(
          animation: _writeCtrl!,
          builder: (context, _) {
            final shown = (full.length * _writeCtrl!.value).round();
            final visible = full.substring(0, shown);
            final inProgress = shown < full.length;
            return Text.rich(
              TextSpan(
                style: textStyle,
                children: [
                  TextSpan(text: visible),
                  if (inProgress)
                    WidgetSpan(
                      alignment: PlaceholderAlignment.middle,
                      child: _PenTip(),
                    ),
                ],
              ),
            );
          },
        ),
      );
    } else {
      content = Text(full, style: textStyle);
    }

    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.04),
          end: Offset.zero,
        ).animate(_fade),
        child: Padding(
          padding: EdgeInsets.only(
            bottom: 22,
            left: isUser ? 0 : 16,
          ),
          child: content,
        ),
      ),
    );
  }
}

/// 펜 끝
class _PenTip extends StatefulWidget {
  @override
  State<_PenTip> createState() => _PenTipState();
}

class _PenTipState extends State<_PenTip>
    with SingleTickerProviderStateMixin {
  late final AnimationController _blink;

  @override
  void initState() {
    super.initState();
    _blink = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _blink.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _blink,
      builder: (context, _) {
        final t = _blink.value;
        return Container(
          margin: const EdgeInsets.only(left: 3, bottom: 2),
          width: 9,
          height: 9,
          decoration: BoxDecoration(
            color: const Color(0xFFC76B86)
                .withValues(alpha: 0.6 + 0.4 * t),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFE8A5B8).withValues(alpha: 0.5 * t),
                blurRadius: 10,
                spreadRadius: 2,
              ),
            ],
          ),
        );
      },
    );
  }
}

/// 무디가 답 쓰는 중 점셋
class _SendingDots extends StatefulWidget {
  const _SendingDots();

  @override
  State<_SendingDots> createState() => _SendingDotsState();
}

class _SendingDotsState extends State<_SendingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 16, bottom: 22),
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (context, _) {
          final t = _ctrl.value;
          return Row(
            children: List.generate(3, (i) {
              final phase = (t - i * 0.2) % 1.0;
              final opacity =
                  (1 - (phase - 0.5).abs() * 2).clamp(0.2, 1.0);
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Opacity(
                  opacity: opacity,
                  child: const Text(
                    '·',
                    style: TextStyle(
                      color: Color(0xFF8A6878),
                      fontSize: 22,
                    ),
                  ),
                ),
              );
            }),
          );
        },
      ),
    );
  }
}

/// 빈 자리 — 탭하면 글쓰기 시작
class _EmptyTapArea extends StatelessWidget {
  final VoidCallback onTap;
  final String placeholder;
  const _EmptyTapArea({required this.onTap, required this.placeholder});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        constraints: const BoxConstraints(minHeight: 90),
        alignment: Alignment.topLeft,
        child: Text(
          placeholder,
          style: const TextStyle(
            fontFamily: 'GowunDodum',
            color: Color(0xFF9E7C8A),
            fontSize: 15,
            fontStyle: FontStyle.italic,
            height: 1.8,
            letterSpacing: 0.2,
            fontWeight: FontWeight.w400,
          ),
        ),
      ),
    );
  }
}

/// 사용자가 글 쓰는 영역
class _WriterBox extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onSave;
  final VoidCallback onCancel;
  final String placeholder;

  const _WriterBox({
    required this.controller,
    required this.focusNode,
    required this.onSave,
    required this.onCancel,
    required this.placeholder,
  });

  @override
  State<_WriterBox> createState() => _WriterBoxState();
}

class _WriterBoxState extends State<_WriterBox> {
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    widget.focusNode.addListener(_onFocusChange);
    _focused = widget.focusNode.hasFocus;
  }

  @override
  void dispose() {
    widget.focusNode.removeListener(_onFocusChange);
    super.dispose();
  }

  void _onFocusChange() {
    if (!mounted) return;
    setState(() => _focused = widget.focusNode.hasFocus);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: _focused
                ? const Color(0xFFEFD9D4).withValues(alpha: 0.6)
                : const Color(0xFFF0DCD6).withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _focused
                  ? const Color(0xFFD4A5B0).withValues(alpha: 0.5)
                  : const Color(0xFFD4A5B0).withValues(alpha: 0.15),
              width: 1,
            ),
          ),
          child: TextField(
            controller: widget.controller,
            focusNode: widget.focusNode,
            minLines: 2,
            maxLines: 8,
            autofocus: true,
            cursorColor: const Color(0xFFC76B86),
            cursorWidth: 1.5,
            style: const TextStyle(
              fontFamily: 'GowunDodum',
              color: Color(0xFF3D2438),
              fontSize: 16.5,
              height: 1.8,
              fontWeight: FontWeight.w400,
              letterSpacing: 0.1,
            ),
            decoration: InputDecoration(
              hintText: widget.placeholder,
              hintStyle: const TextStyle(
                fontFamily: 'GowunDodum',
                color: Color(0xFF9E7C8A),
                fontSize: 15,
                fontStyle: FontStyle.italic,
                height: 1.8,
                letterSpacing: 0.2,
                fontWeight: FontWeight.w400,
              ),
              filled: false,
              fillColor: Colors.transparent,
              border: InputBorder.none,
              focusedBorder: InputBorder.none,
              enabledBorder: InputBorder.none,
              disabledBorder: InputBorder.none,
              errorBorder: InputBorder.none,
              focusedErrorBorder: InputBorder.none,
              contentPadding: EdgeInsets.zero,
              isDense: true,
            ),
          ),
        ),
        const SizedBox(height: 14),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(
              onPressed: widget.onCancel,
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF9E7C8A),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                textStyle: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              child: const Text('취소'),
            ),
            const SizedBox(width: 4),
            TextButton(
              onPressed: widget.onSave,
              style: TextButton.styleFrom(
                backgroundColor:
                    const Color(0xFFE8A5B8).withValues(alpha: 0.35),
                foregroundColor: const Color(0xFF7A2E45),
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                textStyle: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              child: const Text('남기기'),
            ),
          ],
        ),
      ],
    );
  }
}

/// 한도 안내
class _LimitedNote extends StatelessWidget {
  const _LimitedNote();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Text(
        '오늘은 여기까지. 내일 다시 만나요.',
        style: TextStyle(
          fontFamily: 'GowunDodum',
          color: const Color(0xFF9E7C8A).withValues(alpha: 0.85),
          fontSize: 13.5,
          fontStyle: FontStyle.italic,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

/// 우상단 메뉴 버튼
class _MenuButton extends StatelessWidget {
  final VoidCallback onTap;
  const _MenuButton({required this.onTap});

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
            Icons.more_vert_rounded,
            color: AppTheme.textSecondary.withValues(alpha: 0.7),
            size: 22,
          ),
        ),
      ),
    );
  }
}

/// 우상단 위로함 버튼 — 받은 위로로 가는 진입점.
/// 안 읽은 위로가 있으면 작은 뱃지로 개수를 표시한다.
class _ComfortButton extends StatelessWidget {
  final int unread;
  final VoidCallback onTap;

  const _ComfortButton({required this.unread, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Icon(
                Icons.favorite_rounded,
                color: AppTheme.textSecondary.withValues(alpha: 0.7),
                size: 22,
              ),
              if (unread > 0)
                Positioned(
                  right: -5,
                  top: -5,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 5, vertical: 1),
                    constraints: const BoxConstraints(minWidth: 16),
                    decoration: BoxDecoration(
                      color: AppTheme.accent,
                      borderRadius: BorderRadius.circular(9),
                      border: Border.all(
                        color: AppTheme.background,
                        width: 1.5,
                      ),
                    ),
                    child: Text(
                      unread > 99 ? '99+' : '$unread',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        height: 1.1,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 무디 답변 직후 일기장에 가만히 놓이는 "마음 띄우기" 제안 칩.
/// 강제 모달이 아니라, 누르면 RaiseComfortSheet 가 열리고 무시하면 지나간다.
class _RaiseHintChip extends StatelessWidget {
  final VoidCallback onTap;

  const _RaiseHintChip({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 16, bottom: 22, top: 2),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(18),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              decoration: BoxDecoration(
                color: const Color(0xFFE8A5B8).withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: const Color(0xFFD4A5B0).withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.favorite_border_rounded,
                    size: 15,
                    color: const Color(0xFFC76B86).withValues(alpha: 0.8),
                  ),
                  const SizedBox(width: 7),
                  Text(
                    '이 마음, 누군가에게 띄워볼까요?',
                    style: const TextStyle(
                      fontFamily: 'GowunDodum',
                      color: Color(0xFF7A4D5A),
                      fontSize: 13.5,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.1,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 무디가 던지는 시작 칩들 — 무디 인사 아래에 가볍게 깔린다.
/// 사용자가 빈 종이 앞에서 멈추지 않게 작은 시작점을 던져준다.
class _StarterChips extends StatelessWidget {
  final List<String> chips;
  final ValueChanged<String> onTap;

  const _StarterChips({required this.chips, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 16, bottom: 22, top: 2),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: chips.map((text) {
          return _StarterChip(text: text, onTap: () => onTap(text));
        }).toList(),
      ),
    );
  }
}

class _StarterChip extends StatelessWidget {
  final String text;
  final VoidCallback onTap;

  const _StarterChip({required this.text, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFFE8A5B8).withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: const Color(0xFFD4A5B0).withValues(alpha: 0.3),
              width: 1,
            ),
          ),
          child: Text(
            text,
            style: const TextStyle(
              fontFamily: 'GowunDodum',
              color: Color(0xFF7A4D5A),
              fontSize: 13.5,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.1,
            ),
          ),
        ),
      ),
    );
  }
}