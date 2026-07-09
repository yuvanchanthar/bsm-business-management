import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../core/app_colors.dart';
import '../models/ledger_model.dart';
import '../models/customer_model.dart';
import '../models/payment_model.dart';
import '../models/inventory_model.dart';
import '../services/api_service.dart';
import '../services/token_service.dart';
import '../services/sms_settings_service.dart';
import '../services/pdf_service.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';
import 'package:open_filex/open_filex.dart';
import 'package:flutter/services.dart';
import 'delivery_detail_screen.dart';
import 'credit_sale_detail_screen.dart';
import 'credit_sale_screen.dart';
import 'customer_statement_screen.dart';

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
  bool _dataChanged = false;

  // Tabs: 0 = Ledger, 1 = Payments
  int _selectedTab = 0;
  String _paymentFilter = 'All'; // All, Active, Voided
  List<PaymentModel> _customerPayments = [];

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
      final payments = await _apiService.getCustomerPayments(widget.customerId);
      if (mounted) {
        setState(() {
          _ledger = ledger;
          _customerPayments = payments;
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
    final double currentBalance = _ledger!.customer.openingBalance +
        _ledger!.totalDelivered -
        _ledger!.totalPaid;
    // For display: pending is only the positive portion of net balance
    final double pendingBalance = currentBalance > 0 ? currentBalance : 0.0;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final String amountText = amountController.text.trim();
          final double enteredAmount = double.tryParse(amountText) ?? 0;
          final double remainingBalance = currentBalance - enteredAmount;
          final bool isOverpaid = enteredAmount > pendingBalance && pendingBalance > 0;

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            title: Text('Collect Payment', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Pending Balance Card
                  _buildDialogBalanceCard(
                    'Pending Balance',
                    pendingBalance,
                    pendingBalance > 0 ? Colors.red.shade600 : AppColors.primaryGreen,
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
                    // Remaining Balance Card — show abs so it never shows negative
                    _buildDialogBalanceCard(
                      remainingBalance >= 0 ? 'Remaining Pending' : 'Advance Credit',
                      remainingBalance.abs(),
                      remainingBalance < 0 ? AppColors.primaryGreen : AppColors.primaryGreen,
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
      _dataChanged = true;
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

  List<PaymentModel> get _filteredPayments {
    if (_paymentFilter == 'Active') return _customerPayments.where((p) => !p.isVoided).toList();
    if (_paymentFilter == 'Voided') return _customerPayments.where((p) => p.isVoided).toList();
    return _customerPayments;
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
          onPressed: () => Navigator.pop(context, _dataChanged),
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
      body: WillPopScope(
        onWillPop: () async {
          Navigator.pop(context, _dataChanged);
          return false;
        },
        child: CustomScrollView(
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
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: _showStatementOptions,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal.shade600,
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(56),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 0,
                    ),
                    icon: const Icon(Icons.picture_as_pdf),
                    label: Text('Statement PDF', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(height: 32),

                  // Tabs
                  _buildTabToggle(),
                  const SizedBox(height: 16),

                  if (_selectedTab == 1) _buildPaymentFilters(),
                ],
              ),
            ),
          ),

          if (_selectedTab == 0 && displayItems.isEmpty)
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
          else if (_selectedTab == 0)
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

          if (_selectedTab == 1)
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              sliver: SliverList.builder(
                itemCount: _filteredPayments.length,
                itemBuilder: (context, index) {
                  final p = _filteredPayments[index];
                  if (p.isVoided) return _buildVoidedPaymentCard(p);
                  return _buildActivePaymentCard(p);
                },
              ),
            ),

          if (_selectedTab == 1 && _filteredPayments.isEmpty)
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              sliver: SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 40),
                  child: Center(
                    child: Text(
                      'No $_paymentFilter payments found',
                      style: GoogleFonts.inter(color: AppColors.textSecondary),
                    ),
                  ),
                ),
              ),
            ),

          const SliverToBoxAdapter(child: SizedBox(height: 80)),
        ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard(CustomerLedgerModel ledger) {
    final double netBalance = ledger.customer.openingBalance + ledger.totalDelivered - ledger.totalPaid;
    final isPending = netBalance >= 0;
    final isAdvance = netBalance < 0;
    final pendingAmount = isPending ? netBalance : 0.0;
    final advanceAmount = isAdvance ? netBalance.abs() : 0.0;

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
          _buildCommunicationButtons(ledger.customer, netBalance),
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildMetric('DELIVERED', '₹${ledger.totalDelivered.toStringAsFixed(0)}', Colors.black),
              _buildMetric('PAID', '₹${ledger.totalPaid.toStringAsFixed(0)}', AppColors.primaryGreen),
              _buildMetric(
                'PENDING',
                '₹${pendingAmount.toStringAsFixed(0)}',
                isPending ? Colors.red.shade700 : AppColors.textSecondary,
              ),
              _buildMetric(
                'ADVANCE',
                '₹${advanceAmount.toStringAsFixed(0)}',
                isAdvance ? AppColors.primaryGreen : AppColors.textSecondary,
              ),
            ],
          ),
          if (ledger.customer.openingBalance > 0) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.account_balance_wallet_outlined,
                          size: 16, color: Colors.amber.shade700),
                      const SizedBox(width: 8),
                      Text(
                        'Opening Balance (Old Balance)',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.amber.shade800,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    '₹${ledger.customer.openingBalance.toStringAsFixed(0)}',
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: Colors.amber.shade800,
                    ),
                  ),
                ],
              ),
            ),
          ],
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
    // Seed from 0 — the opening_balance transaction (if present) is already in
    // the sorted transactions list from the backend and will add its own amount
    // to the running balance, so we must NOT pre-seed with openingBalance.
    double runningBalance = 0;
    final List<_LedgerItemWithBalance> itemsWithBalance = [];
    for (var t in ledger.transactions) {
      if (t.type == LedgerEntryType.delivery ||
    t.type == LedgerEntryType.openingBalance ||
    t.type == LedgerEntryType.creditSale) {
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

  void _navigateToCreditSaleDetail(LedgerEntry entry) {
    final targetId = entry.id;
    if (targetId == null || targetId.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: Sale ID missing for this entry'),
            backgroundColor: Colors.red.shade800,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CreditSaleDetailScreen(saleId: targetId),
      ),
    );
  }

  // ── Edit Credit Sale ────────────────────────────────────────────────────────

  Future<void> _handleEditCreditSale(LedgerEntry entry) async {
    final saleId = entry.id;
    if (saleId == null || saleId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error: Sale ID missing'), backgroundColor: Colors.red),
      );
      return;
    }

    // Show loading indicator while fetching sale data
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator(color: AppColors.primaryGreen)),
    );

    try {
      final saleData = await _apiService.getCreditSaleById(saleId);
      if (!mounted) return;
      Navigator.pop(context); // close loading

      // Build customer from existing ledger (used for display only in edit mode)
      final customer = _ledger!.customer;
      final prefilledCustomer = CustomerModel(
        id: customer.id,
        name: customer.name,
        phone: customer.phone,
        address: '',
        balance: customer.balance,
        openingBalance: customer.openingBalance,
        creditLimit: customer.creditLimit,
        pendingDays: customer.pendingDays,
      );

      // Reconstruct products from sale items
      final rawItems = saleData['items'] as List? ?? [];
      final prefilledProducts = rawItems.map((item) {
        final m = Map<String, dynamic>.from(item as Map);
        double parseD(dynamic v) {
          if (v == null) return 0.0;
          if (v is num) return v.toDouble();
          return double.tryParse(v.toString()) ?? 0.0;
        }
        final name = m['itemName']?.toString() ?? m['product']?.toString() ?? '';
        final qty = parseD(m['quantity'] ?? m['qty']);
        final unit = m['unit']?.toString() ?? 'Bag';
        final price = parseD(m['price']);
        final inventoryId = m['inventoryId']?.toString() ?? m['_id']?.toString() ?? '';

        // Create a minimal InventoryItemModel stub so the dropdown shows the name
        final stub = InventoryItemModel(
          id: inventoryId,
          itemName: name,
          currentStock: 9999, // non-blocking for edit mode
          unit: unit,
          threshold: 0,
          category: null,
        );
        return CreditSaleProduct(
          item: stub,
          quantity: qty,
          price: price,
          selectedUnit: unit,
        );
      }).toList();

      final paymentReceived = (saleData['paymentReceived'] is num)
          ? (saleData['paymentReceived'] as num).toDouble()
          : double.tryParse(saleData['paymentReceived']?.toString() ?? '0') ?? 0.0;

      // Backward-compatible: default to 0 if backend doesn't return this field yet.
      final outstandingPayment = (saleData['outstandingPayment'] is num)
          ? (saleData['outstandingPayment'] as num).toDouble()
          : double.tryParse(saleData['outstandingPayment']?.toString() ?? '0') ?? 0.0;

      final notes = saleData['notes']?.toString() ?? '';

      final result = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => CreditSaleScreen(
            editMode: true,
            saleId: saleId,
            prefilledCustomer: prefilledCustomer,
            prefilledProducts: prefilledProducts,
            prefilledPaymentReceived: paymentReceived,
            prefilledOutstandingPayment: outstandingPayment,
            prefilledNotes: notes,
          ),
        ),
      );

      if (result == true && mounted) {
        _dataChanged = true;
        await _fetchLedger();
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // close loading
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Failed to load sale: ${e.toString().replaceAll("Exception: ", "")}'),
          backgroundColor: Colors.red,
        ));
      }
    }
  }

  // ── Delete Credit Sale ──────────────────────────────────────────────────────

  Future<void> _handleDeleteCreditSale(LedgerEntry entry) async {
    final saleId = entry.id;
    if (saleId == null || saleId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error: Sale ID missing'), backgroundColor: Colors.red),
      );
      return;
    }

    bool isDeleting = false;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              const Icon(Icons.delete_outline, color: Colors.red, size: 24),
              const SizedBox(width: 10),
              Text('Delete Credit Sale?',
                  style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 18)),
            ],
          ),
          content: Text(
            'Are you sure you want to delete this Credit Sale? This action cannot be undone.',
            style: GoogleFonts.inter(fontSize: 14, color: AppColors.textSecondary),
          ),
          actions: [
            TextButton(
              onPressed: isDeleting ? null : () => Navigator.pop(ctx, false),
              child: Text('Cancel', style: GoogleFonts.inter(color: AppColors.textSecondary)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                disabledBackgroundColor: Colors.grey.withValues(alpha: 0.5),
              ),
              onPressed: isDeleting
                  ? null
                  : () async {
                      setDialogState(() => isDeleting = true);
                      try {
                        await _apiService.deleteCreditSale(saleId);
                        if (ctx.mounted) Navigator.pop(ctx, true);
                      } catch (e) {
                        if (ctx.mounted) {
                          setDialogState(() => isDeleting = false);
                          ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                            content: Text(e.toString().replaceAll('Exception: ', '')),
                            backgroundColor: Colors.red,
                          ));
                        }
                      }
                    },
              child: isDeleting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Text('Delete', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );

    if (confirmed == true && mounted) {
      _dataChanged = true;
      await _fetchLedger();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Credit Sale deleted successfully'),
        backgroundColor: Colors.green,
      ));
    }
  }

  Widget _buildLedgerRow(LedgerEntry t, double bal) {
    final isDelivery = t.type == LedgerEntryType.delivery;
    final isCreditSale = t.type == LedgerEntryType.creditSale;
    final isOpeningBalance = t.type == LedgerEntryType.openingBalance;
    final isPayment = t.type == LedgerEntryType.payment;

    final Color amountColor =
        isOpeningBalance
            ? Colors.amber.shade800
            : isDelivery
                ? const Color(0xFFE64A19)
                : isCreditSale
                    ? Colors.deepPurple
                    : const Color(0xFF2E7D32);

    final IconData rowIcon =
        isOpeningBalance
            ? Icons.account_balance_wallet_outlined
            : isDelivery
                ? Icons.local_shipping_outlined
                : isCreditSale
                    ? Icons.shopping_cart_checkout
                    : Icons.payments_outlined;

    final String rowLabel =
        isOpeningBalance
            ? 'Opening Balance'
            : isDelivery
                ? 'Delivery'
                : isCreditSale
                    ? 'Credit Sale'
                    : 'Payment';

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
        color: isOpeningBalance
            ? Colors.amber.withValues(alpha: 0.06)
            : isCreditSale
                ? Colors.deepPurple.withValues(alpha: 0.05)
                : Colors.white,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () {
            if (isDelivery) {
              _navigateToDeliveryDetail(t);
            } else if (isCreditSale) {
              _navigateToCreditSaleDetail(t);
            }
          },
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
                    rowIcon,
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
                            rowLabel,
                            style: GoogleFonts.inter(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          if (isDelivery || isCreditSale) ...[
                            const SizedBox(width: 8),
                            Icon(Icons.chevron_right, size: 16, color: AppColors.primaryGreen.withValues(alpha: 0.6)),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        isOpeningBalance
                            ? 'Old balance brought forward'
                            : DateFormat('hh:mm aa').format(t.date),
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

                // Amount + optional popup menu for creditSale
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
                    // ── Popup menu: only for Credit Sale entries ──
                    if (isCreditSale) ...[
                      const SizedBox(height: 4),
                      SizedBox(
                        height: 28,
                        width: 28,
                        child: PopupMenuButton<String>(
                          padding: EdgeInsets.zero,
                          icon: const Icon(Icons.more_vert, size: 18, color: AppColors.textSecondary),
                          onSelected: (value) {
                            if (value == 'edit') _handleEditCreditSale(t);
                            if (value == 'delete') _handleDeleteCreditSale(t);
                          },
                          itemBuilder: (_) => [
                            PopupMenuItem(
                              value: 'edit',
                              child: Row(
                                children: [
                                  const Icon(Icons.edit_outlined, size: 18, color: Colors.blueAccent),
                                  const SizedBox(width: 10),
                                  Text('Edit', style: GoogleFonts.inter(fontSize: 14)),
                                ],
                              ),
                            ),
                            PopupMenuItem(
                              value: 'delete',
                              child: Row(
                                children: [
                                  const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                                  const SizedBox(width: 10),
                                  Text('Delete', style: GoogleFonts.inter(fontSize: 14, color: Colors.red)),
                                ],
                              ),
                            ),
                          ],
                        ),
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
    final message = '''
BSM Agro Industry

Dear $name,

Your pending balance is ₹${balance.abs().toStringAsFixed(0)}.

Please make the payment at your earliest convenience.

Thank you for your business.

BSM Agro Industry
''';
    
   
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

  final customer = _ledger?.customer;
  if (customer == null) return;

  final balance = _ledger!.finalBalance;

  final message = '''
Hello ${customer.name},

Your pending balance is ₹${balance.abs().toStringAsFixed(0)}.

Please make the payment at your earliest convenience.

BSM Agro Industry
''';

  final cleanPhone = _formatPhone(phone);

  final Uri url = Uri.parse(
    'sms:$cleanPhone?body=${Uri.encodeComponent(message)}',
  );

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
BSM Agro Industry

Dear ${customer.name},

Payment received successfully.

Amount Received: ₹${NumberFormat('#,##,###').format(amount)}

Previous Balance: ₹${NumberFormat('#,##,###').format(oldBalance)}
Current Balance: ₹${NumberFormat('#,##,###').format(newBalance)}

Thank you for your payment.

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

  Future<void> _showStatementOptions() async {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text(
                'Generate Statement',
                style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.visibility_outlined, color: Colors.deepPurple),
                title: Text('View Statement (In-App)', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                subtitle: Text('Browse all transactions with Credit Sale details', style: GoogleFonts.inter(fontSize: 12)),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => CustomerStatementScreen(
                    customerId: widget.customerId,
                    customerName: _ledger?.customer.name ?? '',
                  )));
                },
              ),
              const Divider(height: 1, indent: 16, endIndent: 16),
              ListTile(
                leading: const Icon(Icons.list_alt, color: AppColors.primaryGreen),
                title: Text('All Transactions', style: GoogleFonts.inter()),
                onTap: () {
                  Navigator.pop(context);
                  _generateStatementPdf(null, null);
                },
              ),
              ListTile(
                leading: const Icon(Icons.calendar_today, color: AppColors.primaryGreen),
                title: Text('This Month', style: GoogleFonts.inter()),
                onTap: () {
                  Navigator.pop(context);
                  final now = DateTime.now();
                  final start = DateTime(now.year, now.month, 1);
                  final end = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
                  _generateStatementPdf(start, end);
                },
              ),
              ListTile(
                leading: const Icon(Icons.calendar_month, color: AppColors.primaryGreen),
                title: Text('Last Month', style: GoogleFonts.inter()),
                onTap: () {
                  Navigator.pop(context);
                  final now = DateTime.now();
                  final start = DateTime(now.year, now.month - 1, 1);
                  final end = DateTime(now.year, now.month, 0, 23, 59, 59);
                  _generateStatementPdf(start, end);
                },
              ),
              ListTile(
                leading: const Icon(Icons.date_range, color: AppColors.primaryGreen),
                title: Text('Custom Date Range', style: GoogleFonts.inter()),
                onTap: () async {
                  Navigator.pop(context);
                  final picked = await showDateRangePicker(
                    context: context,
                    firstDate: DateTime(2000),
                    lastDate: DateTime.now(),
                    builder: (context, child) {
                      return Theme(
                        data: Theme.of(context).copyWith(
                          colorScheme: const ColorScheme.light(
                            primary: AppColors.primaryGreen,
                            onPrimary: Colors.white,
                            onSurface: AppColors.textPrimary,
                          ),
                        ),
                        child: child!,
                      );
                    },
                  );
                  if (picked != null) {
                    final start = picked.start;
                    final end = DateTime(picked.end.year, picked.end.month, picked.end.day, 23, 59, 59);
                    _generateStatementPdf(start, end);
                  }
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  Future<void> _generateStatementPdf(DateTime? startDate, DateTime? endDate) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(color: AppColors.primaryGreen),
      ),
    );

    try {
      final statement = await _apiService.getCustomerStatement(
        widget.customerId,
        startDate: startDate,
        endDate: endDate,
      );

      if (statement.transactions.isEmpty) {
        if (mounted) {
          Navigator.pop(context); // close dialog
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('No transactions found for this period.'),
              backgroundColor: Colors.orange.shade800,
            ),
          );
        }
        return;
      }

      final pdfService = PdfService();
      final pdfBytes = await pdfService.generateCustomerStatementPdf(statement);

      if (!mounted) return;
      Navigator.pop(context); // close dialog
      
      final cleanName = statement.customer.name.replaceAll(' ', '_').replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '');
      final dateSuffix = DateFormat('ddMMyyyy').format(DateTime.now());
      final filename = 'CustomerStatement_${cleanName}_$dateSuffix.pdf';

      _showPdfActions(pdfBytes, filename);
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // close dialog
        _showError('Failed to generate statement: $e');
      }
    }
  }

  void _showPdfActions(Uint8List pdfBytes, String filename) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text(
                'Statement Ready',
                style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.share, color: Colors.blue),
                title: Text('Share PDF', style: GoogleFonts.inter()),
                subtitle: Text('WhatsApp, Email, etc.', style: GoogleFonts.inter(fontSize: 12)),
                onTap: () {
                  Navigator.pop(context);
                  Printing.sharePdf(bytes: pdfBytes, filename: filename);
                },
              ),
              ListTile(
                leading: const Icon(Icons.download, color: AppColors.primaryGreen),
                title: Text('Download PDF', style: GoogleFonts.inter()),
                subtitle: Text('Save to device', style: GoogleFonts.inter(fontSize: 12)),
                onTap: () async {
                  Navigator.pop(context);
                  await _downloadPdf(pdfBytes, filename);
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  Future<void> _downloadPdf(Uint8List bytes, String filename) async {
    try {
      Directory? dir;
      if (Platform.isAndroid) {
        dir = await getExternalStorageDirectory();
      } else {
        dir = await getApplicationDocumentsDirectory();
      }

      if (dir != null) {
        final file = File('${dir.path}/$filename');
        await file.writeAsBytes(bytes);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Saved to ${file.path}'),
              action: SnackBarAction(
                label: 'OPEN',
                onPressed: () => OpenFilex.open(file.path),
                textColor: Colors.white,
              ),
              backgroundColor: AppColors.primaryGreen,
              duration: const Duration(seconds: 5),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        _showError('Failed to save PDF: $e');
      }
    }
  }

  // ── Payment Tabs & Filters ──────────────────────────────────────────────────
  Widget _buildTabToggle() {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedTab = 0),
              child: Container(
                decoration: BoxDecoration(
                  color: _selectedTab == 0 ? AppColors.primaryGreen : Colors.transparent,
                  borderRadius: BorderRadius.circular(14),
                ),
                alignment: Alignment.center,
                child: Text(
                  'Combined Ledger',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.bold,
                    color: _selectedTab == 0 ? Colors.white : AppColors.textSecondary,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedTab = 1),
              child: Container(
                decoration: BoxDecoration(
                  color: _selectedTab == 1 ? AppColors.primaryGreen : Colors.transparent,
                  borderRadius: BorderRadius.circular(14),
                ),
                alignment: Alignment.center,
                child: Text(
                  'Payments',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.bold,
                    color: _selectedTab == 1 ? Colors.white : AppColors.textSecondary,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentFilters() {
    final activeCount = _customerPayments.where((p) => !p.isVoided).length;
    final voidedCount = _customerPayments.where((p) => p.isVoided).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Active: $activeCount', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primaryGreen)),
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

  // ── Payment Cards ───────────────────────────────────────────────────────────
  Widget _buildActivePaymentCard(PaymentModel p) {
    final displayDate = p.createdAt ?? p.date;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
              decoration: BoxDecoration(color: AppColors.primaryGreen.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.payments, color: AppColors.primaryGreen, size: 20),
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

  Widget _buildVoidedPaymentCard(PaymentModel p) {
    final displayDate = p.createdAt ?? p.date;
    return GestureDetector(
      onTap: () => _showAuditDetailDialog(p),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
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

  // ── Edit & Void Actions ─────────────────────────────────────────────────────
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
                        await _apiService.updateCustomerPayment(
                          p.id!,
                          amount: double.parse(amountCtrl.text.trim()),
                          date: selectedDate,
                          note: noteCtrl.text.trim(),
                        );
                        await _fetchLedger();
                        _dataChanged = true;
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
      await _apiService.voidCustomerPayment(p.id!, reason: reasonCtrl.text.trim());
      await _fetchLedger();
      _dataChanged = true;
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

}
