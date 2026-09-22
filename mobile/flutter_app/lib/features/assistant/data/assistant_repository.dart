import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';

class AiAnswer {
  const AiAnswer({
    required this.text,
    required this.provider,
    required this.model,
  });

  factory AiAnswer.fromJson(Map<String, dynamic> json) {
    return AiAnswer(
      text: json['text'] as String? ?? '',
      provider: json['provider'] as String? ?? '',
      model: json['model'] as String? ?? '',
    );
  }

  final String text;
  final String provider;
  final String model;
}

final assistantRepositoryProvider = Provider<AssistantRepository>(
  (ref) => AssistantRepository(ref.read(dioProvider)),
);

class AssistantRepository {
  AssistantRepository(this._dio);

  final Dio _dio;

  Future<AiAnswer> ask(String prompt) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/ai/complete',
        data: {
          'action': 'simple_question',
          'prompt': prompt,
          'maxTokens': 1024,
        },
      );
      return AiAnswer.fromJson(response.data!);
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }
}
