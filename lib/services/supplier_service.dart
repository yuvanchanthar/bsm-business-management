import 'package:dio/dio.dart';
import '../models/supplier_model.dart';
import '../models/inventory_model.dart';
import '../models/category_model.dart';
import 'dio_client.dart';
import 'token_service.dart';

/// Service for all Supplier / Vendor API operations.
/// Mirrors the conventions of ApiService — uses DioClient, extracts errors,
/// and never modifies existing services.
class SupplierService {
  final TokenService _tokenService;
  late final Dio _dio;

  SupplierService(this._tokenService) {
    _dio = DioClient.build(_tokenService);
  }

  // ── Helpers ──────────────────────────────────────────────────────────────────

  List<dynamic> _parseList(dynamic data, [List<String> listKeys = const []]) {
    if (data == null) return [];
    if (data is List) return data;
    if (data is Map) {
      for (final key in [...listKeys, 'data', 'suppliers', 'purchases', 'payments']) {
        if (data.containsKey(key) && data[key] is List) return data[key];
      }
      return [data];
    }
    return [];
  }

  String _extractError(DioException e) {
    // Full error logging for debug builds
    print('[SupplierService] DioException type: ${e.type}');
    print('[SupplierService] Status code: ${e.response?.statusCode}');
    print('[SupplierService] Response data: ${e.response?.data}');

    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.connectionError) {
      return 'No internet connection. Please try again.';
    }
    final data = e.response?.data;
    if (data is Map) {
      // Backend uses both 'message' and 'error' keys — check both
      if (data['message'] != null) return data['message'].toString();
      if (data['error'] != null) return data['error'].toString();
    }
    final statusCode = e.response?.statusCode;
    return 'Request failed${statusCode != null ? ' ($statusCode)' : ''}. Please try again.';
  }

  // ── Supplier CRUD ─────────────────────────────────────────────────────────────

  /// GET /suppliers/report
  Future<List<SupplierModel>> getSuppliers() async {
    try {
      final response = await _dio.get('/suppliers/report');
      final data = _parseList(response.data, ['suppliers', 'report']);
      return data
          .map((json) => SupplierModel.fromJson(json as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw Exception(_extractError(e));
    }
  }

  /// POST /suppliers
  Future<bool> addSupplier(SupplierModel supplier) async {
    try {
      await _dio.post('/suppliers', data: supplier.toJson());
      return true;
    } on DioException catch (e) {
      throw Exception(_extractError(e));
    }
  }

  /// GET /suppliers/:id/ledger
  Future<SupplierLedgerModel> getSupplierLedger(String supplierId) async {
    try {
      final response = await _dio.get('/suppliers/$supplierId/ledger');
      final data = response.data as Map<String, dynamic>;
      return SupplierLedgerModel.fromJson(data);
    } on DioException catch (e) {
      throw Exception(_extractError(e));
    }
  }

  // ── Purchase ──────────────────────────────────────────────────────────────────

  /// POST /supplier-purchases
  Future<bool> addPurchase(SupplierPurchaseModel purchase) async {
    try {
      await _dio.post('/supplier-purchases', data: purchase.toJson());
      return true;
    } on DioException catch (e) {
      throw Exception(_extractError(e));
    }
  }

  /// PUT /supplier-purchases/:id
  Future<bool> updatePurchase(String id, Map<String, dynamic> data) async {
    try {
      await _dio.put('/supplier-purchases/$id', data: data);
      return true;
    } on DioException catch (e) {
      throw Exception(_extractError(e));
    }
  }

  /// DELETE /supplier-purchases/:id
  Future<bool> deletePurchase(String id) async {
    try {
      await _dio.delete('/supplier-purchases/$id');
      return true;
    } on DioException catch (e) {
      throw Exception(_extractError(e));
    }
  }

  // ── Payment ───────────────────────────────────────────────────────────────────

  /// POST /supplier-payments
  Future<bool> addPayment(SupplierPaymentModel payment) async {
    try {
      await _dio.post('/supplier-payments', data: payment.toJson());
      return true;
    } on DioException catch (e) {
      throw Exception(_extractError(e));
    }
  }

  /// PUT /supplier-payments/:id
  Future<bool> updatePayment(String id, Map<String, dynamic> data) async {
    try {
      await _dio.put('/supplier-payments/$id', data: data);
      return true;
    } on DioException catch (e) {
      throw Exception(_extractError(e));
    }
  }

  /// DELETE /supplier-payments/:id
  Future<bool> deletePayment(String id) async {
    try {
      await _dio.delete('/supplier-payments/$id');
      return true;
    } on DioException catch (e) {
      throw Exception(_extractError(e));
    }
  }

  /// GET /suppliers/top
  Future<List<dynamic>> getTopSuppliers() async {
    try {
      final response = await _dio.get('/suppliers/top');
      if (response.data is List) {
        return response.data as List;
      }
      return [];
    } on DioException catch (e) {
      throw Exception(_extractError(e));
    }
  }

  /// GET /suppliers/analytics
  Future<Map<String, dynamic>> getSupplierAnalytics() async {
    try {
      final response = await _dio.get('/suppliers/analytics');
      if (response.data is Map<String, dynamic>) {
        return response.data as Map<String, dynamic>;
      }
      return {};
    } on DioException catch (e) {
      throw Exception(_extractError(e));
    }
  }

  /// GET /suppliers/report/monthly
  Future<List<dynamic>> getSupplierMonthlyReport() async {
    try {
      final response = await _dio.get('/suppliers/report/monthly');
      if (response.data is List) {
        return response.data as List;
      }
      return [];
    } on DioException catch (e) {
      throw Exception(_extractError(e));
    }
  }

  /// GET /suppliers/:id/pdf-report
  Future<Map<String, dynamic>> getSupplierPdfReport(String supplierId) async {
    try {
      final response = await _dio.get('/suppliers/$supplierId/pdf-report');
      if (response.data is Map<String, dynamic>) {
        return response.data as Map<String, dynamic>;
      }
      return {};
    } on DioException catch (e) {
      throw Exception(_extractError(e));
    }
  }

  /// GET /suppliers/:id/pdf-report → purchaseHistory
  /// Returns FULL purchase documents (with quantity, unit, pricePerUnit, etc.).
  /// Used to pre-fill the Edit Purchase screen correctly, since the ledger
  /// endpoint only returns summarized transaction entries.
  Future<List<SupplierPurchaseModel>> getSupplierPurchasesRaw(String supplierId) async {
    try {
      final response = await _dio.get('/suppliers/$supplierId/pdf-report');
      final data = response.data as Map<String, dynamic>;
      final rawList = data['purchaseHistory'] as List<dynamic>? ?? [];
      print('[SupplierService] getSupplierPurchasesRaw: ${rawList.length} purchases fetched');
      return rawList
          .map((j) => SupplierPurchaseModel.fromJson(j as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw Exception(_extractError(e));
    }
  }

  // ── Inventory ──────────────────────────────────────────────────────────────

  /// GET /inventory — all inventory items
  Future<List<InventoryItemModel>> getInventory() async {
    try {
      final response = await _dio.get('/inventory');
      final data = _parseList(response.data, ['inventory', 'items', 'data']);
      return data
          .map((j) => InventoryItemModel.fromJson(j as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw Exception(_extractError(e));
    }
  }

  /// GET /inventory/low-stock — items at or below threshold
  Future<List<InventoryItemModel>> getLowStockAlerts() async {
    try {
      final response = await _dio.get('/inventory/low-stock');
      final data = _parseList(response.data, ['inventory', 'items', 'data']);
      return data
          .map((j) => InventoryItemModel.fromJson(j as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw Exception(_extractError(e));
    }
  }

  /// GET /inventory/:id — single item with stock history
  Future<InventoryDetailModel> getInventoryDetail(String id) async {
    try {
      final response = await _dio.get('/inventory/$id');
      return InventoryDetailModel.fromJson(
          response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw Exception(_extractError(e));
    }
  }

  /// POST /inventory/:id/stock — manually increase stock
  Future<bool> addStockEntry({
    required String itemId,
    required double quantity,
    required String reason,
    String notes = '',
  }) async {
    try {
      await _dio.post('/inventory/$itemId/stock', data: {
        'quantity': quantity,
        'reason': reason,
        'notes': notes,
      });
      return true;
    } on DioException catch (e) {
      throw Exception(_extractError(e));
    }
  }

  /// PATCH /inventory/:id/threshold
  Future<bool> updateInventoryThreshold(String id, double threshold) async {
    try {
      await _dio.patch('/inventory/$id/threshold',
          data: {'lowStockThreshold': threshold});
      return true;
    } on DioException catch (e) {
      throw Exception(_extractError(e));
    }
  }

  // ── Categories & Grouped Items ──────────────────────────────────────────────

  /// GET /categories
  Future<List<CategoryModel>> getCategories() async {
    try {
      final response = await _dio.get('/categories');
      final data = _parseList(response.data, ['categories', 'data']);
      return data
          .map((j) => CategoryModel.fromJson(j as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw Exception(_extractError(e));
    }
  }

  /// POST /categories
  Future<bool> addCategory(String name, String description) async {
    try {
      await _dio.post('/categories', data: {
        'name': name,
        'description': description,
      });
      return true;
    } on DioException catch (e) {
      throw Exception(_extractError(e));
    }
  }

  /// GET /items/dropdown
  Future<List<GroupedItemModel>> getGroupedItemsDropdown() async {
    try {
      final response = await _dio.get('/items/dropdown');
      final data = _parseList(response.data, ['dropdown', 'data', 'groups']);
      return data
          .map((j) => GroupedItemModel.fromJson(j as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw Exception(_extractError(e));
    }
  }

  /// POST /inventory/item
  Future<bool> addInventoryItem({
    required String itemName,
    required String category,
    required String unit,
    required double threshold,
  }) async {
    try {
      await _dio.post('/inventory/item', data: {
        'itemName': itemName,
        'category': category,
        'unit': unit,
        'lowStockThreshold': threshold,
      });
      return true;
    } on DioException catch (e) {
      throw Exception(_extractError(e));
    }
  }

  /// PUT /inventory/:id — update item metadata (name, category, unit, threshold).
  /// Only the provided (non-null) fields are sent to the backend.
  Future<bool> updateInventoryItem(
    String id, {
    String? itemName,
    String? categoryName,
    String? unit,
    double? lowStockThreshold,
    int? currentStock,
    String? stockCorrectionNote,
  }) async {
    try {
      final body = <String, dynamic>{};
      if (itemName != null) body['itemName'] = itemName;
      if (categoryName != null) body['categoryName'] = categoryName;
      if (unit != null) body['unit'] = unit;
      if (lowStockThreshold != null) body['lowStockThreshold'] = lowStockThreshold;
      if (currentStock != null) {
        body['currentStock'] = currentStock;
        if (stockCorrectionNote != null) {
          body['stockCorrectionNote'] = stockCorrectionNote;
        }
      }
      await _dio.put('/inventory/$id', data: body);
      return true;
    } on DioException catch (e) {
      throw Exception(_extractError(e));
    }
  }

  /// DELETE /inventory/:id — removes item and its stock history.
  /// Backend blocks deletion when currentStock > 0 and returns
  /// { error: "Cannot delete item with remaining stock" }.
  Future<void> deleteInventoryItem(String id) async {
    try {
      await _dio.delete('/inventory/$id');
    } on DioException catch (e) {
      throw Exception(_extractError(e));
    }
  }
}
