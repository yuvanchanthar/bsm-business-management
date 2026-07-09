class StatementItem {
  final String name;
  final double quantity;
  final double? price;
  final String? unit;
  final double? total;

  StatementItem({required this.name, required this.quantity, this.price, this.unit, this.total});

  factory StatementItem.fromJson(Map<String, dynamic> json) {
    double? parseOptional(dynamic v) {
      if (v == null) return null;
      if (v is num) return v.toDouble();
      return double.tryParse(v.toString());
    }
    return StatementItem(
      name: json['itemName']?.toString() ?? json['name']?.toString() ?? json['item']?.toString() ?? json['product']?.toString() ?? '',
      quantity: (json['quantity'] is num) ? (json['quantity'] as num).toDouble() : double.tryParse(json['qty']?.toString() ?? '0') ?? 0.0,
      price: parseOptional(json['price'] ?? json['unitPrice']),
      unit: json['unit']?.toString() ?? 'Bag',
      total: parseOptional(json['total'] ?? json['totalAmount']),
    );
  }
}

class StatementTransaction {
  final DateTime date;
  final String type;
  final String description;
  final double amount;
  final double balance;
  final List<StatementItem> items;
  // Credit Sale extra fields (populated when type == 'credit_sale')
  final double grandTotal;
  final double paymentReceived;
  final double pendingAmount;

  StatementTransaction({
    required this.date,
    required this.type,
    required this.description,
    required this.amount,
    required this.balance,
    this.items = const [],
    this.grandTotal = 0.0,
    this.paymentReceived = 0.0,
    this.pendingAmount = 0.0,
  });

  factory StatementTransaction.fromJson(Map<String, dynamic> json) {
    double parseDouble(dynamic v, {double fallback = 0.0}) {
      if (v == null) return fallback;
      if (v is num) return v.toDouble();
      return double.tryParse(v.toString()) ?? fallback;
    }

    double debit  = parseDouble(json['debit']);
    double credit = parseDouble(json['credit']);
    String description = json['description']?.toString() ?? '';
    // The backend now sends an explicit 'type' field for all transactions.
    final rawType = json['type']?.toString() ?? '';

    String type;
    double amount;

    if (rawType == 'credit_sale') {
      type   = 'credit_sale';
      amount = debit > 0 ? debit : parseDouble(json['pendingAmount'] ?? json['grandTotal']);
    } else if (rawType == 'opening_balance' || description.toLowerCase().contains('opening balance')) {
      type   = 'opening_balance';
      amount = debit;
    } else if (rawType == 'payment' || (rawType.isEmpty && credit > 0)) {
      type   = 'payment';
      amount = credit;
    } else {
      // delivery (or any other debit)
      type   = 'delivery';
      amount = debit;
    }

    return StatementTransaction(
      date: json['date'] != null ? (DateTime.tryParse(json['date'].toString())?.toLocal() ?? DateTime.now()) : DateTime.now(),
      type: type,
      description: description,
      amount: amount,
      balance: parseDouble(json['balance']),
      items: (json['items'] as List?)?.map((i) => StatementItem.fromJson(i as Map<String, dynamic>)).toList() ?? [],
      grandTotal: parseDouble(json['grandTotal'] ?? json['totalAmount']),
      paymentReceived: parseDouble(json['paymentReceived']),
      pendingAmount: parseDouble(json['pendingAmount']),
    );
  }
}

class StatementSummary {
  final double totalDeliveries;
  final double totalPayments;
  final double pendingBalance;

  StatementSummary({
    required this.totalDeliveries,
    required this.totalPayments,
    required this.pendingBalance,
  });

  factory StatementSummary.fromJson(Map<String, dynamic> json) {
    return StatementSummary(
      totalDeliveries: (json['totalDeliveries'] is num) ? (json['totalDeliveries'] as num).toDouble() : double.tryParse(json['totalDeliveries']?.toString() ?? '0') ?? 0.0,
      totalPayments: (json['totalPayments'] is num) ? (json['totalPayments'] as num).toDouble() : double.tryParse(json['totalPayments']?.toString() ?? '0') ?? 0.0,
      pendingBalance: (json['pendingBalance'] is num) ? (json['pendingBalance'] as num).toDouble() : double.tryParse(json['pendingBalance']?.toString() ?? '0') ?? 0.0,
    );
  }
}

class CustomerStatementInfo {
  final String name;
  final String phone;
  final double openingBalance;

  CustomerStatementInfo({
    required this.name,
    required this.phone,
    required this.openingBalance,
  });

  factory CustomerStatementInfo.fromJson(Map<String, dynamic> json) {
    return CustomerStatementInfo(
      name: json['name']?.toString() ?? '',
      phone: json['phone']?.toString() ?? '',
      openingBalance: (json['openingBalance'] is num) ? (json['openingBalance'] as num).toDouble() : double.tryParse(json['openingBalance']?.toString() ?? '0') ?? 0.0,
    );
  }
}

class StatementPeriod {
  final DateTime? startDate;
  final DateTime? endDate;

  StatementPeriod({this.startDate, this.endDate});

  factory StatementPeriod.fromJson(Map<String, dynamic> json) {
    return StatementPeriod(
      startDate: json['startDate'] != null ? DateTime.tryParse(json['startDate'].toString())?.toLocal() : null,
      endDate: json['endDate'] != null ? DateTime.tryParse(json['endDate'].toString())?.toLocal() : null,
    );
  }
}

class CustomerStatementModel {
  final CustomerStatementInfo customer;
  final StatementPeriod period;
  final List<StatementTransaction> transactions;
  final StatementSummary summary;

  CustomerStatementModel({
    required this.customer,
    required this.period,
    required this.transactions,
    required this.summary,
  });

  factory CustomerStatementModel.fromJson(Map<String, dynamic> json) {
    final transactions = (json['transactions'] as List?)
            ?.map((t) => StatementTransaction.fromJson(t as Map<String, dynamic>))
            .toList() ??
        [];

    double totalDeliveries = 0.0;
    double totalPayments = 0.0;

    for (var tx in transactions) {
      if (tx.type == 'delivery' || tx.type == 'credit_sale') {
        totalDeliveries += tx.amount;
      } else if (tx.type == 'payment') {
        totalPayments += tx.amount;
      }
    }

    double pendingBalance = (json['summary']?['pendingBalance'] is num)
        ? (json['summary']['pendingBalance'] as num).toDouble()
        : double.tryParse(json['summary']?['pendingBalance']?.toString() ?? '0') ?? 0.0;

    return CustomerStatementModel(
      customer: CustomerStatementInfo.fromJson(json['customer'] as Map<String, dynamic>? ?? {}),
      period: StatementPeriod.fromJson(json['period'] as Map<String, dynamic>? ?? {}),
      transactions: transactions,
      summary: StatementSummary(
        totalDeliveries: totalDeliveries,
        totalPayments: totalPayments,
        pendingBalance: pendingBalance,
      ),
    );
  }
}
