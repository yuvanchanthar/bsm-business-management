import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../core/stock_format.dart';
import '../core/app_colors.dart';
import '../models/supplier_model.dart';
import '../services/supplier_service.dart';
import '../services/token_service.dart';
import '../services/pdf_service.dart';
import '../widgets/edit_supplier_payment_dialog.dart';
import 'add_supplier_screen.dart';
import 'add_supplier_purchase_screen.dart';
import 'add_supplier_payment_screen.dart';
import 'edit_supplier_purchase_screen.dart';

class SupplierDetailScreen extends StatefulWidget {
  final String supplierId;
  final String supplierName;

  const SupplierDetailScreen({
    super.key,
    required this.supplierId,
    required this.supplierName,
  });

  @override
  State<SupplierDetailScreen> createState() => _SupplierDetailScreenState();
}

class _SupplierDetailScreenState extends State<SupplierDetailScreen>
    with SingleTickerProviderStateMixin {
  late SupplierService _service;
  SupplierLedgerModel? _ledger;
  bool _isLoading = true;
  bool _isDeleting = false;
  bool _isUpdatingStatus = false;
  String? _error;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _init();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    try {
      final ts = await TokenService.getInstance();
      _service = SupplierService(ts);
      await _fetch();
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _isLoading = false; });
    }
  }

  Future<void> _fetch() async {
    if (mounted) setState(() { _isLoading = true; _error = null; });
    try {
      final ledger = await _service.getSupplierLedger(widget.supplierId);
      if (mounted) setState(() { _ledger = ledger; _isLoading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _isLoading = false; });
    }
  }

  Future<void> _editSupplier() async {
    if (_ledger == null) return;
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddSupplierScreen(supplier: _ledger!.supplier),
      ),
    );
    if (result == true) _fetch();
  }

  Future<void> _addPurchase() async {
    if (_ledger == null) return;
    if (!_ledger!.supplier.isActive) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot add purchase for an inactive supplier', style: TextStyle(color: Colors.white)), backgroundColor: Colors.red),
      );
      return;
    }
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddSupplierPurchaseScreen(
          supplierId: widget.supplierId,
          supplierName: widget.supplierName,
          supplierIsActive: _ledger!.supplier.isActive,
        ),
      ),
    );
    if (result == true) _fetch();
  }

  Future<void> _addPayment() async {
    if (_ledger == null) return;
    if (!_ledger!.supplier.isActive) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot add payment for an inactive supplier', style: TextStyle(color: Colors.white)), backgroundColor: Colors.red),
      );
      return;
    }
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddSupplierPaymentScreen(
          supplierId: widget.supplierId,
          supplierName: widget.supplierName,
          pendingBalance: _ledger!.pendingBalance,
          supplierIsActive: _ledger!.supplier.isActive,
        ),
      ),
    );
    if (result == true) _fetch();
  }

  Future<void> _deleteSupplier() async {
    if (_ledger == null) return;
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

    setState(() => _isDeleting = true);
    try {
      await _service.deleteSupplier(widget.supplierId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Supplier deleted successfully'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isDeleting = false);
        final msg = e.toString().replaceFirst('Exception: ', '');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _updateSupplierStatus(bool isActive) async {
    if (_ledger == null) return;
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

    setState(() => _isUpdatingStatus = true);
    try {
      await _service.updateSupplierStatus(widget.supplierId, isActive);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Supplier ${actionName.toLowerCase()}d successfully'),
            backgroundColor: Colors.green,
          ),
        );
        _fetch();
      }
    } catch (e) {
      if (mounted) {
        final msg = e.toString().replaceFirst('Exception: ', '');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isUpdatingStatus = false);
    }
  }

  Future<void> _shareLedgerPdf() async {
    if (_ledger == null) return;
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Generating Ledger PDF...')),
      );
      await PdfService().generateSupplierLedgerPdf(
        supplierName: _ledger!.supplier.name,
        phone: _ledger!.supplier.phone,
        openingBalance: _ledger!.supplier.openingBalance,
        purchases: _ledger!.purchases,
        payments: _ledger!.payments,
        pendingBalance: _ledger!.pendingBalance,
        advanceBalance: _ledger!.advanceBalance,
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to generate PDF: $e'), backgroundColor: Colors.red),
      );
    }
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
        title: Text(
          widget.supplierName,
          style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Colors.purple),
        ),
        actions: [
          if (_ledger != null && !_isLoading) ...[
            IconButton(
              icon: const Icon(Icons.edit_outlined, color: Colors.purple),
              tooltip: 'Edit Supplier',
              onPressed: _isDeleting || _isUpdatingStatus ? null : _editSupplier,
            ),
            if (_isDeleting || _isUpdatingStatus)
              const Padding(
                padding: EdgeInsets.all(12),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(color: Colors.red, strokeWidth: 2),
                ),
              )
            else if (_ledger!.totalPurchased == 0 && _ledger!.totalPaid == 0)
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.red),
                tooltip: 'Delete Supplier',
                onPressed: _deleteSupplier,
              )
            else if (_ledger!.supplier.isActive)
              IconButton(
                icon: const Icon(Icons.block, color: Colors.orange),
                tooltip: 'Deactivate Supplier',
                onPressed: () => _updateSupplierStatus(false),
              )
            else
              IconButton(
                icon: const Icon(Icons.check_circle_outline, color: Colors.green),
                tooltip: 'Activate Supplier',
                onPressed: () => _updateSupplierStatus(true),
              ),
            IconButton(
              icon: const Icon(Icons.share, color: Colors.purple),
              tooltip: 'Share Ledger PDF',
              onPressed: _shareLedgerPdf,
            ),
          ],
          IconButton(
            icon: const Icon(Icons.refresh, color: AppColors.textSecondary),
            onPressed: _fetch,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.purple,
          labelColor: Colors.purple,
          unselectedLabelColor: AppColors.textSecondary,
          labelStyle: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13),
          unselectedLabelStyle: GoogleFonts.inter(fontWeight: FontWeight.w500, fontSize: 13),
          tabs: const [
            Tab(text: 'Purchases'),
            Tab(text: 'Payments'),
          ],
        ),
      ),
      body: _isLoading
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
                        ElevatedButton(onPressed: _fetch, child: const Text('Retry')),
                      ],
                    ),
                  ),
                )
              : Column(
                  children: [
                    // Finance summary card
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                      child: _buildSummaryCard(_ledger!),
                    ),
                    // Tab views
                    Expanded(
                      child: TabBarView(
                        controller: _tabController,
                        children: [
                          _PurchasesTab(
                            ledger: _ledger!,
                            service: _service,
                            onRefresh: _fetch,
                            onAdd: () async {
                              final result = await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => AddSupplierPurchaseScreen(
                                    supplierId: widget.supplierId,
                                    supplierName: widget.supplierName,
                                  ),
                                ),
                              );
                              if (result == true) _fetch();
                            },
                          ),
                          _PaymentsTab(
                            ledger: _ledger!,
                            service: _service,
                            onRefresh: _fetch,
                            onAdd: () async {
                              final result = await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => AddSupplierPaymentScreen(
                                    supplierId: widget.supplierId,
                                    supplierName: widget.supplierName,
                                    pendingBalance: _ledger!.pendingBalance,
                                  ),
                                ),
                              );
                              if (result == true) _fetch();
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
    );
  }

  Widget _buildSummaryCard(SupplierLedgerModel ledger) {
    final pending = ledger.pendingBalance;
    final advance = ledger.advanceBalance;
    final hasPending = pending > 0;
    final hasAdvance = advance > 0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 12,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        children: [
          // Supplier name & phone row
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.purple.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: Text(
                  ledger.supplier.name.isNotEmpty
                      ? ledger.supplier.name[0].toUpperCase()
                      : 'S',
                  style: GoogleFonts.inter(
                      fontSize: 22, fontWeight: FontWeight.bold, color: Colors.purple),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(ledger.supplier.name,
                        style: GoogleFonts.inter(
                            fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                    if (ledger.supplier.phone.isNotEmpty)
                      Text(ledger.supplier.phone,
                          style: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary)),
                    const SizedBox(height: 4),
                    if (ledger.supplier.isActive)
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
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: (hasAdvance ? Colors.green : (hasPending ? Colors.red : Colors.green)).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  hasAdvance ? 'ADVANCE' : (hasPending ? 'PENDING' : 'CLEAR'),
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: hasAdvance ? Colors.green : (hasPending ? Colors.red : Colors.green),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Opening Balance: ₹${ledger.supplier.openingBalance.toStringAsFixed(0)}',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textSecondary,
                ),
              ),
              if (hasAdvance)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'ADVANCE ACTIVE',
                    style: GoogleFonts.inter(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          const Divider(),
          const SizedBox(height: 12),
          // Financial stats row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _StatColumn(
                label: 'PURCHASED',
                value: '₹${ledger.totalPurchased.toStringAsFixed(0)}',
                color: Colors.blueGrey,
              ),
              _StatColumn(
                label: 'PAID',
                value: '₹${ledger.totalPaid.toStringAsFixed(0)}',
                color: Colors.green,
              ),
              if (hasAdvance)
                _StatColumn(
                  label: 'ADVANCE',
                  value: '₹${advance.toStringAsFixed(0)}',
                  color: Colors.green,
                )
              else
                _StatColumn(
                  label: 'PENDING',
                  value: '₹${pending.toStringAsFixed(0)}',
                  color: hasPending ? Colors.red : Colors.green,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Stat column widget ────────────────────────────────────────────────────────

class _StatColumn extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _StatColumn({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label,
            style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
        const SizedBox(height: 4),
        Text(value,
            style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w900, color: color)),
      ],
    );
  }
}

// ── Purchases Tab ─────────────────────────────────────────────────────────────

class _PurchasesTab extends StatefulWidget {
  final SupplierLedgerModel ledger;
  final SupplierService service;
  final VoidCallback onAdd;
  final VoidCallback onRefresh;

  const _PurchasesTab({
    required this.ledger,
    required this.service,
    required this.onAdd,
    required this.onRefresh,
  });

  @override
  State<_PurchasesTab> createState() => _PurchasesTabState();
}

class _PurchasesTabState extends State<_PurchasesTab> {
  String _filter = 'All';

  Widget _buildFilterChip(String label) {
    final isSelected = _filter == label;
    return GestureDetector(
      onTap: () => setState(() => _filter = label),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.purple : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? Colors.purple : Colors.grey.shade300),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
            color: isSelected ? Colors.white : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final allPurchases = widget.ledger.purchases;
    final purchases = allPurchases.where((p) {
      if (_filter == 'Active') return !p.isVoided;
      if (_filter == 'Voided') return p.isVoided;
      return true;
    }).toList();

    final activeCount = allPurchases.where((p) => !p.isVoided).length;
    final voidedCount = allPurchases.where((p) => p.isVoided).length;

    return Stack(
      children: [
        Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Active: $activeCount', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.purple)),
                      Text('Voided: $voidedCount', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.red)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _buildFilterChip('All'),
                      const SizedBox(width: 8),
                      _buildFilterChip('Active'),
                      const SizedBox(width: 8),
                      _buildFilterChip('Voided'),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: purchases.isEmpty
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.receipt_long_outlined,
                        size: 56, color: Colors.purple.withValues(alpha: 0.3)),
                    const SizedBox(height: 12),
                    Text('No purchases yet.',
                        style: GoogleFonts.inter(
                            fontSize: 15, color: AppColors.textSecondary)),
                  ],
                ),
              )
            : RefreshIndicator(
                onRefresh: () async => widget.onRefresh(),
                color: Colors.purple,
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                  itemCount: purchases.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, i) => _PurchaseCard(
                    purchase: purchases[i],
                    service: widget.service,
                    supplierId: widget.ledger.supplier.id ?? '',
                    onRefresh: widget.onRefresh,
                  ),
                ),
              ),
            ),
          ],
        ),
        Positioned(
          right: 20,
          bottom: 24,
          child: FloatingActionButton.extended(
            heroTag: 'add_purchase_fab',
            onPressed: widget.onAdd,
            backgroundColor: Colors.purple,
            icon: const Icon(Icons.add, color: Colors.white),
            label: Text('Add Purchase',
                style: GoogleFonts.inter(
                    fontWeight: FontWeight.bold, color: Colors.white)),
          ),
        ),
      ],
    );
  }
}

class _PurchaseCard extends StatefulWidget {
  final SupplierPurchaseModel purchase;
  final SupplierService service;
  final String supplierId;
  final VoidCallback onRefresh;
  const _PurchaseCard({
    required this.purchase,
    required this.service,
    required this.supplierId,
    required this.onRefresh,
  });
  @override
  State<_PurchaseCard> createState() => _PurchaseCardState();
}

class _PurchaseCardState extends State<_PurchaseCard> {
  bool _isLoading = false;

  Future<void> _confirmVoid() async {
    final id = widget.purchase.id;
    if (id == null) return;
    
    final reasonCtrl = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Void Purchase', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Are you sure you want to void this "${widget.purchase.item}" purchase of ₹${widget.purchase.totalAmount.toStringAsFixed(0)}?\n\nThis will reverse the inventory stock.',
                style: GoogleFonts.inter()),
            const SizedBox(height: 16),
            TextField(
              controller: reasonCtrl,
              decoration: InputDecoration(
                hintText: 'Reason for voiding (optional)',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('Cancel', style: GoogleFonts.inter(color: AppColors.textSecondary))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(context, true),
            child: Text('Void', style: GoogleFonts.inter()),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _isLoading = true);
    try {
      await widget.service.voidPurchase(id, reason: reasonCtrl.text.trim());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Purchase voided'), backgroundColor: Colors.orange));
        widget.onRefresh();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red));
      }
    }
  }

  void _showAuditDetailDialog() {
    final p = widget.purchase;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(children: [
          const Icon(Icons.info_outline, color: Colors.purple),
          const SizedBox(width: 10),
          Text('Purchase Details', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
        ]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildAuditRow('Item', p.item),
            _buildAuditRow('Amount', '₹${p.totalAmount.toStringAsFixed(0)}'),
            _buildAuditRow('Date', DateFormat('dd MMM yyyy').format(p.date)),
            if (p.createdAt != null) _buildAuditRow('Created At', DateFormat('dd MMM yyyy hh:mm a').format(p.createdAt!)),
            if (p.voidedAt != null) _buildAuditRow('Voided At', DateFormat('dd MMM yyyy hh:mm a').format(p.voidedAt!)),
            _buildAuditRow('Delete Reason', p.voidedReason?.isNotEmpty == true ? p.voidedReason! : 'N/A'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Close', style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Colors.purple)),
          ),
        ],
      ),
    );
  }

  Widget _buildAuditRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 100, child: Text(label, style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w600))),
          Expanded(child: Text(value, style: GoogleFonts.inter(fontSize: 13, color: AppColors.textPrimary, fontWeight: FontWeight.w500))),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.purchase;
    final isVoided = p.isVoided;

    final cardContent = Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isVoided ? Colors.grey.shade100 : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: isVoided ? Border.all(color: Colors.grey.shade300) : null,
        boxShadow: isVoided ? null : [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 3))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isVoided ? Colors.red.withValues(alpha: 0.1) : Colors.purple.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(isVoided ? Icons.block : Icons.shopping_bag_outlined, color: isVoided ? Colors.red : Colors.purple, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(p.item,
                        style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                    const SizedBox(height: 4),
                    Wrap(spacing: 6, runSpacing: 4, children: [
                      _Badge('${fmtStock(p.quantity)} ${p.unit}', Colors.blueGrey),
                      _Badge('₹${p.pricePerUnit.toStringAsFixed(0)}/unit', Colors.orange),
                      if (p.category != null && p.category!.isNotEmpty) _Badge(p.category!, Colors.purple),
                    ]),
                    if (p.note.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(p.note,
                          style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis),
                    ],
                    const SizedBox(height: 4),
                    Text(
                      DateFormat('dd MMM yyyy').format(p.date),
                      style: GoogleFonts.inter(fontSize: 11, color: AppColors.textHint),
                    ),
                    if (p.dueDate != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        'Due: ${DateFormat('dd MMM yyyy').format(p.dueDate!)}',
                        style: GoogleFonts.inter(fontSize: 11, color: Colors.redAccent, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '₹${p.totalAmount.toStringAsFixed(0)}',
                    style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: isVoided ? AppColors.textSecondary : Colors.purple, decoration: isVoided ? TextDecoration.lineThrough : null),
                  ),
                  const SizedBox(height: 4),
                  if (isVoided)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(6)),
                      child: Text('\u26d4 VOIDED', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white)),
                    )
                  else if (p.id != null)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        InkWell(
                          borderRadius: BorderRadius.circular(8),
                          onTap: () async {
                            final result = await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => EditSupplierPurchaseScreen(purchase: p, supplierId: widget.supplierId),
                              ),
                            );
                            if (result == true) widget.onRefresh();
                          },
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(color: Colors.purple.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(8)),
                            child: const Icon(Icons.edit_outlined, size: 16, color: Colors.purple),
                          ),
                        ),
                        const SizedBox(width: 6),
                        InkWell(
                          borderRadius: BorderRadius.circular(8),
                          onTap: _isLoading ? null : _confirmVoid,
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(color: Colors.red.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(8)),
                            child: const Icon(Icons.delete_outline, size: 16, color: Colors.red),
                          ),
                        ),
                      ],
                    ),
                  if (p.invoiceImage != null && p.invoiceImage!.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    GestureDetector(
                      onTap: () => showDialog(
                        context: context,
                        builder: (_) => Dialog(
                          backgroundColor: Colors.transparent,
                          insetPadding: const EdgeInsets.all(16),
                          child: Container(
                            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
                            clipBehavior: Clip.antiAlias,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                AppBar(
                                  backgroundColor: Colors.white,
                                  elevation: 0,
                                  title: Text('Invoice - ${p.item}', style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                                  leading: IconButton(icon: const Icon(Icons.close, color: AppColors.textPrimary), onPressed: () => Navigator.pop(context)),
                                ),
                                Container(
                                  constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.6),
                                  child: InteractiveViewer(
                                    minScale: 0.5,
                                    maxScale: 4.0,
                                    child: p.invoiceImage!.startsWith('data:')
                                        ? Image.memory(base64Decode(p.invoiceImage!.split(',')[1]), fit: BoxFit.contain)
                                        : Image.network(p.invoiceImage!, fit: BoxFit.contain, errorBuilder: (_, __, ___) => const Padding(padding: EdgeInsets.all(24), child: Text('Failed to load image'))),
                                  ),
                                ),
                                const SizedBox(height: 16),
                              ],
                            ),
                          ),
                        ),
                      ),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(color: Colors.purple.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          const Icon(Icons.receipt_long_outlined, size: 14, color: Colors.purple),
                          const SizedBox(width: 4),
                          Text('VIEW BILL', style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.purple)),
                        ]),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
          if (isVoided) ...[
            const SizedBox(height: 12),
            if (p.voidedAt != null) ...[
              Text('Voided At:', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
              Text(DateFormat('dd MMM yyyy hh:mm a').format(p.voidedAt!), style: GoogleFonts.inter(fontSize: 12, color: AppColors.textPrimary)),
              const SizedBox(height: 6),
            ],
            Text('Reason:', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
            Text(p.voidedReason?.isNotEmpty == true ? p.voidedReason! : 'No reason provided',
                style: GoogleFonts.inter(fontSize: 12, color: AppColors.textPrimary, fontStyle: FontStyle.italic)),
          ],
        ],
      ),
    );

    return Stack(
      children: [
        if (isVoided) GestureDetector(onTap: _showAuditDetailDialog, child: Opacity(opacity: 0.7, child: cardContent)) else cardContent,
        if (_isLoading)
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.7), borderRadius: BorderRadius.circular(16)),
              child: const Center(child: CircularProgressIndicator(color: Colors.purple)),
            ),
          ),
      ],
    );
  }
}



// ── Payments Tab ──────────────────────────────────────────────────────────────

class _PaymentsTab extends StatefulWidget {
  final SupplierLedgerModel ledger;
  final SupplierService service;
  final VoidCallback onAdd;
  final VoidCallback onRefresh;

  const _PaymentsTab({
    required this.ledger,
    required this.service,
    required this.onAdd,
    required this.onRefresh,
  });

  @override
  State<_PaymentsTab> createState() => _PaymentsTabState();
}

class _PaymentsTabState extends State<_PaymentsTab> {
  String _filter = 'All';

  Widget _buildFilterChip(String label) {
    final isSelected = _filter == label;
    return GestureDetector(
      onTap: () => setState(() => _filter = label),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.purple : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? Colors.purple : Colors.grey.shade300),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
            color: isSelected ? Colors.white : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final allPayments = widget.ledger.payments;
    final payments = allPayments.where((p) {
      if (_filter == 'Active') return !p.isVoided;
      if (_filter == 'Voided') return p.isVoided;
      return true;
    }).toList();

    final activeCount = allPayments.where((p) => !p.isVoided).length;
    final voidedCount = allPayments.where((p) => p.isVoided).length;

    final pending = widget.ledger.pendingBalance;
    final isOverpaid = pending < 0;

    return Stack(
      children: [
        Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Active: $activeCount', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.purple)),
                      Text('Voided: $voidedCount', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.red)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _buildFilterChip('All'),
                      const SizedBox(width: 8),
                      _buildFilterChip('Active'),
                      const SizedBox(width: 8),
                      _buildFilterChip('Voided'),
                    ],
                  ),
                ],
              ),
            ),
            // Pending balance banner
            if (pending != 0)
              Container(
                margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: (isOverpaid ? Colors.green : Colors.red).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: (isOverpaid ? Colors.green : Colors.red).withValues(alpha: 0.2),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      isOverpaid ? Icons.check_circle_outline : Icons.warning_amber_outlined,
                      color: isOverpaid ? Colors.green : Colors.red,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        isOverpaid
                            ? 'Overpaid by ₹${pending.abs().toStringAsFixed(0)}'
                            : 'Pending: ₹${pending.toStringAsFixed(0)}',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: isOverpaid ? Colors.green : Colors.red,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: payments.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.payments_outlined,
                              size: 56, color: Colors.purple.withValues(alpha: 0.3)),
                          const SizedBox(height: 12),
                          Text('No payments recorded.',
                              style: GoogleFonts.inter(fontSize: 15, color: AppColors.textSecondary)),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: () async => widget.onRefresh(),
                      color: Colors.purple,
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                        itemCount: payments.length,
                        separatorBuilder: (_, _s) => const SizedBox(height: 12),
                        itemBuilder: (context, i) => _PaymentCard(
                          payment: payments[i],
                          service: widget.service,
                          onRefresh: widget.onRefresh,
                        ),
                      ),
                    ),
            ),
          ],
        ),
        Positioned(
          right: 20,
          bottom: 24,
          child: FloatingActionButton.extended(
            heroTag: 'add_payment_fab',
            onPressed: isOverpaid ? null : widget.onAdd,
            backgroundColor: isOverpaid ? Colors.grey : Colors.purple,
            icon: const Icon(Icons.add, color: Colors.white),
            label: Text(
              isOverpaid ? 'Overpaid' : 'Add Payment',
              style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }
}

class _PaymentCard extends StatefulWidget {
  final SupplierPaymentModel payment;
  final SupplierService service;
  final VoidCallback onRefresh;
  const _PaymentCard({
    required this.payment,
    required this.service,
    required this.onRefresh,
  });

  @override
  State<_PaymentCard> createState() => _PaymentCardState();
}

class _PaymentCardState extends State<_PaymentCard> {
  bool _isLoading = false;

  Future<void> _confirmVoid() async {
    final id = widget.payment.id;
    if (id == null) return;
    
    final reasonCtrl = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Void Payment', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Are you sure you want to void this payment of ₹${widget.payment.amount.toStringAsFixed(0)}?',
                style: GoogleFonts.inter()),
            const SizedBox(height: 16),
            TextField(
              controller: reasonCtrl,
              decoration: InputDecoration(
                hintText: 'Reason for voiding (optional)',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('Cancel', style: GoogleFonts.inter(color: AppColors.textSecondary))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(context, true),
            child: Text('Void', style: GoogleFonts.inter()),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _isLoading = true);
    try {
      await widget.service.voidPayment(id, reason: reasonCtrl.text.trim());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Payment voided'), backgroundColor: Colors.orange));
        widget.onRefresh();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red));
      }
    }
  }

  void _showAuditDetailDialog() {
    final p = widget.payment;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(children: [
          const Icon(Icons.info_outline, color: Colors.purple),
          const SizedBox(width: 10),
          Text('Payment Details', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
        ]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildAuditRow('Amount', '₹${p.amount.toStringAsFixed(0)}'),
            _buildAuditRow('Date', DateFormat('dd MMM yyyy').format(p.date)),
            if (p.createdAt != null) _buildAuditRow('Created At', DateFormat('dd MMM yyyy hh:mm a').format(p.createdAt!)),
            if (p.voidedAt != null) _buildAuditRow('Voided At', DateFormat('dd MMM yyyy hh:mm a').format(p.voidedAt!)),
            _buildAuditRow('Delete Reason', p.voidedReason?.isNotEmpty == true ? p.voidedReason! : 'N/A'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Close', style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Colors.purple)),
          ),
        ],
      ),
    );
  }

  Widget _buildAuditRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 100, child: Text(label, style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w600))),
          Expanded(child: Text(value, style: GoogleFonts.inter(fontSize: 13, color: AppColors.textPrimary, fontWeight: FontWeight.w500))),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.payment;
    final isVoided = p.isVoided;

    final cardContent = Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isVoided ? Colors.grey.shade100 : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: isVoided ? Border.all(color: Colors.grey.shade300) : null,
        boxShadow: isVoided ? null : [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 3))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isVoided ? Colors.red.withValues(alpha: 0.1) : Colors.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(isVoided ? Icons.block : Icons.payments_outlined, color: isVoided ? Colors.red : Colors.green, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Payment',
                      style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                    ),
                    if (p.note.isNotEmpty)
                      Text(p.note,
                          style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                    Text(
                      DateFormat('dd MMM yyyy').format(p.date),
                      style: GoogleFonts.inter(fontSize: 11, color: AppColors.textHint),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '₹${p.amount.toStringAsFixed(0)}',
                    style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: isVoided ? AppColors.textSecondary : Colors.green, decoration: isVoided ? TextDecoration.lineThrough : null),
                  ),
                  const SizedBox(height: 8),
                  if (isVoided)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(6)),
                      child: Text('\u26d4 VOIDED', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white)),
                    )
                  else if (p.id != null)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        InkWell(
                          borderRadius: BorderRadius.circular(8),
                          onTap: () async {
                            final result = await showEditSupplierPaymentDialog(context, p);
                            if (result == true) widget.onRefresh();
                          },
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(color: Colors.green.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(8)),
                            child: const Icon(Icons.edit_outlined, size: 16, color: Colors.green),
                          ),
                        ),
                        const SizedBox(width: 6),
                        InkWell(
                          borderRadius: BorderRadius.circular(8),
                          onTap: _isLoading ? null : _confirmVoid,
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(color: Colors.red.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(8)),
                            child: const Icon(Icons.delete_outline, size: 16, color: Colors.red),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ],
          ),
          if (isVoided) ...[
            const SizedBox(height: 12),
            if (p.voidedAt != null) ...[
              Text('Voided At:', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
              Text(DateFormat('dd MMM yyyy hh:mm a').format(p.voidedAt!), style: GoogleFonts.inter(fontSize: 12, color: AppColors.textPrimary)),
              const SizedBox(height: 6),
            ],
            Text('Reason:', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
            Text(p.voidedReason?.isNotEmpty == true ? p.voidedReason! : 'No reason provided',
                style: GoogleFonts.inter(fontSize: 12, color: AppColors.textPrimary, fontStyle: FontStyle.italic)),
          ],
        ],
      ),
    );

    return Stack(
      children: [
        if (isVoided) GestureDetector(onTap: _showAuditDetailDialog, child: Opacity(opacity: 0.7, child: cardContent)) else cardContent,
        if (_isLoading)
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.7), borderRadius: BorderRadius.circular(16)),
              child: const Center(child: CircularProgressIndicator(color: Colors.purple)),
            ),
          ),
      ],
    );
  }
}

// ── Badge helper ──────────────────────────────────────────────────────────────

class _Badge extends StatelessWidget {
  final String text;
  final Color color;
  const _Badge(this.text, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(text,
          style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: color)),
    );
  }
}
