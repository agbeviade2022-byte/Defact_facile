import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class AuthService with ChangeNotifier {
  final String _baseUrl = 'http://localhost:3000/api/v1';
  String? _token;
  String? _userId;
  String? _email;
  bool _isLoading = false;

  String? get token => _token;
  String? get userId => _userId;
  String? get email => _email;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _token != null && _token!.isNotEmpty;

  Future<void> login(String email, String password) async {
    _isLoading = true;
    notifyListeners();
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'password': password,
        }),
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        _token = responseData['access_token'];
        _userId = responseData['user']['id'];
        _email = responseData['user']['email'];

        // Save token to shared preferences
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('auth_token', _token!);
        await prefs.setString('user_id', _userId!);
        await prefs.setString('email', _email!);

        _isLoading = false;
        notifyListeners();
      } else {
        final errorData = jsonDecode(response.body);
        throw Exception(errorData['message'] ?? 'Login failed');
      }
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      throw e;
    }
  }

  Future<void> register(String email, String password, String firstName, String lastName) async {
    _isLoading = true;
    notifyListeners();
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/users'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'password': password,
          'firstName': firstName,
          'lastName': lastName,
        }),
      );

      if (response.statusCode == 201) {
        final responseData = jsonDecode(response.body);
        _token = responseData['access_token'];
        _userId = responseData['user']['id'];
        _email = responseData['user']['email'];

        // Save token to shared preferences
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('auth_token', _token!);
        await prefs.setString('user_id', _userId!);
        await prefs.setString('email', _email!);

        _isLoading = false;
        notifyListeners();
      } else {
        final errorData = jsonDecode(response.body);
        throw Exception(errorData['message'] ?? 'Registration failed');
      }
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      throw e;
    }
  }

  Future<void> logout() async {
    _token = null;
    _userId = null;
    _email = null;

    // Clear shared preferences
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    _isLoading = false;
    notifyListeners();
  }

  Future<void> loadAuthState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      final userId = prefs.getString('user_id');
      final email = prefs.getString('email');

      if (token != null && token.isNotEmpty) {
        _token = token;
        _userId = userId;
        _email = email;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error loading auth state: $e');
    }
  }
}