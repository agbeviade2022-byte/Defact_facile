import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class WalletService with ChangeNotifier {
  final String _baseUrl = 'http://localhost:3000/api/v1';

  // Wallet Service State
  bool _isLoading = false;
  String? _error;
  int _balance = 0;
  List<dynamic> _transactionHistory = [];

  bool get isLoading => _isLoading;
  String? get error => _error;
  int get balance => _balance;
  List<dynamic> get transactionHistory => _transactionHistory;

  // Get user ID from shared preferences
  Future<String?> _getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('user_id');
  }

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

  // Get wallet balance
  Future<int> getBalance() async {
    final userId = await _getUserId();
    if (userId == null) {
      throw Exception('User not authenticated');
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final headers = await _getAuthHeaders();

      final response = await http.get(
        Uri.parse('$_baseUrl/ai/wallet/balance/$userId'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        _balance = responseData['balanceTokens'];
        _isLoading = false;
        notifyListeners();
        return _balance;
      } else {
        final errorData = jsonDecode(response.body);
        throw Exception(errorData['message'] ?? 'Failed to get balance');
      }
    } catch (e) {
      _isLoading = false;
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  // Grant free trial bonus
  Future<bool> grantFreeTrialBonus() async {
    final userId = await _getUserId();
    if (userId == null) {
      throw Exception('User not authenticated');
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final headers = await _getAuthHeaders();

      final response = await http.post(
        Uri.parse('$_baseUrl/ai/wallet/grant-free-bonus/$userId'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        final granted = responseData['granted'];

        // Refresh balance after granting bonus
        if (granted) {
          await getBalance();
        }

        _isLoading = false;
        notifyListeners();
        return granted;
      } else {
        final errorData = jsonDecode(response.body);
        throw Exception(errorData['message'] ?? 'Failed to grant bonus');
      }
    } catch (e) {
      _isLoading = false;
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  // Get transaction history
  Future<List<dynamic>> getTransactionHistory({int limit = 50}) async {
    final userId = await _getUserId();
    if (userId == null) {
      throw Exception('User not authenticated');
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final headers = await _getAuthHeaders();

      final response = await http.get(
        Uri.parse('$_baseUrl/ai/wallet/history/$userId'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        _transactionHistory = responseData['transactions'];
        _isLoading = false;
        notifyListeners();
        return _transactionHistory;
      } else {
        final errorData = jsonDecode(response.body);
        throw Exception(errorData['message'] ?? 'Failed to get transaction history');
      }
    } catch (e) {
      _isLoading = false;
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  // Refresh both balance and history
  Future<void> refreshWalletData() async {
    await getBalance();
    await getTransactionHistory();
  }
}