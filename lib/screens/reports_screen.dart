import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/app_colors.dart';
import '../models/monthly_report_model.dart';
import '../services/api_service.dart';
import '../services/token_service.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  late ApiService _apiService;
  MonthlyReportModel? _report;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initData();
  }

  Future<void> _initData() async {
    try {
      final tokenService = await TokenService.getInstance();
      _apiService = ApiService(tokenService);
      await _fetchReport();
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  Future<void> _fetchReport() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final report = await _apiService.getMonthlyReport();
      if (mounted) {
        setState(() {
          _report = report;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Business Reports', style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: AppColors.primaryGreen)),
        backgroundColor: AppColors.background,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
      ),
      body: RefreshIndicator(
        onRefresh: _fetchReport,
        color: AppColors.primaryGreen,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primaryGreen));
    }
    if (_error != null) {
      return Center(child: Text('Error: $_error', style: const TextStyle(color: Colors.red)));
    }
    if (_report == null) {
      return const Center(child: Text('No data found'));
    }

    final totalRevenue = _report!.monthlyRevenue.reduce((a, b) => a + b);
    final totalProfit = _report!.monthlyProfit.reduce((a, b) => a + b);

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Yearly Overview ${_report!.year}',
            style: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 24),
          
          Row(
            children: [
              Expanded(child: _buildStatCard('Total Revenue', totalRevenue, Colors.blue)),
              const SizedBox(width: 16),
              Expanded(child: _buildStatCard('Total Profit', totalProfit, Colors.green)),
            ],
          ),
          
          const SizedBox(height: 32),
          Text(
            'Revenue vs Profit',
            style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 16),
          _buildComparisonChart(),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, double value, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 8),
          Text('₹${(value / 1000).toStringAsFixed(1)}K', style: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.w900, color: AppColors.textPrimary)),
        ],
      ),
    );
  }

  Widget _buildComparisonChart() {
    return Container(
      height: 300,
      padding: const EdgeInsets.only(top: 24, bottom: 8, left: 8, right: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          borderData: FlBorderData(show: false),
          gridData: const FlGridData(show: false),
          titlesData: FlTitlesData(
            leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
                  if (value >= 0 && value < 12) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(months[value.toInt()], style: GoogleFonts.inter(fontSize: 10, color: AppColors.textSecondary)),
                    );
                  }
                  return const SizedBox();
                },
              ),
            ),
          ),
          barGroups: List.generate(12, (index) {
            return BarChartGroupData(
              x: index,
              barRods: [
                BarChartRodData(
                  toY: _report!.monthlyRevenue[index],
                  color: Colors.blue,
                  width: 8,
                  borderRadius: const BorderRadius.only(topLeft: Radius.circular(4), topRight: Radius.circular(4)),
                ),
                BarChartRodData(
                  toY: _report!.monthlyProfit[index],
                  color: Colors.green,
                  width: 8,
                  borderRadius: const BorderRadius.only(topLeft: Radius.circular(4), topRight: Radius.circular(4)),
                ),
              ],
            );
          }),
        ),
      ),
    );
  }
}
