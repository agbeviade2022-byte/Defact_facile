import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/app_config.dart';

bool supabaseInitialized = false;

Future<bool> initializeSupabase() async {
  if (!AppConfig.hasSupabaseConfig) return false;

  await Supabase.initialize(
    url: AppConfig.supabaseUrl,
    publishableKey: AppConfig.supabaseAnonKey,
  );
  supabaseInitialized = true;
  return true;
}

final supabaseClientProvider = Provider<SupabaseClient?>(
  (_) => supabaseInitialized ? Supabase.instance.client : null,
);

final accessTokenProvider = NotifierProvider<AccessTokenNotifier, String?>(
  AccessTokenNotifier.new,
);

class AccessTokenNotifier extends Notifier<String?> {
  static const _storageKey = 'defact_access_token';
  final _storage = const FlutterSecureStorage();

  @override
  String? build() {
    final supabaseToken = supabaseInitialized
        ? Supabase.instance.client.auth.currentSession?.accessToken
        : null;
    unawaited(restore());
    return supabaseToken;
  }

  void setToken(String? token) {
    state = token;
    unawaited(
      token == null
          ? _storage.delete(key: _storageKey)
          : _storage.write(key: _storageKey, value: token),
    );
  }

  Future<void> restore() async {
    final token = await _storage.read(key: _storageKey);
    if (token != null && token.isNotEmpty && state == null) state = token;
  }
}

final authServiceProvider = Provider<AuthService>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return AuthService(client, ref);
});

final authStateProvider = StreamProvider<AuthState>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return client?.auth.onAuthStateChange ?? const Stream.empty();
});

class AuthService {
  AuthService(this._client, this._ref) {
    _authSubscription = _client?.auth.onAuthStateChange.listen(
      (authState) => _setAccessToken(authState.session?.accessToken),
    );
    _ref.onDispose(() => _authSubscription?.cancel());
  }

  final SupabaseClient? _client;
  final Ref _ref;
  late final StreamSubscription<AuthState>? _authSubscription;
  bool _googleInitialized = false;

  bool get isConfigured => _client != null;

  Future<void> sendEmailCode(String email) async {
    _requireClient();
    await _client!.auth.signInWithOtp(email: email, shouldCreateUser: true);
  }

  Future<AuthResponse> verifyEmailCode({
    required String email,
    required String token,
  }) async {
    _requireClient();
    final response = await _client!.auth.verifyOTP(
      email: email,
      token: token,
      type: OtpType.email,
    );
    _setAccessToken(response.session?.accessToken);
    return response;
  }

  Future<bool> signInWithGoogle() async {
    if (AppConfig.googleWebClientId.isEmpty) {
      throw AuthException('Google Auth n’est pas configuré.');
    }

    final googleSignIn = GoogleSignIn.instance;
    if (!_googleInitialized) {
      await googleSignIn.initialize(
        clientId: AppConfig.googleWebClientId,
        serverClientId: AppConfig.googleWebClientId,
      );
      _googleInitialized = true;
    }

    final googleUser = await googleSignIn.authenticate();
    final idToken = googleUser.authentication.idToken;
    if (idToken == null) {
      throw AuthException('Google n’a pas fourni de jeton d’identité.');
    }

    final response = await Dio().post<Map<String, dynamic>>(
      '${AppConfig.apiBaseUrl}/auth/google',
      data: {'idToken': idToken},
    );
    final accessToken = response.data?['accessToken'];
    if (accessToken is! String || accessToken.isEmpty) {
      throw AuthException('Le serveur n’a pas fourni de session Google.');
    }
    _setAccessToken(accessToken);
    return true;
  }

  Future<void> signOut() async {
    await GoogleSignIn.instance.signOut();
    await _client?.auth.signOut();
    _setAccessToken(null);
  }

  void syncCurrentSession() {
    if (_client != null) {
      _setAccessToken(_client.auth.currentSession?.accessToken);
    }
  }

  void _setAccessToken(String? token) {
    _ref.read(accessTokenProvider.notifier).setToken(token);
  }

  void _requireClient() {
    if (_client == null) {
      throw AuthException(
        'Supabase Auth n’est pas configuré pour cet environnement.',
      );
    }
  }
}
