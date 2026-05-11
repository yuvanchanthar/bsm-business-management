class AttendanceEntry {
  final String labourId;
  final String name;
  final String status; // 'present' or 'absent'
  final double wage;

  AttendanceEntry({
    required this.labourId,
    required this.name,
    required this.status,
    required this.wage,
  });

  factory AttendanceEntry.fromJson(Map<String, dynamic> json) {
    return AttendanceEntry(
      labourId: json['labourId']?.toString() ?? '',
      name: json['name'] ?? '',
      status: json['status'] ?? 'absent',
      wage: (json['wage'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'labourId': labourId,
      'name': name,
      'status': status,
      'wage': wage,
    };
  }
}

class AttendanceReport {
  final int totalLabours;
  final int presentCount;
  final int absentCount;
  final double totalWage;

  AttendanceReport({
    required this.totalLabours,
    required this.presentCount,
    required this.absentCount,
    required this.totalWage,
  });

  factory AttendanceReport.fromJson(Map<String, dynamic> json) {
    return AttendanceReport(
      totalLabours: (json['totalLabours'] as num?)?.toInt() ?? 0,
      presentCount: (json['presentCount'] as num?)?.toInt() ?? 0,
      absentCount: (json['absentCount'] as num?)?.toInt() ?? 0,
      totalWage: (json['totalWage'] as num?)?.toDouble() ?? 0.0,
    );
  }
}
