import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../theme/app_theme.dart';
import '../../services/review_service.dart';
import '../../widgets/mascot.dart';

/// 이번 주 돌아보기 화면.
///
/// 메뉴에서 진입. 무디가 일주일을 한 단락으로 정리해주는 자리.
/// 일기장과 같은 따뜻한 종이 톤이지만 살짝 더 차분하고 사색적인 분위기.
class ReviewScreen extends ConsumerStatefulWidget {
  const ReviewScreen({super.key});

  @override
  ConsumerState<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends ConsumerState<ReviewScreen> {
  WeeklyReview? _review;
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
      final r = await ReviewService.instance.fetchThisWeek();
      if (!mounted) return;
      setState(() {
        _review = r;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '회고를 가져오지 못했어요.';
      });
    }
  }

  /// YYYY-MM-DD → "11월 24일"
  String _shortDate(String date) {
    final parts = date.split('-');
    final m = int.parse(parts[1]);
    final d = int.parse(parts[2]);
    return '$m월 $d일';
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
              _TopBar(onClose: () => Navigator.of(context).maybePop()),
              const SizedBox(height: 18),
              Expanded(
                child: _loading
                    ? const _LoadingPaper()
                    : _error != null
                        ? _ErrorPaper(message: _error!, onRetry: _load)
                        : _ReviewPaper(
                            review: _review!,
                            shortDate: _shortDate,
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 상단: 무디 + 라벨 + 닫기 버튼
class _TopBar extends StatelessWidget {
  final VoidCallback onClose;
  const _TopBar({required this.onClose});

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
                '이번 주 돌아보기',
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
            icon: Icons.arrow_back_rounded,
            onTap: onClose,
          ),
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

/// 종이 카드 베이스 — 다른 종이들과 일관된 모양
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
          colors: [
            // 일반 종이보다 살짝 더 깊은 베이지 — 사색적인 분위기
            Color(0xFFF6E9DE),
            Color(0xFFEAD8CC),
          ],
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
                      const Color(0xFFFFE8D6).withValues(alpha: 0.5),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            child,
          ],
        ),
      ),
    );
  }
}

/// 로딩 중 종이
class _LoadingPaper extends StatelessWidget {
  const _LoadingPaper();

  @override
  Widget build(BuildContext context) {
    return _PaperCard(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Text(
            '무디가 한 주를\n천천히 떠올리고 있어요…',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'GowunDodum',
              color: const Color(0xFF8A6878).withValues(alpha: 0.85),
              fontSize: 15,
              fontStyle: FontStyle.italic,
              height: 1.8,
              letterSpacing: 0.2,
            ),
          ),
        ),
      ),
    );
  }
}

/// 에러 종이
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
                  fontSize: 15,
                  fontStyle: FontStyle.italic,
                  height: 1.8,
                ),
              ),
              const SizedBox(height: 20),
              TextButton(
                onPressed: onRetry,
                style: TextButton.styleFrom(
                  backgroundColor:
                      const Color(0xFFE8A5B8).withValues(alpha: 0.35),
                  foregroundColor: const Color(0xFF7A2E45),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 22, vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text(
                  '다시 시도',
                  style: TextStyle(
                    fontFamily: 'GowunDodum',
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
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

/// 실제 회고 종이
class _ReviewPaper extends StatelessWidget {
  final WeeklyReview review;
  final String Function(String date) shortDate;

  const _ReviewPaper({required this.review, required this.shortDate});

  @override
  Widget build(BuildContext context) {
    return _PaperCard(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(26, 30, 26, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 날짜 범위
            Text(
              '${shortDate(review.fromDate)} ~ ${shortDate(review.toDate)}',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'GowunDodum',
                color: Color(0xFF9E7C8A),
                fontSize: 12.5,
                fontStyle: FontStyle.italic,
                letterSpacing: 0.4,
              ),
            ),
            const SizedBox(height: 22),

            // 회고 본문
            Text(
              review.review,
              style: const TextStyle(
                fontFamily: 'GowunDodum',
                color: Color(0xFF3D2438),
                fontSize: 16,
                height: 1.9,
                fontWeight: FontWeight.w400,
                letterSpacing: 0.1,
              ),
            ),

            // 키워드와 일수 — 데이터가 있을 때만
            if (review.hasData) ...[
              const SizedBox(height: 28),
              _ThinDivider(),
              const SizedBox(height: 22),
              if (review.keywords.isNotEmpty) ...[
                _KeywordCluster(keywords: review.keywords),
                const SizedBox(height: 20),
              ],
              Center(
                child: Text(
                  '이번 주 ${review.daysWritten}일 만났어요',
                  style: TextStyle(
                    fontFamily: 'GowunDodum',
                    color: const Color(0xFF9E7C8A).withValues(alpha: 0.85),
                    fontSize: 12.5,
                    fontStyle: FontStyle.italic,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ThinDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 60,
        height: 1,
        color: const Color(0xFFC8A0A8).withValues(alpha: 0.4),
      ),
    );
  }
}

/// 키워드 칩들 — 가운데 정렬로 흩어져 있음
class _KeywordCluster extends StatelessWidget {
  final List<String> keywords;
  const _KeywordCluster({required this.keywords});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 8,
      runSpacing: 8,
      children: keywords.map((k) => _KeywordChip(text: k)).toList(),
    );
  }
}

class _KeywordChip extends StatelessWidget {
  final String text;
  const _KeywordChip({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFE8A5B8).withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(16),
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
          fontSize: 13,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.1,
        ),
      ),
    );
  }
}