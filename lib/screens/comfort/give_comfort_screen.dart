import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../theme/app_theme.dart';
import '../../models/comfort_models.dart';
import '../../providers/comfort_provider.dart';
import '../../services/comfort_content_filter.dart';
import '../../services/comfort_templates.dart';
import '../../utils/app_snackbar.dart';

/// 위로 보내기 화면 (자유입력 버전).
///
/// 풀에서 익명 요청 카드를 한 장씩 꺼내, 그 사람의 기분/대분류에 맞는
/// 추천 문구 칩과 자유 입력칸을 함께 보여준다.
/// - 추천 칩을 탭하면 입력칸에 채워지고, 그대로/고쳐서/직접 써서 보낼 수 있다.
/// - 보내기 전 클라 1차 필터(ComfortContentFilter)로 즉시 피드백.
/// - 서버(comfort_content_reason)가 최종 권위자: 막히면 사유를 스낵바로.
/// - 입력칸+버튼이 콘텐츠 흐름 안에 있어 키보드가 올라오면 함께 따라 올라온다.
/// 받는 사람 정보는 익명(대분류까지만 표시).
class GiveComfortScreen extends ConsumerStatefulWidget {
  const GiveComfortScreen({super.key});

  @override
  ConsumerState<GiveComfortScreen> createState() => _GiveComfortScreenState();
}

class _GiveComfortScreenState extends ConsumerState<GiveComfortScreen> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();

  List<ComfortTemplate> _suggestions = const [];
  String? _suggestionsForRequestId; // 어떤 요청에 대해 만든 추천인지
  bool _sending = false;

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  /// 현재 대상에 맞춰 추천 문구를 한 번만 생성한다.
  /// 대상이 바뀌면 새로 뽑고 입력칸을 비운다.
  void _ensureSuggestions(ComfortRequest req) {
    if (_suggestionsForRequestId == req.id && _suggestions.isNotEmpty) return;
    _suggestions = ComfortTemplates.pickFor(
      moodLevel: req.moodLevel,
      tag: req.tag,
    );
    _suggestionsForRequestId = req.id;
    _controller.clear();
  }

  void _resetForNext() {
    setState(() {
      _suggestions = const [];
      _suggestionsForRequestId = null;
      _controller.clear();
    });
  }

  Future<void> _send(ComfortRequest req) async {
    final text = _controller.text.trim();

    // 클라 1차 필터 — 즉시 피드백
    final reason = ComfortContentFilter.check(text);
    if (reason != null) {
      _showSnack(reason);
      return;
    }

    setState(() => _sending = true);
    FocusScope.of(context).unfocus();

    // 추천 칩 문구를 그대로 보냈으면 그 id, 직접 썼으면 'custom'.
    final matched = _suggestions.where((t) => t.content == text);
    final templateId = matched.isNotEmpty ? matched.first.id : 'custom';

    try {
      await ref.read(comfortGivingProvider.notifier).send(
            requestId: req.id,
            templateId: templateId,
            content: text,
          );
      if (!mounted) return;
      _resetForNext();
      _showSnack('따뜻한 마음을 전했어요.');
    } catch (e) {
      if (!mounted) return;
      // 서버가 막은 사유(악플/만료/중복 등)를 그대로 노출
      _showSnack(e.toString());
      // 만료/중복 등 대상 문제면 다음 대상으로
      final msg = e.toString();
      if (msg.contains('만료') || msg.contains('사라진') || msg.contains('이미 이 마음')) {
        await ref.read(comfortGivingProvider.notifier).next();
        if (mounted) _resetForNext();
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _skip() async {
    _resetForNext();
    await ref.read(comfortGivingProvider.notifier).next();
  }

  void _showSnack(String msg) {
    showAppSnack(context, msg);
    }

  @override
  Widget build(BuildContext context) {
    final asyncReq = ref.watch(comfortGivingProvider);

    return Scaffold(
      backgroundColor: AppTheme.background,
      // 키보드가 올라오면 본문이 줄어들며 입력칸/버튼이 함께 따라 올라온다.
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        backgroundColor: AppTheme.background,
        elevation: 0,
        title: Text('위로 건네기',
            style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w700)),
        iconTheme: IconThemeData(color: AppTheme.textPrimary),
      ),
      body: asyncReq.when(
        loading: () => const Center(
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        error: (e, _) => _buildMessage(
          icon: Icons.cloud_off_rounded,
          title: '잠시 연결이 불안정해요',
          desc: '잠시 후 다시 시도해 주세요.',
          action: '다시 시도',
          onAction: () => ref.read(comfortGivingProvider.notifier).next(),
        ),
        data: (req) {
          if (req == null) return _buildEmpty();
          _ensureSuggestions(req);
          return _buildCard(req);
        },
      ),
    );
  }

  Widget _buildCard(ComfortRequest req) {
    return SafeArea(
      child: SingleChildScrollView(
        // 키보드 높이만큼 하단 여백을 줘서 입력칸이 가려지지 않게.
        padding: EdgeInsets.fromLTRB(
          20,
          12,
          20,
          MediaQuery.of(context).viewInsets.bottom + 20,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 익명 마음 카드
            _AnonCard(req: req, message: _cardMessage(req)),
            const SizedBox(height: 24),

            // 입력칸 (핵심 동작 영역 — 상단부에 배치)
            Text(
              '건네고 싶은 말',
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            Container(
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppTheme.divider),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              child: TextField(
                controller: _controller,
                focusNode: _focusNode,
                minLines: 3,
                maxLines: 6,
                maxLength: ComfortContentFilter.maxLength,
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 15,
                  height: 1.6,
                ),
                decoration: InputDecoration(
                  hintText: '진심을 담아 한마디 건네보세요.\n아래 추천 문구를 골라도 좋아요.',
                  hintStyle: TextStyle(
                    color: AppTheme.textTertiary,
                    fontSize: 14,
                    height: 1.5,
                  ),
                  border: InputBorder.none,
                  counterStyle: TextStyle(
                    color: AppTheme.textTertiary,
                    fontSize: 11,
                  ),
                ),
                onChanged: (_) => setState(() {}), // 보내기 버튼 활성 갱신
              ),
            ),
            const SizedBox(height: 16),

            // 추천 문구 칩
            Text(
              '이런 말은 어때요',
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 10),
            ..._suggestions.map((t) {
              return GestureDetector(
                onTap: () {
                  _controller.text = t.content;
                  _controller.selection = TextSelection.fromPosition(
                    TextPosition(offset: t.content.length),
                  );
                  setState(() {});
                },
                child: Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.divider),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.add_rounded,
                          size: 18, color: AppTheme.textTertiary),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          t.content,
                          style: TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 14,
                            height: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
            const SizedBox(height: 20),

            // 하단 액션 — 콘텐츠 흐름 안에 둬서 키보드 위로 따라 올라옴
            Row(
              children: [
                TextButton(
                  onPressed: _sending ? null : _skip,
                  child: Text(
                    '다음 마음 보기',
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: SizedBox(
                    height: 50,
                    child: ElevatedButton(
                      onPressed: (_controller.text.trim().isNotEmpty &&
                              !_sending)
                          ? () => _send(req)
                          : null,
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
                              '위로 보내기',
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
    );
  }

  /// 요청자가 자유 텍스트를 안 쓰므로(띄우기는 기분+태그만),
  /// 카드에 보여줄 정서 문구를 기분/대분류 기반으로 만들어준다.
  String _cardMessage(ComfortRequest req) {
    final cat = req.category;
    if (cat != null) {
      switch (cat) {
        case ComfortCategory.work:
          return '일과 진로 사이에서\n마음이 무거운 하루를 보내고 있어요.';
        case ComfortCategory.relationship:
          return '사람 사이의 일로\n마음이 복잡한 하루예요.';
        case ComfortCategory.anxiety:
          return '괜히 불안하고 걱정이 많은\n그런 하루를 보내고 있어요.';
        case ComfortCategory.fatigue:
          return '모든 게 지치고\n기운이 나지 않는 하루예요.';
        case ComfortCategory.loneliness:
          return '혼자인 것 같아\n조금 쓸쓸한 하루를 보내고 있어요.';
        case ComfortCategory.sadness:
          return '이유 모를 슬픔이\n마음에 내려앉은 하루예요.';
        case ComfortCategory.etc:
          return '딱히 이유는 모르겠는\n그런 하루를 보내고 있어요.';
      }
    }
    if (req.moodLevel <= 2) {
      return '오늘 마음이 많이\n가라앉아 있는 하루예요.';
    } else if (req.moodLevel == 3) {
      return '그냥 그런,\n잔잔한 하루를 보내고 있어요.';
    }
    return '오늘 하루의 마음을\n조용히 나누고 싶어 해요.';
  }

  Widget _buildEmpty() {
    return _buildMessage(
      icon: Icons.favorite_border_rounded,
      title: '지금은 기다리는 마음이 없어요',
      desc: '모두의 마음이 잠시 평온한가 봐요.\n나중에 다시 들러 위로를 건네주세요.',
      action: '새로고침',
      onAction: () => ref.read(comfortGivingProvider.notifier).next(),
    );
  }

  Widget _buildMessage({
    required IconData icon,
    required String title,
    required String desc,
    required String action,
    required VoidCallback onAction,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: AppTheme.textTertiary),
            const SizedBox(height: 20),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              desc,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 13.5,
                height: 1.6,
              ),
            ),
            const SizedBox(height: 24),
            TextButton(
              onPressed: onAction,
              child: Text(
                action,
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
}

/// 익명 마음 카드 — 받는 사람의 기분/대분류만 보여준다(세부 태그 비노출).
class _AnonCard extends StatelessWidget {
  final ComfortRequest req;
  final String message;

  const _AnonCard({required this.req, required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.moodColor(req.moodLevel).withOpacity(0.35),
            AppTheme.surface,
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _chip(AppTheme.moodLabel(req.moodLevel), AppTheme.textPrimary),
              if (req.category != null) ...[
                const SizedBox(width: 8),
                _chip(req.category!.label, AppTheme.textSecondary),
              ],
            ],
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 16,
              height: 1.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '이름도 얼굴도 모르는 누군가의 마음이에요.',
            style: TextStyle(
              color: AppTheme.textTertiary,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(String text, Color textColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppTheme.background.withOpacity(0.4),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: textColor,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}