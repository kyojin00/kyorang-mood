import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme/app_theme.dart';
import '../models/comfort_models.dart';
import '../providers/comfort_provider.dart';
import '../utils/app_snackbar.dart';

/// 익명 위로 풀에 "이 마음"을 띄우는 바텀시트.
///
/// 어디서든 RaiseComfortSheet.show(context) 로 호출한다.
/// 흐름: 기분 단계 → 대분류 칩 → 대분류 누르면 세부 태그 펼침 → 세부 선택 → 띄우기 → 안내.
/// 띄우기는 comfortRequestProvider 가 담당(테이블 직접 insert, RLS 허용).
/// 자유 입력은 없음(기분+세부 태그만) → 모더레이션 부담 없음.
class RaiseComfortSheet extends ConsumerStatefulWidget {
  /// 기분 기록 흐름에서 이미 고른 기분이 있으면 초기값으로 넘길 수 있다.
  final int? initialMood;

  const RaiseComfortSheet({super.key, this.initialMood});

  /// 시트를 띄운다. 요청에 성공하면 true, 취소/실패면 false/null.
  static Future<bool?> show(BuildContext context, {int? initialMood}) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => RaiseComfortSheet(initialMood: initialMood),
    );
  }

  @override
  ConsumerState<RaiseComfortSheet> createState() => _RaiseComfortSheetState();
}

class _RaiseComfortSheetState extends ConsumerState<RaiseComfortSheet> {
  int? _mood;
  ComfortCategory? _expandedCategory;  // 펼친 대분류 (아코디언)
  ComfortTag? _selectedTag;            // 선택된 세부 태그
  bool _done = false;                  // 띄우기 성공 후 안내 화면

  @override
  void initState() {
    super.initState();
    _mood = widget.initialMood;
  }

  bool get _canSubmit => _mood != null;

  Future<void> _submit() async {
    if (_mood == null) return;
    final ok = await ref.read(comfortRequestProvider.notifier).raise(
          moodLevel: _mood!,
          tag: _selectedTag,
        );
    if (!mounted) return;
    if (ok) {
      ref.invalidate(comfortGivingProvider);
      setState(() => _done = true);
    } else {
      final err = ref.read(comfortRequestProvider).error;
      showAppSnack(context, err?.toString() ?? '요청을 띄우지 못했어요.');
    }
  }

  @override
  Widget build(BuildContext context) {
    // 시트가 화면을 너무 가리지 않게, 최대 높이를 화면의 85%로 제한.
    final maxHeight = MediaQuery.of(context).size.height * 0.85;

    return Container(
      constraints: BoxConstraints(maxHeight: maxHeight),
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: _done ? _buildDone() : _buildForm(),
        ),
      ),
    );
  }

  // ── 입력 폼 ──
  Widget _buildForm() {
    final submitting = ref.watch(comfortRequestProvider) is AsyncLoading;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 핸들
        Container(
          width: 40,
          height: 4,
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: AppTheme.divider,
            borderRadius: BorderRadius.circular(2),
          ),
        ),

        // 본문 — 길어지면 스크롤
        Flexible(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '이 마음, 누군가에게 띄워볼까요',
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '익명으로 풀에 올라가요. 24시간 안에 누군가의 위로가 닿을 거예요.',
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 13,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 24),

                // 기분 단계
                Text('지금 마음은 어느 정도인가요',
                    style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 12),
                _buildMoodRow(),

                const SizedBox(height: 24),

                // 맥락 — 대분류 + 세부 (아코디언)
                Row(
                  children: [
                    Text('무엇 때문일까요',
                        style: TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w700)),
                    const SizedBox(width: 6),
                    Text('(선택)',
                        style: TextStyle(
                            color: AppTheme.textTertiary, fontSize: 12)),
                  ],
                ),
                const SizedBox(height: 12),
                _buildCategoryAccordion(),

                const SizedBox(height: 20),
              ],
            ),
          ),
        ),

        // 띄우기 버튼 — 항상 하단 고정(콘텐츠는 위에서 스크롤)
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: (_canSubmit && !submitting) ? _submit : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.accent,
              disabledBackgroundColor: AppTheme.surfaceVariant,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: submitting
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor:
                          AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Text(
                    '마음 띄우기',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildMoodRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(5, (i) {
        final level = i + 1;
        final selected = _mood == level;
        return GestureDetector(
          onTap: () => setState(() => _mood = level),
          child: Container(
            width: 56,
            height: 64,
            decoration: BoxDecoration(
              color: selected
                  ? AppTheme.moodColor(level).withOpacity(0.9)
                  : AppTheme.surfaceVariant,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: selected
                    ? AppTheme.moodColor(level)
                    : AppTheme.divider,
                width: selected ? 2 : 1,
              ),
            ),
            child: Center(
              child: Text(
                AppTheme.moodLabel(level),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: selected ? Colors.white : AppTheme.textSecondary,
                  fontSize: 11,
                  fontWeight:
                      selected ? FontWeight.w800 : FontWeight.w500,
                ),
              ),
            ),
          ),
        );
      }),
    );
  }

  /// 대분류 칩을 누르면 그 아래에 세부 태그가 펼쳐지는 아코디언.
  Widget _buildCategoryAccordion() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 대분류 칩들
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: ComfortCategory.values.map((cat) {
            final expanded = _expandedCategory == cat;
            final hasSelectedTag =
                _selectedTag != null && _selectedTag!.category == cat;
            return GestureDetector(
              onTap: () => setState(() {
                if (_expandedCategory == cat) {
                  // 같은 걸 다시 누르면 접기
                  _expandedCategory = null;
                } else {
                  _expandedCategory = cat;
                }
              }),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 9),
                decoration: BoxDecoration(
                  color: hasSelectedTag
                      ? AppTheme.accent.withOpacity(0.9)
                      : (expanded
                          ? AppTheme.accent.withOpacity(0.2)
                          : AppTheme.surfaceVariant),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: hasSelectedTag || expanded
                        ? AppTheme.accent
                        : AppTheme.divider,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      cat.label,
                      style: TextStyle(
                        color: hasSelectedTag
                            ? Colors.white
                            : AppTheme.textSecondary,
                        fontSize: 13,
                        fontWeight: hasSelectedTag
                            ? FontWeight.w700
                            : FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      expanded
                          ? Icons.expand_less_rounded
                          : Icons.expand_more_rounded,
                      size: 16,
                      color: hasSelectedTag
                          ? Colors.white
                          : AppTheme.textTertiary,
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),

        // 펼친 대분류의 세부 태그 — 부드러운 등장
        AnimatedSize(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          alignment: Alignment.topCenter,
          child: _expandedCategory == null
              ? const SizedBox(width: double.infinity)
              : Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceVariant.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppTheme.divider),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _expandedCategory!.hint,
                          style: TextStyle(
                            color: AppTheme.textTertiary,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _expandedCategory!.tags.map((tag) {
                            final selected = _selectedTag == tag;
                            return GestureDetector(
                              onTap: () => setState(() {
                                _selectedTag = selected ? null : tag;
                              }),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: selected
                                      ? AppTheme.accent.withOpacity(0.85)
                                      : AppTheme.surface,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: selected
                                        ? AppTheme.accent
                                        : AppTheme.divider,
                                  ),
                                ),
                                child: Text(
                                  tag.label,
                                  style: TextStyle(
                                    color: selected
                                        ? Colors.white
                                        : AppTheme.textPrimary,
                                    fontSize: 12.5,
                                    fontWeight: selected
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),
                ),
        ),
      ],
    );
  }

  // ── 띄우기 성공 안내 ──
  Widget _buildDone() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 40,
          height: 4,
          margin: const EdgeInsets.only(bottom: 20),
          decoration: BoxDecoration(
            color: AppTheme.divider,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: AppTheme.accent.withOpacity(0.15),
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.favorite_rounded,
              color: AppTheme.accentLight, size: 30),
        ),
        const SizedBox(height: 20),
        Text(
          '마음을 띄웠어요',
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          '이제 누군가가 당신의 마음을 보고\n조용히 위로를 건넬 거예요.\n도착하면 위로함에서 만날 수 있어요.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 13.5,
            height: 1.6,
          ),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.surfaceVariant,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: Text(
              '닫기',
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ],
    );
  }
}