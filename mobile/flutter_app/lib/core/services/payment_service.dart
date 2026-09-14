import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class PaymentService with ChangeNotifier {
  final String _baseUrl = 'http://localhost:3000/api/v1';

  // Payment Service State
  bool _isLoading = false;
  String? _error;

  bool get isLoading => _isLoading;
  String? get error => _error;

  // Get authentication headers
  Future<Map<String, String>> _getAuthHeaders() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');

    final headers = {
      'Content-Type': 'application/json',
    };

    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }

    return headers;
  }

  // Initialize subscription payment
  Future<Map<String, dynamic>> initializeSubscriptionPayment(
      String userId, String planId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final headers = await _getAuthHeaders();

      final response = await http.post(
        Uri.parse('$_baseUrl/geniuspay/initialize-subscription/$userId/$planId'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        _isLoading = false;
        notifyListeners();
        return responseData;
      } else {
        final errorData = jsonDecode(response.body);
        throw Exception(errorData['message'] ?? 'Failed to initialize subscription payment');
      }
    } catch (e) {
      _isLoading = false;
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  // Initialize token recharge
  Future<Map<String, dynamic>> initializeTokenRecharge(
      String userId, int tokensAmount) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final headers = await _getAuthHeaders();

      final response = await http.post(
        Uri.parse('$_baseUrl/geniuspay/initialize-recharge/$userId/$tokensAmount'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        _isLoading = false;
        notifyListeners();
        return responseData;
      } else {
        final errorData = jsonDecode(response.body);
        throw Exception(errorData['message'] ?? 'Failed to initialize token recharge');
      }
    } catch (e) {
      _isLoading = false;
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  // TODO: Add method to check payment status (could poll balance or listen to wallet updates)
  // This would typically be handled by checking wallet balance updates after redirecting
  // to the payment URL and returning from the payment process
}