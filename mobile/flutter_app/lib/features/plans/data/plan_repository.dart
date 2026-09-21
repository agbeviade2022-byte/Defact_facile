import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';

enum PlanAudience { personal, organization, both }

class PlanSummary {
  const PlanSummary({
    required this.id,
    required this.code,
    required this.name,
    required this.description,
    required this.audience,
    required this.priceMonthly,
    required this.priceYearly,
    required this.currency,
    required this.aiCreditsMonthly,
    required this.limits,
    required this.features,
  });

  factory PlanSummary.fromJson(Map<String, dynamic> json) {
    final audience = switch (json['audience']) {
      'PERSONAL' => PlanAudience.personal,
      'ORGANIZATION' => PlanAudience.organization,
      _ => PlanAudience.both,
    };

    return PlanSummary(
      id: json['id'] as String,
      code: json['code'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      audience: audience,
      priceMonthly: _toDouble(json['priceMonthly']),
      priceYearly: _toDouble(json['priceYearly']),
      currency: (json['currency'] as String? ?? 'XOF').trim(),
      aiCreditsMonthly: (json['aiCreditsMonthly'] as num?)?.toInt() ?? 0,
      limits: _toMap(json['limits']),
      features: _toMap(json['features']),
    );
  }

  final String id;
  final String code;
  final String name;
  final String? description;
  final PlanAudience audience;
  final double priceMonthly;
  final double priceYearly;
  final String currency;
  final int aiCreditsMonthly;
  final Map<String, dynamic> limits;
  final Map<String, dynamic> features;

  static double _toDouble(Object? value) =>
      value is num ? value.toDouble() : double.tryParse('$value') ?? 0;

  static Map<String, dynamic> _toMap(Object? value) =>
      value is Map<String, dynamic> ? value : const <String, dynamic>{};
}

final planRepositoryProvider = Provider<PlanRepository>(
  (ref) => PlanRepository(ref.read(dioProvider)),
);

final plansProvider = FutureProvider<List<PlanSummary>>((ref) async {
  return ref.read(planRepositoryProvider).list();
});

class PlanRepository {
  PlanRepository(this._dio);

  final Dio _dio;

  Future<List<PlanSummary>> list() async {
    final response = await _dio.get<List<dynamic>>('/plans');
    return (response.data ?? const <dynamic>[])
        .whereType<Map<String, dynamic>>()
        .map(PlanSummary.fromJson)
        .toList();
  }
}
