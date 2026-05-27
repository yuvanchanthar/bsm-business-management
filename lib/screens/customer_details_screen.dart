import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../core/app_colors.dart';
import '../models/invoice_model.dart';
import '../models/ledger_model.dart';
import '../models/payment_model.dart';
import '../services/api_service.dart';
import '../services/pdf_service.dart';
import '../services/token_service.dart';
import '../services/sms_settings_service.dart';
import '../features/invoice/services/invoice_generator_service.dart';
import 'delivery_detail_screen.dart';

// Simple DTO to keep SliverList builder clean.
// Stores the precomputed running balance for each entry.
class _LedgerItemWithBalance {
  final LedgerEntry entry;
  final double balance;

  const _LedgerItemWithBalance({required this.entry, required this.balance});
}

class CustomerDetailsScreen extends StatefulWidget {
  final String customerId;
  const CustomerDetailsScreen({super.key, required this.customerId});

  @override
  State<CustomerDetailsScreen> createState() => _CustomerDetailsScreenState();
}
class _CustomerDetailsScreenState extends State<CustomerDetailsScreen> {
  late ApiService _apiService;
  final SmsSettingsService _smsService = SmsSettingsService();
  CustomerLedgerModel? _ledger;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initData();
  }

  Future<void> _initData() async {
    try {
      final tokenService = await TokenService.getInstance();
      _apiService = ApiService(tokenService);
      await _smsService.init();
      await _fetchLedger();
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  // Tracks a lightweight in-progress refresh (does not blank the whole screen).
  bool _isRefreshing = false;

  /// Fetches ledger data and updates state. On the first load (_ledger == null)
  /// it shows a full-screen spinner; subsequent calls do a quiet background
  /// refresh so the existing values remain visible while data loads.
  Future<void> _fetchLedger() async {
    if (_ledger == null) {
      // Initial load — show full-screen spinner.
      if (mounted) setState(() => _isLoading = true);
    } else {
      // Subsequent refresh — quiet indicator only.
      if (mounted) setState(() => _isRefreshing = true);
    }

    try {
      final ledger = await _apiService.getCustomerLedger(widget.customerId);
      if (mounted) {
        setState(() {
          _ledger = ledger;
          _isLoading = false;
          _isRefreshing = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          // Preserve existing ledger data on refresh failure.
          if (_ledger == null) _error = e.toString();
          _isLoading = false;
          _isRefreshing = false;
        });
      }
    }
  }


  Future<void> _showAddPaymentDialog() async {
    final amountController = TextEditingController();
    final noteController = TextEditingController();
    final double currentBalance = _ledger!.finalBalance;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final String amountText = amountController.text.trim();
          final double enteredAmount = double.tryParse(amountText) ?? 0;
          final double remainingBalance = currentBalance - enteredAmount;
          final bool isOverpaid = enteredAmount > currentBalance && currentBalance > 0;

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            title: Text('Collect Payment', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Current Balance Card
                  _buildDialogBalanceCard(
                    'Current Balance',
                    currentBalance,
                    Colors.blue,
                  ),
                  const SizedBox(height: 16),
                  
                  TextField(
                    controller: amountController,
                    keyboardType: TextInputType.number,
                    onChanged: (_) => setDialogState(() {}),
                    decoration: InputDecoration(
                      labelText: 'Amount Received (₹)',
                      prefixIcon: const Icon(Icons.currency_rupee),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.primaryGreen, width: 2),
                      ),
                    ),
                  ),
                  
                  if (amountText.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    // Amount Received Summary Card
                    _buildDialogBalanceCard(
                      'Amount Received',
                      enteredAmount,
                      isOverpaid ? Colors.red : AppColors.primaryGreen,
                    ),
                    const SizedBox(height: 8),
                    // Remaining Balance Card
                    _buildDialogBalanceCard(
                      'Remaining Balance',
                      remainingBalance,
                      remainingBalance < 0 ? Colors.red : AppColors.primaryGreen,
                    ),
                    if (isOverpaid)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          'Entered amount exceeds pending balance',
                          style: GoogleFonts.inter(color: Colors.red, fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ),
                  ],
                  
                  const SizedBox(height: 16),
                  TextField(
                    controller: noteController,
                    decoration: InputDecoration(
                      labelText: 'Note (Optional)',
                      prefixIcon: const Icon(Icons.note_alt_outlined),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Cancel', style: GoogleFonts.inter(color: AppColors.textSecondary)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: isOverpaid ? Colors.grey : AppColors.primaryGreen,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
                onPressed: isOverpaid ? null : () => Navigator.pop(context, true),
                child: Text('Save Payment', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      ),
    );

    if (result != true || amountController.text.trim().isEmpty) return;

    final amount = double.tryParse(amountController.text.trim());
    if (amount == null || amount <= 0) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter a valid amount')),
        );
      }
      return;
    }

    try {
      // 1. Capture old balance
      final oldBalance = _ledger!.finalBalance;

      // 2. Submit payment to the CUSTOMER payments endpoint.
      final payment = PaymentModel(
        customerId: widget.customerId,
        name: _ledger!.customer.name,
        amount: amount,
        date: DateTime.now(),
        note: noteController.text.trim(),
      );
      await _apiService.addCustomerPayment(payment);

      // 3. Re-fetch the ledger — this is the ONLY source of truth.
      await _fetchLedger();
      final newBalance = _ledger!.finalBalance;

      // 4. Confirm to the user only after the UI is updated.
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Payment recorded successfully'),
            backgroundColor: Colors.green,
          ),
        );

        // 5. Trigger SMS flow automatically
        _triggerPaymentSMS(oldBalance, amount, newBalance);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Payment failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator(color: AppColors.primaryGreen)));
    }

    if (_error != null) {
      return Scaffold(body: Center(child: Text('Error: $_error')));
    }

    final ledger = _ledger!;
    final ledgerItems = _computeLedgerItemsWithBalance(ledger);

    // Group items by date for KhataBook style
    final List<dynamic> displayItems = [];
    DateTime? lastDate;

    for (var item in ledgerItems) {
      final date = DateTime(item.entry.date.year, item.entry.date.month, item.entry.date.day);
      if (lastDate == null || date != lastDate) {
        displayItems.add(date); // Store the date as a header marker
        lastDate = date;
      }
      displayItems.add(item);
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context, true),
        ),
        title: Text(
          'Customer Ledger',
          style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: AppColors.primaryGreen),
        ),
        actions: [
          if (_isRefreshing)
            const Padding(
              padding: EdgeInsets.only(right: 16),
              child: Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.primaryGreen,
                  ),
                ),
              ),
            ),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            sliver: SliverList(
              delegate: SliverChildListDelegate(
                [
                  // Summary Card
                  _buildSummaryCard(ledger),
                  const SizedBox(height: 24),

                  // Actions
                  ElevatedButton.icon(
                    onPressed: _showAddPaymentDialog,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryGreen,
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(56),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 0,
                    ),
                    icon: const Icon(Icons.add_card),
                    label: Text('Collect Payment', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(height: 32),

                  // Ledger Section header
                  Text(
                    'Combined Ledger',
                    style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),

          if (displayItems.isEmpty)
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              sliver: SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 40),
                  child: Center(
                    child: Text(
                      'No transaction history found',
                      style: GoogleFonts.inter(color: AppColors.textSecondary),
                    ),
                  ),
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              sliver: SliverList.builder(
                itemCount: displayItems.length,
                itemBuilder: (context, index) {
                  final item = displayItems[index];
                  if (item is DateTime) {
                    return _buildDateHeader(item);
                  }
                  final ledgerItem = item as _LedgerItemWithBalance;
                  return _buildLedgerRow(ledgerItem.entry, ledgerItem.balance);
                },
              ),
            ),

          const SliverToBoxAdapter(child: SizedBox(height: 80)),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(CustomerLedgerModel ledger) {
    final balance = ledger.finalBalance;
    final isPending = balance > 0;
    final isAdvance = balance < 0;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ledger.customer.name,
                      style: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      ledger.customer.phone,
                      style: GoogleFonts.inter(fontSize: 14, color: AppColors.textSecondary),
                    ),
                    if (ledger.customer.creditLimit > 0 && ledger.customer.balance > ledger.customer.creditLimit) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Credit Limit Exceeded (₹${ledger.customer.creditLimit.toStringAsFixed(0)})',
                        style: GoogleFonts.inter(fontSize: 12, color: Colors.red, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: isPending ? Colors.red.withValues(alpha: 0.1) : (isAdvance ? Colors.green.withValues(alpha: 0.1) : Colors.grey.withValues(alpha: 0.1)),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      isPending ? 'PENDING' : (isAdvance ? 'ADVANCE' : 'CLEAR'),
                      style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: isPending ? Colors.red : (isAdvance ? Colors.green : AppColors.textSecondary)),
                    ),
                  ),
                  if (ledger.customer.pendingDays >= 30) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${ledger.customer.pendingDays} DAYS OVERDUE',
                        style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.orange),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildCommunicationButtons(ledger.customer, balance),
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildMetric('DELIVERED', '₹${ledger.totalDelivered.toStringAsFixed(0)}', Colors.black),
              _buildMetric('PAID', '₹${ledger.totalPaid.toStringAsFixed(0)}', AppColors.primaryGreen),
              _buildMetric('BALANCE', '₹${balance.abs().toStringAsFixed(0)}', isPending ? Colors.red : AppColors.primaryGreen),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetric(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
        const SizedBox(height: 4),
        Text(value, style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w900, color: color)),
      ],
    );
  }

  Widget _buildDateHeader(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    String label;
    if (date == today) {
      label = 'Today';
    } else if (date == yesterday) {
      label = 'Yesterday';
    } else {
      label = DateFormat('dd MMM yyyy').format(date);
    }

    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 12),
      child: Row(
        children: [
          Expanded(child: Divider(color: AppColors.textHint.withValues(alpha: 0.2))),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              label.toUpperCase(),
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: AppColors.textHint,
                letterSpacing: 1.2,
              ),
            ),
          ),
          Expanded(child: Divider(color: AppColors.textHint.withValues(alpha: 0.2))),
        ],
      ),
    );
  }

  List<_LedgerItemWithBalance> _computeLedgerItemsWithBalance(CustomerLedgerModel ledger) {
    double runningBalance = 0;
    // The transactions from the server are sorted oldest first to correctly calculate running balance
    // But we might want to display latest first. Let's calculate balances then reverse for display.
    
    final List<_LedgerItemWithBalance> itemsWithBalance = [];
    for (var t in ledger.transactions) {
      if (t.type == LedgerEntryType.delivery) {
        runningBalance += t.amount;
      } else {
        runningBalance -= t.amount;
      }
      itemsWithBalance.add(_LedgerItemWithBalance(entry: t, balance: runningBalance));
    }

    // Display latest first
    return itemsWithBalance.reversed.toList();
  }

  void _navigateToDeliveryDetail(LedgerEntry entry) {
    print('--------------------------------------------------');
    print('[Combined Ledger] TAP EVENT');
    print('ENTRY_TYPE: ${entry.type}');
    print('ENTRY_DELIVERY_ID: ${entry.deliveryId}');
    print('ENTRY_TXN_ID: ${entry.id}');
    print('--------------------------------------------------');

    if (entry.type != LedgerEntryType.delivery) {
      print('[Combined Ledger] Navigation blocked: Entry is not a delivery.');
      return;
    }

    final targetId = entry.deliveryId;
    
    if (targetId == null || targetId.isEmpty) {
      print('[Combined Ledger] Navigation failed: deliveryId is null or empty.');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: Delivery ID missing for this entry'),
            backgroundColor: Colors.red.shade800,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    print('[Combined Ledger] Navigating to DeliveryDetailScreen with ID: $targetId');
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DeliveryDetailScreen(deliveryId: targetId),
      ),
    );
  }

  Widget _buildLedgerRow(LedgerEntry t, double bal) {
    final isDelivery = t.type == LedgerEntryType.delivery;
    final amountColor = isDelivery ? const Color(0xFFE64A19) : const Color(0xFF2E7D32); // Orange-Red for Debit, Green for Credit
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          if (isDelivery)
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
        ],
      ),
      child: Material(
        color: isDelivery ? Colors.white : Colors.white.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: isDelivery ? () => _navigateToDeliveryDetail(t) : null,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Icon
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: amountColor.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isDelivery ? Icons.local_shipping_outlined : Icons.payments_outlined,
                    color: amountColor,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 16),
                
                // Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            isDelivery ? 'Delivery' : 'Payment',
                            style: GoogleFonts.inter(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          if (isDelivery) ...[
                            const SizedBox(width: 8),
                            Icon(Icons.chevron_right, size: 16, color: AppColors.primaryGreen.withValues(alpha: 0.6)),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        DateFormat('hh:mm aa').format(t.date),
                        style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Bal: ₹${bal.toStringAsFixed(0)}',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary.withValues(alpha: 0.8),
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Amount
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '₹${t.amount.toStringAsFixed(0)}',
                      style: GoogleFonts.inter(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: amountColor,
                      ),
                    ),
                    if (t.description.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        t.description,
                        style: GoogleFonts.inter(fontSize: 10, color: AppColors.textHint),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --- Communication Actions ---

  Widget _buildCommunicationButtons(dynamic customer, double balance) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildCircleIconButton(
          icon: Icons.phone_rounded,
          onTap: () => _handleCall(customer.phone),
          color: const Color(0xFF007AFF), // iOS Blue
        ),
        _buildCircleIconButton(
          icon: FontAwesomeIcons.whatsapp,
          onTap: () => _handleWhatsApp(customer.phone, customer.name, balance),
          color: const Color(0xFF25D366), // WhatsApp Green
        ),
        _buildCircleIconButton(
          icon: Icons.message_rounded,
          onTap: () => _handleSMS(customer.phone),
          color: const Color(0xFFFF9500), // SMS Orange
        ),
      ],
    );
  }

  Widget _buildCircleIconButton({
    required IconData icon,
    required VoidCallback onTap,
    required Color color,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.2), width: 1.5),
        ),
        child: Icon(
          icon,
          size: 28,
          color: color,
        ),
      ),
    );
  }

  String _formatPhone(String phone) {
    // Remove all non-numeric characters
    return phone.replaceAll(RegExp(r'\D'), '');
  }

  void _handleCall(String phone) async {
    if (phone.isEmpty) {
      _showError('Phone number not available');
      return;
    }
    final Uri url = Uri.parse('tel:$phone');
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    } else {
      _showError('Could not open dialer');
    }
  }

  void _handleWhatsApp(String phone, String name, double balance) async {
    if (phone.isEmpty) {
      _showError('Phone number not available');
      return;
    }
    
    final cleanPhone = _formatPhone(phone);
    // Add country code if missing (assuming India 91 as default if length is 10)
    final finalPhone = cleanPhone.length == 10 ? '91$cleanPhone' : cleanPhone;
    
    final message = 'Hello $name, your pending balance is ₹${balance.abs().toStringAsFixed(0)}.';
    final url = Uri.parse('https://wa.me/$finalPhone?text=${Uri.encodeComponent(message)}');
    
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      _showError('Could not open WhatsApp');
    }
  }

  void _handleSMS(String phone) async {
    if (phone.isEmpty) {
      _showError('Phone number not available');
      return;
    }

    if (_smsService.smsMode == 'bsm_sms') {
      _showComingSoon();
      return;
    }

    final Uri url = Uri.parse('sms:$phone');
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    } else {
      _showError('Could not open SMS app');
    }
  }

  void _showComingSoon() {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.rocket_launch_outlined, color: AppColors.primaryGreen),
            const SizedBox(width: 12),
            Text('Coming Soon', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          'BSM SMS backend integration is coming soon. Use "My Number" for now to send SMS locally.',
          style: GoogleFonts.inter(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('OK', style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: AppColors.primaryGreen)),
          ),
        ],
      ),
    );
  }

  void _triggerPaymentSMS(double oldBalance, double amount, double newBalance) async {
    final customer = _ledger?.customer;
    if (customer == null) return;

    if (customer.phone.isEmpty) {
      _showError('Customer mobile number unavailable');
      return;
    }

    if (_smsService.smsMode == 'bsm_sms') {
      _showComingSoon();
      return;
    }

    final String message = '''
Hello ${customer.name},

Payment received successfully.

Previous Balance:
₹${NumberFormat('#,##,###').format(oldBalance.abs())}

Amount Paid:
₹${NumberFormat('#,##,###').format(amount)}

Remaining Balance:
₹${NumberFormat('#,##,###').format(newBalance.abs())}

Thank you,
BSM Agro Industry''';

    final cleanPhone = _formatPhone(customer.phone);
    final Uri url = Uri.parse('sms:$cleanPhone?body=${Uri.encodeComponent(message)}');
    
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    } else {
      _showError('Could not open SMS app');
    }
  }

  Widget _buildDialogBalanceCard(String label, double amount, Color color) {
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
            '₹${NumberFormat('#,##,###.##').format(amount.abs())}',
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red.shade800,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

}
