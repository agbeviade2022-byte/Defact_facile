import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';

class QuoteSummary {
  const QuoteSummary({
    required this.id,
    required this.number,
    required this.status,
    required this.issueDate,
    required this.currency,
    required this.subtotal,
    required this.taxAmount,
    required this.total,
  });

  factory QuoteSummary.fromJson(Map<String, dynamic> json) {
    return QuoteSummary(
      id: json['id'] as String,
      number: json['number'] as String,
      status: json['status'] as String? ?? 'DRAFT',
      issueDate: json['issueDate'] as String,
      currency: json['currency'] as String? ?? 'XOF',
      subtotal: _toDouble(json['subtotal']),
      taxAmount: _toDouble(json['taxAmount']),
      total: _toDouble(json['total']),
    );
  }

  final String id;
  final String number;
  final String status;
  final String issueDate;
  final String currency;
  final double subtotal;
  final double taxAmount;
  final double total;

  static double _toDouble(Object? value) =>
      value is num ? value.toDouble() : double.tryParse('$value') ?? 0;
}

final quotesRepositoryProvider = Provider<QuotesRepository>(
  (ref) => QuotesRepository(ref.read(dioProvider)),
);

final quotesProvider = FutureProvider<List<QuoteSummary>>((ref) async {
  return ref.read(quotesRepositoryProvider).list();
});

class QuotesRepository {
  QuotesRepository(this._dio);

  final Dio _dio;

  Future<List<QuoteSummary>> list() async {
    try {
      final response = await _dio.get<List<dynamic>>('/quotes');
      return (response.data ?? [])
          .whereType<Map<String, dynamic>>()
          .map(QuoteSummary.fromJson)
          .toList();
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<QuoteSummary> create({
    required String description,
    required double quantity,
    required double unitPrice,
    double taxRate = 0,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/quotes',
        data: {
          'items': [
            {
              'description': description,
              'quantity': quantity,
              'unitPrice': unitPrice,
              'taxRate': taxRate,
            },
          ],
        },
      );
      return QuoteSummary.fromJson(response.data!);
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }
}
