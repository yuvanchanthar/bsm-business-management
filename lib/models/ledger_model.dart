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
    double? resolve(List<String> keys) {
      for (final k in keys) {
        if (json.containsKey(k)) {
          final v = json[k];
          final parsed = _asDouble(v, fallback: double.nan);
          if (!parsed.isNaN) return parsed;
        }
      }
      return null;
    }

    final txns = (json['transactions'] as List?)
            ?.map((t) => LedgerEntry.fromJson(t as Map<String, dynamic>))
            .toList() ??
        [];

    double calcDelivered = 0.0;
    double calcPaid = 0.0;
    for (var t in txns) {
  if (t.type == LedgerEntryType.delivery ||
      t.type == LedgerEntryType.creditSale) {
    calcDelivered += t.amount;
  }

  if (t.type == LedgerEntryType.payment) {
    calcPaid += t.amount;
  }
}
    final customer = CustomerModel.fromJson(
        json['customer'] as Map<String, dynamic>? ?? {});

    double? backendDelivered = resolve(['delivered', 'totalDelivered']);
    double? backendPaid = resolve(['paid', 'totalPaid']);
    double? backendBalance = resolve(['balance', 'finalBalance']);

    final double finalDelivered = backendDelivered ?? calcDelivered;
    final double finalPaid = backendPaid ?? calcPaid;
    final double calculatedBalance = customer.openingBalance + finalDelivered - finalPaid;
    final double finalBalance = backendBalance ?? calculatedBalance;

    return CustomerLedgerModel(
      customer: customer,
      transactions: txns,
      totalDelivered: finalDelivered,
      totalPaid: finalPaid,
      finalBalance: finalBalance,
    );
  }
}

enum LedgerEntryType { delivery, payment, openingBalance, creditSale }

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

    // Resolve type explicitly — no silent fallback to payment for unknown types.
    final rawType = json['type']?.toString();

late final LedgerEntryType resolvedType;

switch (rawType) {
  case 'opening_balance':
    resolvedType = LedgerEntryType.openingBalance;
    break;

  case 'delivery':
    resolvedType = LedgerEntryType.delivery;
    break;

  case 'credit_sale':
    resolvedType = LedgerEntryType.creditSale;
    break;

  case 'payment':
    resolvedType = LedgerEntryType.payment;
    break;

  default:
    resolvedType = LedgerEntryType.payment;
    break;
}

    return LedgerEntry(
      date: json['date'] != null
          ? DateTime.tryParse(json['date'].toString()) ?? DateTime.now()
          : DateTime.now(),
      type: resolvedType,
      // Backend sends the label in 'note'; 'description' kept as legacy fallback.
      description: json['note']?.toString() ?? json['description']?.toString() ?? '',
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
