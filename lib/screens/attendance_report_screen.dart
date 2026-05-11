import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/app_colors.dart';
import '../models/attendance_model.dart';
import '../services/api_service.dart';
import '../services/token_service.dart';

class AttendanceReportScreen extends StatefulWidget {
  const AttendanceReportScreen({super.key});

  @override
  State<AttendanceReportScreen> createState() => _AttendanceReportScreenState();
}

class _AttendanceReportScreenState extends State<AttendanceReportScreen> {
  late ApiService _apiService;
  DateTime _selectedDate = DateTime.now();
  AttendanceReport? _report;
  bool _isLoading = false;
  bool _serviceReady = false;

  @override
  void initState() {
    super.initState();
    _initService();
  }

  Future<void> _initService() async {
    final tokenService = await TokenService.getInstance();
    _apiService = ApiService(tokenService);
    setState(() => _serviceReady = true);
    _fetchReport();
  }

  Future<void> _fetchReport() async {
    if (!_serviceReady) return;
    setState(() => _isLoading = true);
    try {
      final report = await _apiService.getAttendanceReport(_selectedDate);
      if (mounted) setState(() { _report = report; _isLoading = false; });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
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
      _fetchReport();
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
        title: Text('Attendance Report', style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: AppColors.primaryGreen)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Report Summary', style: GoogleFonts.inter(fontSize: 28, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
            const SizedBox(height: 6),
            Text('View attendance summary for a specific date.', style: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary)),
            const SizedBox(height: 24),

            // Date selector card
            GestureDetector(
              onTap: _pickDate,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.primaryGreen.withValues(alpha: 0.4), width: 1.5),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 3))],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primaryGreen.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.calendar_today, color: AppColors.primaryGreen, size: 20),
                    ),
                    const SizedBox(width: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Selected Date', style: GoogleFonts.inter(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
                        Text(_formattedDate, style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                      ],
                    ),
                    const Spacer(),
                    const Icon(Icons.chevron_right, color: AppColors.textSecondary),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 28),

            if (_isLoading)
              const Center(child: Padding(
                padding: EdgeInsets.all(32),
                child: CircularProgressIndicator(color: AppColors.primaryGreen),
              ))
            else if (_report == null)
              Center(child: Text('No data. Pick a date.', style: GoogleFonts.inter(color: AppColors.textSecondary)))
            else ...[
              _buildReportCard(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildReportCard() {
    final r = _report!;
    final attendanceRate = r.totalLabours == 0 ? 0.0 : r.presentCount / r.totalLabours;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('SUMMARY', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textSecondary, letterSpacing: 1.2)),
        const SizedBox(height: 12),
        // 2x2 grid of stat cards
        Row(
          children: [
            _buildStatTile('TOTAL', '${r.totalLabours}', AppColors.textPrimary, Icons.people_outline),
            const SizedBox(width: 12),
            _buildStatTile('PRESENT', '${r.presentCount}', Colors.green, Icons.check_circle_outline),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            _buildStatTile('ABSENT', '${r.absentCount}', Colors.red, Icons.cancel_outlined),
            const SizedBox(width: 12),
            _buildStatTile('TOTAL WAGE', '₹${r.totalWage.toStringAsFixed(0)}', AppColors.primaryGreen, Icons.payments_outlined),
          ],
        ),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 3))],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Attendance Rate', style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14)),
                  Text('${(attendanceRate * 100).toStringAsFixed(1)}%',
                      style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: AppColors.primaryGreen, fontSize: 14)),
                ],
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: attendanceRate,
                  minHeight: 10,
                  backgroundColor: Colors.grey.shade200,
                  valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primaryGreen),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatTile(String label, String value, Color color, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 3))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(height: 10),
            Text(label, style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
            const SizedBox(height: 4),
            Text(value, style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.bold, color: color)),
          ],
        ),
      ),
    );
  }
}
