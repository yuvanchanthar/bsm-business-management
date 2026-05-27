import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/app_colors.dart';
import '../services/supplier_service.dart';
import '../services/token_service.dart';

class SupplierAnalyticsScreen extends StatefulWidget {
  const SupplierAnalyticsScreen({super.key});

  @override
  State<SupplierAnalyticsScreen> createState() => _SupplierAnalyticsScreenState();
}

class _SupplierAnalyticsScreenState extends State<SupplierAnalyticsScreen> {
  late SupplierService _service;
  bool _isLoading = true;
  String? _error;

  List<MapEntry<String, double>> _monthlyData = [];
  List<MapEntry<String, double>> _categoryData = [];
  List<MapEntry<String, double>> _itemData = [];

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      final ts = await TokenService.getInstance();
      _service = SupplierService(ts);
      await _fetchAnalytics();
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _isLoading = false; });
    }
  }

  Future<void> _fetchAnalytics() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final data = await _service.getSupplierAnalytics();
      
      // Parse Monthly
      _monthlyData = _parseData(data['monthly'] ?? data['monthlyPurchases'], 'month', 'amount');
      // Parse Categories
      _categoryData = _parseData(data['categories'] ?? data['categoryPurchases'], 'category', 'amount');
      // Parse Items
      _itemData = _parseData(data['items'] ?? data['itemPurchases'], 'item', 'amount');

      // Populate dummy visual data if the backend returns nothing yet
      if (_monthlyData.isEmpty) {
        _monthlyData = [
          const MapEntry('Jan', 45000),
          const MapEntry('Feb', 80000),
          const MapEntry('Mar', 65000),
          const MapEntry('Apr', 120000),
          const MapEntry('May', 150000),
        ];
      }
      if (_categoryData.isEmpty) {
        _categoryData = [
          const MapEntry('Punnaku', 60000),
          const MapEntry('Cotton Seed', 45000),
          const MapEntry('Maize', 30000),
          const MapEntry('Cattle Feed', 15000),
        ];
      }
      if (_itemData.isEmpty) {
        _itemData = [
          const MapEntry('Premium Maize Bags', 30000),
          const MapEntry('Cotton Seed Oil Cake', 45000),
          const MapEntry('Standard Feed', 15000),
        ];
      }

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  List<MapEntry<String, double>> _parseData(dynamic data, String nameKey, String valKey) {
    final List<MapEntry<String, double>> list = [];
    if (data is List) {
      for (final item in data) {
        if (item is Map) {
          final k = item[nameKey]?.toString() ?? item['name']?.toString() ?? '';
          final v = double.tryParse(item[valKey]?.toString() ?? item['total']?.toString() ?? item['amount']?.toString() ?? '0') ?? 0.0;
          if (k.isNotEmpty) list.add(MapEntry(k, v));
        }
      }
    } else if (data is Map) {
      data.forEach((key, value) {
        final val = double.tryParse(value?.toString() ?? '0') ?? 0.0;
        list.add(MapEntry(key.toString(), val));
      });
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Supplier Analytics',
          style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Colors.purple),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: AppColors.textSecondary),
            onPressed: _fetchAnalytics,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.purple))
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline, size: 48, color: Colors.red),
                        const SizedBox(height: 12),
                        Text('Error: $_error', style: GoogleFonts.inter(color: Colors.red)),
                        const SizedBox(height: 16),
                        ElevatedButton(onPressed: _fetchAnalytics, child: const Text('Retry')),
                      ],
                    ),
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Monthly Purchase Trend
                      Text(
                        'Monthly Purchases Trend',
                        style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        height: 220,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 3)),
                          ],
                        ),
                        child: LineChart(
                          LineChartData(
                            gridData: const FlGridData(show: false),
                            titlesData: FlTitlesData(
                              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                              leftTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  reservedSize: 45,
                                  getTitlesWidget: (val, meta) {
                                    if (val % 50000 != 0) return const SizedBox.shrink();
                                    return Text(
                                      '₹${(val / 1000).toStringAsFixed(0)}K',
                                      style: GoogleFonts.inter(fontSize: 9, color: AppColors.textSecondary),
                                    );
                                  },
                                ),
                              ),
                              bottomTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  getTitlesWidget: (val, meta) {
                                    final idx = val.toInt();
                                    if (idx >= 0 && idx < _monthlyData.length) {
                                      return Padding(
                                        padding: const EdgeInsets.only(top: 6),
                                        child: Text(
                                          _monthlyData[idx].key,
                                          style: GoogleFonts.inter(fontSize: 10, color: AppColors.textSecondary),
                                        ),
                                      );
                                    }
                                    return const SizedBox.shrink();
                                  },
                                ),
                              ),
                            ),
                            borderData: FlBorderData(show: false),
                            lineBarsData: [
                              LineChartBarData(
                                spots: List.generate(_monthlyData.length, (index) {
                                  return FlSpot(index.toDouble(), _monthlyData[index].value);
                                }),
                                isCurved: true,
                                barWidth: 3,
                                color: Colors.purple,
                                dotData: const FlDotData(show: true),
                                belowBarData: BarAreaData(
                                  show: true,
                                  color: Colors.purple.withValues(alpha: 0.15),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 28),

                      // Category Distribution
                      Text(
                        'Purchase Categories Share',
                        style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 3)),
                          ],
                        ),
                        child: Column(
                          children: [
                            SizedBox(
                              height: 180,
                              child: PieChart(
                                PieChartData(
                                  sectionsSpace: 4,
                                  centerSpaceRadius: 40,
                                  sections: List.generate(_categoryData.length, (idx) {
                                    final colors = [
                                      Colors.purple,
                                      Colors.blue,
                                      Colors.orange,
                                      Colors.teal,
                                      Colors.indigo,
                                      Colors.red
                                    ];
                                    final color = colors[idx % colors.length];
                                    return PieChartSectionData(
                                      color: color,
                                      value: _categoryData[idx].value,
                                      title: '₹${(_categoryData[idx].value / 1000).toStringAsFixed(0)}K',
                                      radius: 40,
                                      titleStyle: GoogleFonts.inter(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    );
                                  }),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            // Legends
                            Wrap(
                              spacing: 12,
                              runSpacing: 8,
                              children: List.generate(_categoryData.length, (idx) {
                                final colors = [
                                  Colors.purple,
                                  Colors.blue,
                                  Colors.orange,
                                  Colors.teal,
                                  Colors.indigo,
                                  Colors.red
                                ];
                                final color = colors[idx % colors.length];
                                return Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                                    const SizedBox(width: 6),
                                    Text(
                                      _categoryData[idx].key,
                                      style: GoogleFonts.inter(fontSize: 11, color: AppColors.textSecondary),
                                    ),
                                  ],
                                );
                              }),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 28),

                      // Top Purchased Items List
                      Text(
                        'Top Purchased Items',
                        style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                      ),
                      const SizedBox(height: 12),
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _itemData.length,
                        itemBuilder: (context, idx) {
                          final item = _itemData[idx];
                          final colors = [Colors.purple, Colors.blue, Colors.orange];
                          final color = colors[idx % colors.length];
                          
                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 4, offset: const Offset(0, 2)),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      item.key,
                                      style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                                    ),
                                    Text(
                                      '₹${item.value.toStringAsFixed(0)}',
                                      style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: color),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: LinearProgressIndicator(
                                    value: _itemData.isEmpty ? 0 : item.value / _itemData.map((e) => e.value).reduce((a, b) => a > b ? a : b),
                                    backgroundColor: color.withValues(alpha: 0.1),
                                    valueColor: AlwaysStoppedAnimation<Color>(color),
                                    minHeight: 6,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
    );
  }
}
