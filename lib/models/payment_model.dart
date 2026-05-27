// ─────────────────────────────────────────────────────────────────────────────
// payment_model.dart
//
// Models for labour payments and salary reporting.
// Key design rule: always try multiple field names from the backend to handle
// any naming variation (e.g. "pendingBalance" vs "balance", "earned" vs
// "totalEarned") without crashing.
// ─────────────────────────────────────────────────────────────────────────────

/// Helper: safely read a numeric field from JSON, trying multiple key names.
double _num(Map<String, dynamic> json, List<String> keys) {
  for (final k in keys) {
    final v = json[k];
    if (v != null) {
      if (v is num) return v.toDouble();
      if (v is String) return double.tryParse(v) ?? 0.0;
    }
  }
  return 0.0;
}

// ── PaymentModel ──────────────────────────────────────────────────────────────

class PaymentModel {
  final String? id;
  final String? labourId;
  final String? customerId;
  final String name;
  final double amount;
  final DateTime date;
  final String? note;
  final DateTime? createdAt;

  PaymentModel({
    this.id,
    this.labourId,
    this.customerId,
    required this.name,
    required this.amount,
    required this.date,
    this.note,
    this.createdAt,
  });

  factory PaymentModel.fromJson(Map<String, dynamic> json) {
    return PaymentModel(
      id: json['_id']?.toString(),
      labourId: json['labourId']?.toString(),
      customerId: json['customerId']?.toString(),
      name: json['name'] ?? '',
      amount: _num(json, ['amount']),
      date: json['date'] != null
          ? DateTime.tryParse(json['date'].toString()) ?? DateTime.now()
          : DateTime.now(),
      note: json['note']?.toString(),
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (labourId != null) 'labourId': labourId,
      if (customerId != null) 'customerId': customerId,
      'name': name,
      'amount': amount,
      'date':
          '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}',
      if (note != null && note!.isNotEmpty) 'note': note,
    };
  }
}

// ── LabourSalaryReport (summary list item) ────────────────────────────────────
// Populated from: GET /api/labours/report
// Backend shape: { "report": [ { labourId, name, role, dailyWage, daysWorked,
//                                totalEarned, totalPaid, pendingBalance } ],
//                  "totals": { ... } }

class LabourSalaryReport {
  final String labourId;
  final String name;
  final String role;
  final double dailyWage;
  final double daysWorked;      // ← new field
  final double totalEarned;
  final double totalPaid;
  final double balance;      // mapped from "pendingBalance" OR "balance"

  LabourSalaryReport({
    required this.labourId,
    required this.name,
    required this.role,
    required this.dailyWage,
    required this.daysWorked,
    required this.totalEarned,
    required this.totalPaid,
    required this.balance,
  });

  factory LabourSalaryReport.fromJson(Map<String, dynamic> json) {
    // Log every parsed entry so we can spot mismatches in the console.
    // ignore: avoid_print
    print('[LabourSalaryReport] parsing: $json');

    return LabourSalaryReport(
      labourId: json['labourId']?.toString() ?? json['_id']?.toString() ?? '',
      name: json['name'] ?? '',
      role: json['role'] ?? '',
      // dailyWage may be nested under the labour master object
      dailyWage: _num(json, ['dailyWage', 'daily_wage', 'wage']),
      // daysWorked
      daysWorked: ((json['daysWorked'] ?? json['days_worked']) as num?)?.toDouble() ?? 0.0,
      // Backend may name this field differently
      totalEarned: _num(json, ['totalEarned', 'earned', 'total_earned']),
      totalPaid:   _num(json, ['totalPaid',   'paid',   'total_paid']),
      // ⚠️ CRITICAL: backend sends "pendingBalance", Flutter previously read
      // "balance" which was always null → 0. Try both names.
      balance:     _num(json, ['pendingBalance', 'balance', 'pending_balance',
                                'remainingBalance']),
    );
  }
}

// ── LabourDetailReport (single labour detail view) ────────────────────────────
// Populated from: GET /api/labours/report?labourId=<id>
// AND:            GET /api/labour-payments/:labourId  (payments history)

class LabourDetailReport {
  final String labourId;
  final String name;
  final String role;
  final String phone;
  final double dailyWage;
  final double daysWorked;
  final double totalEarned;
  final double totalPaid;
  final double balance;
  final List<PaymentModel> payments;
  final List<AttendanceRecord> attendance;

  LabourDetailReport({
    required this.labourId,
    required this.name,
    required this.role,
    required this.phone,
    required this.dailyWage,
    required this.daysWorked,
    required this.totalEarned,
    required this.totalPaid,
    required this.balance,
    required this.payments,
    required this.attendance,
  });

  factory LabourDetailReport.fromJson(Map<String, dynamic> json) {
    // ignore: avoid_print
    print('[LabourDetailReport] RAW JSON:');
    print(json);
    print('[LabourDetailReport] parsing summary fields: '
        'earned=${json['totalEarned'] ?? json['earned']} '
        'paid=${json['totalPaid'] ?? json['paid']} '
        'balance=${json['pendingBalance'] ?? json['balance']} '
        'dailyWage=${json['dailyWage'] ?? json['wage'] ?? json['daily_wage']} '
        'role=${json['role']}');

    final parsedDailyWage = _num(json, ['dailyWage', 'daily_wage', 'wage']);
    // ignore: avoid_print
    print('PARSED DAILYWAGE: $parsedDailyWage');

    return LabourDetailReport(
      labourId: json['labourId']?.toString() ?? json['_id']?.toString() ?? '',
      name:     json['name']  ?? '',
      role:     json['role']?.toString()  ?? '',
      phone:    json['phone']?.toString() ?? '',
      dailyWage:   parsedDailyWage,
      daysWorked:  ((json['daysWorked'] ?? json['days_worked']) as num?)?.toDouble() ?? 0.0,
      totalEarned: _num(json, ['totalEarned', 'earned', 'total_earned']),
      totalPaid:   _num(json, ['totalPaid',   'paid',   'total_paid']),
      // ⚠️ CRITICAL: try pendingBalance first
      balance:     _num(json, ['pendingBalance', 'balance', 'pending_balance',
                                'remainingBalance']),
      // Payments and attendance may come from this JSON directly, or may be
      // injected separately by ApiService.getLabourDetailReport().
      payments: (json['payments'] as List<dynamic>? ?? [])
          .map((p) => PaymentModel.fromJson(p as Map<String, dynamic>))
          .toList(),
      attendance: (json['attendance'] as List<dynamic>? ?? [])
          .map((a) => AttendanceRecord.fromJson(a as Map<String, dynamic>))
          .toList(),
    );
  }

  /// Creates a copy with overridden payments & attendance lists.
  /// Used by ApiService when fetching payment history separately.
  LabourDetailReport copyWith({
    List<PaymentModel>? payments,
    List<AttendanceRecord>? attendance,
  }) {
    return LabourDetailReport(
      labourId:    labourId,
      name:        name,
      role:        role,
      phone:       phone,
      dailyWage:   dailyWage,
      daysWorked:  daysWorked,
      totalEarned: totalEarned,
      totalPaid:   totalPaid,
      balance:     balance,
      payments:    payments    ?? this.payments,
      attendance:  attendance  ?? this.attendance,
    );
  }
}

// ── AttendanceRecord (per-day row inside LabourDetailReport) ──────────────────

class AttendanceRecord {
  final String id;
  final String date;
  final String status;   // "full_day" | "half_day" | "absent"
  final double wage;     // earned for that day (0 if absent)

  AttendanceRecord({
    this.id = '',
    required this.date,
    required this.status,
    required this.wage,
  });

  factory AttendanceRecord.fromJson(Map<String, dynamic> json) {
    String parsedStatus = json['status']?.toString() ?? 'absent';
    if (parsedStatus == 'present') {
      parsedStatus = 'full_day';
    }

    return AttendanceRecord(
      id:     json['_id']?.toString() ?? '',
      date:   json['date']?.toString()   ?? '',
      status: parsedStatus,
      wage:   _num(json, ['wage', 'dailyWage', 'amount']),
    );
  }
}
