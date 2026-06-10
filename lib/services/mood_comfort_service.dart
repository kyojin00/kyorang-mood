import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/comfort_models.dart';

/// 교랑무드 · 익명 위로 풀의 Supabase 통신 창구.
///
/// 모든 동작은 SECURITY DEFINER RPC 를 통해서만 이뤄진다
/// (테이블 직접 접근은 RLS 로 막혀 있음 → 익명성/검증 보장).
///
/// 제공 기능:
///  - fetchPendingRequest() : 풀에서 위로할 대상 하나 꺼내기
///  - sendComfort()         : 고른/직접 쓴 문구로 위로 보내기
///  - getMyComforts()       : 내가 받은 위로 목록 (+ 읽음 처리, 신고된 건 제외)
///  - unreadCount()         : 안 읽은 위로 수 (뱃지용)
///  - reportComfort()       : 받은 위로 신고
class MoodComfortService {
  MoodComfortService._();
  static final MoodComfortService instance = MoodComfortService._();

  SupabaseClient get _sb => Supabase.instance.client;

  /// 풀에서 위로를 보낼 대상 하나를 꺼낸다.
  /// 보낼 대상이 없으면 null.
  Future<ComfortRequest?> fetchPendingRequest() async {
    try {
      final res = await _sb.rpc('fetch_one_pending_request');
      final list = (res as List?) ?? const [];
      if (list.isEmpty) return null;
      return ComfortRequest.fromJson(
        Map<String, dynamic>.from(list.first as Map),
      );
    } on PostgrestException catch (e) {
      throw _humanize(e);
    } catch (_) {
      throw '잠시 연결이 불안정해요. 다시 시도해 주세요.';
    }
  }

  /// 고른/직접 쓴 문구로 위로를 보낸다.
  /// 직접 쓴 경우 [templateId] 는 'custom' 을 사용한다.
  /// 검증 실패(악플/만료/중복/한도/차단)는 메시지와 함께 예외로 던진다.
  Future<bool> sendComfort({
    required String requestId,
    required String templateId,
    required String content,
  }) async {
    try {
      await _sb.rpc('send_comfort_reply', params: {
        'p_request_id': requestId,
        'p_template_id': templateId,
        'p_content': content,
      });
      return true;
    } on PostgrestException catch (e) {
      throw _humanize(e);
    } catch (_) {
      throw '위로를 보내지 못했어요. 다시 시도해 주세요.';
    }
  }

  /// 내가 받은 위로 목록을 가져온다.
  /// [markRead] 가 true 면 조회와 동시에 읽음 처리한다.
  /// 내가 신고한 위로는 서버에서 제외되어 돌아온다.
  Future<List<ReceivedComfort>> getMyComforts({bool markRead = true}) async {
    try {
      final res = await _sb.rpc('get_my_comforts', params: {
        'p_mark_read': markRead,
      });
      final list = (res as List?) ?? const [];
      return list
          .map((e) =>
              ReceivedComfort.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } on PostgrestException catch (e) {
      throw _humanize(e);
    } catch (_) {
      throw '위로함을 불러오지 못했어요. 다시 시도해 주세요.';
    }
  }

  /// 안 읽은 위로 수. (읽음 처리하지 않고 카운트만)
  /// 실패 시 0 을 반환해 화면이 깨지지 않게 한다.
  Future<int> unreadCount() async {
    try {
      final list = await getMyComforts(markRead: false);
      return list.where((c) => !c.isRead).length;
    } catch (_) {
      return 0;
    }
  }

  /// 받은 위로를 신고한다.
  /// 신고된 위로는 내 위로함에서 즉시 사라지고, 누적 임계 도달 시
  /// 발신자가 자동 발송 차단된다(서버에서 처리).
  /// [reason] 은 짧은 사유 라벨(예: 'abusive', 'spam', 'other').
  Future<bool> reportComfort({
    required String replyId,
    String? reason,
  }) async {
    try {
      await _sb.rpc('report_comfort_reply', params: {
        'p_reply_id': replyId,
        'p_reason': reason,
      });
      return true;
    } on PostgrestException catch (e) {
      throw _humanize(e);
    } catch (_) {
      throw '신고를 처리하지 못했어요. 다시 시도해 주세요.';
    }
  }

  /// RPC 가 raise exception 으로 던진 한글 메시지를 살려서 반환한다.
  String _humanize(PostgrestException e) {
    final msg = e.message.trim();
    if (msg.isEmpty) {
      return '잠시 문제가 생겼어요. 다시 시도해 주세요.';
    }
    final looksFriendly = RegExp(r'[가-힣]').hasMatch(msg);
    return looksFriendly ? msg : '잠시 문제가 생겼어요. 다시 시도해 주세요.';
  }
}