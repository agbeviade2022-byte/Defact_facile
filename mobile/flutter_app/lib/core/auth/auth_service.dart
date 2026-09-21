import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
  @override
  String? build() => supabaseInitialized
      ? Supabase.instance.client.auth.currentSession?.accessToken
      : null;

  void setToken(String? token) => state = token;
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
    _requireClient();
    return _client!.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: kIsWeb ? Uri.base.origin : null,
    );
  }

  Future<void> signOut() async {
    _requireClient();
    await _client!.auth.signOut();
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
