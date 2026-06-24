import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/app_colors.dart';
import '../models/attendance_model.dart';
import '../models/payment_model.dart';
import '../services/api_service.dart';
import '../services/token_service.dart';

class LabourAttendanceScreen extends StatefulWidget {
  final String labourId;
  final String labourName;
  const LabourAttendanceScreen({super.key, required this.labourId, required this.labourName});

  @override
  State<LabourAttendanceScreen> createState() => _LabourAttendanceScreenState();
}

class _LabourAttendanceScreenState extends State<LabourAttendanceScreen> {
  late ApiService _apiService;
  List<AttendanceRecord> _records = [];
  double _dailyWage = 0;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final tokenService = await TokenService.getInstance();
    _apiService = ApiService(tokenService);
    _fetchAttendance();
  }

  Future<void> _fetchAttendance() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final r = await _apiService.getLabourDetailReport(widget.labourId);
      if (mounted) {
        setState(() {
          _records = r.attendance;
          _dailyWage = r.dailyWage;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.toString().replaceAll('Exception: ', '');
        });
      }
    }
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
        title: Text('${widget.labourName} - Attendance', 
          style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: AppColors.primaryGreen, fontSize: 18)
        ),
        actions: [
          IconButton(icon: const Icon(Icons.refresh, color: AppColors.primaryGreen), onPressed: _fetchAttendance),
        ],
      ),
      body: _isLoading && _records.isEmpty
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
              : _buildAttendanceList(),
    );
  }

  Widget _buildAttendanceList() {
    if (_records.isEmpty) {
      return Center(child: Text('No attendance records', style: GoogleFonts.inter(color: AppColors.textSecondary)));
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
      itemCount: _records.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, i) {
        final rec = _records[i];
        
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

        double displayWage = 0;
        if (isFullDay) displayWage = _dailyWage;
        if (isHalfDay) displayWage = _dailyWage * 0.5;

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
    setState(() => _isLoading = true);
    try {
      await _apiService.updateAttendance(rec.id, newStatus);
      await _fetchAttendance();
      if (mounted) setState(() => _isLoading = false);
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
