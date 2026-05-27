// inventory_model.dart — Inventory & Stock Management Models

double _invNum(dynamic v) {
  if (v == null) return 0.0;
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v) ?? 0.0;
  return 0.0;
}

// ── InventoryItemModel ────────────────────────────────────────────────────────

class InventoryItemModel {
  final String? id;
  final String itemName;
  final double currentStock;
  final String unit;
  final double threshold;
  final String? category;
  final DateTime? lastUpdated;

  const InventoryItemModel({
    this.id,
    required this.itemName,
    required this.currentStock,
    required this.unit,
    required this.threshold,
    this.category,
    this.lastUpdated,
  });

  /// 'normal' | 'low' | 'out-of-stock'
  String get status {
    if (currentStock <= 0) return 'out-of-stock';
    if (currentStock <= threshold) return 'low';
    return 'normal';
  }

  bool get isLowStock => currentStock > 0 && currentStock <= threshold;
  bool get isOutOfStock => currentStock <= 0;

  InventoryItemModel copyWith({
    String? id,
    String? itemName,
    double? currentStock,
    String? unit,
    double? threshold,
    String? category,
    DateTime? lastUpdated,
  }) {
    return InventoryItemModel(
      id: id ?? this.id,
      itemName: itemName ?? this.itemName,
      currentStock: currentStock ?? this.currentStock,
      unit: unit ?? this.unit,
      threshold: threshold ?? this.threshold,
      category: category ?? this.category,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }

  factory InventoryItemModel.fromJson(Map<String, dynamic> json) {
    final itemJson = json['item'] is Map<String, dynamic>
        ? json['item'] as Map<String, dynamic>
        : json;
    return InventoryItemModel(
      id: itemJson['_id']?.toString() ?? itemJson['id']?.toString(),
      itemName: itemJson['itemName']?.toString() ??
          itemJson['name']?.toString() ??
          '',
      currentStock: _invNum(itemJson['currentStock'] ??
          itemJson['stock'] ??
          itemJson['quantity']),
      unit: itemJson['unit']?.toString() ?? 'units',
      threshold: _invNum(
          itemJson['threshold'] ?? itemJson['minStock'] ?? itemJson['minQty']),
      category: itemJson['category']?.toString(),
      lastUpdated: itemJson['lastUpdated'] != null
          ? DateTime.tryParse(itemJson['lastUpdated'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'itemName': itemName,
        'currentStock': currentStock,
        'unit': unit,
        'threshold': threshold,
        if (category != null) 'category': category,
      };
}

// ── StockHistoryEntry ─────────────────────────────────────────────────────────

class StockHistoryEntry {
  final String? id;
  final String type; // 'increase' | 'decrease'
  final double quantity;
  final String note;
  final String source; // 'purchase' | 'delivery' | 'manual'
  final DateTime date;

  const StockHistoryEntry({
    this.id,
    required this.type,
    required this.quantity,
    this.note = '',
    this.source = 'manual',
    required this.date,
  });

  factory StockHistoryEntry.fromJson(Map<String, dynamic> json) {
    return StockHistoryEntry(
      id: json['_id']?.toString() ?? json['id']?.toString(),
      type: json['type']?.toString() ?? 'increase',
      quantity: _invNum(json['quantity'] ?? json['amount']),
      note: json['note']?.toString() ??
          json['description']?.toString() ??
          '',
      source: json['source']?.toString() ?? 'manual',
      date: json['date'] != null
          ? DateTime.tryParse(json['date'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}

// ── InventoryDetailModel ──────────────────────────────────────────────────────

class InventoryDetailModel {
  final InventoryItemModel item;
  final List<StockHistoryEntry> history;

  const InventoryDetailModel({required this.item, required this.history});

  InventoryDetailModel copyWith({
    InventoryItemModel? item,
    List<StockHistoryEntry>? history,
  }) {
    return InventoryDetailModel(
      item: item ?? this.item,
      history: history ?? this.history,
    );
  }

  factory InventoryDetailModel.fromJson(Map<String, dynamic> json) {
    // Backend may return { item: {...}, history: [...] }
    // or the item fields at root with a stockHistory array
    final itemJson = json['item'] is Map<String, dynamic>
        ? json['item'] as Map<String, dynamic>
        : json;

    final historyJson = (json['history'] as List<dynamic>?) ??
        (json['stockHistory'] as List<dynamic>?) ??
        (json['transactions'] as List<dynamic>?) ??
        [];

    return InventoryDetailModel(
      item: InventoryItemModel.fromJson(itemJson),
      history: historyJson
          .map((e) =>
              StockHistoryEntry.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}
