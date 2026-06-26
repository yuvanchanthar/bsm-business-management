import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/app_colors.dart';
import '../models/supplier_model.dart';
import '../services/supplier_service.dart';
import '../services/token_service.dart';
import 'supplier_detail_screen.dart';
import 'add_supplier_screen.dart';
import 'supplier_analytics_screen.dart';
import 'supplier_monthly_report_screen.dart';

class SupplierListScreen extends StatefulWidget {
  const SupplierListScreen({super.key});

  @override
  State<SupplierListScreen> createState() => _SupplierListScreenState();
}

class _SupplierListScreenState extends State<SupplierListScreen> {
  late SupplierService _service;
  List<SupplierModel> _allSuppliers = [];
  List<SupplierModel> _filtered = [];
  List<dynamic> _topSuppliers = [];
  bool _isLoading = true;
  String? _error;
  String? _deletingId; // tracks which supplier is being deleted
  String? _statusUpdatingId; // tracks which supplier is being activated/deactivated
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _init();
    _searchCtrl.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    try {
      final ts = await TokenService.getInstance();
      _service = SupplierService(ts);
      await _fetchSuppliers();
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _isLoading = false; });
    }
  }

  Future<void> _fetchSuppliers() async {
    if (mounted) setState(() { _isLoading = true; _error = null; });
    try {
      final list = await _service.getSuppliers();
      final top = await _service.getTopSuppliers();
      if (mounted) {
        setState(() {
          _allSuppliers = list;
          _filtered = list;
          _topSuppliers = top;
          _isLoading = false;
        });
      }
    } catch (e) {
      // Try to fallback to suppliers list if top endpoint fails
      try {
        final list = await _service.getSuppliers();
        if (mounted) {
          setState(() {
            _allSuppliers = list;
            _filtered = list;
            _topSuppliers = [];
            _isLoading = false;
          });
        }
      } catch (_) {
        if (mounted) setState(() { _error = e.toString(); _isLoading = false; });
      }
    }
  }

  void _onSearchChanged() {
    final q = _searchCtrl.text.toLowerCase();
    setState(() {
      _filtered = _allSuppliers.where((s) =>
          s.name.toLowerCase().contains(q) || s.phone.contains(q)).toList();
    });
  }

  Future<void> _deleteSupplier(SupplierModel supplier) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Delete Supplier',
            style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
        content: Text(
          'Are you sure you want to delete this supplier?',
          style: GoogleFonts.inter(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel',
                style: GoogleFonts.inter(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(context, true),
            child: Text('Delete', style: GoogleFonts.inter()),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    setState(() => _deletingId = supplier.id);
    try {
      await _service.deleteSupplier(supplier.id!);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Supplier deleted successfully'),
            backgroundColor: Colors.green,
          ),
        );
        _fetchSuppliers();
      }
    } catch (e) {
      if (mounted) {
        final msg = e.toString().replaceFirst('Exception: ', '');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _deletingId = null);
    }
  }

  Future<void> _updateSupplierStatus(SupplierModel supplier, bool isActive) async {
    final actionName = isActive ? 'Activate' : 'Deactivate';
    
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('$actionName Supplier',
            style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
        content: Text(
          isActive 
            ? 'Do you want to activate this supplier?'
            : 'Are you sure you want to deactivate this supplier?\n\nInactive suppliers cannot be used for new purchases or payments.',
          style: GoogleFonts.inter(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel',
                style: GoogleFonts.inter(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: isActive ? Colors.green : Colors.orange, 
                foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(context, true),
            child: Text(actionName, style: GoogleFonts.inter()),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    setState(() => _statusUpdatingId = supplier.id);
    try {
      await _service.updateSupplierStatus(supplier.id!, isActive);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Supplier ${actionName.toLowerCase()}d successfully'),
            backgroundColor: Colors.green,
          ),
        );
        _fetchSuppliers();
      }
    } catch (e) {
      if (mounted) {
        final msg = e.toString().replaceFirst('Exception: ', '');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _statusUpdatingId = null);
    }
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
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.purple.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.inventory_2_outlined, color: Colors.purple, size: 22),
            ),
            const SizedBox(width: 12),
            Text(
              'Suppliers',
              style: GoogleFonts.inter(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.purple,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: AppColors.textSecondary),
            onPressed: _fetchSuppliers,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _fetchSuppliers,
        color: Colors.purple,
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Vendor Management',
                    style: GoogleFonts.inter(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Manage your suppliers and purchase history.',
                    style: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 16),
                  // Search bar
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: Row(
                      children: [
                        const Icon(Icons.search, color: AppColors.textSecondary, size: 20),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: _searchCtrl,
                            decoration: InputDecoration(
                              hintText: 'Search by name or phone...',
                              hintStyle: GoogleFonts.inter(color: AppColors.textSecondary, fontSize: 14),
                              border: InputBorder.none,
                            ),
                            style: GoogleFonts.inter(fontSize: 14, color: AppColors.textPrimary),
                          ),
                        ),
                        if (_searchCtrl.text.isNotEmpty)
                          GestureDetector(
                            onTap: () => _searchCtrl.clear(),
                            child: const Icon(Icons.close, size: 18, color: AppColors.textSecondary),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Add Supplier button
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.purple,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      onPressed: () async {
                        final result = await Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const AddSupplierScreen()),
                        );
                        if (result == true) _fetchSuppliers();
                      },
                      icon: const Icon(Icons.add, size: 20),
                      label: Text(
                        'Add Supplier',
                        style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Analytics and Monthly Reports buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const SupplierAnalyticsScreen()),
                            );
                          },
                          icon: const Icon(Icons.bar_chart_rounded, size: 18, color: Colors.purple),
                          label: Text(
                            'Analytics',
                            style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.purple),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.purple),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const SupplierMonthlyReportScreen()),
                            );
                          },
                          icon: const Icon(Icons.picture_as_pdf_outlined, size: 18, color: Colors.purple),
                          label: Text(
                            'Monthly Reports',
                            style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.purple),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.purple),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
            // Top Suppliers Section
            if (!_isLoading && _error == null) _buildTopSuppliers(),
            // List
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: Colors.purple))
                  : _error != null
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.error_outline, size: 48, color: Colors.red),
                                const SizedBox(height: 12),
                                Text('Error: $_error',
                                    textAlign: TextAlign.center,
                                    style: GoogleFonts.inter(color: Colors.red)),
                                const SizedBox(height: 16),
                                ElevatedButton(
                                  onPressed: _fetchSuppliers,
                                  child: const Text('Retry'),
                                ),
                              ],
                            ),
                          ),
                        )
                      : _filtered.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.inventory_2_outlined,
                                      size: 64, color: Colors.purple.withValues(alpha: 0.3)),
                                  const SizedBox(height: 16),
                                  Text(
                                    _searchCtrl.text.isEmpty
                                        ? 'No suppliers yet.\nTap "Add Supplier" to begin.'
                                        : 'No suppliers match your search.',
                                    textAlign: TextAlign.center,
                                    style: GoogleFonts.inter(fontSize: 15, color: AppColors.textSecondary),
                                  ),
                                ],
                              ),
                            )
                          : ListView.separated(
                              padding: const EdgeInsets.fromLTRB(24, 0, 24, 100),
                              itemCount: _filtered.length,
                              separatorBuilder: (_, _s) => const SizedBox(height: 12),
                              itemBuilder: (context, i) => _SupplierCard(
                                supplier: _filtered[i],
                                isDeleting: _deletingId == _filtered[i].id,
                                onTap: () async {
                                  await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => SupplierDetailScreen(
                                        supplierId: _filtered[i].id!,
                                        supplierName: _filtered[i].name,
                                      ),
                                    ),
                                  );
                                  _fetchSuppliers();
                                },
                                onEdit: () async {
                                  final result = await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => AddSupplierScreen(
                                          supplier: _filtered[i]),
                                    ),
                                  );
                                  if (result == true) _fetchSuppliers();
                                },
                                onDelete: () => _deleteSupplier(_filtered[i]),
                                isUpdatingStatus: _statusUpdatingId == _filtered[i].id,
                                onActivate: () => _updateSupplierStatus(_filtered[i], true),
                                onDeactivate: () => _updateSupplierStatus(_filtered[i], false),
                              ),
                            ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopSuppliers() {
    if (_topSuppliers.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          child: Text(
            '⭐ Top Suppliers',
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        SizedBox(
          height: 75,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 18),
            itemCount: _topSuppliers.length,
            itemBuilder: (context, index) {
              final item = _topSuppliers[index];
              final name = item['name']?.toString() ?? 'Supplier';
              final total = double.tryParse(item['totalPurchase']?.toString() ?? '0') ?? 0.0;
              final rank = index + 1;
              
              return Container(
                width: 170,
                margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                  border: Border.all(color: Colors.purple.withValues(alpha: 0.1)),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 12,
                      backgroundColor: Colors.purple.shade50,
                      child: Text(
                        '$rank',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.purple,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            name,
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                           ),
                           Text(
                             '₹${total.toStringAsFixed(0)}',
                             style: GoogleFonts.inter(
                               fontSize: 12,
                               fontWeight: FontWeight.bold,
                               color: Colors.green,
                             ),
                           ),
                         ],
                       ),
                     ),
                   ],
                 ),
               );
             },
           ),
         ),
         const SizedBox(height: 12),
       ],
     );
   }
 }

// ── Supplier List Card ────────────────────────────────────────────────────────

class _SupplierCard extends StatelessWidget {
  final SupplierModel supplier;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onActivate;
  final VoidCallback onDeactivate;
  final bool isDeleting;
  final bool isUpdatingStatus;

  const _SupplierCard({
    required this.supplier,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
    required this.onActivate,
    required this.onDeactivate,
    required this.isDeleting,
    required this.isUpdatingStatus,
  });

  @override
  Widget build(BuildContext context) {
    final pending = supplier.pendingBalance;
    final advance = supplier.advanceBalance;
    final hasPending = pending > 0;
    final hasAdvance = advance > 0;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
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
          border: hasPending
              ? Border.all(color: Colors.purple.withValues(alpha: 0.15), width: 1)
              : null,
        ),
        child: Row(
          children: [
            // Avatar
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: Colors.purple.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              alignment: Alignment.center,
              child: Text(
                supplier.name.isNotEmpty ? supplier.name[0].toUpperCase() : 'S',
                style: GoogleFonts.inter(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.purple,
                ),
              ),
            ),
            const SizedBox(width: 14),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          supplier.name,
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (supplier.isActive)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.green.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '🟢 Active',
                            style: GoogleFonts.inter(fontSize: 10, color: Colors.green, fontWeight: FontWeight.bold),
                          ),
                        )
                      else
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.red.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '🔴 Inactive',
                            style: GoogleFonts.inter(fontSize: 10, color: Colors.red, fontWeight: FontWeight.bold),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    supplier.phone,
                    style: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _MiniStat(
                        label: 'Purchased',
                        value: '₹${supplier.totalPurchased.toStringAsFixed(0)}',
                        color: Colors.blueGrey,
                      ),
                      const SizedBox(width: 10),
                      _MiniStat(
                        label: 'Paid',
                        value: '₹${supplier.totalPaid.toStringAsFixed(0)}',
                        color: Colors.green,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Pending / Advance amount
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (hasAdvance) ...[
                  Text(
                    '₹${advance.toStringAsFixed(0)}',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'ADVANCE',
                      style: GoogleFonts.inter(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                  ),
                ] else ...[
                  Text(
                    '₹${pending.toStringAsFixed(0)}',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: hasPending ? Colors.red : Colors.green,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: (hasPending ? Colors.red : Colors.green).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      hasPending ? 'PENDING' : 'CLEAR',
                      style: GoogleFonts.inter(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: hasPending ? Colors.red : Colors.green,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 4),
                const Icon(Icons.chevron_right, size: 18, color: AppColors.textHint),
                const SizedBox(height: 6),
                if (isDeleting || isUpdatingStatus)
                  const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(color: Colors.purple, strokeWidth: 2),
                  )
                else
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert, color: AppColors.textSecondary, size: 20),
                    padding: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    onSelected: (val) {
                      if (val == 'edit') onEdit();
                      else if (val == 'delete') onDelete();
                      else if (val == 'activate') onActivate();
                      else if (val == 'deactivate') onDeactivate();
                    },
                    itemBuilder: (context) {
                      final hasHistory = supplier.totalPurchased > 0 || supplier.totalPaid > 0;
                      return [
                        PopupMenuItem(
                          value: 'edit',
                          child: Row(
                            children: [
                              const Icon(Icons.edit_outlined, color: Colors.purple, size: 18),
                              const SizedBox(width: 8),
                              Text('Edit', style: GoogleFonts.inter()),
                            ],
                          ),
                        ),
                        if (!hasHistory)
                          PopupMenuItem(
                            value: 'delete',
                            child: Row(
                              children: [
                                const Icon(Icons.delete_outline, color: Colors.red, size: 18),
                                const SizedBox(width: 8),
                                Text('Delete', style: GoogleFonts.inter(color: Colors.red)),
                              ],
                            ),
                          ),
                        if (hasHistory)
                          if (supplier.isActive)
                            PopupMenuItem(
                              value: 'deactivate',
                              child: Row(
                                children: [
                                  const Icon(Icons.block, color: Colors.orange, size: 18),
                                  const SizedBox(width: 8),
                                  Text('Deactivate', style: GoogleFonts.inter(color: Colors.orange)),
                                ],
                              ),
                            )
                          else
                            PopupMenuItem(
                              value: 'activate',
                              child: Row(
                                children: [
                                  const Icon(Icons.check_circle_outline, color: Colors.green, size: 18),
                                  const SizedBox(width: 8),
                                  Text('Activate', style: GoogleFonts.inter(color: Colors.green)),
                                ],
                              ),
                            ),
                      ];
                    },
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _MiniStat({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.bold, color: color)),
          Text(value,
              style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: color)),
        ],
      ),
    );
  }
}
