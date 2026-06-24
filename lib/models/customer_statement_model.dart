class StatementItem {
  final String name;
  final double quantity;
  final double? price;

  StatementItem({required this.name, required this.quantity, this.price});

  factory StatementItem.fromJson(Map<String, dynamic> json) {
    return StatementItem(
      name: json['itemName']?.toString() ?? json['name']?.toString() ?? json['item']?.toString() ?? '',
      quantity: (json['quantity'] is num) ? (json['quantity'] as num).toDouble() : double.tryParse(json['qty']?.toString() ?? '0') ?? 0.0,
      price: (json['price'] is num) ? (json['price'] as num).toDouble() : (json['unitPrice'] is num) ? (json['unitPrice'] as num).toDouble() : double.tryParse(json['price']?.toString() ?? ''),
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

  StatementTransaction({
    required this.date,
    required this.type,
    required this.description,
    required this.amount,
    required this.balance,
    this.items = const [],
  });

  factory StatementTransaction.fromJson(Map<String, dynamic> json) {
    double debit = (json['debit'] is num) ? (json['debit'] as num).toDouble() : double.tryParse(json['debit']?.toString() ?? '0') ?? 0.0;
    double credit = (json['credit'] is num) ? (json['credit'] as num).toDouble() : double.tryParse(json['credit']?.toString() ?? '0') ?? 0.0;
    String description = json['description']?.toString() ?? '';
    
    String type = '';
    double amount = 0.0;

    if (description.toLowerCase().contains('opening balance')) {
      type = 'opening_balance';
      amount = debit;
    } else if (debit > 0) {
      type = 'delivery';
      amount = debit;
    } else if (credit > 0) {
      type = 'payment';
      amount = credit;
    }

    return StatementTransaction(
      date: json['date'] != null ? DateTime.tryParse(json['date'].toString()) ?? DateTime.now() : DateTime.now(),
      type: type,
      description: description,
      amount: amount,
      balance: (json['balance'] is num) ? (json['balance'] as num).toDouble() : double.tryParse(json['balance']?.toString() ?? '0') ?? 0.0,
      items: (json['items'] as List?)?.map((i) => StatementItem.fromJson(i as Map<String, dynamic>)).toList() ?? [],
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
      startDate: json['startDate'] != null ? DateTime.tryParse(json['startDate'].toString()) : null,
      endDate: json['endDate'] != null ? DateTime.tryParse(json['endDate'].toString()) : null,
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
      if (tx.type == 'delivery') {
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
