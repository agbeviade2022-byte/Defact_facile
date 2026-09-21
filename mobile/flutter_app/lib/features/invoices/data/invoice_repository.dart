import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';

class InvoiceSummary {
  const InvoiceSummary({
    required this.id,
    required this.number,
    required this.status,
    required this.issueDate,
    required this.currency,
    required this.subtotal,
    required this.taxAmount,
    required this.total,
    required this.amountDue,
  });

  factory InvoiceSummary.fromJson(Map<String, dynamic> json) {
    return InvoiceSummary(
      id: json['id'] as String,
      number: json['number'] as String,
      status: json['status'] as String? ?? 'DRAFT',
      issueDate: json['issueDate'] as String,
      currency: json['currency'] as String? ?? 'XOF',
      subtotal: _toDouble(json['subtotal']),
      taxAmount: _toDouble(json['taxAmount']),
      total: _toDouble(json['total']),
      amountDue: _toDouble(json['amountDue']),
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
  final double amountDue;

  static double _toDouble(Object? value) =>
      value is num ? value.toDouble() : double.tryParse('$value') ?? 0;
}

final invoicesRepositoryProvider = Provider<InvoicesRepository>(
  (ref) => InvoicesRepository(ref.read(dioProvider)),
);

final invoicesProvider = FutureProvider<List<InvoiceSummary>>((ref) async {
  return ref.read(invoicesRepositoryProvider).list();
});

class InvoicesRepository {
  InvoicesRepository(this._dio);

  final Dio _dio;

  Future<List<InvoiceSummary>> list() async {
    try {
      final response = await _dio.get<List<dynamic>>('/invoices');
      return (response.data ?? [])
          .whereType<Map<String, dynamic>>()
          .map(InvoiceSummary.fromJson)
          .toList();
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<InvoiceSummary> createFromQuote(String quoteId) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/invoices/from-quote',
        data: {'quoteId': quoteId},
      );
      return InvoiceSummary.fromJson(response.data!);
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }
}
