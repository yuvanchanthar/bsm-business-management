import 'customer_model.dart';

double _asDouble(dynamic value, {double fallback = 0.0}) {
  if (value == null) return fallback;
  if (value is num) return value.toDouble();
  if (value is String) {
    final v = value.trim();
    if (v.isEmpty) return fallback;
    return double.tryParse(v) ?? fallback;
  }
  return fallback;
}

class CustomerLedgerModel {
  final CustomerModel customer;
  final List<LedgerEntry> transactions;
  final double totalDelivered;
  final double totalPaid;
  final double finalBalance;

  CustomerLedgerModel({
    required this.customer,
    required this.transactions,
    required this.totalDelivered,
    required this.totalPaid,
    required this.finalBalance,
  });

  factory CustomerLedgerModel.fromJson(Map<String, dynamic> json) {
    // Backend sends: delivered, paid, balance
    // Fallback to old keys (totalDelivered, totalPaid, finalBalance) for
    // backward compatibility with any cached or legacy responses.
    double resolve(List<String> keys) {
      for (final k in keys) {
        final v = json[k];
        final parsed = _asDouble(v, fallback: double.nan);
        if (!parsed.isNaN) return parsed;
      }
      return 0.0;
    }

    final txns = (json['transactions'] as List?)
            ?.map((t) => LedgerEntry.fromJson(t as Map<String, dynamic>))
            .toList() ??
        [];

    double calcDelivered = 0.0;
    double calcPaid = 0.0;
    for (var t in txns) {
      if (t.type == LedgerEntryType.delivery) calcDelivered += t.amount;
      if (t.type == LedgerEntryType.payment) calcPaid += t.amount;
    }

    double backendDelivered = resolve(['delivered', 'totalDelivered']);
    double backendPaid = resolve(['paid', 'totalPaid']);
    double backendBalance = resolve(['balance', 'finalBalance']);

    return CustomerLedgerModel(
      customer: CustomerModel.fromJson(
          json['customer'] as Map<String, dynamic>? ?? {}),
      transactions: txns,
      totalDelivered: backendDelivered > 0 ? backendDelivered : calcDelivered,
      totalPaid: backendPaid > 0 ? backendPaid : calcPaid,
      finalBalance: backendBalance != 0 ? backendBalance : (calcDelivered - calcPaid),
    );
  }
}

enum LedgerEntryType { delivery, payment }

class LedgerEntry {
  final DateTime date;
  final LedgerEntryType type;
  final String description;
  final double amount;
  final String? id;
  final String? deliveryId;
  final String? invoiceId;
  final String? templateId;

  LedgerEntry({
    required this.date,
    required this.type,
    required this.description,
    required this.amount,
    this.id,
    this.deliveryId,
    this.invoiceId,
    this.templateId,
  });

  factory LedgerEntry.fromJson(Map<String, dynamic> json) {
    // Backend now returns deliveryId, invoiceId, templateId directly in the ledger entry object.
    // We map these directly to ensure they survive end-to-end.
    final String? deliveryId = json['deliveryId']?.toString();
    final String? invoiceId = json['invoiceId']?.toString();
    final String? templateId = json['templateId']?.toString();
    final String? id = (json['_id'] ?? json['id'])?.toString();

    print('--------------------------------------------------');
    print('[LedgerEntry.fromJson] DEBUG LOG');
    print('TYPE: ${json['type']}');
    print('DELIVERY_ID: $deliveryId');
    print('INVOICE_ID: $invoiceId');
    print('TEMPLATE_ID: $templateId');
    print('TXN_ID: $id');
    print('RAW_JSON: $json');
    print('--------------------------------------------------');

    return LedgerEntry(
      date: json['date'] != null 
          ? DateTime.tryParse(json['date']) ?? DateTime.now() 
          : DateTime.now(),
      type: json['type'] == 'delivery' 
          ? LedgerEntryType.delivery 
          : LedgerEntryType.payment,
      description: json['description'] ?? '',
      amount: _asDouble(
        json['amount'] ??
            json['total'] ??
            json['deliveryTotal'] ??
            json['grandTotal'] ??
            json['totalAmount'] ??
            json['finalAmount'] ??
            json['invoiceAmount'],
      ),
      id: id,
      deliveryId: deliveryId,
      invoiceId: invoiceId,
      templateId: templateId,
    );
  }
}
