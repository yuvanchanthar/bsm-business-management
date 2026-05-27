/// Attendance statuses supported by the backend.
/// Legacy 'present' is mapped → 'full_day' for backward compatibility.
class AttendanceEntry {
  final String labourId;
  final String name;

  /// One of: 'full_day', 'half_day', 'absent'
  /// Old 'present' records are normalised to 'full_day' at parse time.
  final String status;
  final double wage;

  AttendanceEntry({
    required this.labourId,
    required this.name,
    required this.status,
    required this.wage,
  });

  /// Normalise legacy 'present' → 'full_day'.
  static String _normaliseStatus(String? raw) {
    if (raw == null || raw.isEmpty) return 'absent';
    if (raw == 'present') return 'full_day';
    const valid = {'full_day', 'half_day', 'absent'};
    return valid.contains(raw) ? raw : 'absent';
  }

  factory AttendanceEntry.fromJson(Map<String, dynamic> json) {
    return AttendanceEntry(
      labourId: json['labourId']?.toString() ?? '',
      name: json['name'] ?? '',
      status: _normaliseStatus(json['status']?.toString()),
      wage: (json['wage'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'labourId': labourId,
      'name': name,
      'status': status, // always sends exact backend value
      'wage': wage,
    };
  }
}

class AttendanceReport {
  final int totalLabours;

  /// Number of full-day entries (legacy presentCount is kept for compatibility).
  final int fullDayCount;

  /// Number of half-day entries.
  final int halfDayCount;

  /// Number of absent entries.
  final int absentCount;

  final double totalWage;

  AttendanceReport({
    required this.totalLabours,
    required this.fullDayCount,
    required this.halfDayCount,
    required this.absentCount,
    required this.totalWage,
  });

  /// Total worked days: fullDay = 1, halfDay = 0.5, absent = 0.
  double get daysWorked => fullDayCount + (halfDayCount * 0.5);

  /// Backward-compat alias.
  int get presentCount => fullDayCount;

  factory AttendanceReport.fromJson(Map<String, dynamic> json) {
    // Support both old (presentCount) and new (fullDayCount) backend keys.
    final fullDay = (json['fullDayCount'] as num?)?.toInt() ??
        (json['presentCount'] as num?)?.toInt() ??
        0;
    final halfDay = (json['halfDayCount'] as num?)?.toInt() ?? 0;
    final absent = (json['absentCount'] as num?)?.toInt() ?? 0;

    return AttendanceReport(
      totalLabours: (json['totalLabours'] as num?)?.toInt() ?? 0,
      fullDayCount: fullDay,
      halfDayCount: halfDay,
      absentCount: absent,
      totalWage: (json['totalWage'] as num?)?.toDouble() ?? 0.0,
    );
  }
}
