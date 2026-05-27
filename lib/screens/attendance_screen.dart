import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/app_colors.dart';
import '../models/labour_model.dart';
import '../models/attendance_model.dart';
import '../services/api_service.dart';
import '../services/token_service.dart';

class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  late ApiService _apiService;
  List<LabourModel> _labours = [];

  // Map from labourId → 'full_day' | 'half_day' | 'absent' | null
  final Map<String, String?> _statusMap = {};
  bool _isLoading = true;
  bool _isSubmitting = false;
  DateTime _selectedDate = DateTime.now();

  // ── Status constants ──────────────────────────────────────────────────────

  static const String kFullDay  = 'full_day';
  static const String kHalfDay  = 'half_day';
  static const String kAbsent   = 'absent';

  // ── Lifecycle ─────────────────────────────────────────────────────────────

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

  // ── Data fetching ─────────────────────────────────────────────────────────

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        _apiService.getLabours(),
        _apiService.getAttendanceRecords(_selectedDate),
      ]);

      final labours          = results[0] as List<LabourModel>;
      final attendanceRecords = results[1] as List<AttendanceEntry>;

      if (mounted) {
        setState(() {
          _labours = labours;
          _statusMap.clear();

          for (final l in labours) {
            final existing =
                attendanceRecords.where((r) => r.labourId == l.id).firstOrNull;
            if (existing != null) {
              // fromJson already normalises 'present' → 'full_day'
              _statusMap[l.id!] = existing.status;
            } else {
              // Show empty selection for labours with no existing record for this date
              _statusMap[l.id!] = null;
            }
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load data: $e'), backgroundColor: Colors.red),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  // ── Date picker ───────────────────────────────────────────────────────────

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
      _fetchData();
    }
  }

  // ── Summary getters ───────────────────────────────────────────────────────

  int get _fullDayCount  => _statusMap.values.where((s) => s == kFullDay).length;
  int get _halfDayCount  => _statusMap.values.where((s) => s == kHalfDay).length;
  int get _absentCount   => _statusMap.values.where((s) => s == kAbsent).length;

  /// Full Day = 1 day, Half Day = 0.5 day, Absent = 0.
  double get _daysWorked => _fullDayCount + (_halfDayCount * 0.5);


  // ── Submit ────────────────────────────────────────────────────────────────

  Future<void> _submitAttendance() async {
    if (_labours.isEmpty) return;
    setState(() => _isSubmitting = true);

    try {
      // 1. Build entries for all labours that have a status selected
      final entries = _labours
          .where((l) => _statusMap[l.id!] != null)
          .map((l) {
        return AttendanceEntry(
          labourId: l.id!,
          name: l.name,
          status: _statusMap[l.id!]!,
          wage: l.dailyWage,
        );
      }).toList();

      if (entries.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please mark at least one labour')),
          );
        }
        setState(() => _isSubmitting = false);
        return;
      }

      await _apiService.submitAttendance(_selectedDate, entries);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Attendance saved successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }

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

  // ── Helpers ───────────────────────────────────────────────────────────────

  String get _formattedDate {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${_selectedDate.day} ${months[_selectedDate.month - 1]} ${_selectedDate.year}';
  }

  // ── Build ─────────────────────────────────────────────────────────────────

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
          'Daily Attendance',
          style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: AppColors.primaryGreen),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: AppColors.primaryGreen),
            onPressed: _fetchData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primaryGreen))
          : Column(
              children: [
                // ── Header ─────────────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Date picker
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
                              const Icon(Icons.calendar_today_outlined,
                                  size: 18, color: AppColors.primaryGreen),
                              const SizedBox(width: 8),
                              Text(
                                _formattedDate,
                                style: GoogleFonts.inter(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textPrimary),
                              ),
                              const SizedBox(width: 8),
                              const Icon(Icons.arrow_drop_down, color: AppColors.textSecondary),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // ── Stats row (4 cards) ─────────────────────────────
                      Row(
                        children: [
                          _buildStat('FULL DAYS', '$_fullDayCount', Colors.green),
                          const SizedBox(width: 8),
                          _buildStat('HALF DAYS', '$_halfDayCount', Colors.orange),
                          const SizedBox(width: 8),
                          _buildStat('ABSENT', '$_absentCount', Colors.red),
                          const SizedBox(width: 8),
                          _buildStat('WORKED', _daysWorked % 1 == 0
                              ? '${_daysWorked.toInt()}'
                              : _daysWorked.toStringAsFixed(1), AppColors.primaryGreen),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 8),

                // ── Labour list ─────────────────────────────────────────
                Expanded(
                  child: _labours.isEmpty
                      ? Center(
                          child: Text(
                            'No labours to mark attendance for.',
                            style: GoogleFonts.inter(color: AppColors.textSecondary),
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
                          itemCount: _labours.length,
                          separatorBuilder: (context, index) => const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                             final labour = _labours[index];
                             final status = _statusMap[labour.id!];
                             return _buildAttendanceRow(labour, status);
                          },
                        ),
                ),

                // ── Submit button ───────────────────────────────────────
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
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
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

  // ── Labour attendance card ───────────────────────────────────────────────

  Widget _buildAttendanceRow(LabourModel labour, String? status) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top row: avatar + name/role
          Row(
            children: [
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
                  style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryGreen),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      labour.name,
                      style: GoogleFonts.inter(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: AppColors.textPrimary),
                    ),
                    Text(
                      '${labour.role} · ₹${labour.dailyWage.toStringAsFixed(0)}/day',
                      style: GoogleFonts.inter(
                          fontSize: 11, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // ── Three-chip selector ─────────────────────────────────────
          Row(
            children: [
              _buildChip(
                label: 'Full Day',
                status: kFullDay,
                selectedStatus: status,
                selectedColor: Colors.green,
                labourId: labour.id!,
              ),
              const SizedBox(width: 8),
              _buildChip(
                label: 'Half Day',
                status: kHalfDay,
                selectedStatus: status,
                selectedColor: Colors.orange,
                labourId: labour.id!,
              ),
              const SizedBox(width: 8),
              _buildChip(
                label: 'Absent',
                status: kAbsent,
                selectedStatus: status,
                selectedColor: Colors.red,
                labourId: labour.id!,
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Selectable chip ──────────────────────────────────────────────────────

  Widget _buildChip({
    required String label,
    required String status,
    required String? selectedStatus,
    required Color selectedColor,
    required String labourId,
  }) {
    final isSelected = selectedStatus == status;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _statusMap[labourId] = status),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeInOut,
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? selectedColor : Colors.transparent,
            borderRadius: BorderRadius.circular(30),
            border: Border.all(
              color: isSelected ? selectedColor : Colors.grey.shade300,
              width: 1.5,
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isSelected ? Colors.white : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }

  // ── Stat card ─────────────────────────────────────────────────────────────

  Widget _buildStat(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: GoogleFonts.inter(
                  fontSize: 8,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textSecondary,
                  letterSpacing: 0.4),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: GoogleFonts.inter(
                  fontSize: 15, fontWeight: FontWeight.bold, color: color),
            ),
          ],
        ),
      ),
    );
  }
}
