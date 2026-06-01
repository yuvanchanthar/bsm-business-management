import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/app_colors.dart';
import '../models/labour_report_model.dart';
import '../services/api_service.dart';
import '../services/token_service.dart';
import 'labour_detail_report_screen.dart';

class SalaryReportScreen extends StatefulWidget {
  const SalaryReportScreen({super.key});

  @override
  State<SalaryReportScreen> createState() => _SalaryReportScreenState();
}

class _SalaryReportScreenState extends State<SalaryReportScreen> {
  late ApiService _apiService;
  List<LabourReportModel> _reports = [];
  Map<String, dynamic> _totals = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final tokenService = await TokenService.getInstance();
    _apiService = ApiService(tokenService);
    _fetchReport();
  }

  Future<void> _fetchReport() async {
    setState(() => _isLoading = true);
    try {
      final response = await _apiService.getSalaryReport();
      if (mounted) {
        setState(() { 
          _reports = (response['report'] as List<dynamic>).cast<LabourReportModel>();
          _totals = response['totals'] as Map<String, dynamic>? ?? {};
          _isLoading = false; 
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
        setState(() => _isLoading = false);
      }
    }
  }

  double get _totalPending {
    final t = _totals['totalPending'] ?? _totals['pendingBalance'] ?? _totals['pending'];
    if (t != null) return (t as num).toDouble();
    return _reports.fold(0.0, (s, r) => s + (r.pendingBalance > 0 ? r.pendingBalance : 0));
  }
  
  double get _totalPaid {
    final t = _totals['totalPaid'] ?? _totals['paid'];
    if (t != null) return (t as num).toDouble();
    return _reports.fold(0.0, (s, r) => s + r.totalPaid);
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
        title: Text('Salary Report', style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: AppColors.primaryGreen)),
        actions: [
          IconButton(icon: const Icon(Icons.refresh, color: AppColors.primaryGreen), onPressed: _fetchReport),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primaryGreen))
          : Column(
              children: [
                // Summary header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Salary Overview', style: GoogleFonts.inter(fontSize: 26, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                      const SizedBox(height: 4),
                      Text('Track earnings, payments & pending balances.', style: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary)),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          _buildSummaryChip('Total Paid', '₹${_totalPaid.toStringAsFixed(0)}', Colors.green),
                          const SizedBox(width: 12),
                          _buildSummaryChip('Total Pending', '₹${_totalPending.toStringAsFixed(0)}', Colors.red),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Expanded(
                  child: _reports.isEmpty
                      ? Center(
                          child: Column(mainAxisSize: MainAxisSize.min, children: [
                            const Icon(Icons.receipt_long_outlined, size: 64, color: AppColors.textSecondary),
                            const SizedBox(height: 12),
                            Text('No salary data available.', style: GoogleFonts.inter(color: AppColors.textSecondary)),
                          ]),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                          itemCount: _reports.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 12),
                          itemBuilder: (context, i) => _buildReportCard(_reports[i]),
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildSummaryChip(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: color, letterSpacing: 0.5)),
          const SizedBox(height: 4),
          Text(value, style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
        ]),
      ),
    );
  }

  Widget _buildReportCard(LabourReportModel r) {
    final double earned = r.totalEarned;
    final double paid = r.totalPaid;
    final double pending = (earned - paid) > 0 ? (earned - paid) : 0;
    final double advance = (paid - earned) > 0 ? (paid - earned) : 0;

    final isPending = pending > 0;
    final isAdvance = advance > 0;
    final balanceColor = isAdvance ? Colors.blue : (isPending ? Colors.red : Colors.green);
    final balanceLabel = isAdvance ? 'ADVANCE' : (isPending ? 'PENDING' : 'SETTLED');

    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => LabourDetailReportScreen(
              labourId: r.id, labourName: r.name),
        ),
      ).then((_) => _fetchReport()),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 3))],
        ),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.primaryGreen.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10)),
                  alignment: Alignment.center,
                  child: Text(
                    r.name.isNotEmpty ? r.name[0].toUpperCase() : 'L',
                    style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primaryGreen)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(r.name,
                        style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.textPrimary)),
                    Text('${r.daysWorked} day${r.daysWorked == 1 ? '' : 's'} worked',
                        style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary)),
                  ]),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: balanceColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8)),
                  child: Text(balanceLabel,
                      style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: balanceColor)),
                ),
              ],
            ),
            const SizedBox(height: 14),
            const Divider(height: 1, thickness: 0.5),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildFinancialItem('EARNED',  '₹${earned.toStringAsFixed(0)}', AppColors.textPrimary),
                _buildFinancialItem('PAID',    '₹${paid.toStringAsFixed(0)}',   Colors.green),
                _buildFinancialItem('ADVANCE', '₹${advance.toStringAsFixed(0)}', isAdvance ? Colors.blue : AppColors.textSecondary),
                _buildFinancialItem('PENDING', '₹${pending.toStringAsFixed(0)}', isPending ? Colors.red : AppColors.textSecondary),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFinancialItem(String label, String value, Color color) {
    return Column(children: [
      Text(label, style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.bold, color: AppColors.textSecondary, letterSpacing: 0.8)),
      const SizedBox(height: 4),
      Text(value, style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
    ]);
  }
}
