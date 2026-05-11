import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/app_colors.dart';
import '../models/labour_model.dart';
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
          // Ensure no duplicate labours exist by checking IDs
          final uniqueLabours = <String, LabourModel>{};
          for (var l in labours) {
            uniqueLabours[l.id ?? l.name] = l;
          }
          
          _allLabours = uniqueLabours.values.toList();
          _isLoading = false;
        });
        _onSearchChanged(); // This reliably sets _filteredLabours
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
