import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/mood_entry.dart';
import '../services/mood_storage.dart';

/// 기분 기록 목록을 관리하는 프로바이더.
///
/// 앱 시작 시 Hive에 저장된 기록을 즉시 읽어 화면에 보여주고,
/// 기록이 추가/수정/삭제되면 상태를 갱신해 화면이 자동으로 따라온다.
/// (서버 동기화는 추후 각 메서드 안에 추가)
final moodEntriesProvider =
    NotifierProvider<MoodEntriesNotifier, List<MoodEntry>>(
  MoodEntriesNotifier.new,
);

class MoodEntriesNotifier extends Notifier<List<MoodEntry>> {
  @override
  List<MoodEntry> build() {
    // 로컬 캐시를 즉시 읽어 초기 상태로 사용 (빠른 첫 화면)
    return MoodStorage.instance.getAll();
  }

  /// 새 기분 기록을 남긴다.
  /// id와 시각은 내부에서 생성하므로 화면은 기분 값과 메모만 넘기면 된다.
  /// 생성된 기록을 반환하므로, 곧바로 제안을 붙이는 데 사용할 수 있다.
  Future<MoodEntry> record({
    required int moodLevel,
    String? note,
  }) async {
    final now = DateTime.now();
    final entry = MoodEntry(
      id: now.microsecondsSinceEpoch.toString(),
      date: now,
      moodLevel: moodLevel,
      note: (note != null && note.trim().isNotEmpty) ? note.trim() : null,
    );
    await MoodStorage.instance.save(entry);
    state = MoodStorage.instance.getAll();
    return entry;
  }

  /// 기록에 건넨 제안을 붙인다.
  /// (기분 기록 후 맞춤 제안을 보여줄 때 호출)
  Future<void> attachSuggestion(
    String id, {
    required String suggestion,
    required SuggestionType type,
  }) async {
    final entry = MoodStorage.instance.getById(id);
    if (entry == null) return;
    final updated = entry.copyWith(
      suggestion: suggestion,
      suggestionType: type,
    );
    await MoodStorage.instance.save(updated);
    state = MoodStorage.instance.getAll();
  }

  /// 제안에 대한 사용자 반응을 기록한다.
  /// (2차 버전의 추천 보정에 쓰일 데이터)
  Future<void> markSuggestion(String id, {required bool helpful}) async {
    final entry = MoodStorage.instance.getById(id);
    if (entry == null) return;
    final updated = entry.copyWith(suggestionHelpful: helpful);
    await MoodStorage.instance.save(updated);
    state = MoodStorage.instance.getAll();
  }

  /// 기록을 삭제한다.
  Future<void> remove(String id) async {
    await MoodStorage.instance.delete(id);
    state = MoodStorage.instance.getAll();
  }

  /// 상태를 저장소와 다시 맞춘다 (외부 변경 후 강제 갱신용).
  void refresh() {
    state = MoodStorage.instance.getAll();
  }
}

/// 오늘 남긴 기록 목록 (기분 기록 화면에서 "오늘 기록했는지" 확인용).
final todayEntriesProvider = Provider<List<MoodEntry>>((ref) {
  final all = ref.watch(moodEntriesProvider);
  final now = DateTime.now();
  return all
      .where((e) =>
          e.date.year == now.year &&
          e.date.month == now.month &&
          e.date.day == now.day)
      .toList();
});

/// 특정 연·월의 기록 목록 (돌아보기 달력용).
/// family로 (year, month)를 받아 해당 월만 골라준다.
final monthEntriesProvider =
    Provider.family<List<MoodEntry>, ({int year, int month})>((ref, ym) {
  final all = ref.watch(moodEntriesProvider);
  return all
      .where((e) => e.date.year == ym.year && e.date.month == ym.month)
      .toList();
});