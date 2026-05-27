class PendingCustomer {
  final String id;
  final String name;
  final double balance;

  PendingCustomer({required this.id, required this.name, required this.balance});

  static double _asDouble(dynamic value, {double fallback = 0.0}) {
    if (value == null) return fallback;
    if (value is num) return value.toDouble();
    if (value is String) {
      final v = value.trim();
      if (v.isEmpty) return fallback;
      return double.tryParse(v) ?? fallback;
    }
    return fallback;
  }

  factory PendingCustomer.fromJson(Map<String, dynamic> json) {
    return PendingCustomer(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      balance: _asDouble(json['balance']),
    );
  }
}

class SupplierDueAlert {
  final String purchaseId;
  final String supplierId;
  final String supplierName;
  final String itemName;
  final double totalAmount;
  final double amountDue;
  final String dueDate;
  final String date;

  SupplierDueAlert({
    required this.purchaseId,
    required this.supplierId,
    required this.supplierName,
    required this.itemName,
    required this.totalAmount,
    required this.amountDue,
    required this.dueDate,
    required this.date,
  });

  factory SupplierDueAlert.fromJson(Map<String, dynamic> json) {
    double asDouble(dynamic value, {double fallback = 0.0}) {
      if (value == null) return fallback;
      if (value is num) return value.toDouble();
      if (value is String) return double.tryParse(value.trim()) ?? fallback;
      return fallback;
    }
    return SupplierDueAlert(
      purchaseId: json['purchaseId']?.toString() ?? json['_id']?.toString() ?? '',
      supplierId: json['supplierId']?.toString() ?? '',
      supplierName: json['supplierName']?.toString() ?? '',
      itemName: json['itemName']?.toString() ?? json['item']?.toString() ?? '',
      totalAmount: asDouble(json['totalAmount'] ?? json['amount']),
      amountDue: asDouble(json['amountDue'] ?? json['amount']),
      dueDate: json['dueDate']?.toString() ?? '',
      date: json['date']?.toString() ?? '',
    );
  }
}

class DashboardStatsModel {
  final int totalCustomers;
  final int todayOrders;
  final double todayRevenue;
  final double totalDeliveredAmount;
  final double pendingPaymentsAmount;
  final int pendingPaymentsCount;
  final double advancePaymentsAmount;
  final double labourPendingSalary;
  final double labourPaidSalary;
  final double labourEarnedSalary;
  final List<PendingCustomer> mostPendingCustomers;
  final List<double> monthlyRevenue;
  final double supplierPending;
  final double supplierAdvance;
  final List<SupplierDueAlert> supplierUpcomingDue;
  final List<SupplierDueAlert> supplierOverdue;

  DashboardStatsModel({
    required this.totalCustomers,
    required this.todayOrders,
    required this.todayRevenue,
    required this.totalDeliveredAmount,
    required this.pendingPaymentsAmount,
    required this.pendingPaymentsCount,
    required this.advancePaymentsAmount,
    required this.labourPendingSalary,
    required this.labourPaidSalary,
    required this.labourEarnedSalary,
    required this.mostPendingCustomers,
    required this.monthlyRevenue,
    required this.supplierPending,
    required this.supplierAdvance,
    required this.supplierUpcomingDue,
    required this.supplierOverdue,
  });

  factory DashboardStatsModel.fromJson(Map<String, dynamic> json) {
    int asInt(dynamic value, {int fallback = 0}) {
      if (value == null) return fallback;
      if (value is int) return value;
      if (value is num) return value.toInt();
      if (value is String) return int.tryParse(value.trim()) ?? fallback;
      return fallback;
    }

    double asDouble(dynamic value, {double fallback = 0.0}) {
      if (value == null) return fallback;
      if (value is num) return value.toDouble();
      if (value is String) {
        final v = value.trim();
        if (v.isEmpty) return fallback;
        return double.tryParse(v) ?? fallback;
      }
      return fallback;
    }

    final pendingCustomers = (json['mostPendingCustomers'] is List)
        ? (json['mostPendingCustomers'] as List)
            .whereType<Map>()
            .map((e) => PendingCustomer.fromJson(
                Map<String, dynamic>.from(e as Map)))
            .toList()
        : <PendingCustomer>[];

    final rev = (json['monthlyRevenue'] is List)
        ? (json['monthlyRevenue'] as List)
            .map((e) => asDouble(e))
            .toList()
        : List.filled(12, 0.0);

    final supplierMap = json['supplier'] is Map ? json['supplier'] as Map : {};
    final sPending = asDouble(supplierMap['totalPending']);
    final sAdvance = asDouble(supplierMap['totalAdvance']);

    List<SupplierDueAlert> parseAlertList(dynamic listData) {
      if (listData is List) {
        return listData
            .map((e) => SupplierDueAlert.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
      }
      return [];
    }

    final upcoming = supplierMap['upcomingDue'] is Map
        ? parseAlertList((supplierMap['upcomingDue'] as Map)['list'])
        : <SupplierDueAlert>[];

    final overdueList = supplierMap['overdue'] is Map
        ? parseAlertList((supplierMap['overdue'] as Map)['list'])
        : <SupplierDueAlert>[];

    return DashboardStatsModel(
      totalCustomers: asInt(json['totalCustomers']),
      todayOrders: asInt(json['todayOrders']),
      todayRevenue: asDouble(json['todayRevenue']),
      totalDeliveredAmount: asDouble(json['totalDeliveredAmount']),
      pendingPaymentsAmount: asDouble(
          (json['pendingPayments'] is Map) ? (json['pendingPayments'] as Map)['totalAmount'] : null),
      pendingPaymentsCount: asInt(
          (json['pendingPayments'] is Map) ? (json['pendingPayments'] as Map)['count'] : null),
      advancePaymentsAmount: asDouble(
          (json['advancePayments'] is Map) ? (json['advancePayments'] as Map)['totalAmount'] : null),
      labourPendingSalary: asDouble(
          (json['labour'] is Map) ? (json['labour'] as Map)['totalPendingSalary'] : null),
      labourPaidSalary: asDouble(
          (json['labour'] is Map) ? (json['labour'] as Map)['totalPaidSalary'] : null),
      labourEarnedSalary: asDouble(
          (json['labour'] is Map) ? (json['labour'] as Map)['totalEarnedSalary'] : null),
      mostPendingCustomers: pendingCustomers,
      monthlyRevenue: rev,
      supplierPending: sPending,
      supplierAdvance: sAdvance,
      supplierUpcomingDue: upcoming,
      supplierOverdue: overdueList,
    );
  }

  factory DashboardStatsModel.empty() {
    return DashboardStatsModel(
      totalCustomers: 0,
      todayOrders: 0,
      todayRevenue: 0,
      totalDeliveredAmount: 0,
      pendingPaymentsAmount: 0,
      pendingPaymentsCount: 0,
      advancePaymentsAmount: 0,
      labourPendingSalary: 0,
      labourPaidSalary: 0,
      labourEarnedSalary: 0,
      mostPendingCustomers: [],
      monthlyRevenue: List.filled(12, 0.0),
      supplierPending: 0,
      supplierAdvance: 0,
      supplierUpcomingDue: [],
      supplierOverdue: [],
    );
  }
}
