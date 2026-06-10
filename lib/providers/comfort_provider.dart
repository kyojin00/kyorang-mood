import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/comfort_models.dart';
import '../services/mood_comfort_service.dart';

/// 무디가 대신 채워주는 위로인지 구분하기 위한 확장 표현.
/// (ReceivedComfort 는 서버 모델이라 건드리지 않고, 화면용으로 한 겹 감싼다)
class ComfortItem {
  final ReceivedComfort comfort;
  final bool isFromMudi;

  const ComfortItem({required this.comfort, this.isFromMudi = false});
}

// ════════════════════════════════════════════════
// 1) 위로 요청 띄우기 (insert) — 기분 기록 흐름에서 호출
// ════════════════════════════════════════════════

/// 위로 요청 띄우기 동작을 담는 노티파이어.
/// 성공 여부/진행 상태만 관리하고, 목록 갱신은 호출 측에서 invalidate 한다.
final comfortRequestProvider =
    NotifierProvider<ComfortRequestNotifier, AsyncValue<void>>(
  ComfortRequestNotifier.new,
);

class ComfortRequestNotifier extends Notifier<AsyncValue<void>> {
  @override
  AsyncValue<void> build() => const AsyncData(null);

  /// 위로 요청을 풀에 띄운다.
  /// requests 테이블은 RLS(requests_insert_own)로 본인 insert 가 허용되므로
  /// RPC 가 아닌 직접 insert 를 사용한다. (도배/한도는 트리거가 막아줌)
  Future<bool> raise({
    required int moodLevel,
    ComfortTag? tag,
  }) async {
    state = const AsyncLoading();
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) {
      state = AsyncError('로그인이 필요해요.', StackTrace.current);
      return false;
    }
    try {
      await Supabase.instance.client.from('mood_comfort_requests').insert({
        'requester_id': uid,
        'mood_level': moodLevel,
        if (tag != null) 'tag': tag.value,
      });
      state = const AsyncData(null);
      return true;
    } on PostgrestException catch (e) {
      // 트리거가 던지는 "아직 위로를 기다리는 마음이..." 등 한글 메시지를 살림
      final msg = RegExp(r'[가-힣]').hasMatch(e.message)
          ? e.message.trim()
          : '요청을 띄우지 못했어요. 다시 시도해 주세요.';
      state = AsyncError(msg, StackTrace.current);
      return false;
    } catch (_) {
      state = AsyncError('요청을 띄우지 못했어요. 다시 시도해 주세요.',
          StackTrace.current);
      return false;
    }
  }
}

// ════════════════════════════════════════════════
// 2) 내가 받은 위로 목록 (+ 만료 폴백)
// ════════════════════════════════════════════════

/// 내가 받은 위로 목록. 조회 시 읽음 처리까지 한다.
/// 만료됐는데 위로를 못 받은 경우, 무디의 위로를 맨 앞에 끼워 넣는다.
final myComfortsProvider =
    AsyncNotifierProvider<MyComfortsNotifier, List<ComfortItem>>(
  MyComfortsNotifier.new,
);

class MyComfortsNotifier extends AsyncNotifier<List<ComfortItem>> {
  @override
  Future<List<ComfortItem>> build() async {
    return _load();
  }

  Future<List<ComfortItem>> _load() async {
    final received =
        await MoodComfortService.instance.getMyComforts(markRead: true);

    final items =
        received.map((c) => ComfortItem(comfort: c)).toList();

    // 만료 폴백: 받은 위로가 하나도 없으면 무디가 한마디 건넨다.
    // (서버에 저장하지 않고 화면에서만 보여줌 → 서버 오염 없음)
    if (items.isEmpty) {
      items.add(_mudiFallback());
    }
    return items;
  }

  /// 목록을 다시 불러온다 (위로 받은 뒤 / 화면 복귀 시).
  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_load);
  }

  ComfortItem _mudiFallback() {
    return ComfortItem(
      isFromMudi: true,
      comfort: ReceivedComfort(
        replyId: 'mudi_fallback',
        content:
            '아직 누군가의 위로가 닿지 않았네요. 그래도 오늘 마음을 꺼내본 당신, 정말 잘했어요.',
        createdAt: DateTime.now(),
        isRead: true,
        moodLevel: 3,
        tag: null,
      ),
    );
  }
}

// ════════════════════════════════════════════════
// 3) 안읽은 위로 수 (뱃지)
// ════════════════════════════════════════════════

/// 안 읽은 위로 수. 홈/탭 뱃지에 사용.
/// 자동 새로고침은 하지 않으며, 위로 받은 뒤 ref.invalidate 로 갱신한다.
final unreadComfortCountProvider = FutureProvider<int>((ref) async {
  return MoodComfortService.instance.unreadCount();
});

// ════════════════════════════════════════════════
// 4) 위로 보내기 흐름 (풀에서 하나씩)
// ════════════════════════════════════════════════

/// 현재 위로할 대상을 들고 있는 노티파이어.
/// next() 로 풀에서 하나 꺼내고, send() 로 위로를 보낸 뒤 자동으로 다음을 꺼낸다.
final comfortGivingProvider =
    AsyncNotifierProvider<ComfortGivingNotifier, ComfortRequest?>(
  ComfortGivingNotifier.new,
);

class ComfortGivingNotifier extends AsyncNotifier<ComfortRequest?> {
  @override
  Future<ComfortRequest?> build() async {
    return MoodComfortService.instance.fetchPendingRequest();
  }

  /// 풀에서 다음 대상을 꺼낸다. 없으면 null 상태.
  Future<void> next() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => MoodComfortService.instance.fetchPendingRequest(),
    );
  }

  /// 현재 대상에게 고른 문구로 위로를 보낸다.
  /// 성공하면 자동으로 다음 대상을 꺼낸다.
  /// 실패 시 예외 메시지를 던지며 현재 대상은 유지한다(화면에서 스낵바 처리).
  Future<void> send({
    required String requestId,
    required String templateId,
    required String content,
  }) async {
    await MoodComfortService.instance.sendComfort(
      requestId: requestId,
      templateId: templateId,
      content: content,
    );
    // 성공 → 다음 대상으로
    await next();
  }
}