class LabourReportModel {
  final String id;
  final String name;
  final double totalEarned;
  final double totalPaid;
  final double pendingBalance;
  final int daysWorked;

  LabourReportModel({
    required this.id,
    required this.name,
    required this.totalEarned,
    required this.totalPaid,
    required this.pendingBalance,
    this.daysWorked = 0,
  });

  factory LabourReportModel.fromJson(Map<String, dynamic> json) {
    return LabourReportModel(
      id: json['_id']?.toString() ?? json['labourId']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Unknown',
      totalEarned: (json['totalEarned'] ?? 0).toDouble(),
      totalPaid: (json['totalPaid'] ?? 0).toDouble(),
      pendingBalance: (json['pendingBalance'] ?? 0).toDouble(),
      daysWorked: (json['daysWorked'] ?? 0).toInt(),
    );
  }
}
