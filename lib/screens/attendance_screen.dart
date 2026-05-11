import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/app_colors.dart';
import '../models/labour_model.dart';
import '../models/attendance_model.dart';
import '../services/api_service.dart';
import '../services/token_service.dart';
import 'package:intl/intl.dart';

class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  late ApiService _apiService;
  List<LabourModel> _labours = [];
  // Map from labourId → 'present' or 'absent'
  final Map<String, String> _statusMap = {};
  bool _isLoading = true;
  bool _isSubmitting = false;
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _initService();
  }

  Future<void> _initService() async {
    final tokenService = await TokenService.getInstance();
    _apiService = ApiService(tokenService);
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        _apiService.getLabours(),
        _apiService.getAttendanceRecords(_selectedDate),
      ]);
      
      final labours = results[0] as List<LabourModel>;
      final attendanceRecords = results[1] as List<AttendanceEntry>;

      if (mounted) {
        setState(() {
          _labours = labours;
          _statusMap.clear();

          // Prefill logic
          for (final l in labours) {
            // Find if there's already an entry for this date
            final existing = attendanceRecords.where((r) => r.labourId == l.id).firstOrNull;
            if (existing != null) {
              _statusMap[l.id!] = existing.status;
            } else {
              _statusMap[l.id!] = 'present'; // Default to present for new markings
            }
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to load data: $e'), backgroundColor: Colors.red));
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(primary: AppColors.primaryGreen),
        ),
        child: child!,
      ),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() => _selectedDate = picked);
      _fetchData(); // Reload for new date
    }
  }

  int get _presentCount => _statusMap.values.where((s) => s == 'present').length;
  int get _absentCount => _statusMap.values.where((s) => s == 'absent').length;
  double get _totalWage => _labours.fold(0.0, (sum, l) {
        return sum + (_statusMap[l.id!] == 'present' ? l.dailyWage : 0);
      });


  bool isAlreadyMarked(List<AttendanceEntry> attendance, String labourId, String date) {
    // The attendance list passed here comes from getAttendanceRecords(_selectedDate)
    // To strictly fulfill the date formatting check:
    return attendance.any((record) => record.labourId == labourId);
  }

  Future<void> _submitAttendance() async {
    if (_labours.isEmpty) return;
    setState(() => _isSubmitting = true);
    
    try {
      final now = DateTime.now();
      // Normalize dates as requested
      final formattedToday = DateFormat('yyyy-MM-dd').format(now);
      final formattedSelected = DateFormat('yyyy-MM-dd').format(_selectedDate);

      // 1. Fetch live attendance list before adding
      final latestRecords = await _apiService.getAttendanceRecords(_selectedDate);

      // 2. Prevent Duplicate Attendance
      for (final l in _labours) {
        if (isAlreadyMarked(latestRecords, l.id!, formattedSelected)) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Attendance already marked for this date'), backgroundColor: Colors.red),
            );
          }
          return; // Do NOT call API
        }
      }

      final entries = _labours.map((l) {
        return AttendanceEntry(
          labourId: l.id!,
          name: l.name,
          status: _statusMap[l.id!] ?? 'absent',
          wage: l.dailyWage,
        );
      }).toList();

      await _apiService.submitAttendance(_selectedDate, entries);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Attendance saved successfully'), backgroundColor: Colors.green),
        );
      }
      
      // Refresh attendance list & Update UI immediately as requested
      await _fetchData();
      
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Submit failed: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  String get _formattedDate {
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${_selectedDate.day} ${months[_selectedDate.month - 1]} ${_selectedDate.year}';
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
        title: Text('Daily Attendance', style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: AppColors.primaryGreen)),
        actions: [
          IconButton(icon: const Icon(Icons.refresh, color: AppColors.primaryGreen), onPressed: _fetchData),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primaryGreen))
          : Column(
              children: [
                // Header info
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Interactive Date Picker row
                      GestureDetector(
                        onTap: _pickDate,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.calendar_today_outlined, size: 18, color: AppColors.primaryGreen),
                              const SizedBox(width: 8),
                              Text(_formattedDate, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                              const SizedBox(width: 8),
                              const Icon(Icons.arrow_drop_down, color: AppColors.textSecondary),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Stats row
                      Row(
                        children: [
                          _buildStat('PRESENT', '$_presentCount', Colors.green),
                          const SizedBox(width: 12),
                          _buildStat('ABSENT', '$_absentCount', Colors.red),
                          const SizedBox(width: 12),
                          _buildStat('TOTAL WAGE', '₹${_totalWage.toStringAsFixed(0)}', AppColors.primaryGreen),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                // Labour list
                Expanded(
                  child: _labours.isEmpty
                      ? Center(
                          child: Text('No labours to mark attendance for.',
                              style: GoogleFonts.inter(color: AppColors.textSecondary)))
                      : ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
                          itemCount: _labours.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final labour = _labours[index];
                            final status = _statusMap[labour.id!] ?? 'present';
                            return _buildAttendanceRow(labour, status);
                          },
                        ),
                ),
                // Submit button
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton.icon(
                      onPressed: _isSubmitting ? null : _submitAttendance,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryGreen,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
                      ),
                      icon: _isSubmitting
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Icon(Icons.send, size: 20),
                      label: Text(
                        _isSubmitting ? 'Saving...' : 'Save Attendance',
                        style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildAttendanceRow(LabourModel labour, String status) {
    final isPresent = status == 'present';
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 3))],
      ),
      child: Row(
        children: [
          // Avatar circle with initials
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.primaryGreen.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.center,
            child: Text(
              labour.name.isNotEmpty ? labour.name[0].toUpperCase() : 'L',
              style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primaryGreen),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(labour.name, style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.textPrimary)),
                Text('${labour.role} · ₹${labour.dailyWage.toStringAsFixed(0)}/day',
                    style: GoogleFonts.inter(fontSize: 11, color: AppColors.textSecondary)),
              ],
            ),
          ),
          // Toggle buttons
          Row(
            children: [
              _buildToggle('P', isPresent, Colors.green, () {
                setState(() => _statusMap[labour.id!] = 'present');
              }),
              const SizedBox(width: 8),
              _buildToggle('A', !isPresent, Colors.red, () {
                setState(() => _statusMap[labour.id!] = 'absent');
              }),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildToggle(String label, bool isSelected, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: isSelected ? color : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(8),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: isSelected ? Colors.white : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildStat(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6, offset: const Offset(0, 2))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.bold, color: AppColors.textSecondary, letterSpacing: 0.5)),
            const SizedBox(height: 4),
            Text(value, style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
          ],
        ),
      ),
    );
  }
}
