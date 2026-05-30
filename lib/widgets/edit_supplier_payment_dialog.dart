import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/app_colors.dart';
import '../models/supplier_model.dart';
import '../services/supplier_service.dart';
import '../services/token_service.dart';

/// Shows a modal bottom sheet to edit an existing supplier payment.
/// Returns `true` if the payment was successfully updated.
Future<bool?> showEditSupplierPaymentDialog(
  BuildContext context,
  SupplierPaymentModel payment,
) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _EditPaymentSheet(payment: payment),
  );
}

class _EditPaymentSheet extends StatefulWidget {
  final SupplierPaymentModel payment;
  const _EditPaymentSheet({required this.payment});

  @override
  State<_EditPaymentSheet> createState() => _EditPaymentSheetState();
}

class _EditPaymentSheetState extends State<_EditPaymentSheet> {
  final _amountCtrl = TextEditingController();
  final _noteCtrl   = TextEditingController();
  late DateTime _selectedDate;
  bool _isLoading = false;

  late SupplierService _service;
  bool _serviceReady = false;

  double get _enteredAmount =>
      double.tryParse(_amountCtrl.text.trim()) ?? 0;

  @override
  void initState() {
    super.initState();
    _amountCtrl.text  = widget.payment.amount.toString();
    _noteCtrl.text    = widget.payment.note;
    _selectedDate     = widget.payment.date;
    _amountCtrl.addListener(() => setState(() {}));
    _init();
  }

  Future<void> _init() async {
    final ts = await TokenService.getInstance();
    _service = SupplierService(ts);
    if (mounted) setState(() => _serviceReady = true);
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
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
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
    if (widget.payment.id == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot edit: missing payment ID')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final fmt = (DateTime d) =>
          '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

      await _service.updatePayment(widget.payment.id!, {
        'amount': _enteredAmount,
        'note':   _noteCtrl.text.trim(),
        'date':   fmt(_selectedDate),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Payment updated successfully'),
              backgroundColor: Colors.green),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  'Failed: ${e.toString().replaceAll('Exception: ', '')}'),
              backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(24, 20, 24, bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle bar
          Center(
            child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Title
          Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child:
                  const Icon(Icons.edit_outlined, color: Colors.green, size: 20),
            ),
            const SizedBox(width: 12),
            Text('Edit Payment',
                style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary)),
          ]),
          const SizedBox(height: 24),

          // Amount field
          TextField(
            controller: _amountCtrl,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'Amount (₹)',
              labelStyle:
                  GoogleFonts.inter(color: AppColors.textSecondary),
              prefixIcon:
                  const Icon(Icons.currency_rupee, color: Colors.green),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12)),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                    const BorderSide(color: Colors.purple, width: 2),
              ),
            ),
            style: GoogleFonts.inter(
                fontSize: 18, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 16),

          // Note field
          TextField(
            controller: _noteCtrl,
            decoration: InputDecoration(
              labelText: 'Note (Optional)',
              labelStyle:
                  GoogleFonts.inter(color: AppColors.textSecondary),
              prefixIcon: const Icon(Icons.note_alt_outlined,
                  color: Colors.purple),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12)),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                    const BorderSide(color: Colors.purple, width: 2),
              ),
            ),
            style: GoogleFonts.inter(color: AppColors.textPrimary),
          ),
          const SizedBox(height: 16),

          // Date picker
          GestureDetector(
            onTap: _pickDate,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(children: [
                const Icon(Icons.calendar_today_outlined,
                    color: Colors.purple, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
                    style: GoogleFonts.inter(
                        fontSize: 15, color: AppColors.textPrimary),
                  ),
                ),
                Text('CHANGE',
                    style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.purple)),
              ]),
            ),
          ),
          const SizedBox(height: 24),

          // Save button
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: (_isLoading || !_serviceReady) ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purple,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
              icon: _isLoading
                  ? const SizedBox(
                      width: 20, height: 20,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.save_outlined),
              label: Text(
                _isLoading ? 'Saving...' : 'Update Payment',
                style: GoogleFonts.inter(
                    fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
