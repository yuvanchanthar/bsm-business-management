class MonthlyReportModel {
  final List<double> monthlyRevenue;
  final List<double> monthlyProfit;
  final int year;

  MonthlyReportModel({
    required this.monthlyRevenue,
    required this.monthlyProfit,
    required this.year,
  });

  factory MonthlyReportModel.fromJson(Map<String, dynamic> json) {
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

    int asInt(dynamic value, {int fallback = 0}) {
      if (value == null) return fallback;
      if (value is int) return value;
      if (value is num) return value.toInt();
      if (value is String) return int.tryParse(value.trim()) ?? fallback;
      return fallback;
    }

    final rev = (json['monthlyRevenue'] is List)
        ? (json['monthlyRevenue'] as List).map((e) => asDouble(e)).toList()
        : List.filled(12, 0.0);

    final prof = (json['monthlyProfit'] is List)
        ? (json['monthlyProfit'] as List).map((e) => asDouble(e)).toList()
        : List.filled(12, 0.0);

    return MonthlyReportModel(
      monthlyRevenue: rev,
      monthlyProfit: prof,
      year: asInt(json['year'], fallback: DateTime.now().year),
    );
  }

  factory MonthlyReportModel.empty() {
    return MonthlyReportModel(
      monthlyRevenue: List.filled(12, 0.0),
      monthlyProfit: List.filled(12, 0.0),
      year: DateTime.now().year,
    );
  }
}
