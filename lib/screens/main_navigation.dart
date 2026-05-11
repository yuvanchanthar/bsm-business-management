import 'package:flutter/material.dart';
import '../core/app_colors.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dashboard_screen.dart';
import 'delivery_list_screen.dart';
import 'customers_screen.dart';
import 'labour_screen.dart';
import 'reports_screen.dart';

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _currentIndex = 0; // Default to Dashboard tab

  final List<Widget> _screens = [
    const DashboardScreen(),
    const DeliveryListScreen(),
    const CustomersScreen(),
    const LabourScreen(),
    const ReportsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: _screens[_currentIndex],
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              offset: const Offset(0, -4),
              blurRadius: 10,
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) {
            setState(() {
              _currentIndex = index;
            });
          },
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.white,
          selectedItemColor: Colors.white,
          unselectedItemColor: AppColors.textSecondary,
          selectedLabelStyle: GoogleFonts.inter(
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
          unselectedLabelStyle: GoogleFonts.inter(
            fontSize: 10,
            fontWeight: FontWeight.w600,
          ),
          items: [
            _buildNavItem(Icons.dashboard_outlined, 'DASHBOARD', 0),
            _buildNavItem(Icons.local_shipping_outlined, 'DELIVERY', 1),
            _buildNavItem(Icons.people_alt, 'CUSTOMERS', 2),
            _buildNavItem(Icons.engineering_outlined, 'LABOUR', 3),
            _buildNavItem(Icons.insights, 'REPORTS', 4),
          ],
        ),
      ),
    );
  }

  BottomNavigationBarItem _buildNavItem(IconData iconData, String label, int index) {
    bool isSelected = _currentIndex == index;
    return BottomNavigationBarItem(
      icon: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        margin: const EdgeInsets.only(bottom: 4),
        decoration: isSelected
            ? BoxDecoration(
                color: AppColors.primaryGreen,
                borderRadius: BorderRadius.circular(16),
              )
            : null,
        child: Icon(
          iconData,
          color: isSelected ? Colors.white : AppColors.textSecondary,
          size: 24,
        ),
      ),
      label: label,
    );
  }
}
