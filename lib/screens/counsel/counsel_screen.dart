import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../theme/app_theme.dart';
import '../../models/chat_message.dart';
import '../../providers/chat_provider.dart';
import '../../widgets/mascot.dart';

/// 상담 화면.
///
/// 마스코트(무디)와 따뜻하게 대화한다.
/// 답변 대기 중에는 '입력 중' 표시가 뜨고,
/// 하단에는 위기 시 도움받을 수 있는 연락처를 안내한다.
class CounselScreen extends ConsumerStatefulWidget {
  const CounselScreen({super.key});

  @override
  ConsumerState<CounselScreen> createState() => _CounselScreenState();
}

class _CounselScreenState extends ConsumerState<CounselScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
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

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    _controller.clear();
    FocusScope.of(context).unfocus();
    await ref.read(chatProvider.notifier).send(text);
    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(chatProvider);

    ref.listen(chatProvider, (prev, next) {
      if (prev?.messages.length != next.messages.length || next.waiting) {
        _scrollToBottom();
      }
    });

    final itemCount = state.messages.length + (state.waiting ? 1 : 0);

    return Scaffold(
      backgroundColor: AppTheme.background,
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('무디와 이야기하기'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // 위기 도움 안내 (상단 고정)
            _buildHelpBar(context),
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                itemCount: itemCount,
                itemBuilder: (context, i) {
                  if (i >= state.messages.length) {
                    return _buildTyping();
                  }
                  return _buildMessage(context, state.messages[i]);
                },
              ),
            ),
            if (state.error != null) _buildError(state.error!),
            _buildInput(context, state.waiting),
          ],
        ),
      ),
    );
  }

  Widget _buildMessage(BuildContext context, ChatMessage msg) {
    if (!msg.isUser) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 16, right: 40),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _avatar(),
            const SizedBox(width: 10),
            Flexible(
              child: _bubble(
                context,
                child: Text(
                  msg.content,
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
            child: _bubble(
              context,
              child: Text(
                msg.content,
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

  Widget _avatar() {
    return const Mascot(
      pose: MascotPose.front,
      size: 40,
      animate: false,
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

  Widget _buildError(String error) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Text(
        error,
        style: const TextStyle(color: AppTheme.textTertiary, fontSize: 13),
      ),
    );
  }

  // 위기 도움 안내 (상단 고정)
  Widget _buildHelpBar(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: AppTheme.surface.withValues(alpha: 0.5),
      child: Text(
        '힘든 마음이 클 땐 혼자 견디지 마세요 · 자살예방 상담 109 · 정신건강상담 1577-0199',
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontSize: 11,
              color: AppTheme.textTertiary,
            ),
      ),
    );
  }

  Widget _buildInput(BuildContext context, bool waiting) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppTheme.divider)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              minLines: 1,
              maxLines: 4,
              enabled: !waiting,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _send(),
              style: Theme.of(context).textTheme.bodyLarge,
              decoration: InputDecoration(
                hintText: waiting ? '무디가 듣고 있어요…' : '마음을 들려주세요',
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: Icon(
              Icons.send_rounded,
              color: waiting ? AppTheme.textTertiary : AppTheme.accentLight,
            ),
            onPressed: waiting ? null : _send,
          ),
        ],
      ),
    );
  }
}