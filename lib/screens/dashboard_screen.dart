import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../core/app_colors.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../controllers/auth_controller.dart';
import 'add_delivery_screen.dart';
import 'add_customer_screen.dart';
import '../widgets/stat_card.dart';
import 'login_screen.dart';
import '../services/api_service.dart';
import '../services/token_service.dart';
import '../models/dashboard_stats_model.dart';
import 'customers_screen.dart'; // Add navigation if needed
import 'labour_screen.dart'; // Add navigation if needed

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  ApiService? _apiService;
  Future<ApiService>? _apiInitFuture;
  DashboardStatsModel _stats = DashboardStatsModel.empty();
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initData();
  }

  Future<ApiService> _ensureApiService() {
    final existing = _apiService;
    if (existing != null) return Future.value(existing);

    return _apiInitFuture ??= TokenService.getInstance().then((tokenService) {
      final service = ApiService(tokenService);
      _apiService = service;
      return service;
    });
  }

  Future<void> _initData() async {
    try {
      await _ensureApiService();
      await _fetchDashboardStats();
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  Future<void> _fetchDashboardStats() async {
    try {
      if (mounted) {
        setState(() {
          _isLoading = true;
          _error = null;
        });
      }

      final api = await _ensureApiService();
      final stats = await api.getDashboardStats();
      if (mounted) {
        setState(() {
          _stats = stats;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handleLogout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Logout',
          style: GoogleFonts.inter(fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Are you sure you want to logout?',
          style: GoogleFonts.inter(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              'Cancel',
              style: GoogleFonts.inter(color: AppColors.textSecondary),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryGreen,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('Logout', style: GoogleFonts.inter()),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      await context.read<AuthController>().logout();
      if (context.mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (_) => false,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthController>().currentUser;
    final displayName = user?.name ?? 'Admin';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Row(
          children: [
            Image.asset(
              'assets/images/logo.png',
              width: 40,
              height: 40,
              fit: BoxFit.contain,
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'BSM Agro Industry',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryGreen,
                  ),
                ),
                Text(
                  displayName,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications, color: AppColors.primaryGreen),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: AppColors.textSecondary),
            tooltip: 'Logout',
            onPressed: () => _handleLogout(context),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _fetchDashboardStats,
        color: AppColors.primaryGreen,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Welcome, $displayName',
                style: GoogleFonts.inter(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 24),

              // Quick Actions Row
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () async {
                        final res = await Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const AddDeliveryScreen()));
                        if (res == true) _fetchDashboardStats();
                      },
                      child: _buildQuickAction(
                        icon: Icons.add_circle_outline,
                        label: 'Add Delivery',
                        color: AppColors.primaryGreen,
                        textColor: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: InkWell(
                      onTap: () async {
                        final res = await Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const AddCustomerScreen()));
                        if (res == true) _fetchDashboardStats();
                      },
                      child: _buildQuickAction(
                        icon: Icons.person_add_outlined,
                        label: 'Add Customer',
                        color: const Color(0xFFC8E6C9),
                        textColor: AppColors.primaryGreen,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              if (_isLoading)
                const Center(child: CircularProgressIndicator(color: AppColors.primaryGreen))
              else if (_error != null)
                Center(
                  child: Text(
                    'Error loading stats: $_error',
                    style: const TextStyle(color: Colors.red),
                  ),
                )
              else ...[
                // Custom Top Stats
                Row(
                  children: [
                    Expanded(
                      child: StatCard(
                        title: 'Total Customers',
                        value: '${_stats.totalCustomers}',
                        icon: Icons.people_alt_outlined,
                        color: const Color(0xFFE3F2FD), // Light Blue
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: StatCard(
                        title: 'Advance Pay',
                        value: '₹${_stats.advancePaymentsAmount.toStringAsFixed(0)}',
                        icon: Icons.account_balance_wallet_outlined,
                        color: const Color(0xFFE8F5E9), // Light Green
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Stats
                StatCard(
                  title: 'Today Revenue',
                  value: '₹${_stats.todayRevenue.toStringAsFixed(0)}',
                  badgeText: '${_stats.todayOrders} ORDERS TODAY',
                  icon: Icons.storefront_outlined,
                  isLarge: true,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: StatCard(
                        title: 'PENDING PAYMENTS',
                        value: '₹${_stats.pendingPaymentsAmount.toStringAsFixed(0)}',
                        badgeText: '${_stats.pendingPaymentsCount} Cust.',
                        color: const Color(0xFFFFEBEE), // Light Red for pending
                        icon: Icons.payments_outlined,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: StatCard(
                        title: 'Total Delivered',
                        value: '₹${(_stats.totalDeliveredAmount/1000).toStringAsFixed(1)}K',
                        icon: Icons.timeline,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Salary Overview
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFEBEE),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.people_outline,
                            color: Color(0xFFC62828), size: 24),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Labour Pending Salary',
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            Text(
                              '₹${_stats.labourPendingSalary.toStringAsFixed(0)}',
                              style: GoogleFonts.inter(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right, color: AppColors.textHint),
                    ],
                  ),
                ),
                
                const SizedBox(height: 24),
                if (_stats.monthlyRevenue.any((r) => r > 0)) ...[
                  Text(
                    'Monthly Revenue',
                    style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 16),
                  _buildRevenueChart(),
                ],
                
                const SizedBox(height: 24),
                if (_stats.mostPendingCustomers.isNotEmpty) ...[
                  Text(
                    'Top Pending Customers',
                    style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 16),
                  ..._stats.mostPendingCustomers.map((c) => _buildPendingCustomerCard(c)),
                ],
              ],
              const SizedBox(height: 24),

              // Operational Insights banner
              Container(
                height: 200,
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  image: const DecorationImage(
                    image: NetworkImage(
                        'https://images.unsplash.com/photo-1500382017468-9049fed747ef?ixlib=rb-1.2.1&auto=format&fit=crop&w=1000&q=80'),
                    fit: BoxFit.cover,
                  ),
                ),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.8),
                        Colors.transparent,
                      ],
                    ),
                  ),
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Operational Insights',
                        style: GoogleFonts.inter(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Review your weekly resource efficiency.',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: Colors.white.withValues(alpha: 0.8),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickAction({
    required IconData icon,
    required String label,
    required Color color,
    required Color textColor,
  }) {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: textColor, size: 20),
          const SizedBox(width: 8),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRevenueChart() {
    return Container(
      height: 250,
      padding: const EdgeInsets.only(top: 24, bottom: 8, left: 8, right: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          borderData: FlBorderData(show: false),
          gridData: const FlGridData(show: false),
          titlesData: FlTitlesData(
            leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
                  if (value >= 0 && value < 12) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(months[value.toInt()], style: GoogleFonts.inter(fontSize: 10, color: AppColors.textSecondary)),
                    );
                  }
                  return const SizedBox();
                },
              ),
            ),
          ),
          barGroups: _stats.monthlyRevenue.asMap().entries.map((e) {
            return BarChartGroupData(
              x: e.key,
              barRods: [
                BarChartRodData(
                  toY: e.value,
                  color: AppColors.primaryGreen,
                  width: 16,
                  borderRadius: BorderRadius.circular(4),
                )
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildPendingCustomerCard(PendingCustomer customer) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(customer.name, style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
          ),
          Text(
            '₹${customer.balance.toStringAsFixed(0)}',
            style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Colors.red),
          ),
        ],
      ),
    );
  }
}
