import 'package:intl/intl.dart';

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

// ── DeliveryInvoice ───────────────────────────────────────────────────────────
// Lightweight invoice snapshot embedded inside a Delivery from GET /delivery.
// Not the same as InvoiceModel (which is a full invoice for PDF generation).
class DeliveryInvoice {
  final String id;
  final String? invoiceNumber;
  final double amount;
  final String? pdfUrl;
  
  final String? customerName;
  final String? customerPhone;
  final String? gstNumber;
  final String? companyName;
  final String? address;
  final String? templateId;
  final List<Map<String, dynamic>> customFields;
  final String? vehicleNumber;

  const DeliveryInvoice({
    required this.id,
    this.invoiceNumber,
    required this.amount,
    this.pdfUrl,
    this.customerName,
    this.customerPhone,
    this.gstNumber,
    this.companyName,
    this.address,
    this.templateId,
    this.customFields = const [],
    this.vehicleNumber,
  });

  factory DeliveryInvoice.fromJson(Map<String, dynamic> json) {
    return DeliveryInvoice(
      id: json['_id']?.toString() ?? '',
      invoiceNumber: json['invoiceNumber']?.toString(),
      amount: _asDouble(json['amount']),
      pdfUrl: json['pdfUrl']?.toString(),
      customerName: json['customerName']?.toString(),
      customerPhone: json['customerPhone']?.toString(),
      gstNumber: json['gstNumber']?.toString(),
      companyName: json['companyName']?.toString(),
      address: json['address']?.toString(),
      templateId: json['templateId']?.toString(),
      customFields: _parseCustomFields(json['customFields']),
      vehicleNumber: json['vehicleNumber']?.toString(),
    );
  }

  static List<Map<String, dynamic>> _parseCustomFields(dynamic rawData) {
    if (rawData == null) return [];
    if (rawData is List) {
      return List<Map<String, dynamic>>.from(
          rawData.map((e) => Map<String, dynamic>.from(e as Map)));
    }
    if (rawData is Map) {
      // Legacy backward compatibility
      final List<Map<String, dynamic>> converted = [];
      rawData.forEach((key, value) {
        converted.add({'label': key.toString(), 'value': value.toString()});
      });
      return converted;
    }
    return [];
  }

  DeliveryInvoice copyWith({
    String? id,
    String? invoiceNumber,
    double? amount,
    String? pdfUrl,
    String? customerName,
    String? customerPhone,
    String? gstNumber,
    String? companyName,
    String? address,
    String? templateId,
    List<Map<String, dynamic>>? customFields,
    String? vehicleNumber,
  }) {
    return DeliveryInvoice(
      id: id ?? this.id,
      invoiceNumber: invoiceNumber ?? this.invoiceNumber,
      amount: amount ?? this.amount,
      pdfUrl: pdfUrl ?? this.pdfUrl,
      customerName: customerName ?? this.customerName,
      customerPhone: customerPhone ?? this.customerPhone,
      gstNumber: gstNumber ?? this.gstNumber,
      companyName: companyName ?? this.companyName,
      address: address ?? this.address,
      templateId: templateId ?? this.templateId,
      customFields: customFields ?? this.customFields,
      vehicleNumber: vehicleNumber ?? this.vehicleNumber,
    );
  }
}

class ProductItem {
  final String name; // mapped as productType
  final double quantity;
  final String unit;
  final String pricingType; // 'Per KG' or 'Per Bag'
  final double pricePerUnit; // mapped as price
  final double costPerUnit; // mapped as cost

  ProductItem({
    required this.name,
    required this.quantity,
    required this.unit,
    required this.pricingType,
    required this.pricePerUnit,
    this.costPerUnit = 0.0,
  });

  // Aliases required by new PDF logic
  String get product => name;
  double get qty => quantity;
  double get price => pricePerUnit;
  double get cost => costPerUnit;
  double get total => totalAmount;

  double get totalAmount => quantity * pricePerUnit;

  Map<String, dynamic> toJson() => {
        // FIX 2: Send both naming conventions for backward + forward compatibility.
        // Backend accepts 'itemName' (new) and 'product' (legacy) — send both.
        'itemName': name,
        'product': name,

        // Send both 'quantity' (new) and 'qty' (legacy) — backend accepts either.
        'quantity': quantity,
        'qty': quantity,

        'unit': unit,              // inventory deduction unit (KG or Bags) — independent
        'pricingType': pricingType, // pricing mode (Per KG or Per Bag) — independent

        'price': pricePerUnit,
        'cost': costPerUnit,
        'total': totalAmount,
      };

  factory ProductItem.fromJson(Map<String, dynamic> json) {
    return ProductItem(
      name: json['product'] ?? json['productType'] ?? json['itemName'] ?? '',
      quantity: _asDouble(json['qty'] ?? json['quantity']),
      unit: json['unit'] ?? '',
      // FIX 1: Read pricingType directly from backend field.
      // Falls back to unit-derived value for old deliveries that lack pricingType.
      pricingType: json['pricingType']?.toString() ??
          (json['unit'] == 'KG' ? 'Per KG' : 'Per Bag'),
      pricePerUnit: _asDouble(json['price']),
      costPerUnit: _asDouble(json['cost']),
    );
  }
}

class Delivery {
  final String id;
  final String? customerId; 
  final String customerName; // mapped as customer
  final String? customerPhone; 
  final double previousBalance;
  final double updatedBalance;
  final double deliveryTotal;

  final List<ProductItem> products;
  final List<ProductItem> items;
  final String crewLeader;
  final String priority;
  final String status;
  final DateTime timestamp;
  final DeliveryInvoice? invoice;
  final bool stockDeducted;
  final String? vehicleNumber;

  Delivery({
    required this.id,
    this.customerId,
    required this.customerName,
    this.customerPhone,
    this.previousBalance = 0.0,
    this.updatedBalance = 0.0,
    this.deliveryTotal = 0.0,
    required this.products,
    this.items = const [],
    required this.crewLeader,
    required this.priority,
    required this.status,
    required this.timestamp,
    this.invoice,
    this.stockDeducted = false,
    this.vehicleNumber,
  });

  double get totalQuantity => _sourceItems.fold(0.0, (sum, item) => sum + item.quantity);

  /// The single authoritative source list: products takes priority, fallback to items.
  /// This prevents grandTotal = 0 when the backend stores entries under 'items'.
  List<ProductItem> get _sourceItems => products.isNotEmpty ? products : items;

  /// Grand total derived from the same source list used by the payload serializer.
  double get grandTotal => _sourceItems.fold(0.0, (sum, item) => sum + item.totalAmount);

  String get formattedDate => DateFormat('dd MMM yyyy, hh:mm a').format(timestamp);

  static double calculateFinalAmount(double balance, double calculatedDeliveryTotal) {
    return balance + calculatedDeliveryTotal;
  }

  Map<String, dynamic> toJson() {
    // Use unified source so grandTotal == items serialized == what backend sums.
    final src = _sourceItems;
    final computedTotal = src.fold(0.0, (double s, i) => s + i.totalAmount);
    final resolvedTotal = deliveryTotal > 0 ? deliveryTotal : computedTotal;
    final resolvedAmount = (invoice?.amount != null && invoice!.amount > 0)
        ? invoice!.amount
        : resolvedTotal;

    // Temporary debug — verifies payload before every API call.
    print('========== DELIVERY PAYLOAD DEBUG ==========');
    print('[PAYLOAD] products.length : ${products.length}');
    print('[PAYLOAD] items.length    : ${items.length}');
    print('[PAYLOAD] _sourceItems    : ${src.length} items used');
    print('[PAYLOAD] computedTotal   : $computedTotal');
    print('[PAYLOAD] deliveryTotal   : $deliveryTotal');
    print('[PAYLOAD] resolvedTotal   : $resolvedTotal  (grandTotal sent)');
    print('[PAYLOAD] resolvedAmount  : $resolvedAmount');
    // FIX 3: Print serialized items so unit/pricingType can be verified before each save.
    print('========== DELIVERY ITEMS ==========');
    print(src.map((e) => e.toJson()).toList());
    print('====================================');
    print('============================================');

    return {
      'customerId': customerId,
      'customer': customerName,
      'customerPhone': customerPhone,
      'previousBalance': previousBalance,
      'updatedBalance': updatedBalance,
      // All three aliases so the backend can read whichever field it expects.
      'deliveryTotal': resolvedTotal,
      'grandTotal': resolvedTotal,
      'amount': resolvedAmount,
      'crewLeader': crewLeader,
      'priority': priority,
      'status': status,
      'stockDeducted': stockDeducted,
      // Always use unified source — never sends an empty list when items is populated.
      'items': src.map((e) => e.toJson()).toList(),
      'gstNumber': invoice?.gstNumber,
      'companyName': invoice?.companyName,
      'address': invoice?.address,
      'customFields': invoice?.customFields ?? [],
      'vehicleNumber': vehicleNumber,
    };
  }

  factory Delivery.fromJson(Map<String, dynamic> json) {
    final pList = json['products'] is List ? (json['products'] as List) : const [];
    final iList = json['items'] is List ? (json['items'] as List) : const [];

    List<ProductItem> productList = pList
        .whereType<Map>()
        .map((i) => ProductItem.fromJson(Map<String, dynamic>.from(i as Map)))
        .toList();
    List<ProductItem> itemList = iList
        .whereType<Map>()
        .map((i) => ProductItem.fromJson(Map<String, dynamic>.from(i as Map)))
        .toList();

    // Fix: Fallback to items if products is empty (since backend stores them as items)
    if (productList.isEmpty && itemList.isNotEmpty) {
      productList = itemList;
    }

    // Parse embedded invoice snapshot if present
    final rawInvoice = json['invoice'];
    
    final customFields = (json['invoice']?['customFields'] ?? json['customFields'] ?? []) as List;

    DeliveryInvoice? invoice;
    if (rawInvoice is Map<String, dynamic>) {
      final invoiceData = Map<String, dynamic>.from(rawInvoice);
      invoiceData['customFields'] = customFields;
      // Map vehicleNumber if present at root but not in invoice map
      if (invoiceData['vehicleNumber'] == null && json['vehicleNumber'] != null) {
        invoiceData['vehicleNumber'] = json['vehicleNumber'];
      }
      invoice = DeliveryInvoice.fromJson(invoiceData);
    } else if (customFields.isNotEmpty) {
      invoice = DeliveryInvoice(
        id: '',
        amount: _asDouble(json['deliveryTotal'] ?? json['grandTotal']),
        customFields: DeliveryInvoice._parseCustomFields(customFields),
        vehicleNumber: json['vehicleNumber']?.toString(),
      );
    }

    final status = json['status'] ?? 'pending';
    print('[MODEL DEBUG] Delivery ID: ${json['_id'] ?? json['id']}, Status: $status');

    return Delivery(
      id: json['_id']?.toString() ?? json['id']?.toString() ?? '',
      customerId: json['customerId']?.toString(),
      customerName: json['customer'] ?? '',
      customerPhone: json['customerPhone']?.toString(),
      previousBalance: _asDouble(json['previousBalance']),
      updatedBalance: _asDouble(json['updatedBalance']),
      deliveryTotal: _asDouble(json['deliveryTotal'] ?? json['grandTotal']),
      products: productList,
      items: itemList,
      crewLeader: json['crewLeader'] ?? '',
      priority: json['priority'] ?? 'NORMAL',
      status: status,
      timestamp: json['createdAt'] != null ? (DateTime.tryParse(json['createdAt'])?.toLocal() ?? DateTime.now()) : DateTime.now(),
      invoice: invoice,
      stockDeducted: json['stockDeducted'] ?? false,
      vehicleNumber: json['vehicleNumber']?.toString() ?? invoice?.vehicleNumber,
    );
  }

  factory Delivery.create({
    String? customerId,
    required String customerName,
    String? customerPhone,
    double previousBalance = 0.0,
    double updatedBalance = 0.0,
    double deliveryTotal = 0.0,
    required List<ProductItem> products,
    List<ProductItem> items = const [],
    required String crewLeader,
    required String priority,
    String status = 'pending',
    String? gstNumber,
    String? companyName,
    String? address,
    List<Map<String, dynamic>> customFields = const [],
    bool stockDeducted = false,
    String? vehicleNumber,
  }) {
    final timestamp = DateTime.now();
    final id = 'BSM-${timestamp.millisecondsSinceEpoch}';
    return Delivery(
      id: id,
      customerId: customerId,
      customerName: customerName,
      customerPhone: customerPhone,
      previousBalance: previousBalance,
      updatedBalance: updatedBalance,
      deliveryTotal: deliveryTotal,
      products: products,
      items: items,
      crewLeader: crewLeader,
      priority: priority,
      status: status,
      timestamp: timestamp,
      invoice: DeliveryInvoice(
        id: '', 
        amount: deliveryTotal, 
        gstNumber: gstNumber,
        companyName: companyName,
        address: address,
        customFields: customFields,
        vehicleNumber: vehicleNumber,
      ),
      stockDeducted: stockDeducted,
      vehicleNumber: vehicleNumber,
    );
  }

  Delivery copyWith({
    String? id,
    String? customerId,
    String? customerName,
    String? customerPhone,
    double? previousBalance,
    double? updatedBalance,
    double? deliveryTotal,
    List<ProductItem>? products,
    List<ProductItem>? items,
    String? crewLeader,
    String? priority,
    String? status,
    DateTime? timestamp,
    DeliveryInvoice? invoice,
    bool? stockDeducted,
    String? vehicleNumber,
  }) {
    return Delivery(
      id: id ?? this.id,
      customerId: customerId ?? this.customerId,
      customerName: customerName ?? this.customerName,
      customerPhone: customerPhone ?? this.customerPhone,
      previousBalance: previousBalance ?? this.previousBalance,
      updatedBalance: updatedBalance ?? this.updatedBalance,
      deliveryTotal: deliveryTotal ?? this.deliveryTotal,
      products: products ?? this.products,
      items: items ?? this.items,
      crewLeader: crewLeader ?? this.crewLeader,
      priority: priority ?? this.priority,
      status: status ?? this.status,
      timestamp: timestamp ?? this.timestamp,
      invoice: invoice ?? this.invoice,
      stockDeducted: stockDeducted ?? this.stockDeducted,
      vehicleNumber: vehicleNumber ?? this.vehicleNumber,
    );
  }
}
