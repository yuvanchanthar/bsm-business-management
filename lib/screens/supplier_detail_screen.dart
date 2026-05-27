import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../core/app_colors.dart';
import '../models/supplier_model.dart';
import '../services/supplier_service.dart';
import '../services/token_service.dart';
import '../services/pdf_service.dart';
import 'add_supplier_purchase_screen.dart';
import 'add_supplier_payment_screen.dart';

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
          if (_ledger != null && !_isLoading)
            IconButton(
              icon: const Icon(Icons.share, color: Colors.purple),
              tooltip: 'Share Ledger PDF',
              onPressed: _shareLedgerPdf,
            ),
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

class _PurchasesTab extends StatelessWidget {
  final SupplierLedgerModel ledger;
  final VoidCallback onAdd;

  const _PurchasesTab({required this.ledger, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    final purchases = ledger.purchases;
    return Stack(
      children: [
        purchases.isEmpty
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.receipt_long_outlined,
                        size: 56, color: Colors.purple.withValues(alpha: 0.3)),
                    const SizedBox(height: 12),
                    Text('No purchases yet.',
                        style: GoogleFonts.inter(fontSize: 15, color: AppColors.textSecondary)),
                  ],
                ),
              )
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                itemCount: purchases.length,
                separatorBuilder: (_, _s) => const SizedBox(height: 12),
                itemBuilder: (context, i) => _PurchaseCard(purchase: purchases[i]),
              ),
        Positioned(
          right: 20,
          bottom: 24,
          child: FloatingActionButton.extended(
            heroTag: 'add_purchase_fab',
            onPressed: onAdd,
            backgroundColor: Colors.purple,
            icon: const Icon(Icons.add, color: Colors.white),
            label: Text('Add Purchase',
                style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Colors.white)),
          ),
        ),
      ],
    );
  }
}

class _PurchaseCard extends StatelessWidget {
  final SupplierPurchaseModel purchase;
  const _PurchaseCard({required this.purchase});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 3)),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.purple.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.shopping_bag_outlined, color: Colors.purple, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(purchase.item,
                    style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    _Badge(
                      '${purchase.quantity.toStringAsFixed(purchase.quantity % 1 == 0 ? 0 : 1)} ${purchase.unit}',
                      Colors.blueGrey,
                    ),
                    const SizedBox(width: 6),
                    _Badge('₹${purchase.pricePerUnit.toStringAsFixed(0)}/unit', Colors.orange),
                    if (purchase.category != null) ...[
                      const SizedBox(width: 6),
                      _Badge(purchase.category!, Colors.purple),
                    ],
                  ],
                ),
                if (purchase.note.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(purchase.note,
                      style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                ],
                const SizedBox(height: 4),
                Text(
                  DateFormat('dd MMM yyyy').format(purchase.date),
                  style: GoogleFonts.inter(fontSize: 11, color: AppColors.textHint),
                ),
                if (purchase.dueDate != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    'Due: ${DateFormat('dd MMM yyyy').format(purchase.dueDate!)}',
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
                '₹${purchase.totalAmount.toStringAsFixed(0)}',
                style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.purple),
              ),
              const SizedBox(height: 8),
              if (purchase.invoiceImage != null && purchase.invoiceImage!.isNotEmpty)
                GestureDetector(
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (_) => Dialog(
                        backgroundColor: Colors.transparent,
                        insetPadding: const EdgeInsets.all(16),
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              AppBar(
                                backgroundColor: Colors.white,
                                elevation: 0,
                                title: Text(
                                  'Invoice - ${purchase.item}',
                                  style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                                ),
                                leading: IconButton(
                                  icon: const Icon(Icons.close, color: AppColors.textPrimary),
                                  onPressed: () => Navigator.pop(context),
                                ),
                              ),
                              Container(
                                constraints: BoxConstraints(
                                  maxHeight: MediaQuery.of(context).size.height * 0.6,
                                ),
                                child: InteractiveViewer(
                                  minScale: 0.5,
                                  maxScale: 4.0,
                                  child: purchase.invoiceImage!.startsWith('data:')
                                      ? Image.memory(
                                          base64Decode(purchase.invoiceImage!.split(',')[1]),
                                          fit: BoxFit.contain,
                                        )
                                      : Image.network(
                                          purchase.invoiceImage!,
                                          fit: BoxFit.contain,
                                          errorBuilder: (_, __, ___) => Container(
                                            padding: const EdgeInsets.all(24),
                                            child: const Text('Failed to load invoice image'),
                                          ),
                                        ),
                                ),
                              ),
                              const SizedBox(height: 16),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.purple.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.receipt_long_outlined, size: 14, color: Colors.purple),
                        const SizedBox(width: 4),
                        Text(
                          'VIEW BILL',
                          style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.purple),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Payments Tab ──────────────────────────────────────────────────────────────

class _PaymentsTab extends StatelessWidget {
  final SupplierLedgerModel ledger;
  final VoidCallback onAdd;

  const _PaymentsTab({required this.ledger, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    final payments = ledger.payments;
    final pending = ledger.pendingBalance;
    final isOverpaid = pending < 0;

    return Stack(
      children: [
        Column(
          children: [
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
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                      itemCount: payments.length,
                      separatorBuilder: (_, _s) => const SizedBox(height: 12),
                      itemBuilder: (context, i) => _PaymentCard(payment: payments[i]),
                    ),
            ),
          ],
        ),
        Positioned(
          right: 20,
          bottom: 24,
          child: FloatingActionButton.extended(
            heroTag: 'add_payment_fab',
            onPressed: isOverpaid ? null : onAdd,
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

class _PaymentCard extends StatelessWidget {
  final SupplierPaymentModel payment;
  const _PaymentCard({required this.payment});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 3)),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.payments_outlined, color: Colors.green, size: 22),
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
                if (payment.note.isNotEmpty)
                  Text(payment.note,
                      style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                Text(
                  DateFormat('dd MMM yyyy').format(payment.date),
                  style: GoogleFonts.inter(fontSize: 11, color: AppColors.textHint),
                ),
              ],
            ),
          ),
          Text(
            '₹${payment.amount.toStringAsFixed(0)}',
            style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.green),
          ),
        ],
      ),
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
