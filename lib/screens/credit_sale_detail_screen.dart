import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../core/app_colors.dart';
import '../services/api_service.dart';
import '../services/token_service.dart';
import 'credit_invoice_preview_screen.dart';

class CreditSaleDetailScreen extends StatefulWidget {
  final String saleId;

  const CreditSaleDetailScreen({super.key, required this.saleId});

  @override
  State<CreditSaleDetailScreen> createState() => _CreditSaleDetailScreenState();
}

class _CreditSaleDetailScreenState extends State<CreditSaleDetailScreen> {
  static const _green = AppColors.primaryGreen;
  final _apiService = ApiService(TokenService.instance);
  
  Map<String, dynamic>? _saleData;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchSaleDetails();
  }

  Future<void> _fetchSaleDetails() async {
    try {
      final data = await _apiService.getCreditSaleById(widget.saleId);
      if (mounted) {
        setState(() {
          _saleData = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceAll('Exception: ', '');
          _isLoading = false;
        });
      }
    }
  }

  double _parse(dynamic val) {
    if (val == null) return 0.0;
    if (val is num) return val.toDouble();
    if (val is String) return double.tryParse(val) ?? 0.0;
    return 0.0;
  }

  String get _invoiceNumber => _saleData?['invoiceNumber']?.toString() ?? 'N/A';
  String get _customerName => _saleData?['customerName']?.toString() ?? _saleData?['customer']?.toString() ?? 'Unknown Customer';
  String get _notes => _saleData?['notes']?.toString() ?? '';
  
  double get _previousBalance => _parse(_saleData?['previousBalance']);
  double get _grandTotal => _parse(_saleData?['grandTotal'] ?? _saleData?['totalAmount'] ?? _saleData?['amount']);
  double get _paymentReceived => _parse(_saleData?['paymentReceived']);
  double get _pendingAmount => _parse(_saleData?['pendingAmount'] ?? _saleData?['currentSalePending'] ?? (_grandTotal - _paymentReceived));
  double get _currentBalance => _parse(_saleData?['currentBalance'] ?? _saleData?['updatedBalance'] ?? (_previousBalance + _pendingAmount));

  String get _dateString {
    final rawDate = _saleData?['createdAt'] ?? _saleData?['date'];
    final date = rawDate != null ? (DateTime.tryParse(rawDate.toString()) ?? DateTime.now()) : DateTime.now();
    return DateFormat('dd MMM yyyy, hh:mm a').format(date);
  }

  List<Map<String, dynamic>> get _items {
    final raw = _saleData?['items'] ?? _saleData?['products'];
    if (raw is List) {
      return raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }
    return [];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Credit Sale Details', style: GoogleFonts.inter(
          fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: AppColors.border.withValues(alpha: 0.5), height: 1),
        ),
      ),
      body: _buildBody(),
      bottomNavigationBar: _saleData != null ? _buildBottomActions() : null,
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: _green));
    }
    if (_errorMessage != null) {
      return Center(child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, color: Colors.red, size: 48),
          const SizedBox(height: 16),
          Text(_errorMessage!, style: GoogleFonts.inter(color: Colors.red)),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              setState(() { _isLoading = true; _errorMessage = null; });
              _fetchSaleDetails();
            },
            child: const Text('Retry'),
          )
        ],
      ));
    }
    if (_saleData == null) {
      return const Center(child: Text('Sale details not found.'));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHeaderCard(),
          const SizedBox(height: 20),
          _sectionTitle('Products Sold'),
          const SizedBox(height: 12),
          _buildProductsList(),
          if (_notes.isNotEmpty) ...[
            const SizedBox(height: 20),
            _sectionTitle('Notes'),
            const SizedBox(height: 12),
            _buildNotesCard(),
          ],
          const SizedBox(height: 24),
          _buildInvoiceSummary(),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
    );
  }

  Widget _buildHeaderCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(color: _green.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
                child: Text('CREDIT SALE', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: _green)),
              ),
              Text(_dateString, style: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary)),
            ],
          ),
          const SizedBox(height: 16),
          Text('Invoice No.', style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary)),
          Text(_invoiceNumber, style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
          const Padding(padding: EdgeInsets.symmetric(vertical: 16), child: Divider(height: 1)),
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: AppColors.primaryGreen.withValues(alpha: 0.12),
                child: Text(_customerName.isNotEmpty ? _customerName[0].toUpperCase() : '?', 
                  style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.primaryGreen)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Customer', style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary)),
                    Text(_customerName, style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProductsList() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: _items.length,
        separatorBuilder: (_, __) => Divider(height: 1, color: AppColors.border.withValues(alpha: 0.5)),
        itemBuilder: (context, index) {
          final item = _items[index];
          final name = item['product']?.toString() ?? item['itemName']?.toString() ?? 'Item';
          final qty = _parse(item['qty'] ?? item['quantity']);
          final unit = item['unit']?.toString() ?? '';
          final price = _parse(item['price']);
          final total = _parse(item['total'] ?? item['totalAmount']);
          
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(8)),
                  child: Center(child: Text('${index + 1}', style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: AppColors.textSecondary))),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                      const SizedBox(height: 4),
                      Text('${qty.toStringAsFixed(0)} $unit × ₹${price.toStringAsFixed(0)}', style: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary)),
                    ],
                  ),
                ),
                Text('₹${total.toStringAsFixed(2)}', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildNotesCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.note_alt_outlined, size: 20, color: AppColors.textSecondary),
          const SizedBox(width: 12),
          Expanded(child: Text(_notes, style: GoogleFonts.inter(fontSize: 14, color: AppColors.textPrimary))),
        ],
      ),
    );
  }

  Widget _buildInvoiceSummary() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 15, offset: const Offset(0, 6))],
        border: Border.all(color: _green.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.receipt_long, color: _green, size: 20),
              const SizedBox(width: 8),
              Text('Accounting Summary', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
            ],
          ),
          const SizedBox(height: 16),
          _SummaryRow('Grand Total', '₹${_grandTotal.toStringAsFixed(2)}', isBold: true, color: AppColors.textPrimary),
          const SizedBox(height: 8),
          _SummaryRow('Paid Now', '₹${_paymentReceived.toStringAsFixed(2)}', color: Colors.blue),
          const SizedBox(height: 8),
          _SummaryRow('Pending', '₹${_pendingAmount.toStringAsFixed(2)}', isBold: true, color: _green),
          const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Divider(height: 1)),
          _SummaryRow('Previous Balance', '₹${_previousBalance.toStringAsFixed(2)}', color: _previousBalance > 0 ? Colors.red : AppColors.textSecondary),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _currentBalance > 0 ? Colors.red.withValues(alpha: 0.08) : _green.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: _SummaryRow('Current Balance', '₹${_currentBalance.toStringAsFixed(2)}', isBold: true, isLarge: true, color: _currentBalance > 0 ? Colors.red : _green),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomActions() {
    return Container(
      padding: EdgeInsets.fromLTRB(16, 12, 16, MediaQuery.of(context).padding.bottom + 12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, -4))],
      ),
      child: SafeArea(
        child: ElevatedButton.icon(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => CreditInvoicePreviewScreen(invoiceData: _saleData!)),
            );
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: _green,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            elevation: 0,
          ),
          icon: const Icon(Icons.picture_as_pdf),
          label: Text('Preview Invoice', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isBold;
  final bool isLarge;
  final Color color;

  const _SummaryRow(this.label, this.value, {
    this.isBold = false,
    this.isLarge = false,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: GoogleFonts.inter(fontSize: isLarge ? 15 : 14, color: AppColors.textSecondary, fontWeight: isBold ? FontWeight.w600 : FontWeight.normal)),
        Text(value, style: GoogleFonts.inter(fontSize: isLarge ? 18 : 15, fontWeight: isBold ? FontWeight.bold : FontWeight.w600, color: color)),
      ],
    );
  }
}
