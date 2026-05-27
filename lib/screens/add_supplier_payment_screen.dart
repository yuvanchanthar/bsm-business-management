import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/app_colors.dart';
import '../models/supplier_model.dart';
import '../services/supplier_service.dart';
import '../services/token_service.dart';

class AddSupplierPaymentScreen extends StatefulWidget {
  final String supplierId;
  final String supplierName;
  final double pendingBalance;

  const AddSupplierPaymentScreen({
    super.key,
    required this.supplierId,
    required this.supplierName,
    required this.pendingBalance,
  });

  @override
  State<AddSupplierPaymentScreen> createState() => _AddSupplierPaymentScreenState();
}

class _AddSupplierPaymentScreenState extends State<AddSupplierPaymentScreen> {
  final _amountCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  bool _isLoading = false;
  late SupplierService _service;

  double get _enteredAmount => double.tryParse(_amountCtrl.text.trim()) ?? 0;
  double get _remaining => widget.pendingBalance - _enteredAmount;
  bool get _isOverpaid => _enteredAmount > widget.pendingBalance && widget.pendingBalance > 0;

  @override
  void initState() {
    super.initState();
    _amountCtrl.addListener(() => setState(() {}));
    _init();
  }

  Future<void> _init() async {
    final ts = await TokenService.getInstance();
    _service = SupplierService(ts);
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(primary: Colors.purple),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _save() async {
    if (_enteredAmount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid amount')),
      );
      return;
    }
    if (_isOverpaid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Amount exceeds pending balance'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final payment = SupplierPaymentModel(
        supplierId: widget.supplierId,
        amount: _enteredAmount,
        note: _noteCtrl.text.trim(),
        date: _selectedDate,
      );
      await _service.addPayment(payment);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Payment recorded'), backgroundColor: Colors.green),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final amountText = _amountCtrl.text.trim();

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
          'Add Payment',
          style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Colors.purple),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Supplier badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.purple.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.inventory_2_outlined, size: 16, color: Colors.purple),
                  const SizedBox(width: 6),
                  Text(widget.supplierName,
                      style: GoogleFonts.inter(
                          fontSize: 13, fontWeight: FontWeight.bold, color: Colors.purple)),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Current pending card
            _BalanceCard(
              label: 'Pending Balance',
              value: widget.pendingBalance,
              color: widget.pendingBalance > 0 ? Colors.red : Colors.green,
            ),
            const SizedBox(height: 16),

            // Amount field
            TextField(
              controller: _amountCtrl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Amount to Pay (₹)',
                labelStyle: GoogleFonts.inter(color: AppColors.textSecondary),
                prefixIcon: const Icon(Icons.currency_rupee, color: Colors.purple),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.purple, width: 2),
                ),
              ),
              style: GoogleFonts.inter(fontSize: 18, color: AppColors.textPrimary),
            ),

            // Live preview
            if (amountText.isNotEmpty) ...[
              const SizedBox(height: 12),
              _BalanceCard(
                label: 'Payment Amount',
                value: _enteredAmount,
                color: _isOverpaid ? Colors.red : Colors.purple,
              ),
              const SizedBox(height: 8),
              _BalanceCard(
                label: 'Remaining After Payment',
                value: _remaining,
                color: _remaining < 0 ? Colors.red : Colors.green,
              ),
              if (_isOverpaid)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 16),
                      const SizedBox(width: 6),
                      Text(
                        'Exceeds pending balance — payment blocked',
                        style: GoogleFonts.inter(
                            color: Colors.red, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
            ],

            const SizedBox(height: 16),
            TextField(
              controller: _noteCtrl,
              decoration: InputDecoration(
                labelText: 'Note (Optional)',
                labelStyle: GoogleFonts.inter(color: AppColors.textSecondary),
                prefixIcon: const Icon(Icons.note_alt_outlined, color: Colors.purple),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.purple, width: 2),
                ),
              ),
            ),

            const SizedBox(height: 16),
            // Date picker
            GestureDetector(
              onTap: _pickDate,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today_outlined, color: Colors.purple, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
                        style: GoogleFonts.inter(fontSize: 15, color: AppColors.textPrimary),
                      ),
                    ),
                    Text('CHANGE',
                        style: GoogleFonts.inter(
                            fontSize: 11, fontWeight: FontWeight.bold, color: Colors.purple)),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton.icon(
                onPressed: (_isLoading || _isOverpaid) ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isOverpaid ? Colors.grey : Colors.purple,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
                icon: _isLoading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.payments_outlined),
                label: Text(
                  _isLoading
                      ? 'Saving...'
                      : _isOverpaid
                          ? 'Overpaid — Blocked'
                          : 'Record Payment',
                  style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

// ── Balance preview card ──────────────────────────────────────────────────────

class _BalanceCard extends StatelessWidget {
  final String label;
  final double value;
  final Color color;

  const _BalanceCard({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: GoogleFonts.inter(
                  fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
          Text(
            '₹${value.abs().toStringAsFixed(0)}',
            style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold, color: color),
          ),
        ],
      ),
    );
  }
}
