// inventory_repository.dart
// Repository pattern wrapper around SupplierService for all inventory operations.
// Consumers depend on this class; screens never call SupplierService directly for inventory.

import '../models/inventory_model.dart';
import '../services/supplier_service.dart';
import '../services/inventory_service.dart';
import '../services/token_service.dart';

class InventoryRepository {
  SupplierService? _service;

  // Lazy-init: obtains TokenService once and caches the SupplierService.
  Future<SupplierService> _svc() async {
    _service ??= SupplierService(await TokenService.getInstance());
    return _service!;
  }

  /// Returns all inventory items, deduplicated by itemName (keeps first occurrence).
  Future<List<InventoryItemModel>> getAll() async {
    final svc = await _svc();
    final raw = await svc.getInventory();
    return _dedupe(raw);
  }

  /// Returns only items at or below their threshold.
  Future<List<InventoryItemModel>> getLowStock() async {
    final svc = await _svc();
    final raw = await svc.getLowStockAlerts();
    return _dedupe(raw);
  }

  /// Returns full detail (item + history) for a single inventory item.
  Future<InventoryDetailModel> getDetail(String id) async {
    final svc = await _svc();
    return svc.getInventoryDetail(id);
  }

  /// PATCH /inventory/:id/threshold — updates the low-stock threshold.
  /// Throws a user-friendly [Exception] on failure.
  Future<void> updateThreshold(String id, double threshold) async {
    final svc = await _svc();
    await svc.updateInventoryThreshold(id, threshold);
  }

  /// POST /inventory/:id/stock — manually increase stock.
  Future<void> addStock({
    required String itemId,
    required double quantity,
    required String reason,
    String notes = '',
  }) async {
    final svc = await _svc();
    await svc.addStockEntry(
      itemId: itemId,
      quantity: quantity,
      reason: reason,
      notes: notes,
    );
  }

  /// PUT /inventory/:id — update item metadata (name, category, unit, threshold).
  /// Pass only the fields you want to change; null fields are ignored.
  Future<void> updateItem(
    String id, {
    String? itemName,
    String? categoryName,
    String? unit,
    double? lowStockThreshold,
    int? currentStock,
    String? stockCorrectionNote,
  }) async {
    final svc = await _svc();
    await svc.updateInventoryItem(
      id,
      itemName: itemName,
      categoryName: categoryName,
      unit: unit,
      lowStockThreshold: lowStockThreshold,
      currentStock: currentStock,
      stockCorrectionNote: stockCorrectionNote,
    );
  }

  /// DELETE /inventory/:id — removes item and its stock history.
  /// Throws a user-friendly [Exception] if backend rejects (e.g. stock > 0).
  Future<void> deleteItem(String id) async {
    final svc = await _svc();
    await svc.deleteInventoryItem(id);
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  /// Removes entries with duplicate itemName, keeping the first occurrence.
  List<InventoryItemModel> _dedupe(List<InventoryItemModel> items) {
    final seen = <String>{};
    return items.where((item) => seen.add(item.itemName)).toList();
  }

  // ── Category Drill-Down ────────────────────────────────────────────────────

  InventoryService? _inventorySvc;

  Future<InventoryService> _invSvc() async {
    _inventorySvc ??= InventoryService(await TokenService.getInstance());
    return _inventorySvc!;
  }

  /// GET /inventory/by-category — category list with totals.
  Future<List<InventoryCategorySummary>> getInventoryByCategory() async {
    final svc = await _invSvc();
    return svc.getInventoryByCategory();
  }

  /// GET /inventory/category/{categoryName} — summary + items for one category.
  Future<InventoryCategoryDetail> getCategoryDetail(String categoryName) async {
    final svc = await _invSvc();
    return svc.getCategoryDetail(categoryName);
  }
}
