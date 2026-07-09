import 'package:intl/intl.dart';
import 'delivery.dart';

class InvoiceModel {
  final String id;
  final String invoiceNumber;
  final String customerId;
  final String deliveryId;
  final String type; // "original" | "updated"
  final String templateId;
  final String customerName;
  final String customerPhone;
  final String? gstNumber;
  final String? companyName;
  final String? address;
  final String? vehicleNumber;
  final List<Map<String, dynamic>> customFields;
  final List<ProductItem> products;
  final List<ProductItem> items;
  final double totalAmount;
  final double previousBalance;
  final double finalAmount;
  final DateTime createdAt;

  InvoiceModel({
    required this.id,
    required this.invoiceNumber,
    required this.customerId,
    required this.deliveryId,
    required this.type,
    this.templateId = 'classic',
    required this.customerName,
    required this.customerPhone,
    this.gstNumber,
    this.companyName,
    this.address,
    this.vehicleNumber,
    this.customFields = const [],
    required this.products,
    this.items = const [],
    required this.totalAmount,
    required this.previousBalance,
    required this.finalAmount,
    required this.createdAt,
  });

  bool get isUpdated => type == 'updated';

  String get formattedDate => DateFormat('dd MMM yyyy').format(createdAt);
  String get formattedTime => DateFormat('hh:mm a').format(createdAt);
  String get formattedDateTime =>
      DateFormat('dd MMM yyyy, hh:mm a').format(createdAt);

  factory InvoiceModel.fromJson(Map<String, dynamic> json) {
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

    final rawProducts = json['products'] as List? ?? [];
    final rawItems = json['items'] as List? ?? [];

    final products = rawProducts
        .map((p) => ProductItem.fromJson(p as Map<String, dynamic>))
        .toList();
    final items = rawItems
        .map((p) => ProductItem.fromJson(p as Map<String, dynamic>))
        .toList();

    // Fallback: if stored finalAmount is 0, derive from items/products
    final storedFinalAmount =
        asDouble(json['finalAmount']);
    final storedTotalAmount =
        asDouble(json['totalAmount']);

    // Sum raw 'total' field from items array (backend may store it)
    double sumRawList(List raw) => raw.fold<double>(
          0.0,
          (s, e) =>
              s +
              asDouble((e is Map) ? (e as Map)['total'] : null),
        );

    final itemsSum = sumRawList(rawItems);
    final productsSum = sumRawList(rawProducts);

    double resolvedFinalAmount = storedFinalAmount;
    if (resolvedFinalAmount <= 0) {
      // try totalAmount field first
      if (storedTotalAmount > 0) {
        resolvedFinalAmount = storedTotalAmount;
      } else if (itemsSum > 0) {
        resolvedFinalAmount = itemsSum;
      } else if (productsSum > 0) {
        resolvedFinalAmount = productsSum;
      }
    }

    double resolvedTotalAmount =
        storedTotalAmount > 0 ? storedTotalAmount : resolvedFinalAmount;

    return InvoiceModel(
      id: json['_id']?.toString() ?? '',
      invoiceNumber: json['invoiceNumber'] ?? '',
      customerId: json['customerId']?.toString() ?? '',
      deliveryId: json['deliveryId']?.toString() ?? '',
      type: json['type'] ?? 'original',
      templateId: json['templateId']?.toString() ?? 'classic',
      customerName: json['customerName'] ?? '',
      customerPhone: json['customerPhone'] ?? '',
      gstNumber: json['gstNumber']?.toString(),
      companyName: json['companyName']?.toString(),
      address: json['address']?.toString(),
      vehicleNumber: json['vehicleNumber']?.toString(),
      customFields: _parseCustomFields(json['customFields']),
      products: products,
      items: items,
      totalAmount: resolvedTotalAmount,
      previousBalance: asDouble(json['previousBalance']),
      finalAmount: resolvedFinalAmount,
      createdAt: json['createdAt'] != null
          ? (DateTime.tryParse(json['createdAt'])?.toLocal() ?? DateTime.now())
          : DateTime.now(),
    );
  }

  static List<Map<String, dynamic>> _parseCustomFields(dynamic rawData) {
    if (rawData == null) return [];
    if (rawData is List) {
      return List<Map<String, dynamic>>.from(
          rawData.map((e) => Map<String, dynamic>.from(e as Map)));
    }
    if (rawData is Map) {
      final List<Map<String, dynamic>> converted = [];
      rawData.forEach((key, value) {
        converted.add({'label': key.toString(), 'value': value.toString()});
      });
      return converted;
    }
    return [];
  }

  Map<String, dynamic> toJson() => {
        'invoiceNumber': invoiceNumber,
        'customerId': customerId,
        'deliveryId': deliveryId,
        'type': type,
        'templateId': templateId,
        'customerName': customerName,
        'customerPhone': customerPhone,
        'gstNumber': gstNumber,
        'companyName': companyName,
        'address': address,
        'vehicleNumber': vehicleNumber,
        'customFields': customFields,
        'items': items.isNotEmpty ? items.map((p) => p.toJson()).toList() : products.map((p) => {
          'product': p.name,
          'qty': p.quantity,
          'price': p.pricePerUnit,
          'total': p.totalAmount,
        }).toList(),
        'products': products.map((p) => p.toJson()).toList(),
        'totalAmount': totalAmount,
        'previousBalance': previousBalance,
        'finalAmount': finalAmount,
        'createdAt': createdAt.toIso8601String(),
      };

  /// Builds a temporary InvoiceModel from a Delivery for client-side PDF preview.
  static InvoiceModel fromDelivery(Delivery delivery, String type) {
    return InvoiceModel(
      id: delivery.invoice?.id ?? 'TEMP_${delivery.id}',
      invoiceNumber: delivery.invoice?.invoiceNumber ?? 'INV-${DateTime.now().millisecondsSinceEpoch}',
      customerId: delivery.customerId ?? '',
      deliveryId: delivery.id,
      type: type,
      templateId: delivery.invoice?.templateId ?? 'classic',
      customerName: delivery.customerName,
      customerPhone: delivery.customerPhone ?? '',
      gstNumber: delivery.invoice?.gstNumber,
      companyName: delivery.invoice?.companyName,
      address: delivery.invoice?.address,
      vehicleNumber: delivery.vehicleNumber,
      customFields: delivery.invoice?.customFields ?? [],
      products: delivery.products,
      items: delivery.items,
      totalAmount: delivery.deliveryTotal > 0
          ? delivery.deliveryTotal
          : delivery.grandTotal,
      previousBalance: delivery.previousBalance,
      finalAmount: delivery.updatedBalance,
      createdAt: DateTime.now(),
    );
  }

  /// Converts this InvoiceModel back into a temporary Delivery snapshot 
  /// for use with the new InvoiceGeneratorService templates.
  Delivery toDelivery() {
    return Delivery(
      id: deliveryId,
      customerId: customerId,
      customerName: customerName,
      customerPhone: customerPhone,
      previousBalance: previousBalance,
      updatedBalance: finalAmount,
      deliveryTotal: totalAmount,
      // products: products,
      // items: items,
      products: products.isNotEmpty ? products : items,
      items: items.isNotEmpty ? items : products,
      crewLeader: 'SYSTEM',
      priority: 'NORMAL',
      status: 'DELIVERED',
      timestamp: createdAt,
      invoice: DeliveryInvoice(
        id: id,
        invoiceNumber: invoiceNumber,
        amount: finalAmount,
        customerName: customerName,
        customerPhone: customerPhone,
        gstNumber: gstNumber,
        companyName: companyName,
        address: address,
        customFields: customFields,
        templateId: templateId,
        vehicleNumber: vehicleNumber,
      ),
      vehicleNumber: vehicleNumber,
    );
  }
}
