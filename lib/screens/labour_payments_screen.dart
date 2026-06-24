import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../core/app_colors.dart';
import '../models/payment_model.dart';
import '../services/api_service.dart';
import '../services/token_service.dart';
import 'add_payment_screen.dart';

class LabourPaymentsScreen extends StatefulWidget {
  final String labourId;
  final String labourName;
  const LabourPaymentsScreen({super.key, required this.labourId, required this.labourName});

  @override
  State<LabourPaymentsScreen> createState() => _LabourPaymentsScreenState();
}

class _LabourPaymentsScreenState extends State<LabourPaymentsScreen> {
  late ApiService _apiService;
  List<PaymentModel> _payments = [];
  bool _isLoading = true;
  String? _errorMessage;
  String _paymentFilter = 'All'; // 'All', 'Active', 'Voided'

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final tokenService = await TokenService.getInstance();
    _apiService = ApiService(tokenService);
    _fetchPayments();
  }

  Future<void> _fetchPayments() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final r = await _apiService.getLabourDetailReport(widget.labourId);
      if (mounted) {
        setState(() {
          _payments = r.payments;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.toString().replaceAll('Exception: ', '');
        });
      }
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
        title: Text('${widget.labourName} - Payments', 
          style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: AppColors.primaryGreen, fontSize: 18)
        ),
        actions: [
          IconButton(icon: const Icon(Icons.refresh, color: AppColors.primaryGreen), onPressed: _fetchPayments),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primaryGreen,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: Text('Add Payment', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => AddPaymentScreen(labourId: widget.labourId, labourName: widget.labourName)),
          );
          if (result == true) {
            _fetchPayments();
          }
        },
      ),
      body: _isLoading && _payments.isEmpty
          ? const Center(child: CircularProgressIndicator(color: AppColors.primaryGreen))
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline, color: Colors.red, size: 48),
                      const SizedBox(height: 16),
                      Text('$_errorMessage', style: GoogleFonts.inter(fontSize: 16, color: AppColors.textSecondary)),
                    ],
                  ),
                )
              : _buildPaymentsList(),
    );
  }

  Widget _buildPaymentsList() {
    final activeCount = _payments.where((p) => !p.isVoided).length;
    final voidedCount = _payments.where((p) => p.isVoided).length;

    final filteredPayments = _payments.where((p) {
      if (_paymentFilter == 'Active') return !p.isVoided;
      if (_paymentFilter == 'Voided') return p.isVoided;
      return true;
    }).toList();

    return Column(
      children: [
        // Filter & Summary Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
          ),
          child: Column(
            children: [
              // Summary Counters
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Active Payments: $activeCount', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.primaryGreen)),
                  Text('Voided Payments: $voidedCount', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.red)),
                ],
              ),
              const SizedBox(height: 12),
              // Filter Chips
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
        // List
        Expanded(
          child: filteredPayments.isEmpty
              ? Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.payments_outlined, size: 56, color: AppColors.textSecondary),
                    const SizedBox(height: 12),
                    Text('No $_paymentFilter payments', style: GoogleFonts.inter(color: AppColors.textSecondary, fontSize: 15)),
                  ]),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 100),
                  itemCount: filteredPayments.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, i) {
                    final p = filteredPayments[i];
                    if (p.isVoided) return _buildVoidedPaymentCard(p);
                    return _buildActivePaymentCard(p);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildFilterChip(String label) {
    final isSelected = _paymentFilter == label;
    return GestureDetector(
      onTap: () => setState(() => _paymentFilter = label),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryGreen : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? AppColors.primaryGreen : Colors.grey.shade300),
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

  // ── Active payment card ───────────────────────────────────────────────────
  Widget _buildActivePaymentCard(PaymentModel p) {
    final displayDate = p.createdAt ?? p.date;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              width: 42, height: 42,
              decoration: BoxDecoration(color: Colors.green.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.payments, color: Colors.green, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('\u20b9${p.amount.toStringAsFixed(0)}',
                  style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
              if (p.note != null && p.note!.trim().isNotEmpty)
                Text(p.note!, style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary))
              else
                Text('No note', style: GoogleFonts.inter(fontSize: 12, color: AppColors.textHint, fontStyle: FontStyle.italic)),
            ])),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(color: Colors.green.shade100, borderRadius: BorderRadius.circular(6)),
              child: Text('Active', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.green.shade700)),
            ),
          ]),
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _showEditPaymentSheet(p),
                icon: const Icon(Icons.edit_outlined, size: 15),
                label: Text('Edit', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primaryGreen,
                  side: const BorderSide(color: AppColors.primaryGreen),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _showVoidConfirmDialog(p),
                icon: const Icon(Icons.delete_outline, size: 15),
                label: Text('Void', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  side: const BorderSide(color: Colors.red),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                ),
              ),
            ),
          ]),
        ],
      ),
    );
  }

  // ── Voided payment card ──────────────────────────────────────────────────
  Widget _buildVoidedPaymentCard(PaymentModel p) {
    final displayDate = p.createdAt ?? p.date;
    return GestureDetector(
      onTap: () => _showAuditDetailDialog(p),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Opacity(
          opacity: 0.7,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Container(
                  width: 42, height: 42,
                  decoration: BoxDecoration(color: Colors.red.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.block, color: Colors.red, size: 20),
                ),
                const SizedBox(width: 14),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('\u20b9${p.amount.toStringAsFixed(0)}',
                      style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary, decoration: TextDecoration.lineThrough)),
                  Text(DateFormat('dd MMM yyyy').format(displayDate),
                      style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary)),
                ])),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(6)),
                  child: Text('\u26d4 VOIDED', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white)),
                ),
              ]),
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
          ),
        ),
      ),
    );
  }

  void _showAuditDetailDialog(PaymentModel p) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(children: [
          const Icon(Icons.info_outline, color: AppColors.primaryGreen),
          const SizedBox(width: 10),
          Text('Payment Details', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
        ]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildAuditRow('Amount', '\u20b9${p.amount.toStringAsFixed(0)}'),
            _buildAuditRow('Date', DateFormat('dd MMM yyyy').format(p.date)),
            if (p.createdAt != null) _buildAuditRow('Created At', DateFormat('dd MMM yyyy hh:mm a').format(p.createdAt!)),
            if (p.voidedAt != null) _buildAuditRow('Voided At', DateFormat('dd MMM yyyy hh:mm a').format(p.voidedAt!)),
            _buildAuditRow('Delete Reason', p.voidedReason?.isNotEmpty == true ? p.voidedReason! : 'N/A'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Close', style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: AppColors.primaryGreen)),
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

  // ── Edit Payment sheet ────────────────────────────────────────────────────
  Future<void> _showEditPaymentSheet(PaymentModel p) async {
    if (p.id == null) return;
    final amountCtrl = TextEditingController(text: p.amount.toStringAsFixed(0));
    final noteCtrl   = TextEditingController(text: p.note ?? '');
    DateTime selectedDate = p.date;
    final formKey = GlobalKey<FormState>();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: StatefulBuilder(builder: (ctx, setSheet) {
          return Container(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Form(
              key: formKey,
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Edit Payment', style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                const SizedBox(height: 20),
                // Amount
                Text('Amount (₹)', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
                const SizedBox(height: 6),
                TextFormField(
                  controller: amountCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
                  decoration: InputDecoration(
                    prefixText: '₹ ',
                    filled: true, fillColor: AppColors.background,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: AppColors.border)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: AppColors.border)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.primaryGreen, width: 2)),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Amount is required';
                    if (double.tryParse(v) == null || double.parse(v) <= 0) return 'Enter valid amount';
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                // Date
                Text('Payment Date', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
                const SizedBox(height: 6),
                GestureDetector(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: ctx,
                      initialDate: selectedDate,
                      firstDate: DateTime(2024),
                      lastDate: DateTime.now(),
                      builder: (c, child) => Theme(data: Theme.of(c).copyWith(colorScheme: const ColorScheme.light(primary: AppColors.primaryGreen)), child: child!),
                    );
                    if (picked != null) setSheet(() => selectedDate = picked);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                    decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.border)),
                    child: Row(children: [
                      const Icon(Icons.calendar_today_outlined, size: 18, color: AppColors.primaryGreen),
                      const SizedBox(width: 10),
                      Text(DateFormat('dd MMM yyyy').format(selectedDate), style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600)),
                    ]),
                  ),
                ),
                const SizedBox(height: 14),
                // Note
                Text('Note (Optional)', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
                const SizedBox(height: 6),
                TextFormField(
                  controller: noteCtrl,
                  maxLines: 2,
                  decoration: InputDecoration(
                    hintText: 'e.g. Weekly payment...',
                    filled: true, fillColor: AppColors.background,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: AppColors.border)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: AppColors.border)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.primaryGreen, width: 2)),
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryGreen,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () async {
                      if (!formKey.currentState!.validate()) return;
                      Navigator.pop(ctx);
                      setState(() => _isLoading = true);
                      try {
                        await _apiService.updateLabourPayment(
                          p.id!,
                          amount: double.parse(amountCtrl.text.trim()),
                          date: selectedDate,
                          note: noteCtrl.text.trim(),
                        );
                        await _fetchPayments();
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('✅ Payment updated successfully'), backgroundColor: Colors.green),
                          );
                        }
                      } catch (e) {
                        if (mounted) {
                          setState(() => _isLoading = false);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Failed to update: $e'), backgroundColor: Colors.red),
                          );
                        }
                      }
                    },
                    child: Text('Save Changes', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                  ),
                ),
              ]),
            ),
          );
        }),
      ),
    );
  }

  // ── Void confirmation dialog ──────────────────────────────────────────────
  Future<void> _showVoidConfirmDialog(PaymentModel p) async {
    if (p.id == null) return;
    final reasonCtrl = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(children: [
          const Icon(Icons.delete_outline, color: Colors.red),
          const SizedBox(width: 10),
          Text('Void Payment', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
        ]),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Are you sure you want to void this payment of ₹${p.amount.toStringAsFixed(0)}?',
              style: GoogleFonts.inter(fontSize: 14, color: AppColors.textSecondary)),
          const SizedBox(height: 16),
          Text('Reason (Optional)', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
          const SizedBox(height: 6),
          TextField(
            controller: reasonCtrl,
            maxLines: 2,
            decoration: InputDecoration(
              hintText: 'Reason for voiding...',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Cancel', style: GoogleFonts.inter(color: AppColors.textSecondary))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Void Payment', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    setState(() => _isLoading = true);
    try {
      await _apiService.voidLabourPayment(p.id!, reason: reasonCtrl.text.trim());
      await _fetchPayments();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Payment voided successfully'), backgroundColor: Colors.orange),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to void: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  // ── Restore confirmation dialog ───────────────────────────────────────────
  Future<void> _showRestoreConfirmDialog(PaymentModel p) async {
    if (p.id == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(children: [
          const Icon(Icons.restore, color: Colors.orange),
          const SizedBox(width: 10),
          Text('Restore Payment', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
        ]),
        content: Text(
          'Restore this payment of ₹${p.amount.toStringAsFixed(0)}?\nThis will add it back to the payment history.',
          style: GoogleFonts.inter(fontSize: 14, color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Cancel', style: GoogleFonts.inter(color: AppColors.textSecondary))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange.shade700, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Restore', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    setState(() => _isLoading = true);
    try {
      await _apiService.restoreLabourPayment(p.id!);
      await _fetchPayments();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Payment restored successfully'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to restore: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }
}
