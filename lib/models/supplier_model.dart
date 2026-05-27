// ─────────────────────────────────────────────────────────────────────────────
// supplier_model.dart
//
// Data models for the Supplier / Vendor module.
// Follows the same parsing conventions used across the rest of the codebase
// (try multiple field names, never crash on missing fields).
// ─────────────────────────────────────────────────────────────────────────────

double _safeNum(Map<String, dynamic> json, List<String> keys) {
  for (final k in keys) {
    final v = json[k];
    if (v != null) {
      if (v is num) return v.toDouble();
      if (v is String) return double.tryParse(v) ?? 0.0;
    }
  }
  return 0.0;
}

// ── SupplierModel ─────────────────────────────────────────────────────────────

class SupplierModel {
  final String? id;
  final String name;
  final String phone;
  final String address;
  final double totalPurchased;
  final double totalPaid;
  final double pendingBalance;
  final double openingBalance;
  final double advanceBalance;
  final DateTime? createdAt;

  SupplierModel({
    this.id,
    required this.name,
    required this.phone,
    this.address = '',
    this.totalPurchased = 0.0,
    this.totalPaid = 0.0,
    this.pendingBalance = 0.0,
    this.openingBalance = 0.0,
    this.advanceBalance = 0.0,
    this.createdAt,
  });

  double get pending => totalPurchased - totalPaid;

  factory SupplierModel.fromJson(Map<String, dynamic> json) {
    return SupplierModel(
      id: json['_id']?.toString() ?? json['id']?.toString(),
      name: json['name']?.toString() ?? '',
      phone: json['phone']?.toString() ?? '',
      address: json['address']?.toString() ?? '',
      totalPurchased: _safeNum(json, ['totalPurchased', 'totalPurchase', 'purchased']),
      totalPaid: _safeNum(json, ['totalPaid', 'paid']),
      pendingBalance: _safeNum(json, ['pendingBalance', 'balance', 'pending']),
      openingBalance: _safeNum(json, ['openingBalance', 'opBal', 'opening_balance']),
      advanceBalance: _safeNum(json, ['advanceBalance', 'advance_balance', 'advance']),
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'phone': phone,
        'address': address,
        'openingBalance': openingBalance,
      };
}

// ── SupplierPurchaseModel ─────────────────────────────────────────────────────

class SupplierPurchaseModel {
  final String? id;
  final String? supplierId;
  final String item;
  final double quantity;
  final String unit;
  final double pricePerUnit;
  final double totalAmount;
  final String note;
  final DateTime date;
  final String category;
  final DateTime? dueDate;
  final String? invoiceImage;
  final DateTime? createdAt;

  SupplierPurchaseModel({
    this.id,
    this.supplierId,
    required this.item,
    required this.quantity,
    this.unit = '',
    required this.pricePerUnit,
    required this.totalAmount,
    this.note = '',
    required this.date,
    this.category = 'Others',
    this.dueDate,
    this.invoiceImage,
    this.createdAt,
  });

  factory SupplierPurchaseModel.fromJson(Map<String, dynamic> json) {
    return SupplierPurchaseModel(
      id: json['_id']?.toString() ?? json['id']?.toString(),
      supplierId: json['supplierId']?.toString(),
      item: json['itemName']?.toString() ?? json['item']?.toString() ?? json['name']?.toString() ?? json['note']?.toString() ?? '',
      quantity: _safeNum(json, ['quantity', 'qty']),
      unit: json['unit']?.toString() ?? '',
      pricePerUnit: _safeNum(json, ['pricePerUnit', 'price', 'rate']),
      totalAmount: _safeNum(json, ['totalAmount', 'total', 'amount']),
      note: json['note']?.toString() ?? '',
      date: json['date'] != null
          ? DateTime.tryParse(json['date'].toString()) ?? DateTime.now()
          : DateTime.now(),
      category: json['category']?.toString() ?? 'Others',
      dueDate: json['dueDate'] != null ? DateTime.tryParse(json['dueDate'].toString()) : null,
      invoiceImage: json['invoiceImage']?.toString(),
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        if (supplierId != null) 'supplierId': supplierId,
        'item': item,
        'quantity': quantity,
        'unit': unit,
        'pricePerUnit': pricePerUnit,
        'totalAmount': totalAmount,
        if (note.isNotEmpty) 'note': note,
        'category': category,
        if (dueDate != null)
          'dueDate':
              '${dueDate!.year}-${dueDate!.month.toString().padLeft(2, '0')}-${dueDate!.day.toString().padLeft(2, '0')}',
        if (invoiceImage != null) 'invoiceImage': invoiceImage,
        'date':
            '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}',
      };
}

// ── SupplierPaymentModel ──────────────────────────────────────────────────────

class SupplierPaymentModel {
  final String? id;
  final String? supplierId;
  final double amount;
  final String note;
  final DateTime date;
  final DateTime? createdAt;

  SupplierPaymentModel({
    this.id,
    this.supplierId,
    required this.amount,
    this.note = '',
    required this.date,
    this.createdAt,
  });

  factory SupplierPaymentModel.fromJson(Map<String, dynamic> json) {
    return SupplierPaymentModel(
      id: json['_id']?.toString() ?? json['id']?.toString(),
      supplierId: json['supplierId']?.toString(),
      amount: _safeNum(json, ['amount']),
      note: json['note']?.toString() ?? '',
      date: json['date'] != null
          ? DateTime.tryParse(json['date'].toString()) ?? DateTime.now()
          : DateTime.now(),
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        if (supplierId != null) 'supplierId': supplierId,
        'amount': amount,
        if (note.isNotEmpty) 'note': note,
        'date':
            '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}',
      };
}

// ── SupplierLedgerModel ───────────────────────────────────────────────────────

class SupplierLedgerModel {
  final SupplierModel supplier;
  final List<SupplierPurchaseModel> purchases;
  final List<SupplierPaymentModel> payments;
  final double totalPurchased;
  final double totalPaid;
  final double openingBalance;
  final double pendingBalance;
  final double advanceBalance;

  SupplierLedgerModel({
    required this.supplier,
    required this.purchases,
    required this.payments,
    required this.totalPurchased,
    required this.totalPaid,
    required this.openingBalance,
    required this.pendingBalance,
    required this.advanceBalance,
  });

  factory SupplierLedgerModel.fromJson(Map<String, dynamic> json) {
    final supplierJson = json['supplier'] as Map<String, dynamic>? ?? json;
    
    final List<dynamic> transactionsJson = json['transactions'] as List<dynamic>? ?? [];
    
    final List<dynamic> purchasesJson = json['purchaseHistory'] as List<dynamic>? ??
        json['purchases'] as List<dynamic>? ??
        transactionsJson.where((t) => t['type'] == 'purchase').toList();
        
    final List<dynamic> paymentsJson = json['paymentHistory'] as List<dynamic>? ??
        json['payments'] as List<dynamic>? ??
        transactionsJson.where((t) => t['type'] == 'payment').toList();

    final purchases = purchasesJson
        .map((p) => SupplierPurchaseModel.fromJson(p as Map<String, dynamic>))
        .toList();
    final payments = paymentsJson
        .map((p) => SupplierPaymentModel.fromJson(p as Map<String, dynamic>))
        .toList();

    final totalPurchased = _safeNum(json, ['totalPurchased', 'totalPurchase']) > 0
        ? _safeNum(json, ['totalPurchased', 'totalPurchase'])
        : purchases.fold(0.0, (s, p) => s + p.totalAmount);

    final totalPaid = _safeNum(json, ['totalPaid', 'paid']) > 0
        ? _safeNum(json, ['totalPaid', 'paid'])
        : payments.fold(0.0, (s, p) => s + p.amount);

    final openingBalance = _safeNum(json, ['openingBalance', 'opBal']) > 0
        ? _safeNum(json, ['openingBalance', 'opBal'])
        : _safeNum(supplierJson, ['openingBalance', 'opBal', 'opening_balance']);

    final pendingBalance = _safeNum(json, ['pendingBalance', 'balance', 'pending']) > 0
        ? _safeNum(json, ['pendingBalance', 'balance', 'pending'])
        : _safeNum(supplierJson, ['pendingBalance', 'balance', 'pending']);

    final advanceBalance = _safeNum(json, ['advanceBalance', 'advance']) > 0
        ? _safeNum(json, ['advanceBalance', 'advance'])
        : _safeNum(supplierJson, ['advanceBalance', 'advance']);

    return SupplierLedgerModel(
      supplier: SupplierModel.fromJson(supplierJson),
      purchases: purchases,
      payments: payments,
      totalPurchased: totalPurchased,
      totalPaid: totalPaid,
      openingBalance: openingBalance,
      pendingBalance: pendingBalance,
      advanceBalance: advanceBalance,
    );
  }
}
