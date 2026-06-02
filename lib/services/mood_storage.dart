import 'dart:convert';

import 'package:hive_ce_flutter/hive_flutter.dart';   // 기존: package:hive_flutter/hive_flutter.dart

import '../models/mood_entry.dart';

/// 기분 기록의 로컬 저장(Hive)을 담당하는 서비스.
///
/// MVP에서는 서버 없이 로컬에만 저장한다.
/// MoodEntry를 JSON 문자열로 직렬화해 박스에 보관하며,
/// 박스는 열 때와 사용할 때 모두 <String>으로 타입을 통일한다.
/// (타입 파라미터 불일치 시 저장이 실패할 수 있으므로 주의)
class MoodStorage {
  MoodStorage._();

  /// 싱글톤 인스턴스
  static final MoodStorage instance = MoodStorage._();

  static const String _boxName = 'mood_entries';

  Box<String>? _box;

  /// 박스 핸들. init() 이후에만 접근 가능.
  Box<String> get _entries {
    final box = _box;
    if (box == null) {
      throw StateError(
        'MoodStorage가 초기화되지 않았습니다. 앱 시작 시 init()을 먼저 호출하세요.',
      );
    }
    return box;
  }

  /// 박스를 연다. 앱 시작 시 1회 호출.
  /// Hive.initFlutter()는 main에서 먼저 실행되어 있어야 한다.
  Future<void> init() async {
    if (_box != null && _box!.isOpen) return;
    _box = await Hive.openBox<String>(_boxName);
  }

  /// 기분 기록을 저장(신규/갱신 공용). id를 키로 사용한다.
  Future<void> save(MoodEntry entry) async {
    await _entries.put(entry.id, jsonEncode(entry.toJson()));
  }

  /// 모든 기록을 최신순(날짜 내림차순)으로 반환.
  List<MoodEntry> getAll() {
    final list = _entries.values
        .map((raw) => MoodEntry.fromJson(
              jsonDecode(raw) as Map<String, dynamic>,
            ))
        .toList();
    list.sort((a, b) => b.date.compareTo(a.date));
    return list;
  }

  /// id로 단건 조회. 없으면 null.
  MoodEntry? getById(String id) {
    final raw = _entries.get(id);
    if (raw == null) return null;
    return MoodEntry.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  /// 특정 날짜(yyyy-MM-dd 기준)의 기록들을 반환.
  /// 하루에 여러 번 기록할 수 있으므로 리스트로 반환한다.
  List<MoodEntry> getByDate(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    final key = '$y-$m-$d';
    return getAll().where((e) => e.dateKey == key).toList();
  }

  /// 특정 연·월에 속한 기록들을 반환 (달력 화면용).
  List<MoodEntry> getByMonth(int year, int month) {
    return getAll()
        .where((e) => e.date.year == year && e.date.month == month)
        .toList();
  }

  /// id로 기록 삭제.
  Future<void> delete(String id) async {
    await _entries.delete(id);
  }

  /// 전체 기록 삭제 (디버그/초기화용).
  Future<void> clear() async {
    await _entries.clear();
  }
}