import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/todo.dart';

const String _kApiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  // 백엔드(Spring) server.port=8080 에 정렬. dart-define API_BASE_URL 로 오버라이드 가능.
  defaultValue: 'http://localhost:8080',
);

class TodoApi {
  static final String baseUrl = _kApiBaseUrl;

  static Future<List<String>> getAssignees() async {
    final uri = Uri.parse('$baseUrl/todos/assignees');
    final response = await http.get(uri, headers: _headers);
    if (response.statusCode == 200) {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final data = json['data'] as List<dynamic>;
      return data.map((e) {
        if (e is String) return e;
        if (e is Map<String, dynamic>) return e['name'] as String? ?? '';
        return '';
      }).where((s) => s.isNotEmpty).toList();
    }
    throw _parseError(response);
  }

  static Future<TodoListResponse> getTodos({
    required String status,
    required int page,
    int limit = 20,
    String? search,
    String? tag,
    String? assignee,
    String sort = 'priority',
  }) async {
    final queryParameters = {
      'status': status,
      'page': '$page',
      'limit': '$limit',
      'sort': sort,
      if (search != null && search.isNotEmpty) 'search': search,
      if (tag != null && tag.isNotEmpty) 'tag': tag,
      if (assignee != null && assignee.isNotEmpty) 'assignee': assignee,
    };
    final uri = Uri.parse(
      '$baseUrl/todos',
    ).replace(queryParameters: queryParameters);
    final response = await http.get(uri, headers: _headers);
    if (response.statusCode == 200) {
      return TodoListResponse.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>,
      );
    }
    throw _parseError(response);
  }

  static Future<Todo> createTodo({
    required String title,
    required TodoPriority priority,
    String? description,
    String? note,
    String? startAt,
    String? dueAt,
  }) async {
    final body = <String, dynamic>{
      'title': title,
      'priority': priority.apiValue,
    };
    if (description != null) body['description'] = description;
    if (note != null) body['note'] = note;
    if (startAt != null) body['startAt'] = startAt;
    if (dueAt != null) body['dueAt'] = dueAt;

    final response = await http.post(
      Uri.parse('$baseUrl/todos'),
      headers: _headers,
      body: jsonEncode(body),
    );
    if (response.statusCode == 201) {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      return Todo.fromJson(json['data'] as Map<String, dynamic>);
    }
    throw _parseError(response);
  }

  static Future<Todo> updateTodo({
    required String id,
    String? title,
    String? description,
    String? note,
    String? startAt,
    String? dueAt,
    bool? completed,
    TodoPriority? priority,
    bool clearDescription = false,
    bool clearNote = false,
    bool clearStartAt = false,
    bool clearDueAt = false,
  }) async {
    final body = <String, dynamic>{};
    if (title != null) body['title'] = title;
    if (clearDescription) {
      body['description'] = null;
    } else if (description != null) {
      body['description'] = description;
    }
    if (clearNote) {
      body['note'] = null;
    } else if (note != null) {
      body['note'] = note;
    }
    if (clearStartAt) {
      body['startAt'] = null;
    } else if (startAt != null) {
      body['startAt'] = startAt;
    }
    if (clearDueAt) {
      body['dueAt'] = null;
    } else if (dueAt != null) {
      body['dueAt'] = dueAt;
    }
    if (completed != null) body['completed'] = completed;
    if (priority != null) body['priority'] = priority.apiValue;

    final response = await http.patch(
      Uri.parse('$baseUrl/todos/$id'),
      headers: _headers,
      body: jsonEncode(body),
    );
    if (response.statusCode == 200) {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      return Todo.fromJson(json['data'] as Map<String, dynamic>);
    }
    throw _parseError(response);
  }

  static Future<Map<String, List<Todo>>> getCalendar({
    required int year,
    required int month,
  }) async {
    final uri = Uri.parse(
      '$baseUrl/todos/calendar',
    ).replace(queryParameters: {'year': '$year', 'month': '$month'});
    final response = await http.get(uri, headers: _headers);
    if (response.statusCode == 200) {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final data = json['data'] as Map<String, dynamic>;
      return data.map(
        (date, todos) => MapEntry(
          date,
          (todos as List)
              .map((t) => Todo.fromJson(t as Map<String, dynamic>))
              .toList(),
        ),
      );
    }
    throw _parseError(response);
  }

  static Future<Todo> addTag({
    required String id,
    required String tag,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/todos/$id/tags'),
      headers: _headers,
      body: jsonEncode({'tag': tag}),
    );
    if (response.statusCode == 200) {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      return Todo.fromJson(json['data'] as Map<String, dynamic>);
    }
    throw _parseError(response);
  }

  static Future<Todo> removeTag({
    required String id,
    required String tag,
  }) async {
    final uri = Uri.parse(
      '$baseUrl/todos/$id/tags',
    ).replace(queryParameters: {'tag': tag});
    final response = await http.delete(uri, headers: _headers);
    if (response.statusCode == 200) {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      return Todo.fromJson(json['data'] as Map<String, dynamic>);
    }
    throw _parseError(response);
  }

  static Future<void> deleteTodo(String id) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/todos/$id'),
      headers: _headers,
    );
    if (response.statusCode == 204) return;
    throw _parseError(response);
  }

  static const Map<String, String> _headers = {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };

  static ApiException _parseError(http.Response response) {
    try {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      return ApiException(
        statusCode: response.statusCode,
        error: ApiError.fromJson(json),
      );
    } catch (_) {
      return ApiException(
        statusCode: response.statusCode,
        error: ApiError(code: 'INTERNAL_ERROR', message: '서버 응답을 처리할 수 없습니다.'),
      );
    }
  }
}
