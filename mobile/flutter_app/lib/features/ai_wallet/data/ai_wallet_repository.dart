import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';

class AiWalletBalance {
  const AiWalletBalance({
    required this.balance,
    required this.lifetimeCredited,
    required this.lifetimeConsumed,
  });

  factory AiWalletBalance.fromJson(Map<String, dynamic> json) {
    return AiWalletBalance(
      balance: (json['balance'] as num?)?.toInt() ?? 0,
      lifetimeCredited: (json['lifetimeCredited'] as num?)?.toInt() ?? 0,
      lifetimeConsumed: (json['lifetimeConsumed'] as num?)?.toInt() ?? 0,
    );
  }

  final int balance;
  final int lifetimeCredited;
  final int lifetimeConsumed;
}

class AiTopUpCheckout {
  const AiTopUpCheckout({required this.checkoutUrl, required this.reference});

  factory AiTopUpCheckout.fromJson(Map<String, dynamic> json) {
    return AiTopUpCheckout(
      checkoutUrl: json['checkoutUrl'] as String,
      reference: json['reference'] as String,
    );
  }

  final String checkoutUrl;
  final String reference;
}

final aiWalletRepositoryProvider = Provider<AiWalletRepository>(
  (ref) => AiWalletRepository(ref.read(dioProvider)),
);

final aiWalletProvider = FutureProvider<AiWalletBalance>((ref) async {
  return ref.read(aiWalletRepositoryProvider).balance();
});

class AiWalletRepository {
  AiWalletRepository(this._dio);

  final Dio _dio;

  Future<AiWalletBalance> balance() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>('/ai/wallet');
      return AiWalletBalance.fromJson(response.data!);
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<AiTopUpCheckout> createTopUp(int amount) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/ai/wallet/top-ups',
        data: {'amount': amount},
      );
      return AiTopUpCheckout.fromJson(response.data!);
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }
}
