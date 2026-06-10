import 'package:supabase_flutter/supabase_flutter.dart';

/// 무디가 챙기는 사용자의 일정·할 일.
class Task {
  final String id;
  final String title;
  final DateTime? dueAt;
  final DateTime? dueDate;
  final String status; // 'pending' | 'done' | 'cancelled'
  final DateTime? completedAt;
  final DateTime createdAt;

  Task({
    required this.id,
    required this.title,
    this.dueAt,
    this.dueDate,
    required this.status,
    this.completedAt,
    required this.createdAt,
  });

  bool get isPending => status == 'pending';
  bool get isDone => status == 'done';
  bool get isCancelled => status == 'cancelled';

  /// 시간까지 있는 일정인지 (UI에서 시간 표시)
  bool get hasTime => dueAt != null;

  /// 날짜만이라도 있는지 (없으면 "언젠가")
  bool get hasDate => dueAt != null || dueDate != null;

  factory Task.fromRow(Map<String, dynamic> row) {
    return Task(
      id: row['id'] as String,
      title: row['title'] as String,
      dueAt: row['due_at'] != null
          ? DateTime.parse(row['due_at'] as String).toLocal()
          : null,
      dueDate: row['due_date'] != null
          ? DateTime.parse(row['due_date'] as String)
          : null,
      status: row['status'] as String,
      completedAt: row['completed_at'] != null
          ? DateTime.parse(row['completed_at'] as String).toLocal()
          : null,
      createdAt: DateTime.parse(row['created_at'] as String).toLocal(),
    );
  }
}

class TaskService {
  TaskService._();
  static final TaskService instance = TaskService._();

  /// 다가오는 pending 일정 목록 (날짜 있는 것 먼저, 그다음 "언젠가").
  Future<List<Task>> fetchPending() async {
    final client = Supabase.instance.client;
    final userId = client.auth.currentUser?.id;
    if (userId == null) return [];

    final rows = await client
        .from('task')
        .select()
        .eq('user_id', userId)
        .eq('status', 'pending')
        .order('due_date', ascending: true, nullsFirst: false)
        .order('due_at', ascending: true, nullsFirst: false)
        .order('created_at', ascending: false);

    return (rows as List)
        .map((r) => Task.fromRow(r as Map<String, dynamic>))
        .toList();
  }

  /// 완료된 일정 (최근 30개).
  Future<List<Task>> fetchDone({int limit = 30}) async {
    final client = Supabase.instance.client;
    final userId = client.auth.currentUser?.id;
    if (userId == null) return [];

    final rows = await client
        .from('task')
        .select()
        .eq('user_id', userId)
        .eq('status', 'done')
        .order('completed_at', ascending: false)
        .limit(limit);

    return (rows as List)
        .map((r) => Task.fromRow(r as Map<String, dynamic>))
        .toList();
  }

  /// 수동으로 새 일정 추가 (백업 입력 경로).
  Future<Task> add({
    required String title,
    DateTime? dueAt,
    DateTime? dueDate,
  }) async {
    final client = Supabase.instance.client;
    final userId = client.auth.currentUser?.id;
    if (userId == null) throw Exception('로그인이 필요해요.');

    final row = await client
        .from('task')
        .insert({
          'user_id': userId,
          'title': title.trim(),
          'due_at': dueAt?.toUtc().toIso8601String(),
          'due_date': dueDate != null
              ? '${dueDate.year.toString().padLeft(4, '0')}-${dueDate.month.toString().padLeft(2, '0')}-${dueDate.day.toString().padLeft(2, '0')}'
              : (dueAt != null
                  ? '${dueAt.year.toString().padLeft(4, '0')}-${dueAt.month.toString().padLeft(2, '0')}-${dueAt.day.toString().padLeft(2, '0')}'
                  : null),
        })
        .select()
        .single();

    return Task.fromRow(row);
  }

  /// 수동으로 완료 처리.
  Future<void> complete(String taskId) async {
    final client = Supabase.instance.client;
    await client.from('task').update({
      'status': 'done',
      'completed_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', taskId);
  }

  /// 수동으로 취소 처리.
  Future<void> cancel(String taskId) async {
    final client = Supabase.instance.client;
    await client
        .from('task')
        .update({'status': 'cancelled'}).eq('id', taskId);
  }

  /// pending으로 되돌리기 (잘못 완료한 경우).
  Future<void> reopen(String taskId) async {
    final client = Supabase.instance.client;
    await client.from('task').update({
      'status': 'pending',
      'completed_at': null,
    }).eq('id', taskId);
  }
}