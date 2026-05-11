import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/app_colors.dart';
import '../models/labour_model.dart';
import 'attendance_screen.dart';
import 'attendance_report_screen.dart';
import 'labour_detail_report_screen.dart';
import 'add_payment_screen.dart';

class LabourDetailsScreen extends StatelessWidget {
  final LabourModel labour;
  const LabourDetailsScreen({super.key, required this.labour});

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
        title: Text('Labour Details', style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: AppColors.primaryGreen)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Column(
          children: [
            // Profile Card
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 4))],
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      // Avatar initials
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: AppColors.primaryGreen.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          (labour.name.isNotEmpty) ? labour.name[0].toUpperCase() : 'L',
                          style: GoogleFonts.inter(fontSize: 28, fontWeight: FontWeight.bold, color: AppColors.primaryGreen),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    labour.name,
                                    style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(color: AppColors.wholesaleBadgeBg, borderRadius: BorderRadius.circular(8)),
                                  child: Text('ACTIVE', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.wholesaleBadgeText)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(labour.role, style: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  // Info chips
                  Row(
                    children: [
                      _buildInfoChip(Icons.phone_outlined, labour.phone),
                      const SizedBox(width: 12),
                      _buildInfoChip(Icons.payments_outlined, '₹${labour.dailyWage.toStringAsFixed(0)}/day'),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Daily Wage card
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.primaryGreen,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [BoxShadow(color: AppColors.primaryGreen.withValues(alpha: 0.3), blurRadius: 15, offset: const Offset(0, 8))],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('DAILY WAGE', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white.withValues(alpha: 0.8), letterSpacing: 1)),
                      const SizedBox(height: 6),
                      Text('₹${labour.dailyWage.toStringAsFixed(0)}', style: GoogleFonts.inter(fontSize: 36, fontWeight: FontWeight.bold, color: Colors.white)),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(14)),
                    child: const Icon(Icons.payments, color: Colors.white, size: 28),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Quick Actions
            Row(
              children: [
                Expanded(
                  child: _buildActionButton(
                    context,
                    icon: Icons.calendar_today_outlined,
                    label: 'ATTENDANCE',
                    color: AppColors.primaryGreen,
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const AttendanceScreen())),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildActionButton(
                    context,
                    icon: Icons.account_balance_wallet_outlined,
                    label: 'SALARY',
                    color: Colors.indigo,
                    onTap: () => Navigator.push(context, MaterialPageRoute(
                      builder: (context) => LabourDetailReportScreen(labourId: labour.id!, labourName: labour.name),
                    )),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildActionButton(
                    context,
                    icon: Icons.payments_outlined,
                    label: 'PAY NOW',
                    color: Colors.green,
                    onTap: () => Navigator.push(context, MaterialPageRoute(
                      builder: (context) => AddPaymentScreen(labourId: labour.id!, labourName: labour.name),
                    )),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 48),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String label) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(icon, size: 14, color: AppColors.primaryGreen),
            const SizedBox(width: 6),
            Expanded(
              child: Text(label, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary), overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton(BuildContext context, {required IconData icon, required String label, required Color color, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 12),
            Text(label, textAlign: TextAlign.center, style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
          ],
        ),
      ),
    );
  }
}
