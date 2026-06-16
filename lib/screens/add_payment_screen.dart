import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/app_colors.dart';
import '../models/payment_model.dart';
import '../services/api_service.dart';
import '../services/token_service.dart';
import '../services/sms_settings_service.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';

class AddPaymentScreen extends StatefulWidget {
  final String labourId;
  final String labourName;
  const AddPaymentScreen({super.key, required this.labourId, required this.labourName});

  @override
  State<AddPaymentScreen> createState() => _AddPaymentScreenState();
}

class _AddPaymentScreenState extends State<AddPaymentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  bool _isLoading = false;
  
  double _oldBalance  = 0;   // raw backend balance (kept for fallback)
  double _totalEarned = 0;   // cumulative earned salary
  double _totalPaid   = 0;   // cumulative total paid
  String _phone = '';
  final SmsSettingsService _smsService = SmsSettingsService();

  @override
  void initState() {
    super.initState();
    _fetchLabourDetails();
  }

  Future<void> _fetchLabourDetails() async {
    try {
      final tokenService = await TokenService.getInstance();
      final apiService = ApiService(tokenService);
      await _smsService.init();
      final report = await apiService.getLabourDetailReport(widget.labourId);
      if (mounted) {
        setState(() {
          _oldBalance  = report.balance;
          _totalEarned = report.totalEarned;
          _totalPaid   = report.totalPaid;
          _phone       = report.phone;
        });
      }
    } catch (e) {
      debugPrint('Silent skip: Labour details fetch failed: $e');
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(colorScheme: const ColorScheme.light(primary: AppColors.primaryGreen)),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  String get _formattedDate {
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${_selectedDate.day} ${months[_selectedDate.month - 1]} ${_selectedDate.year}';
  }

  Future<void> _handleSubmit({bool confirmDuplicate = false}) async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      final tokenService = await TokenService.getInstance();
      final apiService = ApiService(tokenService);

      final payment = PaymentModel(
        labourId: widget.labourId,
        name: widget.labourName,
        amount: double.parse(_amountController.text.trim()),
        date: _selectedDate,
        note: _noteController.text.trim(),
      );
      await apiService.addPayment(payment, confirmDuplicate: confirmDuplicate);

      // Re-fetch details to get updated earned / paid / balance
      double newBalance = 0;
      double totalEarned = 0;
      double totalPaid   = 0;
      try {
        final updatedReport = await apiService.getLabourDetailReport(widget.labourId);
        newBalance   = updatedReport.balance;
        totalEarned  = updatedReport.totalEarned;
        totalPaid    = updatedReport.totalPaid;
      } catch (e) {
        debugPrint('Failed to fetch updated balance: $e');
        newBalance  = _oldBalance - payment.amount;
        totalPaid   = payment.amount;  // best-effort fallback
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('\u2705 Payment recorded successfully'), backgroundColor: Colors.green),
        );
        await _sendPaymentSMS(totalEarned, totalPaid);
        if (mounted) Navigator.pop(context, true);
      }
    } on LabourPaymentDuplicateException catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showDuplicateWarningDialog(e.message);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Shows the ⚠️ Possible Duplicate Payment dialog.
  /// If user taps "Save Anyway", re-sends with confirmDuplicate: true.
  void _showDuplicateWarningDialog(String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(children: [
          const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 26),
          const SizedBox(width: 10),
          Expanded(child: Text('Possible Duplicate Payment', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16))),
        ]),
        content: Text(message, style: GoogleFonts.inter(fontSize: 14, color: AppColors.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: GoogleFonts.inter(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryGreen,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              _handleSubmit(confirmDuplicate: true);
            },
            child: Text('Save Anyway', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // ── Derived balances ──────────────────────────────────────────────────
    // Same formula as SalaryReportScreen / LabourDetailReportScreen.
    final String amountText       = _amountController.text.trim();
    final double enteredAmount    = double.tryParse(amountText) ?? 0;
    final double pendingBalance   = (_totalEarned - _totalPaid) > 0
        ? (_totalEarned - _totalPaid) : 0;
    final double advanceBalance   = (_totalPaid - _totalEarned) > 0
        ? (_totalPaid - _totalEarned) : 0;
    final double remainingBalance = pendingBalance - enteredAmount;
    final bool   isOverpaid       = enteredAmount > pendingBalance && pendingBalance > 0;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary), onPressed: () => Navigator.pop(context)),
        title: Text('Add Payment', style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: AppColors.primaryGreen)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Labour info card
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppColors.primaryGreen.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.primaryGreen.withValues(alpha: 0.2)),
                ),
                child: Row(children: [
                  Container(
                    width: 44, height: 44,
                    decoration: BoxDecoration(color: AppColors.primaryGreen, borderRadius: BorderRadius.circular(10)),
                    alignment: Alignment.center,
                    child: Text(widget.labourName.isNotEmpty ? widget.labourName[0].toUpperCase() : 'L',
                        style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
                  ),
                  const SizedBox(width: 14),
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('PAYING TO', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.primaryGreen, letterSpacing: 0.8)),
                    Text(widget.labourName, style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                  ]),
                ]),
              ),
              const SizedBox(height: 28),

              // ── Balance summary row ─────────────────────────────────────
              Row(
                children: [
                  Expanded(
                    child: _buildTopBalanceCard(
                      'Pending Salary',
                      pendingBalance,
                      AppColors.primaryGreen,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildTopBalanceCard(
                      'Advance Balance',
                      advanceBalance,
                      advanceBalance > 0 ? Colors.orange : AppColors.textSecondary,
                      dimmed: advanceBalance == 0,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              _buildLabel('Payment Amount (₹)'),
              TextFormField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                onChanged: (_) {
                  if (mounted) setState(() {});
                },
                style: GoogleFonts.inter(fontSize: 28, fontWeight: FontWeight.bold, color: AppColors.primaryGreen),
                decoration: InputDecoration(
                  hintText: '0',
                  hintStyle: GoogleFonts.inter(fontSize: 28, color: AppColors.textHint),
                  prefixText: '₹ ',
                  prefixStyle: GoogleFonts.inter(fontSize: 28, fontWeight: FontWeight.bold, color: AppColors.primaryGreen),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: AppColors.border)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: AppColors.border)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.primaryGreen, width: 2)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Amount is required';
                  if (double.tryParse(v) == null || double.parse(v) <= 0) return 'Enter a valid amount';
                  return null;
                },
              ),
              
              if (amountText.isNotEmpty) ...[
                const SizedBox(height: 16),
                _buildBalanceSummaryCard(
                  'Amount Paid',
                  enteredAmount,
                  isOverpaid ? Colors.red : AppColors.primaryGreen,
                ),
                const SizedBox(height: 12),
                _buildBalanceSummaryCard(
                  'Remaining Balance',
                  remainingBalance,
                  remainingBalance < 0 ? Colors.red : AppColors.primaryGreen,
                ),
                if (isOverpaid)
                  Padding(
                    padding: const EdgeInsets.only(top: 8, left: 4),
                    child: Text(
                      'Entered amount exceeds pending balance',
                      style: GoogleFonts.inter(color: Colors.red, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ),
              ],
              const SizedBox(height: 20),

              _buildLabel('Payment Date'),
              GestureDetector(
                onTap: _pickDate,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(children: [
                    const Icon(Icons.calendar_today_outlined, color: AppColors.primaryGreen, size: 20),
                    const SizedBox(width: 12),
                    Text(_formattedDate, style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                    const Spacer(),
                    const Icon(Icons.chevron_right, color: AppColors.textSecondary, size: 20),
                  ]),
                ),
              ),
              const SizedBox(height: 20),

              _buildLabel('Note (Optional)'),
              TextFormField(
                controller: _noteController,
                maxLines: 2,
                decoration: InputDecoration(
                  hintText: 'e.g. Advance payment, Weekly payment...',
                  hintStyle: GoogleFonts.inter(color: AppColors.textHint, fontSize: 14),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: AppColors.border)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: AppColors.border)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.primaryGreen, width: 2)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
                style: GoogleFonts.inter(fontSize: 14, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 36),

              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : _handleSubmit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryGreen,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  icon: _isLoading
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.check_circle_outline, size: 22),
                  label: Text(
                    _isLoading ? 'Recording...' : 'Record Payment',
                    style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(text, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textSecondary, letterSpacing: 0.8)),
    );
  }

  /// Sends a salary summary SMS to the labour after a payment is recorded.
  ///
  /// [totalEarned] and [totalPaid] come from the re-fetched [LabourDetailReport]
  /// so they reflect the FULL cumulative position (not just this payment).
  ///
  /// Advance / pending are derived the same way as [SalaryReportScreen] and
  /// [LabourDetailReportScreen] to guarantee consistency across the app.
  Future<void> _sendPaymentSMS(double totalEarned, double totalPaid) async {
    if (_phone.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Labour mobile number unavailable')),
        );
      }
      return;
    }

    if (_smsService.smsMode == 'bsm_sms') {
      if (mounted) _showComingSoonDialog();
      return;
    }

    // ── Advance / Pending calculation ──────────────────────────────────────
    // Mirrors the formula in SalaryReportScreen and LabourDetailReportScreen.
    final double pendingAmount = (totalEarned - totalPaid) > 0
        ? (totalEarned - totalPaid)
        : 0;
    final double advanceAmount = (totalPaid - totalEarned) > 0
        ? (totalPaid - totalEarned)
        : 0;

    final fmt = NumberFormat('#,##,###');

    // ── SMS body ───────────────────────────────────────────────────────────
    final StringBuffer buf = StringBuffer();
    buf.writeln('Hello ${widget.labourName},');
    buf.writeln();
    buf.writeln('Payment processed successfully.');
    buf.writeln();
    buf.writeln('Earned Salary : ₹${fmt.format(totalEarned)}');
    buf.writeln('Total Paid    : ₹${fmt.format(totalPaid)}');
    if (advanceAmount > 0) {
      buf.writeln('Advance Amount: ₹${fmt.format(advanceAmount)}');
    }
    buf.writeln('Pending Salary: ₹${fmt.format(pendingAmount)}');
    buf.writeln();
    buf.writeln('Thank you,');
    buf.write('BSM Agro Industry');

    final cleanPhone = _phone.replaceAll(RegExp(r'\D'), '');
    final Uri url = Uri.parse(
        'sms:$cleanPhone?body=${Uri.encodeComponent(buf.toString())}');

    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open SMS app')),
        );
      }
    }
  }

  void _showComingSoonDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.rocket_launch_outlined, color: AppColors.primaryGreen),
            const SizedBox(width: 12),
            const Text('Coming Soon'),
          ],
        ),
        content: const Text('BSM SMS backend integration is coming soon. Use "My Number" for now to send SMS locally.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK', style: TextStyle(color: AppColors.primaryGreen, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBalanceCard(String label, double amount, Color color, {bool dimmed = false}) {
    final effectiveColor = dimmed ? color.withValues(alpha: 0.5) : color;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: effectiveColor.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: effectiveColor.withValues(alpha: 0.1), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '₹${NumberFormat('#,##,###').format(amount.abs())}',
            style: GoogleFonts.inter(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: effectiveColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBalanceSummaryCard(String label, double amount, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.1), width: 1.5),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          Text(
            '₹${NumberFormat('#,##,###').format(amount.abs())}',
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
