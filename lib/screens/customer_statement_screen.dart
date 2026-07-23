import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../core/app_colors.dart';
import '../core/stock_format.dart';
import '../models/customer_statement_model.dart';
import '../services/api_service.dart';
import '../services/token_service.dart';
import '../services/pdf_service.dart';
import 'package:printing/printing.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'package:flutter/services.dart';

class CustomerStatementScreen extends StatefulWidget {
  final String customerId;
  final String customerName;

  const CustomerStatementScreen({
    super.key,
    required this.customerId,
    required this.customerName,
  });

  @override
  State<CustomerStatementScreen> createState() => _CustomerStatementScreenState();
}

class _CustomerStatementScreenState extends State<CustomerStatementScreen> {
  final _apiService = ApiService(TokenService.instance);
  CustomerStatementModel? _statement;
  bool _isLoading = true;
  String? _error;
  DateTime? _startDate;
  DateTime? _endDate;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      final s = await _apiService.getCustomerStatement(
        widget.customerId,
        startDate: _startDate,
        endDate: _endDate,
      );
      if (mounted) setState(() { _statement = s; _isLoading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString().replaceAll('Exception: ', ''); _isLoading = false; });
    }
  }

  Future<void> _pickDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(primary: AppColors.primaryGreen, onPrimary: Colors.white, onSurface: AppColors.textPrimary),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = DateTime(picked.end.year, picked.end.month, picked.end.day, 23, 59, 59);
      });
      _load();
    }
  }

  void _clearFilter() {
    setState(() { _startDate = null; _endDate = null; });
    _load();
  }

  Future<void> _generatePdf() async {
    if (_statement == null) return;
    showDialog(context: context, barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator(color: AppColors.primaryGreen)));
    try {
      final bytes = await PdfService().generateCustomerStatementPdf(_statement!);
      if (!mounted) return;
      Navigator.pop(context);
      final name = widget.customerName.replaceAll(' ', '_').replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '');
      final filename = 'Statement_${name}_${DateFormat('ddMMyyyy').format(DateTime.now())}.pdf';
      _showPdfActions(bytes, filename);
    } catch (e) {
      if (mounted) { Navigator.pop(context); _showErr('Failed: $e'); }
    }
  }

  void _showPdfActions(Uint8List bytes, String filename) {
    showModalBottomSheet(context: context, shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
        const SizedBox(height: 16),
        Text('Statement Ready', style: GoogleFonts.inter(fontSize: 17, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        ListTile(leading: const Icon(Icons.share, color: Colors.blue), title: Text('Share PDF', style: GoogleFonts.inter()),
          onTap: () { Navigator.pop(context); Printing.sharePdf(bytes: bytes, filename: filename); }),
        ListTile(leading: const Icon(Icons.download, color: AppColors.primaryGreen), title: Text('Download PDF', style: GoogleFonts.inter()),
          onTap: () async { Navigator.pop(context); await _downloadPdf(bytes, filename); }),
        const SizedBox(height: 16),
      ])));
  }

  Future<void> _downloadPdf(Uint8List bytes, String filename) async {
    try {
      final dir = Platform.isAndroid ? await getExternalStorageDirectory() : await getApplicationDocumentsDirectory();
      if (dir != null) {
        final file = File('${dir.path}/$filename');
        await file.writeAsBytes(bytes);
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Saved: ${file.path}'),
          action: SnackBarAction(label: 'OPEN', onPressed: () => OpenFilex.open(file.path), textColor: Colors.white),
          backgroundColor: AppColors.primaryGreen, duration: const Duration(seconds: 5)));
      }
    } catch (e) { _showErr('Failed to save: $e'); }
  }

  void _showErr(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red.shade800));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary), onPressed: () => Navigator.pop(context)),
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Account Statement', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
          Text(widget.customerName, style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary)),
        ]),
        actions: [
          IconButton(icon: const Icon(Icons.filter_alt_outlined, color: AppColors.primaryGreen), tooltip: 'Filter by date', onPressed: _pickDateRange),
          IconButton(icon: const Icon(Icons.picture_as_pdf, color: AppColors.primaryGreen), tooltip: 'Export PDF', onPressed: _generatePdf),
        ],
        bottom: PreferredSize(preferredSize: const Size.fromHeight(1), child: Container(color: AppColors.border.withValues(alpha: 0.4), height: 1)),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) return const Center(child: CircularProgressIndicator(color: AppColors.primaryGreen));
    if (_error != null) return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      const Icon(Icons.error_outline, color: Colors.red, size: 48),
      const SizedBox(height: 12),
      Text(_error!, style: GoogleFonts.inter(color: Colors.red), textAlign: TextAlign.center),
      const SizedBox(height: 16),
      ElevatedButton(onPressed: _load, style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryGreen, foregroundColor: Colors.white), child: const Text('Retry')),
    ]));
    if (_statement == null || _statement!.transactions.isEmpty) return _buildEmpty();

    final s = _statement!;
    return Column(children: [
      if (_startDate != null) _buildFilterChip(),
      _buildSummaryBar(s),
      Expanded(child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        itemCount: s.transactions.length,
        itemBuilder: (ctx, i) => _buildTxCard(s.transactions[i]),
      )),
    ]);
  }

  Widget _buildEmpty() => Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
    Icon(Icons.receipt_long, size: 64, color: Colors.grey.shade300),
    const SizedBox(height: 16),
    Text('No transactions found', style: GoogleFonts.inter(fontSize: 16, color: AppColors.textSecondary)),
    if (_startDate != null) ...[
      const SizedBox(height: 8),
      TextButton(onPressed: _clearFilter, child: const Text('Clear filter')),
    ],
  ]));

  Widget _buildFilterChip() {
    final df = DateFormat('dd MMM');
    final label = '${df.format(_startDate!)} – ${df.format(_endDate!)}';
    return Container(color: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(children: [
        Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(color: AppColors.primaryGreen.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
          child: Row(children: [
            const Icon(Icons.calendar_today, size: 12, color: AppColors.primaryGreen),
            const SizedBox(width: 6),
            Text(label, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primaryGreen)),
            const SizedBox(width: 6),
            GestureDetector(onTap: _clearFilter, child: const Icon(Icons.close, size: 14, color: AppColors.primaryGreen)),
          ])),
      ]));
  }

  Widget _buildSummaryBar(CustomerStatementModel s) {
    final pending = s.summary.pendingBalance;
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(children: [
        _SumCol('Total Debits', '₹${NumberFormat('#,##,###').format(s.summary.totalDeliveries)}', Colors.deepOrange),
        _divider(),
        _SumCol('Total Paid', '₹${NumberFormat('#,##,###').format(s.summary.totalPayments)}', AppColors.primaryGreen),
        _divider(),
        _SumCol('Balance', '₹${NumberFormat('#,##,###').format(pending.abs())}', pending > 0 ? Colors.red : AppColors.primaryGreen, bold: true),
      ]),
    );
  }

  Widget _divider() => Container(height: 36, width: 1, color: AppColors.border.withValues(alpha: 0.5), margin: const EdgeInsets.symmetric(horizontal: 8));

  Widget _buildTxCard(StatementTransaction t) {
    switch (t.type) {
      case 'credit_sale': return _CreditSaleCard(t: t);
      case 'payment':     return _PaymentCard(t: t);
      case 'opening_balance': return _OpeningBalanceCard(t: t);
      default:            return _DeliveryCard(t: t);
    }
  }
}

// ─── Summary Column ───────────────────────────────────────────────────────────

class _SumCol extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final bool bold;
  const _SumCol(this.label, this.value, this.color, {this.bold = false});

  @override
  Widget build(BuildContext context) => Expanded(child: Column(children: [
    Text(label, style: GoogleFonts.inter(fontSize: 10, color: AppColors.textSecondary, fontWeight: FontWeight.w500)),
    const SizedBox(height: 3),
    Text(value, style: GoogleFonts.inter(fontSize: 14, fontWeight: bold ? FontWeight.w900 : FontWeight.w700, color: color), maxLines: 1, overflow: TextOverflow.ellipsis),
  ]));
}

// ─── Base card shell ──────────────────────────────────────────────────────────

class _CardShell extends StatelessWidget {
  final Widget child;
  final Color? borderColor;
  const _CardShell({required this.child, this.borderColor});

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 12),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      border: borderColor != null ? Border.all(color: borderColor!.withValues(alpha: 0.3)) : null,
      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 3))],
    ),
    child: child,
  );
}

// ─── Opening Balance Card ──────────────────────────────────────────────────────

class _OpeningBalanceCard extends StatelessWidget {
  final StatementTransaction t;
  const _OpeningBalanceCard({required this.t});

  @override
  Widget build(BuildContext context) => _CardShell(
    borderColor: Colors.amber,
    child: Padding(padding: const EdgeInsets.all(14), child: Row(children: [
      Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.amber.withValues(alpha: 0.12), shape: BoxShape.circle),
        child: const Icon(Icons.account_balance_wallet_outlined, size: 20, color: Colors.amber)),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Opening Balance', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
        Text('Old balance brought forward', style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary)),
      ])),
      Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Text('₹${t.amount.toStringAsFixed(0)}', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.amber.shade800)),
        Text('Bal: ₹${t.balance.toStringAsFixed(0)}', style: GoogleFonts.inter(fontSize: 11, color: AppColors.textSecondary)),
      ]),
    ])),
  );
}

// ─── Payment Card ─────────────────────────────────────────────────────────────

class _PaymentCard extends StatelessWidget {
  final StatementTransaction t;
  const _PaymentCard({required this.t});

  @override
  Widget build(BuildContext context) => _CardShell(
    borderColor: AppColors.primaryGreen,
    child: Padding(padding: const EdgeInsets.all(14), child: Row(children: [
      Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: AppColors.primaryGreen.withValues(alpha: 0.12), shape: BoxShape.circle),
        child: const Icon(Icons.payments_outlined, size: 20, color: AppColors.primaryGreen)),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Payment', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
        Text(DateFormat('dd MMM yyyy, hh:mm a').format(t.date), style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary)),
        if (t.description.isNotEmpty) Text(t.description, style: GoogleFonts.inter(fontSize: 11, color: AppColors.textSecondary), maxLines: 1, overflow: TextOverflow.ellipsis),
      ])),
      Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Text('₹${t.amount.toStringAsFixed(0)}', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.primaryGreen)),
        Text('Bal: ₹${t.balance.toStringAsFixed(0)}', style: GoogleFonts.inter(fontSize: 11, color: AppColors.textSecondary)),
      ]),
    ])),
  );
}

// ─── Delivery Card ────────────────────────────────────────────────────────────

class _DeliveryCard extends StatelessWidget {
  final StatementTransaction t;
  const _DeliveryCard({required this.t});

  @override
  Widget build(BuildContext context) => _CardShell(
    borderColor: const Color(0xFFE64A19),
    child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: const Color(0xFFE64A19).withValues(alpha: 0.1), shape: BoxShape.circle),
          child: const Icon(Icons.local_shipping_outlined, size: 20, color: Color(0xFFE64A19))),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Delivery', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
          Text(DateFormat('dd MMM yyyy, hh:mm a').format(t.date), style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary)),
          if (t.description.isNotEmpty) Text(t.description, style: GoogleFonts.inter(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.w500)),
        ])),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text('₹${t.amount.toStringAsFixed(0)}', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: const Color(0xFFE64A19))),
          Text('Bal: ₹${t.balance.toStringAsFixed(0)}', style: GoogleFonts.inter(fontSize: 11, color: AppColors.textSecondary)),
        ]),
      ]),
      if (t.items.isNotEmpty) ...[
        const Divider(height: 20),
        ...t.items.map((item) => Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(children: [
            const Icon(Icons.circle, size: 6, color: AppColors.textSecondary),
            const SizedBox(width: 8),
            Expanded(child: Text(item.name, style: GoogleFonts.inter(fontSize: 13, color: AppColors.textPrimary))),
            if (item.quantity > 0) Text('${fmtStock(item.quantity)}${item.unit != null ? " ${item.unit}" : ""}', style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary)),
          ]),
        )),
      ],
    ])),
  );
}

// ─── Credit Sale Card (expandable) ────────────────────────────────────────────

class _CreditSaleCard extends StatefulWidget {
  final StatementTransaction t;
  const _CreditSaleCard({required this.t});

  @override
  State<_CreditSaleCard> createState() => _CreditSaleCardState();
}

class _CreditSaleCardState extends State<_CreditSaleCard> {
  bool _expanded = false;

  StatementTransaction get t => widget.t;

  @override
  Widget build(BuildContext context) {
    final pending = t.pendingAmount > 0 ? t.pendingAmount : (t.grandTotal - t.paymentReceived).clamp(0.0, double.infinity);

    return _CardShell(
      borderColor: Colors.deepPurple,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        // ── Header ──────────────────────────────────────────────────────────
        InkWell(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
          onTap: () => setState(() => _expanded = !_expanded),
          child: Padding(padding: const EdgeInsets.all(14), child: Column(children: [
            Row(children: [
              Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.deepPurple.withValues(alpha: 0.1), shape: BoxShape.circle),
                child: const Icon(Icons.shopping_cart_checkout, size: 20, color: Colors.deepPurple)),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Text('Credit Sale', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                  const SizedBox(width: 6),
                  Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: Colors.deepPurple.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)),
                    child: Text('CREDIT', style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.deepPurple))),
                ]),
                Text(DateFormat('dd MMM yyyy, hh:mm a').format(t.date), style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary)),
              ])),
              Icon(_expanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down, color: Colors.deepPurple, size: 22),
            ]),
            // Compact summary (always visible)
            if (!_expanded) ...[
              const SizedBox(height: 10),
              Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(color: const Color(0xFFF3E5F5), borderRadius: BorderRadius.circular(8)),
                child: Row(children: [
                  _CompactStat('Grand Total', '₹${t.grandTotal.toStringAsFixed(0)}', AppColors.textPrimary),
                  _CompactStat('Pending', '₹${pending.toStringAsFixed(0)}', Colors.deepPurple, bold: true),
                  _CompactStat('Balance', '₹${t.balance.toStringAsFixed(0)}', t.balance > 0 ? Colors.red : AppColors.primaryGreen, bold: true),
                ]),
              ),
            ],
          ])),
        ),

        // ── Expanded details ─────────────────────────────────────────────────
        if (_expanded) ...[
          Divider(height: 1, color: Colors.deepPurple.withValues(alpha: 0.2)),
          Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Items
            if (t.items.isNotEmpty) ...[
              Text('Purchased Items', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textSecondary, letterSpacing: 0.5)),
              const SizedBox(height: 8),
              ...t.items.map((item) {
                final qty = fmtStock(item.quantity);
                final unit = (item.unit == null || item.unit!.isEmpty) ? 'Bag' : item.unit!;
                final price = item.price != null ? '₹${item.price!.toStringAsFixed(0)}' : '';
                final total = item.total != null ? item.total! : (item.price != null ? item.price! * item.quantity : 0.0);
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: const Color(0xFFF9F5FF), borderRadius: BorderRadius.circular(8)),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(item.name, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                      Text('$qty $unit × $price', style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary)),
                    ])),
                    Text('₹${total.toStringAsFixed(0)}', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.deepPurple)),
                  ]),
                );
              }),
              const SizedBox(height: 4),
            ],
            // Payment Summary
            Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: const Color(0xFFF3E5F5), borderRadius: BorderRadius.circular(10)), child: Column(children: [
              _SummaryRow('Grand Total', '₹${t.grandTotal.toStringAsFixed(2)}', AppColors.textPrimary, bold: true),
              const SizedBox(height: 6),
              _SummaryRow('Paid Now', '₹${t.paymentReceived.toStringAsFixed(2)}', Colors.blue),
              const SizedBox(height: 6),
              _SummaryRow('Pending', '₹${pending.toStringAsFixed(2)}', Colors.deepPurple, bold: true),
              const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Divider(height: 1)),
              _SummaryRow('Debit', '₹${t.amount.toStringAsFixed(2)}', const Color(0xFFE64A19)),
              const SizedBox(height: 6),
              _SummaryRow('Running Balance', '₹${t.balance.toStringAsFixed(2)}', t.balance > 0 ? Colors.red : AppColors.primaryGreen, bold: true, large: true),
            ])),
          ])),
        ],
      ]),
    );
  }
}

class _CompactStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final bool bold;
  const _CompactStat(this.label, this.value, this.color, {this.bold = false});

  @override
  Widget build(BuildContext context) => Expanded(child: Column(children: [
    Text(label, style: GoogleFonts.inter(fontSize: 9, color: AppColors.textSecondary, fontWeight: FontWeight.w500)),
    const SizedBox(height: 3),
    Text(value, style: GoogleFonts.inter(fontSize: 13, fontWeight: bold ? FontWeight.bold : FontWeight.w600, color: color), maxLines: 1, overflow: TextOverflow.ellipsis),
  ]));
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final bool bold;
  final bool large;
  const _SummaryRow(this.label, this.value, this.color, {this.bold = false, this.large = false});

  @override
  Widget build(BuildContext context) => Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
    Text(label, style: GoogleFonts.inter(fontSize: large ? 14 : 13, color: AppColors.textSecondary, fontWeight: bold ? FontWeight.w600 : FontWeight.normal)),
    Text(value, style: GoogleFonts.inter(fontSize: large ? 16 : 14, fontWeight: bold ? FontWeight.bold : FontWeight.w600, color: color)),
  ]);
}
