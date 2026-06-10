import 'package:hive_ce_flutter/hive_flutter.dart';

/// 교랑무드 · 위로 풀 관련 가벼운 로컬 플래그 저장소.
///
/// "마음 띄우기 제안 칩"을 하루 한 번만 보여주기 위한 날짜 기록 등,
/// 서버에 둘 필요 없는 작은 UI 상태를 보관한다.
/// 박스는 메모리 교훈대로 반드시 Box<String> 타입으로 연다.
class ComfortPrefs {
  ComfortPrefs._();
  static final ComfortPrefs instance = ComfortPrefs._();

  static const String _boxName = 'comfort_prefs';

  // 마지막으로 "마음 띄우기" 제안 칩을 노출한 날짜 (YYYY-MM-DD)
  static const String _kRaiseHintShownDate = 'raise_hint_shown_date';

  Box<String>? _box;

  Box<String> get _prefs {
    final box = _box;
    if (box == null) {
      throw StateError(
        'ComfortPrefs가 초기화되지 않았습니다. 앱 시작 시 init()을 먼저 호출하세요.',
      );
    }
    return box;
  }

  /// 앱 시작 시 1회 호출. Hive.initFlutter()는 main에서 먼저 실행되어 있어야 한다.
  Future<void> init() async {
    if (_box != null && _box!.isOpen) return;
    _box = await Hive.openBox<String>(_boxName);
  }

  /// 오늘 이미 "마음 띄우기" 제안 칩을 보여줬는지.
  bool wasRaiseHintShownToday() {
    final saved = _prefs.get(_kRaiseHintShownDate);
    return saved == _todayKey();
  }

  /// "마음 띄우기" 제안 칩을 오늘 노출했다고 기록한다.
  /// (칩을 눌렀든 무시했든, 노출된 시점에 호출 → 그날은 다시 안 뜸)
  Future<void> markRaiseHintShown() async {
    await _prefs.put(_kRaiseHintShownDate, _todayKey());
  }

  /// 모든 플래그 삭제 (계정 삭제/초기화용).
  Future<void> clear() async {
    await _prefs.clear();
  }

  String _todayKey() {
    final now = DateTime.now();
    final y = now.year.toString().padLeft(4, '0');
    final m = now.month.toString().padLeft(2, '0');
    final d = now.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }
}