import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import '../core/app_colors.dart';
import '../models/invoice_model.dart';
import '../models/ledger_model.dart';
import '../models/payment_model.dart';
import '../services/api_service.dart';
import '../services/pdf_service.dart';
import '../services/token_service.dart';

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
  CustomerLedgerModel? _ledger;
  List<InvoiceModel> _invoices = [];
  bool _isLoading = true;
  bool _isLoadingInvoices = false;
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
      await _fetchLedger();
      _fetchInvoices(); // load invoices in background
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

  Future<void> _fetchInvoices() async {
    if (!mounted) return;
    setState(() => _isLoadingInvoices = true);
    try {
      final invoices = await _apiService.getCustomerInvoices(widget.customerId);
      if (mounted) setState(() => _invoices = invoices);
    } catch (_) {
      // Non-critical — silent failure
    } finally {
      if (mounted) setState(() => _isLoadingInvoices = false);
    }
  }

  Future<void> _showAddPaymentDialog() async {
    final amountController = TextEditingController();
    final noteController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Collect Payment', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: amountController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Amount (₹)',
                prefixIcon: Icon(Icons.currency_rupee),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: noteController,
              decoration: const InputDecoration(
                labelText: 'Note (Optional)',
                prefixIcon: Icon(Icons.note_alt_outlined),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryGreen),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Save Payment'),
          ),
        ],
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
      // 1. Submit payment to the CUSTOMER payments endpoint.
      final payment = PaymentModel(
        customerId: widget.customerId,
        name: _ledger!.customer.name,
        amount: amount,
        date: DateTime.now(),
        note: noteController.text.trim(),
      );
      await _apiService.addCustomerPayment(payment);

      // 2. Re-fetch the ledger — this is the ONLY source of truth.
      //    Do NOT use the payment API response to update UI values.
      await _fetchLedger();

      // 3. Confirm to the user only after the UI is updated.
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Payment recorded successfully'),
            backgroundColor: Colors.green,
          ),
        );
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

          if (ledgerItems.isEmpty)
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
                itemCount: ledgerItems.length,
                itemBuilder: (context, index) {
                  final item = ledgerItems[index];
                  return _buildLedgerRow(item.entry, item.balance);
                },
              ),
            ),

          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            sliver: SliverToBoxAdapter(
              child: const SizedBox(height: 16),
            ),
          ),

          // Invoices header
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            sliver: SliverToBoxAdapter(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Invoices',
                    style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                  ),
                  if (_isLoadingInvoices)
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primaryGreen),
                    ),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            sliver: SliverToBoxAdapter(child: const SizedBox(height: 16)),
          ),

          if (!_isLoadingInvoices && _invoices.isEmpty)
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              sliver: SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(Icons.receipt_long_outlined, size: 40, color: AppColors.textSecondary.withValues(alpha: 0.5)),
                        const SizedBox(height: 8),
                        Text('No invoices yet', style: GoogleFonts.inter(color: AppColors.textSecondary)),
                      ],
                    ),
                  ),
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              sliver: SliverList.builder(
                itemCount: _invoices.length,
                itemBuilder: (context, index) => _buildInvoiceCard(_invoices[index]),
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
          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 24),
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

  Widget _buildLedgerRow(LedgerEntry t, double bal) {
    final isDelivery = t.type == LedgerEntryType.delivery;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.1)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: (isDelivery ? Colors.orange : Colors.green).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              isDelivery ? Icons.local_shipping_outlined : Icons.payments_outlined,
              color: isDelivery ? Colors.orange : Colors.green,
              size: 20,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      isDelivery ? 'Delivery' : 'Payment',
                      style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                    ),
                    Text(
                      DateFormat('dd MMM').format(t.date),
                      style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary),
                    ),
                  ],
                ),
                Text(
                  t.description,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${isDelivery ? "+" : "-"} ₹${t.amount.toStringAsFixed(0)}',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: isDelivery ? Colors.red : Colors.green,
                      ),
                    ),
                    Text(
                      'Bal: ₹${bal.toStringAsFixed(0)}',
                      style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInvoiceCard(InvoiceModel invoice) {
    final isUpdated = invoice.isUpdated;
    final badgeColor = isUpdated ? const Color(0xFFE65100) : AppColors.primaryGreen;
    final badgeBg = isUpdated
        ? const Color(0xFFE65100).withValues(alpha: 0.1)
        : AppColors.primaryGreen.withValues(alpha: 0.1);

    return GestureDetector(
      onTap: () => _openInvoicePdf(invoice),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isUpdated
                ? const Color(0xFFE65100).withValues(alpha: 0.25)
                : Colors.grey.withValues(alpha: 0.1),
            width: isUpdated ? 1.5 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            // Icon
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: badgeBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.receipt_long_outlined,
                color: badgeColor,
                size: 20,
              ),
            ),
            const SizedBox(width: 14),

            // Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Text(
                          invoice.invoiceNumber,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      // Type badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: badgeBg,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          isUpdated ? 'UPDATED' : 'ORIGINAL',
                          style: GoogleFonts.inter(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: badgeColor,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        invoice.formattedDate,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      Text(
                        '₹ ${invoice.finalAmount.toStringAsFixed(0)}',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(width: 10),
            Icon(Icons.chevron_right, color: AppColors.textSecondary, size: 20),
          ],
        ),
      ),
    );
  }

  Future<void> _openInvoicePdf(InvoiceModel invoice) async {
    final pdfService = PdfService();
    try {
      await Printing.layoutPdf(
        onLayout: (format) async => pdfService.generateInvoice(invoice),
        name: '${invoice.invoiceNumber}.pdf',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not open PDF: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
