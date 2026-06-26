import 'package:dio/dio.dart';
import '../models/inventory_model.dart';
import 'dio_client.dart';
import 'token_service.dart';

/// Dedicated service for the Inventory category drill-down APIs.
/// Mirrors the conventions of SupplierService — uses DioClient, extracts errors.
/// Inventory CRUD operations remain in SupplierService to avoid breaking changes.
class InventoryService {
  final TokenService _tokenService;
  late final Dio _dio;

  InventoryService(this._tokenService) {
    _dio = DioClient.build(_tokenService);
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  String _extractError(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
        return 'Server is starting up. Please wait a moment and try again.';
      case DioExceptionType.receiveTimeout:
        return 'Server is taking too long to respond. Please try again.';
      case DioExceptionType.connectionError:
        return 'No internet connection. Please check your network.';
      default:
        break;
    }
    final data = e.response?.data;
    if (data is Map) {
      if (data['message'] != null) return data['message'].toString();
      if (data['error'] != null) return data['error'].toString();
    }
    final statusCode = e.response?.statusCode;
    return 'Request failed${statusCode != null ? ' ($statusCode)' : ''}. Please try again.';
  }

  // ── Category Drill-Down APIs ───────────────────────────────────────────────

  /// GET /inventory/by-category
  /// Returns each active category with item count, total stock, and low stock count.
  Future<List<InventoryCategorySummary>> getInventoryByCategory() async {
    try {
      final response = await _dio.get('/inventory/by-category');
      final data = response.data;
      if (data is! List) return [];
      return data
          .map((j) => InventoryCategorySummary.fromJson(j as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw Exception(_extractError(e));
    }
  }

  /// GET /inventory/category/{categoryName}
  /// Returns summary + all items in the given category.
  Future<InventoryCategoryDetail> getCategoryDetail(String categoryName) async {
    try {
      final encoded = Uri.encodeComponent(categoryName);
      final response = await _dio.get('/inventory/category/$encoded');
      return InventoryCategoryDetail.fromJson(
          response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw Exception(_extractError(e));
    }
  }
}
