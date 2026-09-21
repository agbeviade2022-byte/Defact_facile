import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';

final paymentsRepositoryProvider = Provider<PaymentsRepository>(
  (ref) => PaymentsRepository(ref.read(dioProvider)),
);

class PaymentsRepository {
  PaymentsRepository(this._dio);

  final Dio _dio;

  Future<void> createForInvoice({
    required String invoiceId,
    required double amount,
    required String method,
    String? reference,
    String? notes,
  }) async {
    try {
      await _dio.post<void>(
        '/payments',
        data: {
          'invoiceId': invoiceId,
          'amount': amount,
          'method': method,
          if (reference?.trim().isNotEmpty == true) 'reference': reference!.trim(),
          if (notes?.trim().isNotEmpty == true) 'notes': notes!.trim(),
        },
      );
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }
}
