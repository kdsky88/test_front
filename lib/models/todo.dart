enum TodoPriority {
  high('HIGH', '높음'),
  medium('MEDIUM', '보통'),
  low('LOW', '낮음');

  const TodoPriority(this.apiValue, this.label);

  final String apiValue;
  final String label;

  static TodoPriority fromJson(dynamic value) {
    return TodoPriority.values.firstWhere(
      (priority) => priority.apiValue == value,
      orElse: () => throw const FormatException('잘못된 우선순위 응답입니다.'),
    );
  }
}

class Todo {
  final String id;
  final String title;
  final String? description;
  final String? note;
  final bool completed;
  final TodoPriority priority;
  final DateTime? startAt;
  final DateTime? dueAt;
  final DateTime? completedAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<String> tags;
  final String? assignee;

  const Todo({
    required this.id,
    required this.title,
    this.description,
    this.note,
    required this.completed,
    required this.priority,
    this.startAt,
    this.dueAt,
    this.completedAt,
    required this.createdAt,
    required this.updatedAt,
    this.tags = const [],
    this.assignee,
  });

  factory Todo.fromJson(Map<String, dynamic> json) {
    return Todo(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      note: json['note'] as String?,
      completed: json['completed'] as bool,
      priority: TodoPriority.fromJson(json['priority']),
      startAt: _parseDate(json['startAt']),
      dueAt: _parseDate(json['dueAt']),
      completedAt: _parseDate(json['completedAt']),
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      tags: (json['tags'] as List<dynamic>?)?.cast<String>() ?? const [],
      assignee: json['assignee'] as String?,
    );
  }

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    try {
      return DateTime.parse(value as String);
    } catch (_) {
      return null;
    }
  }

  /// 마감 시각이 이미 지남 → 빨강 (기한 경과)
  bool get isOverdue {
    if (completed || dueAt == null) return false;
    return dueAt!.isBefore(DateTime.now());
  }

  /// 마감일이 오늘이고 아직 지나지 않음 → 빨강 (오늘 마감)
  bool get isDueToday {
    if (completed || isOverdue) return false;
    return _daysUntilDue == 0;
  }

  /// 마감 하루 전(내일 마감) → 주황
  bool get isDueSoon {
    if (completed) return false;
    return _daysUntilDue == 1;
  }

  /// 마감일(로컬 날짜) - 오늘(로컬 날짜) 의 일수 차이. dueAt 없으면 null.
  int? get _daysUntilDue {
    if (dueAt == null) return null;
    final due = dueAt!.toLocal();
    final now = DateTime.now();
    return DateTime(due.year, due.month, due.day)
        .difference(DateTime(now.year, now.month, now.day))
        .inDays;
  }

  Todo copyWith({
    String? title,
    String? description,
    String? note,
    bool? completed,
    TodoPriority? priority,
    DateTime? startAt,
    DateTime? dueAt,
    DateTime? completedAt,
    bool clearStartAt = false,
    bool clearDueAt = false,
    bool clearCompletedAt = false,
    DateTime? updatedAt,
    String? assignee,
  }) {
    return Todo(
      id: id,
      title: title ?? this.title,
      description: description ?? this.description,
      note: note ?? this.note,
      completed: completed ?? this.completed,
      priority: priority ?? this.priority,
      startAt: clearStartAt ? null : (startAt ?? this.startAt),
      dueAt: clearDueAt ? null : (dueAt ?? this.dueAt),
      completedAt: clearCompletedAt ? null : (completedAt ?? this.completedAt),
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      tags: tags,
      assignee: assignee ?? this.assignee,
    );
  }
}

class TodoListResponse {
  final List<Todo> data;
  final int page;
  final int limit;
  final int total;
  final int totalPages;

  const TodoListResponse({
    required this.data,
    required this.page,
    required this.limit,
    required this.total,
    required this.totalPages,
  });

  factory TodoListResponse.fromJson(Map<String, dynamic> json) {
    final meta = json['meta'] as Map<String, dynamic>;
    return TodoListResponse(
      data: (json['data'] as List)
          .map((e) => Todo.fromJson(e as Map<String, dynamic>))
          .toList(),
      page: meta['page'] as int,
      limit: meta['limit'] as int,
      total: meta['total'] as int,
      totalPages: meta['totalPages'] as int,
    );
  }
}

class ApiError {
  final String code;
  final String message;
  final Map<String, String>? fields;

  const ApiError({required this.code, required this.message, this.fields});

  factory ApiError.fromJson(Map<String, dynamic> json) {
    final error = json['error'] as Map<String, dynamic>;
    final rawFields = error['fields'];
    return ApiError(
      code: error['code'] as String,
      message: error['message'] as String,
      fields: rawFields != null
          ? Map<String, String>.from(rawFields as Map)
          : null,
    );
  }
}

class ApiException implements Exception {
  final int statusCode;
  final ApiError error;

  const ApiException({required this.statusCode, required this.error});

  @override
  String toString() => 'ApiException($statusCode): ${error.message}';
}
