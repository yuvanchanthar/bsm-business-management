import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/app_colors.dart';
import '../models/payment_model.dart';
import '../services/api_service.dart';
import '../services/token_service.dart';
import 'add_payment_screen.dart';
import '../models/attendance_model.dart';
import '../services/pdf_service.dart';
import 'package:intl/intl.dart';

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
  
  bool _isWeeklyReport = true;
  DateTime _reportAnchorDate = DateTime.now();

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
      body: _isLoading && _report == null
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
              : Stack(
                  children: [
                    Column(
                      children: [
                        _buildFinanceSummary(),
                        _buildReportSection(),
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
                    if (_isLoading)
                      Container(
                        color: Colors.white.withValues(alpha: 0.5),
                        child: const Center(child: CircularProgressIndicator(color: AppColors.primaryGreen)),
                      ),
                  ],
                ),
    );
  }

  Widget _buildFinanceSummary() {
    final r = _report!;
    final double earned = r.totalEarned;
    final double paid = r.totalPaid;
    final double pending = (earned - paid) > 0 ? (earned - paid) : 0;
    final double advance = (paid - earned) > 0 ? (paid - earned) : 0;

    final isPending = pending > 0;
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
              _buildWhiteStat('EARNED',  '₹${earned.toStringAsFixed(0)}'),
              _buildWhiteStat('PAID',    '₹${paid.toStringAsFixed(0)}'),
              if (advance > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
                  child: Column(children: [
                    Text('ADVANCE', style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.blue, letterSpacing: 0.5)),
                    const SizedBox(height: 2),
                    Text('₹${advance.toStringAsFixed(0)}',
                        style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.blue)),
                  ]),
                )
              else
                _buildWhiteStat('ADVANCE', '₹0'),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
                child: Column(children: [
                  Text('PENDING', style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.bold, color: balanceColor, letterSpacing: 0.5)),
                  const SizedBox(height: 2),
                  Text('₹${pending.toStringAsFixed(0)}',
                      style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: balanceColor)),
                ]),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildReportSection() {
    return Container(
      margin: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Attendance Reports', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
          const SizedBox(height: 16),
          Row(
            children: [
              _buildReportToggle('Weekly', _isWeeklyReport, () => setState(() => _isWeeklyReport = true)),
              const SizedBox(width: 12),
              _buildReportToggle('Monthly', !_isWeeklyReport, () => setState(() => _isWeeklyReport = false)),
            ],
          ),
          const SizedBox(height: 16),
          InkWell(
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _reportAnchorDate,
                firstDate: DateTime(2020),
                lastDate: DateTime.now(),
              );
              if (picked != null) setState(() => _reportAnchorDate = picked);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(12)),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(DateFormat('dd MMM yyyy').format(_reportAnchorDate), style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600)),
                  const Icon(Icons.calendar_today, size: 18, color: AppColors.primaryGreen),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _generateReport,
                  icon: const Icon(Icons.picture_as_pdf, size: 18, color: Colors.white),
                  label: Text('Generate PDF', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white)),
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryGreen, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildReportToggle(String label, bool isSelected, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primaryGreen : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(10),
          ),
          alignment: Alignment.center,
          child: Text(label, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: isSelected ? Colors.white : AppColors.textSecondary)),
        ),
      ),
    );
  }

  Future<void> _generateReport() async {
    if (_report == null) return;

    DateTime start, end;
    if (_isWeeklyReport) {
      end = _reportAnchorDate;
      start = end.subtract(const Duration(days: 6));
    } else {
      start = DateTime(_reportAnchorDate.year, _reportAnchorDate.month, 1);
      end = DateTime(_reportAnchorDate.year, _reportAnchorDate.month + 1, 0);
    }

    // Filter existing attendance records within the range
    final filteredRecords = _report!.attendance.where((rec) {
      final recDate = DateTime.tryParse(rec.date);
      if (recDate == null) return false;
      return (recDate.isAfter(start.subtract(const Duration(seconds: 1))) &&
              recDate.isBefore(end.add(const Duration(days: 1))));
    }).toList();

    // Sort newest first
    filteredRecords.sort((a, b) => b.date.compareTo(a.date));

    // ── Full Runtime Trace ───────────────────────────────────────────
    print("========== PDF TRACE ==========");
    print("REPORT OBJECT:");
    print(_report);

    print("REPORT DAILY WAGE:");
    print(_report?.dailyWage);

    dynamic labour; // Placeholder, not currently defined in this scope
    print("LABOUR:");
    print(labour);

    print("LABOUR DAILY WAGE:");
    print(labour?.dailyWage);

    final records = filteredRecords;
    print("ATTENDANCE FIRST:");
    print(records.isNotEmpty ? "Wage: ${records.first.wage}, Status: ${records.first.status}, Date: ${records.first.date}" : "EMPTY");

    final debugDailyWage =
        (_report?.dailyWage ?? 0) > 0
            ? _report!.dailyWage
            : (labour?.dailyWage ?? 0) > 0
                ? labour!.dailyWage
                : (records.isNotEmpty
                    ? records.first.wage
                    : 0);

    print("FINAL PDF DAILYWAGE:");
    print(debugDailyWage);
    
    final double dailyWage = debugDailyWage;
    // ─────────────────────────────────────────────────────────────────────

    // Calculate Summary
    int fullDays = 0;
    int halfDays = 0;
    int absent = 0;
    double totalEarned = 0;

    for (var rec in filteredRecords) {
      final status = rec.status == 'present' ? 'full_day' : rec.status;
      if (status == 'full_day') {
        fullDays++;
        totalEarned += dailyWage;
      } else if (status == 'half_day') {
        halfDays++;
        totalEarned += dailyWage * 0.5;
      } else {
        absent++;
      }
    }

    // Filter payments within the range
    final filteredPayments = _report!.payments.where((p) {
      final pDate = p.createdAt ?? p.date;
      return (pDate.isAfter(start.subtract(const Duration(seconds: 1))) &&
              pDate.isBefore(end.add(const Duration(days: 1))));
    }).toList();

    double totalPaidInRange = 0;
    for (var p in filteredPayments) totalPaidInRange += p.amount;

    final double workedDays = fullDays + (halfDays * 0.5);

    // Opening Balance = Overall Balance - (Current Period Earned - Current Period Paid)
    final double currentPeriodNet = totalEarned - totalPaidInRange;
    final double openingBalance = _report!.balance - currentPeriodNet;

    final summary = {
      'fullDays': fullDays,
      'halfDays': halfDays,
      'absent': absent,
      'workedDays': workedDays,
      'totalEarned': totalEarned,
      'totalPaid': totalPaidInRange,
      'pending': totalEarned - totalPaidInRange,
    };

    print("[UI] Generating PDF for ${_report!.name}. DailyWage: $dailyWage, Opening: $openingBalance");

    await PdfService().generateAttendanceReport(
      labourName: _report!.name,
      phone: _report!.phone,
      period: "${DateFormat('dd MMM').format(start)} → ${DateFormat('dd MMM yyyy').format(end)}",
      records: filteredRecords,
      dailyWage: dailyWage,
      openingBalance: openingBalance,
      summary: summary,
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
        
        var status = rec.status;
        if (status == 'present') {
          status = 'full_day';
        }

        final isFullDay = status == 'full_day';
        final isHalfDay = status == 'half_day';
        
        Color statusColor;
        String statusLabel;
        
        if (isFullDay) {
          statusColor = Colors.green;
          statusLabel = '🟢 Full Day';
        } else if (isHalfDay) {
          statusColor = Colors.orange;
          statusLabel = '🟠 Half Day';
        } else {
          statusColor = Colors.red;
          statusLabel = '🔴 Absent';
        }

        // Amount logic based on user's prompt
        double displayWage = 0;
        if (isFullDay) displayWage = _report!.dailyWage;
        if (isHalfDay) displayWage = _report!.dailyWage * 0.5;

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6, offset: const Offset(0, 2))],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(rec.date, style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: AppColors.textSecondary, fontSize: 13)),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(statusLabel, style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold, color: statusColor)),
                  GestureDetector(
                    onTap: () => _showEditAttendanceSheet(rec),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.edit, size: 14, color: AppColors.textPrimary),
                          const SizedBox(width: 4),
                          Text('Edit', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Earned:\n₹${displayWage.toStringAsFixed(0)}',
                style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showEditAttendanceSheet(AttendanceRecord rec) async {
    String selectedStatus = rec.status;
    if (selectedStatus == 'present') selectedStatus = 'full_day';

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Container(
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Edit Attendance', style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                  const SizedBox(height: 8),
                  Text(rec.date, style: GoogleFonts.inter(fontSize: 14, color: AppColors.textSecondary)),
                  const SizedBox(height: 24),
                  _buildRadioOption('Full Day', 'full_day', selectedStatus, (val) => setSheetState(() => selectedStatus = val)),
                  const SizedBox(height: 12),
                  _buildRadioOption('Half Day', 'half_day', selectedStatus, (val) => setSheetState(() => selectedStatus = val)),
                  const SizedBox(height: 12),
                  _buildRadioOption('Absent', 'absent', selectedStatus, (val) => setSheetState(() => selectedStatus = val)),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryGreen,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: () {
                        Navigator.pop(context);
                        _updateAttendanceRecord(rec, selectedStatus);
                      },
                      child: Text('Update Attendance', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildRadioOption(String title, String value, String groupValue, Function(String) onChanged) {
    final isSelected = value == groupValue;
    return InkWell(
      onTap: () => onChanged(value),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          border: Border.all(color: isSelected ? AppColors.primaryGreen : Colors.grey.shade300, width: isSelected ? 2 : 1),
          borderRadius: BorderRadius.circular(12),
          color: isSelected ? AppColors.primaryGreen.withValues(alpha: 0.05) : Colors.transparent,
        ),
        child: Row(
          children: [
            Icon(
              isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
              color: isSelected ? AppColors.primaryGreen : Colors.grey.shade400,
            ),
            const SizedBox(width: 12),
            Text(title, style: GoogleFonts.inter(fontSize: 16, fontWeight: isSelected ? FontWeight.bold : FontWeight.w500, color: AppColors.textPrimary)),
          ],
        ),
      ),
    );
  }

  Future<void> _updateAttendanceRecord(AttendanceRecord rec, String newStatus) async {
    print("EDIT ID: ${rec.id}");
    print("OLD:${rec.status}");
    print("NEW:$newStatus");

    setState(() => _isLoading = true);
    try {
      await _apiService.updateAttendance(rec.id, newStatus);
      
      // Success: refresh everything
      await refreshAll(widget.labourId);
      
      if (mounted) {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }
}
