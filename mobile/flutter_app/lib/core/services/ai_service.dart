import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class AiService with ChangeNotifier {
  final String _baseUrl = 'http://localhost:3000/api/v1';

  // AI Service State
  bool _isLoading = false;
  String? _error;
  List<dynamic> _providers = [];
  Map<String, List<String>> _providerModels = {};

  bool get isLoading => _isLoading;
  String? get error => _error;
  List<dynamic> get providers => _providers;
  Map<String, List<String>> get providerModels => _providerModels;

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

  // Chat completion
  Future<dynamic> chatCompletion({
    required String provider,
    required String model,
    required List<Map<String, dynamic>> messages,
    double temperature = 0.7,
    int maxTokens = 1000,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final headers = await _getAuthHeaders();

      final response = await http.post(
        Uri.parse('$_baseUrl/ai/chat'),
        headers: headers,
        body: jsonEncode({
          'provider': provider,
          'model': model,
          'messages': messages,
          'temperature': temperature,
          'maxTokens': maxTokens,
        }),
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        _isLoading = false;
        notifyListeners();
        return responseData;
      } else {
        final errorData = jsonDecode(response.body);
        throw Exception(errorData['message'] ?? 'AI chat failed');
      }
    } catch (e) {
      _isLoading = false;
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  // Execute AI tool (OCR, analysis, etc.)
  Future<dynamic> executeTool({
    required String provider,
    required String model,
    required String tool,
    required Map<String, dynamic> parameters,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final headers = await _getAuthHeaders();

      final response = await http.post(
        Uri.parse('$_baseUrl/ai/execute'),
        headers: headers,
        body: jsonEncode({
          'provider': provider,
          'model': model,
          'tool': tool,
          'parameters': parameters,
        }),
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        _isLoading = false;
        notifyListeners();
        return responseData;
      } else {
        final errorData = jsonDecode(response.body);
        throw Exception(errorData['message'] ?? 'AI tool execution failed');
      }
    } catch (e) {
      _isLoading = false;
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  // Get available providers
  Future<List<dynamic>> getAvailableProviders() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final headers = await _getAuthHeaders();

      final response = await http.get(
        Uri.parse('$_baseUrl/ai/providers'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        _providers = responseData;
        _isLoading = false;
        notifyListeners();
        return _providers;
      } else {
        final errorData = jsonDecode(response.body);
        throw Exception(errorData['message'] ?? 'Failed to get providers');
      }
    } catch (e) {
      _isLoading = false;
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  // Get models for a specific provider
  Future<List<String>> getProviderModels(String provider) async {
    // Check if we already have cached models for this provider
    if (_providerModels.containsKey(provider)) {
      return _providerModels[provider]!;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final headers = await _getAuthHeaders();

      final response = await http.get(
        Uri.parse('$_baseUrl/ai/providers/$provider/models'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        _providerModels[provider] = List<String>.from(responseData);
        _isLoading = false;
        notifyListeners();
        return _providerModels[provider]!;
      } else {
        final errorData = jsonDecode(response.body);
        throw Exception(errorData['message'] ?? 'Failed to get models for $provider');
      }
    } catch (e) {
      _isLoading = false;
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }
}