import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';

class CustomerSummary {
  const CustomerSummary({
    required this.id,
    required this.type,
    required this.name,
    required this.email,
    required this.phone,
    required this.city,
  });

  factory CustomerSummary.fromJson(Map<String, dynamic> json) {
    return CustomerSummary(
      id: json['id'] as String,
      type: json['type'] as String? ?? 'INDIVIDUAL',
      name: json['name'] as String,
      email: json['email'] as String?,
      phone: json['phone'] as String?,
      city: json['city'] as String?,
    );
  }

  final String id;
  final String type;
  final String name;
  final String? email;
  final String? phone;
  final String? city;
}

final customersRepositoryProvider = Provider<CustomersRepository>(
  (ref) => CustomersRepository(ref.read(dioProvider)),
);

final customersProvider = FutureProvider<List<CustomerSummary>>((ref) async {
  return ref.read(customersRepositoryProvider).list();
});

class CustomersRepository {
  CustomersRepository(this._dio);

  final Dio _dio;

  Future<List<CustomerSummary>> list() async {
    try {
      final response = await _dio.get<List<dynamic>>('/customers');
      return (response.data ?? [])
          .map((item) => CustomerSummary.fromJson(item as Map<String, dynamic>))
          .toList();
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<CustomerSummary> create({
    required String type,
    required String name,
    String? email,
    String? phone,
    String? city,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/customers',
        data: {
          'type': type,
          'name': name,
          if (email?.trim().isNotEmpty ?? false) 'email': email!.trim(),
          if (phone?.trim().isNotEmpty ?? false) 'phone': phone!.trim(),
          if (city?.trim().isNotEmpty ?? false) 'city': city!.trim(),
        },
      );
      return CustomerSummary.fromJson(response.data!);
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }
}
