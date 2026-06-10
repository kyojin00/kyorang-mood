import 'package:supabase_flutter/supabase_flutter.dart';

/// 주간 회고 응답.
class WeeklyReview {
  /// 무디가 쓴 회고 본문.
  final String review;

  /// 그 주의 키워드 (5~7개, has_data=false면 빈 배열).
  final List<String> keywords;

  /// 이번 주에 글을 적은 일수.
  final int daysWritten;

  /// 회고 대상 기간의 총 일수 (보통 7).
  final int totalDays;

  /// 실제 회고가 만들어졌는지 (false면 "데이터 부족" 안내).
  final bool hasData;

  /// 회고 대상 시작/끝 날짜 (YYYY-MM-DD).
  final String fromDate;
  final String toDate;

  WeeklyReview({
    required this.review,
    required this.keywords,
    required this.daysWritten,
    required this.totalDays,
    required this.hasData,
    required this.fromDate,
    required this.toDate,
  });
}

/// 주간 회고를 가져오는 서비스.
class ReviewService {
  ReviewService._();
  static final ReviewService instance = ReviewService._();

  static const String _functionName = 'weekly-review';

  /// 오늘을 포함한 최근 7일의 회고를 가져온다.
  /// 날짜는 사용자 시간 기준 (chat_service의 currentLocalDate 로직과 동일).
  Future<WeeklyReview> fetchThisWeek({DateTime? now}) async {
    final t = now ?? DateTime.now();
    // 새벽 0~5시는 전날로 보정
    final base = t.hour < 5 ? t.subtract(const Duration(days: 1)) : t;
    final today = DateTime(base.year, base.month, base.day);
    final from = today.subtract(const Duration(days: 6));

    final fromStr = _formatDate(from);
    final toStr = _formatDate(today);

    return _fetch(fromStr, toStr);
  }

  Future<WeeklyReview> _fetch(String fromDate, String toDate) async {
    final client = Supabase.instance.client;
    final res = await client.functions.invoke(
      _functionName,
      body: {
        'from_date': fromDate,
        'to_date': toDate,
      },
    );

    final data = res.data;
    if (data is! Map) {
      throw Exception('회고를 받지 못했어요.');
    }

    if (data['error'] is String) {
      throw Exception(data['error'] as String);
    }

    return WeeklyReview(
      review: (data['review'] as String?)?.trim() ?? '',
      keywords: (data['keywords'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      daysWritten: (data['days_written'] as int?) ?? 0,
      totalDays: (data['total_days'] as int?) ?? 7,
      hasData: (data['has_data'] as bool?) ?? false,
      fromDate: fromDate,
      toDate: toDate,
    );
  }

  String _formatDate(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }
}