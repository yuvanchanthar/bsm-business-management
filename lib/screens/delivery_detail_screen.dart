import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import '../core/app_colors.dart';
import '../models/ledger_model.dart';
import '../models/delivery.dart';
import '../services/api_service.dart';
import '../services/token_service.dart';
import '../features/invoice/services/invoice_generator_service.dart';

class DeliveryDetailScreen extends StatefulWidget {
  final String deliveryId;

  const DeliveryDetailScreen({super.key, required this.deliveryId});

  @override
  State<DeliveryDetailScreen> createState() => _DeliveryDetailScreenState();
}

class _DeliveryDetailScreenState extends State<DeliveryDetailScreen> {
  late ApiService _apiService;
  Delivery? _delivery;
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
      final delivery = await _apiService.getDeliveryById(widget.deliveryId);
      setState(() {
        _delivery = delivery;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _handleInvoiceAction(String action) async {
    if (_delivery?.invoice == null) return;
    
    final invoice = _delivery!.invoice!;
    final templateId = invoice.templateId;
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final generator = const InvoiceGeneratorService();

    try {
      if (action == 'print') {
        await Printing.layoutPdf(
          onLayout: (format) async => generator.generate(
            templateId: templateId ?? 'classic',
            delivery: _delivery!,
          ),
          name: '${invoice.invoiceNumber ?? 'INV'}_$timestamp.pdf',
        );
      } else if (action == 'share') {
        final pdfBytes = await generator.generate(
          templateId: templateId ?? 'classic',
          delivery: _delivery!,
        );
        await Printing.sharePdf(
          bytes: pdfBytes,
          filename: '${invoice.invoiceNumber ?? 'INV'}_$timestamp.pdf',
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Action failed: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator(color: AppColors.primaryGreen)));
    }

    if (_error != null || _delivery == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Delivery Details')),
        body: Center(child: Text('Error: ${_error ?? "Delivery not found"}')),
      );
    }

    final d = _delivery!;
    final hasInvoice = d.invoice != null;

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
          'Delivery Details',
          style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: AppColors.primaryGreen),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Section: Header Info
            _buildHeaderSection(d),
            const SizedBox(height: 24),

            // Delivery Details Section
            _buildSectionTitle('Delivery Information'),
            const SizedBox(height: 12),
            _buildDeliveryInfoCard(d),
            const SizedBox(height: 24),

            // Products Section
            _buildSectionTitle('Products'),
            const SizedBox(height: 12),
            ...d.products.map((p) => _buildProductItem(p)),
            const SizedBox(height: 24),

            // Payment Summary
            _buildSectionTitle('Payment Summary'),
            const SizedBox(height: 12),
            _buildPaymentSummaryCard(d),
            const SizedBox(height: 32),

            // Invoice Preview Section
            if (hasInvoice) ...[
              _buildSectionTitle('Invoice Preview'),
              const SizedBox(height: 16),
              _buildInvoicePreview(d),
              const SizedBox(height: 24),
              _buildInvoiceActions(),
            ],
            
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: AppColors.textPrimary,
      ),
    );
  }

  Widget _buildHeaderSection(Delivery d) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10)],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  d.customerName,
                  style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                ),
                const SizedBox(height: 4),
                Text(
                  'Order #${d.id.substring(d.id.length - 6).toUpperCase()}',
                  style: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _getStatusColor(d.status).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              d.status.toUpperCase(),
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: _getStatusColor(d.status),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.orange;
      case 'dispatched':
        return Colors.blue;
      case 'completed':
        return Colors.green;
      default:
        return AppColors.primaryGreen;
    }
  }

  Widget _buildDeliveryInfoCard(Delivery d) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          _buildInfoRow(Icons.calendar_today_outlined, 'Date', DateFormat('dd MMM yyyy').format(d.timestamp)),
          const Divider(height: 24),
          _buildInfoRow(Icons.access_time, 'Time', DateFormat('hh:mm aa').format(d.timestamp)),
          if (d.vehicleNumber != null && d.vehicleNumber!.isNotEmpty) ...[
            const Divider(height: 24),
            _buildInfoRow(Icons.directions_car_outlined, 'Vehicle No.', d.vehicleNumber!),
          ],
          if (d.invoice != null) ...[
            const Divider(height: 24),
            _buildInfoRow(Icons.receipt_outlined, 'Invoice No.', d.invoice!.invoiceNumber ?? 'N/A'),
            const Divider(height: 24),
            _buildInfoRow(Icons.design_services_outlined, 'Template', d.invoice!.templateId?.toUpperCase() ?? 'CLASSIC'),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.textSecondary),
        const SizedBox(width: 12),
        Text(label, style: GoogleFonts.inter(fontSize: 14, color: AppColors.textSecondary)),
        const Spacer(),
        Text(value, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
      ],
    );
  }

  Widget _buildProductItem(ProductItem product) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(product.name, style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
                Text('${product.quantity} x ₹${product.pricePerUnit}', style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary)),
              ],
            ),
          ),
          Text(
            '₹${(product.quantity * product.pricePerUnit).toStringAsFixed(0)}',
            style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: AppColors.textPrimary),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentSummaryCard(Delivery d) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.primaryGreen,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          _buildSummaryRow('Total Amount', '₹${d.deliveryTotal.toStringAsFixed(0)}', Colors.white),
          const SizedBox(height: 12),
          _buildSummaryRow('Paid Amount', '₹0', Colors.white70),
          const Divider(color: Colors.white24, height: 24),
          _buildSummaryRow('Balance', '₹${d.deliveryTotal.toStringAsFixed(0)}', Colors.white, isBold: true),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, Color color, {bool isBold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: GoogleFonts.inter(color: color, fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
        Text(value, style: GoogleFonts.inter(color: color, fontSize: 18, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildInvoicePreview(Delivery d) {
    return Container(
      height: 400,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: PdfPreview(
          build: (format) => InvoiceGeneratorService().generate(
            templateId: d.invoice!.templateId ?? 'classic',
            delivery: d,
          ),
          useActions: false,
          allowPrinting: false,
          allowSharing: false,
          canChangeOrientation: false,
          canChangePageFormat: false,
          canDebug: false,
          maxPageWidth: 400,
          loadingWidget: const Center(child: CircularProgressIndicator()),
        ),
      ),
    );
  }

  Widget _buildInvoiceActions() {
    return Row(
      children: [
        Expanded(
          child: _ActionButton(
            icon: Icons.print,
            label: 'Print',
            onTap: () => _handleInvoiceAction('print'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _ActionButton(
            icon: Icons.share,
            label: 'Share',
            onTap: () => _handleInvoiceAction('share'),
          ),
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ActionButton({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: AppColors.primaryGreen,
        side: const BorderSide(color: AppColors.primaryGreen),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 0,
        padding: const EdgeInsets.symmetric(vertical: 12),
      ),
      icon: Icon(icon, size: 20),
      label: Text(label, style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
    );
  }
}
