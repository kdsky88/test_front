import 'dart:convert';
import '../models/expense.dart';
import 'api_config.dart';

class ExpenseApi {
  static const String baseUrl = apiBaseUrl;

  static Future<List<Expense>> list(String tripId) async {
    final response = await apiClient.get(Uri.parse('$baseUrl/trips/$tripId/expenses'), headers: jsonHeaders);
    if (response.statusCode == 200) {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      return (json['data'] as List).map((e) => Expense.fromJson(e as Map<String, dynamic>)).toList();
    }
    throw parseApiError(response);
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
      headers: jsonHeaders,
      body: jsonEncode(body),
    );
    if (response.statusCode == 201) {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      return Expense.fromJson(json['data'] as Map<String, dynamic>);
    }
    throw parseApiError(response);
  }

  static Future<void> delete(String tripId, String id) async {
    final response = await apiClient.delete(Uri.parse('$baseUrl/trips/$tripId/expenses/$id'), headers: jsonHeaders);
    if (response.statusCode == 204) return;
    throw parseApiError(response);
  }
}
