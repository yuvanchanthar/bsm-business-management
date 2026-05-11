class CustomerModel {
  final String? id;
  final String name;
  final String phone;
  final String address;
  final double balance;
  final double creditLimit;
  final DateTime? lastPaymentDate;
  final int pendingDays;
  final DateTime? createdAt;

  CustomerModel({
    this.id,
    required this.name,
    required this.phone,
    required this.address,
    this.balance = 0.0,
    this.creditLimit = 0.0,
    this.lastPaymentDate,
    this.pendingDays = 0,
    this.createdAt,
  });

  factory CustomerModel.fromJson(Map<String, dynamic> json) {
    return CustomerModel(
      id: json['_id']?.toString() ?? json['id']?.toString(),
      name: json['name'] ?? '',
      phone: json['phone'] ?? '',
      address: json['address'] ?? '',
      balance: (json['balance'] as num?)?.toDouble() ?? 0.0,
      creditLimit: (json['creditLimit'] as num?)?.toDouble() ?? 0.0,
      lastPaymentDate: json['lastPaymentDate'] != null ? DateTime.tryParse(json['lastPaymentDate']) : null,
      pendingDays: json['pendingDays'] ?? 0,
      createdAt: json['createdAt'] != null ? DateTime.tryParse(json['createdAt']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) '_id': id,
      'name': name,
      'phone': phone,
      'address': address,
      'balance': balance,
      'creditLimit': creditLimit,
      if (lastPaymentDate != null) 'lastPaymentDate': lastPaymentDate!.toIso8601String(),
      'pendingDays': pendingDays,
      if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
    };
  }

  CustomerModel copyWith({
    String? id,
    String? name,
    String? phone,
    String? address,
    double? balance,
    double? creditLimit,
    DateTime? lastPaymentDate,
    int? pendingDays,
    DateTime? createdAt,
  }) {
    return CustomerModel(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      balance: balance ?? this.balance,
      creditLimit: creditLimit ?? this.creditLimit,
      lastPaymentDate: lastPaymentDate ?? this.lastPaymentDate,
      pendingDays: pendingDays ?? this.pendingDays,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

