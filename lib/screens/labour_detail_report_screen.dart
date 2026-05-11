import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/app_colors.dart';
import '../models/payment_model.dart';
import '../services/api_service.dart';
import '../services/token_service.dart';
import 'add_payment_screen.dart';

class LabourDetailReportScreen extends StatefulWidget {
  final String labourId;
  final String labourName;
  const LabourDetailReportScreen({super.key, required this.labourId, required this.labourName});

  @override
  State<LabourDetailReportScreen> createState() => _LabourDetailReportScreenState();
}

class _LabourDetailReportScreenState extends State<LabourDetailReportScreen>
    with SingleTickerProviderStateMixin {
  late ApiService _apiService;
  LabourDetailReport? _report;
  bool _isLoading = true;
  String? _errorMessage;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _init();
  }

  Future<void> _init() async {
    final tokenService = await TokenService.getInstance();
    _apiService = ApiService(tokenService);
    refreshAll(widget.labourId);
  }

  Future<void> refreshAll(String labourId) async {
    print("[UI] Triggered refreshAll for labourId: $labourId");
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      print("[UI] Calling getLabourReport and getLabourPayments via ApiService...");
      final r = await _apiService.getLabourDetailReport(labourId);
      
      if (mounted) {
        setState(() {
          _report = r;
          _isLoading = false;
        });
        print("[UI] Successfully updated LabourDetailReport UI.");
      }
    } catch (e) {
      print("[UI] Error refreshing UI: $e");
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.toString().replaceAll('Exception: ', '');
        });
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary), onPressed: () => Navigator.pop(context)),
        title: Text(widget.labourName, style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: AppColors.primaryGreen)),
        actions: [
          IconButton(icon: const Icon(Icons.refresh, color: AppColors.primaryGreen), onPressed: () => refreshAll(widget.labourId)),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primaryGreen,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: Text('Add Payment', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => AddPaymentScreen(labourId: widget.labourId, labourName: widget.labourName)),
          );
          if (result == true) {
            print("[UI] Returned from AddPaymentScreen, calling refreshAll...");
            await refreshAll(widget.labourId);
          }
        },
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primaryGreen))
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline, color: Colors.red, size: 48),
                      const SizedBox(height: 16),
                      Text('$_errorMessage', style: GoogleFonts.inter(fontSize: 16, color: AppColors.textSecondary)),
                    ],
                  ),
                )
              : _report == null
                  ? const Center(child: Text('Failed to load report'))
              : Column(
                  children: [
                    _buildFinanceSummary(),
                    _buildTabBar(),
                    Expanded(
                      child: TabBarView(
                        controller: _tabController,
                        children: [
                          _buildPaymentsList(),
                          _buildAttendanceList(),
                        ],
                      ),
                    ),
                  ],
                ),
    );
  }

  Widget _buildFinanceSummary() {
    final r = _report!;
    final isPending = r.balance > 0;
    final balanceColor = isPending ? Colors.red : Colors.green;

    return Container(
      margin: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.primaryGreen,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: AppColors.primaryGreen.withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, 6))],
      ),
      child: Column(
        children: [
          // Labour info row
          Row(children: [
            Container(
              width: 48, height: 48,
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(12)),
              alignment: Alignment.center,
              child: Text(r.name.isNotEmpty ? r.name[0].toUpperCase() : 'L', style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
            ),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(r.name, style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
              Text(
                '${r.role} · ₹${r.dailyWage.toStringAsFixed(0)}/day · ${r.daysWorked} day${r.daysWorked == 1 ? '' : 's'}',
                style: GoogleFonts.inter(fontSize: 12, color: Colors.white.withValues(alpha: 0.8))),
            ])),
          ]),
          const SizedBox(height: 20),
          const Divider(color: Colors.white24, height: 1),
          const SizedBox(height: 16),
          // Financial row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildWhiteStat('EARNED',  '₹${r.totalEarned.toStringAsFixed(0)}'),
              _buildWhiteStat('PAID',    '₹${r.totalPaid.toStringAsFixed(0)}'),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
                child: Column(children: [
                  Text('PENDING', style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.bold, color: balanceColor, letterSpacing: 0.5)),
                  const SizedBox(height: 2),
                  Text('₹${r.balance.abs().toStringAsFixed(0)}',
                      style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: balanceColor)),
                ]),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWhiteStat(String label, String value) {
    return Column(children: [
      Text(label, style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white.withValues(alpha: 0.7), letterSpacing: 0.5)),
      const SizedBox(height: 4),
      Text(value, style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
    ]);
  }

  Widget _buildTabBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      child: Container(
        height: 44,
        decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(12)),
        child: TabBar(
          controller: _tabController,
          indicator: BoxDecoration(color: AppColors.primaryGreen, borderRadius: BorderRadius.circular(10)),
          indicatorSize: TabBarIndicatorSize.tab,
          dividerHeight: 0,
          labelColor: Colors.white,
          unselectedLabelColor: AppColors.textSecondary,
          labelStyle: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13),
          unselectedLabelStyle: GoogleFonts.inter(fontSize: 13),
          tabs: [
            Tab(text: 'Payments (${_report!.payments.length})'),
            Tab(text: 'Attendance (${_report!.attendance.length})'),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentsList() {
    final payments = _report!.payments;
    if (payments.isEmpty) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.payments_outlined, size: 56, color: AppColors.textSecondary),
          const SizedBox(height: 12),
          Text('No payments yet', style: GoogleFonts.inter(color: AppColors.textSecondary, fontSize: 15)),
          const SizedBox(height: 6),
          Text('Tap + Add Payment to record one.', style: GoogleFonts.inter(color: AppColors.textHint, fontSize: 12)),
        ]),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 100),
      itemCount: payments.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, i) {
        final p = payments[i];
        final displayDate = p.createdAt ?? p.date;
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6, offset: const Offset(0, 2))],
          ),
          child: Row(children: [
            Container(
              width: 42, height: 42,
              decoration: BoxDecoration(color: Colors.green.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.payments, color: Colors.green, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('₹${p.amount.toStringAsFixed(0)}',
                  style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
              if (p.note != null && p.note!.trim().isNotEmpty)
                Text(p.note!, style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary))
              else
                Text('No note provided', style: GoogleFonts.inter(fontSize: 12, color: AppColors.textHint, fontStyle: FontStyle.italic)),
            ])),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(displayDate.toString().split(' ')[0],
                  style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
            ]),
          ]),
        );
      },
    );
  }

  Widget _buildAttendanceList() {
    final records = _report!.attendance;
    if (records.isEmpty) {
      return Center(child: Text('No attendance records', style: GoogleFonts.inter(color: AppColors.textSecondary)));
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 100),
      itemCount: records.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, i) {
        final rec = records[i];
        final isPresent = rec.status == 'present';
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6, offset: const Offset(0, 2))],
          ),
          child: Row(children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: (isPresent ? Colors.green : Colors.red).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(isPresent ? Icons.check : Icons.close,
                  color: isPresent ? Colors.green : Colors.red, size: 18),
            ),
            const SizedBox(width: 14),
            Expanded(child: Text(rec.date, style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: AppColors.textPrimary))),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: (isPresent ? Colors.green : Colors.red).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                isPresent ? '₹${rec.wage.toStringAsFixed(0)}' : 'ABSENT',
                style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold,
                    color: isPresent ? Colors.green : Colors.red),
              ),
            ),
          ]),
        );
      },
    );
  }
}
