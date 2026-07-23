import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../core/app_colors.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../core/stock_format.dart';
import '../controllers/auth_controller.dart';
import '../widgets/stat_card.dart';
import 'login_screen.dart';
import '../services/api_service.dart';
import '../services/token_service.dart';
import '../models/dashboard_stats_model.dart';
import '../models/inventory_model.dart';
import '../services/supplier_service.dart';
import 'inventory_list_screen.dart';
import 'inventory_detail_screen.dart';
import 'customers_screen.dart'; // Add navigation if needed
import 'labour_screen.dart'; // Add navigation if needed
import 'delivery_list_screen.dart';
import 'supplier_screen.dart';
import 'supplier_detail_screen.dart';
import 'settings_screen.dart';
import 'credit_sale_screen.dart';
import '../widgets/notification_bell.dart';

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
  List<InventoryItemModel> _lowStockAlerts = [];

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

      final ts = await TokenService.getInstance();
      final supplierService = SupplierService(ts);
      final lowStock = await supplierService.getLowStockAlerts();

      if (mounted) {
        setState(() {
          _stats = stats;
          _lowStockAlerts = lowStock;
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
                borderRadius: BorderRadius.circular(8),
              ),
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
            icon: const Icon(
              Icons.settings_outlined,
              color: AppColors.textSecondary,
            ),
            tooltip: 'Settings',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
          const NotificationBell(),
          IconButton(
            icon: const Icon(
              Icons.logout_rounded,
              color: AppColors.textSecondary,
            ),
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

              Text(
                'Quick Access',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 16),
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 1.3,
                children: [
                  _QuickAccessCard(
                    label: 'Customers',
                    icon: Icons.people_alt_outlined,
                    color: Colors.blue,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const CustomersScreen(),
                        ),
                      ).then((_) => _fetchDashboardStats());
                    },
                  ),
                  _QuickAccessCard(
                    label: 'Deliveries',
                    icon: Icons.local_shipping_outlined,
                    color: Colors.orange,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const DeliveryListScreen(),
                        ),
                      ).then((_) => _fetchDashboardStats());
                    },
                  ),
                  _QuickAccessCard(
                    label: 'Labour',
                    icon: Icons.engineering_outlined,
                    color: Colors.green,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const LabourScreen()),
                      ).then((_) => _fetchDashboardStats());
                    },
                  ),
                  _QuickAccessCard(
                    label: 'Suppliers',
                    icon: Icons.inventory_2_outlined,
                    color: Colors.purple,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const SupplierScreen(),
                        ),
                      ).then((_) => _fetchDashboardStats());
                    },
                  ),
                  _QuickAccessCard(
                    label: 'Inventory',
                    icon: Icons.inventory_2_outlined,
                    color: Colors.teal,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const InventoryListScreen(),
                        ),
                      ).then((_) => _fetchDashboardStats());
                    },
                  ),
                  _QuickAccessCard(
                    label: 'Credit Sales',
                    icon: Icons.receipt_long_outlined,
                    color: Colors.indigo,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const CreditSaleScreen(),
                        ),
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 24),

              if (_isLoading)
                const Center(
                  child: CircularProgressIndicator(
                    color: AppColors.primaryGreen,
                  ),
                )
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
                        value:
                            '₹${_stats.advancePaymentsAmount.toStringAsFixed(0)}',
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
                        value:
                            '₹${_stats.pendingPaymentsAmount.toStringAsFixed(0)}',
                        badgeText: '${_stats.pendingPaymentsCount} Cust.',
                        color: const Color(0xFFFFEBEE), // Light Red for pending
                        icon: Icons.payments_outlined,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: StatCard(
                        title: 'Total Delivered',
                        value:
                            '₹${(_stats.totalDeliveredAmount / 1000).toStringAsFixed(1)}K',
                        icon: Icons.timeline,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: StatCard(
                        title: 'Total Credit Sales',
                        value:
                            '₹${(_stats.totalCreditSalesAmount / 1000).toStringAsFixed(1)}K',
                        icon: Icons.receipt_long_outlined,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: StatCard(
                        title: 'Total Business',
                        value:
                            '₹${(_stats.totalBusinessAmount / 1000).toStringAsFixed(1)}K',
                        icon: Icons.analytics_outlined,
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
                        child: const Icon(
                          Icons.people_outline,
                          color: Color(0xFFC62828),
                          size: 24,
                        ),
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
                      const Icon(
                        Icons.chevron_right,
                        color: AppColors.textHint,
                      ),
                    ],
                  ),
                ),

                if (_lowStockAlerts.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  Text(
                    'Low Stock Alerts',
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ..._lowStockAlerts.map(
                    (alert) => _buildLowStockAlertCard(alert),
                  ),
                ],

                if (_stats.supplierUpcomingDue.isNotEmpty ||
                    _stats.supplierOverdue.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  Text(
                    'Supplier Due Alerts',
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ..._stats.supplierOverdue.map(
                    (alert) => _buildSupplierAlertCard(alert, isOverdue: true),
                  ),
                  ..._stats.supplierUpcomingDue.map(
                    (alert) => _buildSupplierAlertCard(alert, isOverdue: false),
                  ),
                ],

                const SizedBox(height: 24),

                if (_stats.monthlyRevenue.any((r) => r > 0)) ...[
                  Text(
                    'Monthly Revenue',
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildRevenueChart(),
                ],

                const SizedBox(height: 24),
                if (_stats.mostPendingCustomers.isNotEmpty) ...[
                  Text(
                    'Top Pending Customers',
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ..._stats.mostPendingCustomers.map(
                    (c) => _buildPendingCustomerCard(c),
                  ),
                ],
              ],
              const SizedBox(height: 24),

              // Operational Insights banner
              // Container(
              //   height: 200,
              //   width: double.infinity,
              //   decoration: BoxDecoration(
              //     borderRadius: BorderRadius.circular(24),
              //     image: const DecorationImage(
              //       image: NetworkImage(
              //           'https://images.unsplash.com/photo-1500382017468-9049fed747ef?ixlib=rb-1.2.1&auto=format&fit=crop&w=1000&q=80'),
              //       fit: BoxFit.cover,
              //     ),
              //   ),
              //   child: Container(
              //     decoration: BoxDecoration(
              //       borderRadius: BorderRadius.circular(24),
              //       gradient: LinearGradient(
              //         begin: Alignment.bottomCenter,
              //         end: Alignment.topCenter,
              //         colors: [
              //           Colors.black.withValues(alpha: 0.8),
              //           Colors.transparent,
              //         ],
              //       ),
              //     ),
              //     padding: const EdgeInsets.all(24),
              //     child: Column(
              //       mainAxisAlignment: MainAxisAlignment.end,
              //       crossAxisAlignment: CrossAxisAlignment.start,
              //       children: [
              //         Text(
              //           'Operational Insights',
              //           style: GoogleFonts.inter(
              //             fontSize: 20,
              //             fontWeight: FontWeight.bold,
              //             color: Colors.white,
              //           ),
              //         ),
              //         const SizedBox(height: 4),
              //         Text(
              //           'Review your weekly resource efficiency.',
              //           style: GoogleFonts.inter(
              //             fontSize: 14,
              //             color: Colors.white.withValues(alpha: 0.8),
              //           ),
              //         ),
              //       ],
              //     ),
              //   ),
              // ),
              const SizedBox(height: 24),
            ],
          ),
        ),
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
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          borderData: FlBorderData(show: false),
          gridData: const FlGridData(show: false),
          titlesData: FlTitlesData(
            leftTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  const months = [
                    'Jan',
                    'Feb',
                    'Mar',
                    'Apr',
                    'May',
                    'Jun',
                    'Jul',
                    'Aug',
                    'Sep',
                    'Oct',
                    'Nov',
                    'Dec',
                  ];
                  if (value >= 0 && value < 12) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        months[value.toInt()],
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          color: AppColors.textSecondary,
                        ),
                      ),
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
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildSupplierAlertCard(
    SupplierDueAlert alert, {
    required bool isOverdue,
  }) {
    final color = isOverdue ? Colors.red : Colors.orange;
    String alertText = '';

    final today = DateTime.now();
    final todayMidnight = DateTime(today.year, today.month, today.day);
    final due = DateTime.tryParse(alert.dueDate);
    if (due != null) {
      final dueMidnight = DateTime(due.year, due.month, due.day);
      final diff = dueMidnight.difference(todayMidnight).inDays;
      if (diff < 0) {
        final days = diff.abs();
        alertText =
            '${alert.supplierName} overdue by $days day${days > 1 ? "s" : ""}';
      } else if (diff == 1) {
        alertText = '${alert.supplierName} payment due tomorrow';
      } else if (diff == 0) {
        alertText = '${alert.supplierName} payment due today';
      } else {
        alertText = '${alert.supplierName} payment due in $diff days';
      }
    } else {
      alertText = '${alert.supplierName} payment due soon';
    }

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => SupplierDetailScreen(
              supplierId: alert.supplierId,
              supplierName: alert.supplierName,
            ),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: color, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    alertText,
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                      fontSize: 14,
                    ),
                  ),
                  if (alert.itemName.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      'Item: ${alert.itemName} • Due: ₹${alert.amountDue.toStringAsFixed(0)}',
                      style: GoogleFonts.inter(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: color, size: 18),
          ],
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
            child: Text(
              customer.name,
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          Text(
            '₹${customer.balance.toStringAsFixed(0)}',
            style: GoogleFonts.inter(
              fontWeight: FontWeight.bold,
              color: Colors.red,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLowStockAlertCard(InventoryItemModel alert) {
    final color = Colors.red;
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => InventoryDetailScreen(
              itemId: alert.id!,
              itemName: alert.itemName,
            ),
          ),
        ).then((_) => _fetchDashboardStats());
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: color, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '⚠ ${alert.itemName}',
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Remaining: ${fmtStock(alert.currentStock)} ${alert.unit}',
                    style: GoogleFonts.inter(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: color, size: 18),
          ],
        ),
      ),
    );
  }
}

class _QuickAccessCard extends StatefulWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _QuickAccessCard({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  State<_QuickAccessCard> createState() => _QuickAccessCardState();
}

class _QuickAccessCardState extends State<_QuickAccessCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.95,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scaleAnimation,
      child: GestureDetector(
        onTapDown: (_) => _controller.forward(),
        onTapUp: (_) {
          _controller.reverse();
          widget.onTap();
        },
        onTapCancel: () => _controller.reverse(),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: widget.color.withValues(alpha: 0.08),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
            border: Border.all(
              color: widget.color.withValues(alpha: 0.12),
              width: 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: widget.color.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(widget.icon, color: widget.color, size: 28),
              ),
              const SizedBox(height: 12),
              Text(
                widget.label,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
