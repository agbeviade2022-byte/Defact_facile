import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';

class ProductSummary {
  const ProductSummary({
    required this.id,
    required this.kind,
    required this.name,
    required this.unit,
    required this.salePrice,
    required this.trackStock,
  });

  factory ProductSummary.fromJson(Map<String, dynamic> json) {
    return ProductSummary(
      id: json['id'] as String,
      kind: json['kind'] as String? ?? 'PRODUCT',
      name: json['name'] as String,
      unit: json['unit'] as String? ?? 'unité',
      salePrice: _toDouble(json['salePrice']),
      trackStock: json['trackStock'] as bool? ?? false,
    );
  }

  final String id;
  final String kind;
  final String name;
  final String unit;
  final double salePrice;
  final bool trackStock;

  static double _toDouble(Object? value) =>
      value is num ? value.toDouble() : double.tryParse('$value') ?? 0;
}

class StockSummary {
  const StockSummary({
    required this.productId,
    required this.productName,
    required this.unit,
    required this.quantity,
    required this.warehouseName,
  });

  factory StockSummary.fromJson(Map<String, dynamic> json) {
    return StockSummary(
      productId: json['productId'] as String,
      productName: json['productName'] as String,
      unit: json['unit'] as String? ?? 'unité',
      quantity: _toDouble(json['quantity']),
      warehouseName: json['warehouseName'] as String,
    );
  }

  final String productId;
  final String productName;
  final String unit;
  final double quantity;
  final String warehouseName;

  static double _toDouble(Object? value) =>
      value is num ? value.toDouble() : double.tryParse('$value') ?? 0;
}

final inventoryRepositoryProvider = Provider<InventoryRepository>(
  (ref) => InventoryRepository(ref.read(dioProvider)),
);

final productsProvider = FutureProvider<List<ProductSummary>>((ref) async {
  return ref.read(inventoryRepositoryProvider).listProducts();
});

final stockProvider = FutureProvider<List<StockSummary>>((ref) async {
  return ref.read(inventoryRepositoryProvider).listStock();
});

class InventoryRepository {
  InventoryRepository(this._dio);

  final Dio _dio;

  Future<List<ProductSummary>> listProducts() async {
    try {
      final response = await _dio.get<List<dynamic>>('/products');
      return (response.data ?? [])
          .whereType<Map<String, dynamic>>()
          .map(ProductSummary.fromJson)
          .toList();
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<List<StockSummary>> listStock() async {
    try {
      final response = await _dio.get<List<dynamic>>('/inventory');
      return (response.data ?? [])
          .whereType<Map<String, dynamic>>()
          .map(StockSummary.fromJson)
          .toList();
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<void> createProduct({
    required String name,
    required bool trackStock,
    double salePrice = 0,
  }) async {
    try {
      await _dio.post<void>(
        '/products',
        data: {
          'kind': 'PRODUCT',
          'name': name,
          'trackStock': trackStock,
          'salePrice': salePrice,
        },
      );
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<void> adjustStock({
    required String productId,
    required double quantity,
    required String type,
  }) async {
    try {
      await _dio.post<void>(
        '/inventory/movements',
        data: {
          'productId': productId,
          'quantity': quantity,
          'type': type,
        },
      );
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }
}
