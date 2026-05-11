class LabourModel {
  final String? id;
  final String name;
  final String phone;
  final String role;
  final double dailyWage;
  final DateTime? createdAt;

  LabourModel({
    this.id,
    required this.name,
    required this.phone,
    required this.role,
    required this.dailyWage,
    this.createdAt,
  });

  factory LabourModel.fromJson(Map<String, dynamic> json) {
    return LabourModel(
      id: json['_id']?.toString(),
      name: json['name'] ?? '',
      phone: json['phone'] ?? '',
      role: json['role'] ?? '',
      dailyWage: (json['dailyWage'] as num?)?.toDouble() ?? 0.0,
      createdAt: json['createdAt'] != null ? DateTime.tryParse(json['createdAt']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) '_id': id,
      'name': name,
      'phone': phone,
      'role': role,
      'dailyWage': dailyWage,
      if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
    };
  }
}
