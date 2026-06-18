import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/todo.dart';

const String _kApiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://localhost:3000',
);

class TodoApi {
  static final String baseUrl = _kApiBaseUrl;

  static Future<TodoListResponse> getTodos({
    required String status,
    required int page,
    int limit = 20,
    String? search,
  }) async {
    final queryParameters = {
      'status': status,
      'page': '$page',
      'limit': '$limit',
      if (search != null && search.isNotEmpty) 'search': search,
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
    String? description,
    String? dueAt,
  }) async {
    final body = <String, dynamic>{'title': title};
    if (description != null) body['description'] = description;
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
    String? dueAt,
    bool? completed,
    bool clearDescription = false,
    bool clearDueAt = false,
  }) async {
    final body = <String, dynamic>{};
    if (title != null) body['title'] = title;
    if (clearDescription) {
      body['description'] = null;
    } else if (description != null) {
      body['description'] = description;
    }
    if (clearDueAt) {
      body['dueAt'] = null;
    } else if (dueAt != null) {
      body['dueAt'] = dueAt;
    }
    if (completed != null) body['completed'] = completed;

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
