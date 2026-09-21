import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_service.dart';
import '../config/app_config.dart';

/// Header carrying the active workspace. The backend validates it against the
/// user's memberships; the client only declares intent.
const String workspaceHeader = 'X-Workspace-Id';

/// Active workspace id (personal workspace or organization). Set in Mission 03.
final activeWorkspaceIdProvider = Provider<String?>((_) => null);

final dioProvider = Provider<Dio>((ref) {
  final dio = Dio(
    BaseOptions(
      baseUrl: AppConfig.apiBaseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 30),
      headers: const {'Accept': 'application/json'},
    ),
  );

  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        final token = ref.read(accessTokenProvider);
        if (token != null) options.headers['Authorization'] = 'Bearer $token';
        final workspace = ref.read(activeWorkspaceIdProvider);
        if (workspace != null) options.headers[workspaceHeader] = workspace;
        handler.next(options);
      },
    ),
  );

  return dio;
});

/// Normalised API error, mirroring the backend `HttpExceptionFilter` envelope.
class ApiException implements Exception {
  const ApiException({
    required this.statusCode,
    required this.message,
    this.details,
  });

  factory ApiException.fromDio(DioException e) {
    final data = e.response?.data;
    if (data is Map<String, dynamic>) {
      final message = data['message'];
      return ApiException(
        statusCode: e.response?.statusCode ?? 0,
        message: message is List
            ? message.join(', ')
            : message?.toString() ?? e.message ?? '',
        details: data['details'],
      );
    }
    return ApiException(
      statusCode: e.response?.statusCode ?? 0,
      message: e.message ?? 'Erreur réseau',
    );
  }

  final int statusCode;
  final String message;
  final Object? details;

  bool get isNetworkError => statusCode == 0;

  @override
  String toString() => 'ApiException($statusCode): $message';
}
