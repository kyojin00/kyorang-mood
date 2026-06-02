import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../theme/app_theme.dart';
import '../../models/mood_entry.dart';
import '../../providers/mood_provider.dart';
import '../../providers/profile_provider.dart';
import '../../services/suggestion_service.dart';
import '../../widgets/mood_selector.dart';
import '../../widgets/suggestion_card.dart';

/// 대화 단계
enum _Phase { askMood, askNote, finished }

/// 채팅 메시지 한 개
class _Msg {
  final bool isBot;
  final String? text;
  final int? moodLevel;
  final Widget? custom;

  const _Msg.bot(this.text)
      : isBot = true,
        moodLevel = null,
        custom = null;
  const _Msg.user(this.text)
      : isBot = false,
        moodLevel = null,
        custom = null;
  const _Msg.userMood(this.moodLevel)
      : isBot = false,
        text = null,
        custom = null;
  const _Msg.botCustom(this.custom)
      : isBot = true,
        text = null,
        moodLevel = null;
}

/// 기분 기록 (대화형) 화면.
///
/// 허브 홈에서 "기분 기록하기"로 진입한다.
/// 비서(마스코트)가 말풍선으로 묻고, 사용자가 기분/메모로 응답하면
/// 대화가 쌓이며, 마지막에 성향 맞춤 제안을 건넨다.
class ChatRecordScreen extends ConsumerStatefulWidget {
  const ChatRecordScreen({super.key});

  @override
  ConsumerState<ChatRecordScreen> createState() => _ChatRecordScreenState();
}

class _ChatRecordScreenState extends ConsumerState<ChatRecordScreen> {
  final List<_Msg> _messages = [];
  final TextEditingController _noteController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  _Phase _phase = _Phase.askMood;
  int? _selectedLevel;
  MoodEntry? _recordedEntry;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _addBot('${_greeting()}. 오늘 하루는 어땠어요?');
    });
  }

  @override
  void dispose() {
    _noteController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _addBot(String text, {int delayMs = 400}) async {
    setState(() => _busy = true);
    await Future.delayed(Duration(milliseconds: delayMs));
    if (!mounted) return;
    setState(() {
      _messages.add(_Msg.bot(text));
      _busy = false;
    });
    _scrollToBottom();
  }

  Future<void> _addBotCustom(Widget widget, {int delayMs = 400}) async {
    setState(() => _busy = true);
    await Future.delayed(Duration(milliseconds: delayMs));
    if (!mounted) return;
    setState(() {
      _messages.add(_Msg.botCustom(widget));
      _busy = false;
    });
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _onMoodSelected(int level) async {
    if (_busy) return;
    setState(() {
      _selectedLevel = level;
      _messages.add(_Msg.userMood(level));
      _phase = _Phase.askNote;
    });
    _scrollToBottom();
    await _addBot('그렇군요. 무슨 일이 있었는지 한마디 남겨볼래요?');
  }

  Future<void> _onNoteSubmit({required bool skip}) async {
    if (_busy) return;
    final note = skip ? '' : _noteController.text.trim();
    FocusScope.of(context).unfocus();

    if (note.isNotEmpty) {
      setState(() => _messages.add(_Msg.user(note)));
      _scrollToBottom();
    }

    final notifier = ref.read(moodEntriesProvider.notifier);
    final entry = await notifier.record(
      moodLevel: _selectedLevel!,
      note: note,
    );
    final persona = ref.read(personaProvider) ?? SuggestionType.quote;
    final suggestion = SuggestionService.pick(persona, _selectedLevel!);
    await notifier.attachSuggestion(
      entry.id,
      suggestion: suggestion,
      type: persona,
    );

    _recordedEntry = entry.copyWith(
      suggestion: suggestion,
      suggestionType: persona,
    );
    _noteController.clear();

    setState(() => _phase = _Phase.finished);

    await _addBot('오늘의 당신에게, 이 말을 전하고 싶어요.');
    await _addBotCustom(
      SuggestionCard(
        suggestion: suggestion,
        helpful: null,
        onReact: _react,
      ),
      delayMs: 300,
    );
  }

  Future<void> _react(bool helpful) async {
    final entry = _recordedEntry;
    if (entry == null) return;
    await ref
        .read(moodEntriesProvider.notifier)
        .markSuggestion(entry.id, helpful: helpful);
    if (!mounted) return;
    final idx = _messages.lastIndexWhere((m) => m.custom is SuggestionCard);
    if (idx != -1) {
      setState(() {
        _messages[idx] = _Msg.botCustom(
          SuggestionCard(
            suggestion: entry.suggestion!,
            helpful: helpful,
            onReact: _react,
          ),
        );
        _recordedEntry = entry.copyWith(suggestionHelpful: helpful);
      });
    }
  }

  void _restart() {
    setState(() {
      _messages.clear();
      _noteController.clear();
      _selectedLevel = null;
      _recordedEntry = null;
      _phase = _Phase.askMood;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _addBot('다시 기록해볼까요? 지금 기분은 어때요?');
    });
  }

  Color get _moodTint {
    if (_selectedLevel != null) return AppTheme.moodColor(_selectedLevel!);
    return AppTheme.accent;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('오늘 기분'),
      ),
      body: AnimatedContainer(
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(0, -0.8),
            radius: 1.1,
            colors: [
              _moodTint.withValues(alpha: 0.22),
              AppTheme.background,
            ],
            stops: const [0.0, 0.7],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  itemCount: _messages.length + (_busy ? 1 : 0),
                  itemBuilder: (context, i) {
                    if (i >= _messages.length) {
                      return _buildTyping();
                    }
                    return _buildMessage(context, _messages[i]);
                  },
                ),
              ),
              _buildInputArea(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMessage(BuildContext context, _Msg msg) {
    if (msg.isBot) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 16, right: 40),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _avatar(),
            const SizedBox(width: 10),
            Flexible(
              child: msg.custom ??
                  _bubble(
                    context,
                    child: Text(
                      msg.text ?? '',
                      style: Theme.of(context)
                          .textTheme
                          .bodyLarge
                          ?.copyWith(height: 1.5),
                    ),
                    color: AppTheme.surface,
                  ),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 16, left: 40),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Flexible(
            child: msg.moodLevel != null
                ? _moodBubble(context, msg.moodLevel!)
                : _bubble(
                    context,
                    child: Text(
                      msg.text ?? '',
                      style: Theme.of(context)
                          .textTheme
                          .bodyLarge
                          ?.copyWith(color: Colors.white, height: 1.5),
                    ),
                    color: AppTheme.accentDark,
                  ),
          ),
        ],
      ),
    );
  }

  // 채팅 아바타 (작은 마스코트 얼굴)
  Widget _avatar() {
    return Container(
      width: 36,
      height: 36,
      decoration: const BoxDecoration(
        color: AppTheme.accent,
        shape: BoxShape.circle,
      ),
      child: const MoodFace(level: 5, color: Colors.white, size: 36),
    );
  }

  Widget _bubble(
    BuildContext context, {
    required Widget child,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(18),
      ),
      child: child,
    );
  }

  Widget _moodBubble(BuildContext context, int level) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.moodColor(level),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          MoodFace(level: level, color: AppTheme.background, size: 24),
          const SizedBox(width: 8),
          Text(
            AppTheme.moodLabel(level),
            style: const TextStyle(
              color: AppTheme.background,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTyping() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _avatar(),
          const SizedBox(width: 10),
          _bubble(
            context,
            color: AppTheme.surface,
            child: const Text(
              '· · ·',
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 16,
                letterSpacing: 2,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputArea(BuildContext context) {
    switch (_phase) {
      case _Phase.askMood:
        return _buildMoodInput(context);
      case _Phase.askNote:
        return _buildNoteInput(context);
      case _Phase.finished:
        return _buildFinishedInput(context);
    }
  }

  Widget _buildMoodInput(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppTheme.divider)),
      ),
      child: MoodSelector(
        selected: _selectedLevel,
        onSelected: _onMoodSelected,
      ),
    );
  }

  Widget _buildNoteInput(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppTheme.divider)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _noteController,
              maxLength: 100,
              minLines: 1,
              maxLines: 3,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _onNoteSubmit(skip: false),
              style: Theme.of(context).textTheme.bodyLarge,
              decoration: const InputDecoration(
                hintText: '한마디 남기기…',
                counterText: '',
              ),
            ),
          ),
          const SizedBox(width: 8),
          ValueListenableBuilder(
            valueListenable: _noteController,
            builder: (context, value, _) {
              final hasText = value.text.trim().isNotEmpty;
              return TextButton(
                onPressed: () => _onNoteSubmit(skip: !hasText),
                child: Text(hasText ? '보내기' : '건너뛰기'),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildFinishedInput(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppTheme.divider)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextButton(
              onPressed: _restart,
              child: const Text('다시 기록하기'),
            ),
          ),
          Expanded(
            child: TextButton(
              onPressed: () => Navigator.of(context).maybePop(),
              child: const Text('완료'),
            ),
          ),
        ],
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