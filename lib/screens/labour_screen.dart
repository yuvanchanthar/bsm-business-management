import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/app_colors.dart';
import '../models/labour_model.dart';
import '../models/attendance_model.dart';
import '../services/api_service.dart';
import '../services/token_service.dart';
import '../widgets/labour_card.dart';
import 'add_labour_screen.dart';
import 'labour_details_screen.dart';
import 'salary_report_screen.dart';

class LabourScreen extends StatefulWidget {
  const LabourScreen({super.key});

  @override
  State<LabourScreen> createState() => _LabourScreenState();
}

class _LabourScreenState extends State<LabourScreen> {
  late ApiService _apiService;
  List<LabourModel> _allLabours = [];
  List<LabourModel> _filteredLabours = [];
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _initService();
    _searchController.addListener(_onSearchChanged);
  }

  Future<void> _initService() async {
    final tokenService = await TokenService.getInstance();
    _apiService = ApiService(tokenService);
    _fetchLabours();
  }

  Future<void> _fetchLabours() async {
    setState(() {
      _isLoading = true;
      _allLabours = [];
      _filteredLabours = [];
    });
    try {
      final labours = await _apiService.getLabours();
      if (mounted) {
        setState(() {
          final uniqueLabours = <String, LabourModel>{};
          for (var l in labours) {
            uniqueLabours[l.id ?? l.name] = l;
          }
          _allLabours = uniqueLabours.values.toList();
          _isLoading = false;
        });
        _onSearchChanged();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to load labours: $e')));
        setState(() => _isLoading = false);
      }
    }
  }

  void _onSearchChanged() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredLabours = _allLabours.where((l) {
        return l.name.toLowerCase().contains(query) || l.role.toLowerCase().contains(query);
      }).toList();
    });
  }

  Future<void> _deleteLabour(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Labour'),
        content: const Text('Are you sure you want to remove this labour?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await _apiService.deleteLabour(id);
      setState(() {
        _allLabours.removeWhere((l) => l.id == id);
        _filteredLabours.removeWhere((l) => l.id == id);
      });
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Labour removed')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Delete failed: $e')));
    }
  }

  // ── Mark Attendance bottom sheet ──────────────────────────────────────────

  Future<void> _showMarkAttendanceSheet(LabourModel labour) async {
    final today = DateTime.now();
    String? selectedStatus;

    // Pre-load today's existing attendance for this labour (if any)
    try {
      final records = await _apiService.getAttendanceRecords(today);
      final existing = records.where((r) => r.labourId == labour.id).firstOrNull;
      if (existing != null) selectedStatus = existing.status;
    } catch (_) {}

    if (!mounted) return;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) {
          return Container(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Labour header
                Row(
                  children: [
                    Container(
                      width: 44, height: 44,
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
                          Text(labour.name, style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                          Text(
                            '${labour.role} · ₹${labour.dailyWage.toStringAsFixed(0)}/day',
                            style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Text(
                  'Mark Attendance for Today',
                  style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 12),
                // Full Day / Half Day / Absent chips
                Row(
                  children: [
                    _buildAttendanceChip(setSheet, 'Full Day', 'full_day', selectedStatus, Colors.green, (v) => selectedStatus = v),
                    const SizedBox(width: 8),
                    _buildAttendanceChip(setSheet, 'Half Day', 'half_day', selectedStatus, Colors.orange, (v) => selectedStatus = v),
                    const SizedBox(width: 8),
                    _buildAttendanceChip(setSheet, 'Absent', 'absent', selectedStatus, Colors.red, (v) => selectedStatus = v),
                  ],
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryGreen,
                      disabledBackgroundColor: Colors.grey.shade200,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: selectedStatus == null
                        ? null
                        : () async {
                            Navigator.pop(ctx);
                            try {
                              await _apiService.submitAttendance(today, [
                                AttendanceEntry(
                                  labourId: labour.id!,
                                  name: labour.name,
                                  status: selectedStatus!,
                                  wage: labour.dailyWage,
                                ),
                              ]);
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('✅ Attendance saved successfully'),
                                    backgroundColor: Colors.green,
                                  ),
                                );
                              }
                            } catch (e) {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Failed to save: $e'), backgroundColor: Colors.red),
                                );
                              }
                            }
                          },
                    child: Text(
                      'Save Attendance',
                      style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildAttendanceChip(
    StateSetter setSheet,
    String label,
    String value,
    String? selectedStatus,
    Color color,
    Function(String) onSelect,
  ) {
    final isSelected = selectedStatus == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setSheet(() => onSelect(value)),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeInOut,
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? color : Colors.transparent,
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: isSelected ? color : Colors.grey.shade300, width: 1.5),
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

  double get _totalDailyPayroll => _allLabours.fold(0.0, (sum, l) => sum + l.dailyWage);

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: AppColors.primaryGreen,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.engineering, color: Colors.white, size: 18),
            ),
            const SizedBox(width: 12),
            Text(
              'Labour',
              style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primaryGreen),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Salary Report',
            icon: const Icon(Icons.receipt_long_outlined, color: AppColors.primaryGreen),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SalaryReportScreen()),
            ).then((_) => _fetchLabours()),
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: AppColors.primaryGreen),
            onPressed: _fetchLabours,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Workforce', style: GoogleFonts.inter(fontSize: 28, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                  const SizedBox(height: 4),
                  Text(
                    'Manage your field team and daily wage distribution.',
                    style: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary, height: 1.5),
                  ),
                  const SizedBox(height: 16),
                  // Total payroll badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.primaryGreen.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.payments_outlined, color: AppColors.primaryGreen, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          'Daily Payroll: ₹${_totalDailyPayroll.toStringAsFixed(0)}',
                          style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: AppColors.primaryGreen, fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Search Bar
                  Container(
                    decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: Row(
                      children: [
                        const Icon(Icons.search, color: AppColors.textSecondary, size: 20),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: _searchController,
                            decoration: InputDecoration(
                              hintText: 'Search by name or role...',
                              hintStyle: GoogleFonts.inter(color: AppColors.textSecondary, fontSize: 14),
                              border: InputBorder.none,
                            ),
                            style: GoogleFonts.inter(color: AppColors.textPrimary, fontSize: 14),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Add Labour Button
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryGreen,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        elevation: 0,
                      ),
                      onPressed: () async {
                        final result = await Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const AddLabourScreen()),
                        );
                        if (result == true) _fetchLabours();
                      },
                      icon: const Icon(Icons.person_add, size: 20),
                      label: Text('Add Labour', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: AppColors.primaryGreen))
                  : _filteredLabours.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.engineering, size: 64, color: AppColors.textSecondary),
                              const SizedBox(height: 16),
                              Text('No labours found', style: GoogleFonts.inter(fontSize: 16, color: AppColors.textSecondary)),
                            ],
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                          itemCount: _filteredLabours.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final labour = _filteredLabours[index];
                            return LabourCard(
                              name: labour.name,
                              role: labour.role,
                              wage: labour.dailyWage.toStringAsFixed(0),
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => LabourDetailsScreen(labour: labour)),
                              ),
                              onDelete: () => _deleteLabour(labour.id!),
                              onMarkAttendance: () => _showMarkAttendanceSheet(labour),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}
