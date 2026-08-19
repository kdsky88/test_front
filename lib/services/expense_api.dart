import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/expense.dart';
import '../models/todo.dart'; // ApiException / ApiError
import 'api_config.dart';
import 'auth_api.dart';

class ExpenseApi {
  static const String baseUrl = apiBaseUrl;

  static Future<List<Expense>> list(String tripId) async {
    final response = await apiClient.get(Uri.parse('$baseUrl/trips/$tripId/expenses'), headers: _headers);
    if (response.statusCode == 200) {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      return (json['data'] as List).map((e) => Expense.fromJson(e as Map<String, dynamic>)).toList();
    }
    throw _parseError(response);
  }

  static Future<Expense> create(
    String tripId, {
    required double amount,
    required String currency,
    required String category,
    String? memo,
  }) async {
    final body = <String, dynamic>{
      'amount': amount,
      'currency': currency,
      'category': category,
      if (memo != null && memo.isNotEmpty) 'memo': memo,
    };
    final response = await apiClient.post(
      Uri.parse('$baseUrl/trips/$tripId/expenses'),
      headers: _headers,
      body: jsonEncode(body),
    );
    if (response.statusCode == 201) {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      return Expense.fromJson(json['data'] as Map<String, dynamic>);
    }
    throw _parseError(response);
  }

  static Future<void> delete(String tripId, String id) async {
    final response = await apiClient.delete(Uri.parse('$baseUrl/trips/$tripId/expenses/$id'), headers: _headers);
    if (response.statusCode == 204) return;
    throw _parseError(response);
  }

  static Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
    if (AuthSession.accessToken case final token?) 'Authorization': 'Bearer $token',
  };

  static ApiException _parseError(http.Response response) {
    try {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      return ApiException(statusCode: response.statusCode, error: ApiError.fromJson(json));
    } catch (_) {
      return ApiException(
        statusCode: response.statusCode,
        error: ApiError(code: 'INTERNAL_ERROR', message: '서버 응답을 처리할 수 없습니다.'),
      );
    }
  }
}
