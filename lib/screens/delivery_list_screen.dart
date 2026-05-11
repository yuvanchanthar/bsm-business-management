import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/app_colors.dart';
import '../models/delivery.dart';
import '../services/api_service.dart';
import '../services/pdf_service.dart';
import '../services/token_service.dart';
import 'add_delivery_screen.dart';
import 'edit_delivery_screen.dart';

class DeliveryListScreen extends StatefulWidget {
  const DeliveryListScreen({super.key});

  @override
  State<DeliveryListScreen> createState() => _DeliveryListScreenState();
}

class _DeliveryListScreenState extends State<DeliveryListScreen> {
  final ApiService _apiService = ApiService(TokenService.instance);
  final PdfService _pdfService = PdfService();

  List<Delivery> _deliveries = [];
  bool _isLoading = true;
  String? _error;
  String _selectedFilter = 'all';

  @override
  void initState() {
    super.initState();
    _fetchDeliveries();
  }

  List<Delivery> get _filteredDeliveries {
    if (_selectedFilter == 'all') return _deliveries;
    return _deliveries.where((d) => d.status == _selectedFilter).toList();
  }

  Future<void> _fetchDeliveries() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final deliveries = await _apiService.getDeliveries();
      if (mounted) {
        setState(() {
          _deliveries = deliveries;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  // ── PDF helpers ─────────────────────────────────────────────────────────────

  /// Generates PDF bytes for [delivery] using PdfService.
  Future<Uint8List> _generatePdfBytes(Delivery delivery) {
    return _pdfService.generateReceipt(delivery);
  }

  /// Opens the in-app PDF viewer (printable preview).
  Future<void> _viewInvoicePdf(Delivery delivery) async {
    try {
      await Printing.layoutPdf(
        onLayout: (_) => _generatePdfBytes(delivery),
        name: 'Invoice_${delivery.id}.pdf',
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

  /// Generates the PDF, uploads it, and opens WhatsApp
  Future<void> _shareInvoicePdf(Delivery delivery) async {
    try {
      final existingPdfUrl = delivery.invoice?.pdfUrl;

      // 1. If invoice exists and has URL, do NOT regenerate - directly share URL
      if (existingPdfUrl != null && existingPdfUrl.isNotEmpty) {
        final text = 'Please find attached the invoice for delivery ${delivery.id}.\n$existingPdfUrl';
        final phone = delivery.customerPhone?.replaceAll(RegExp(r'[^\d+]'), '') ?? '';
        
        if (phone.isNotEmpty) {
          final formattedPhone = phone.length == 10 ? '91$phone' : phone;
          final whatsappUrl = Uri.parse('https://wa.me/$formattedPhone?text=${Uri.encodeComponent(text)}');

          if (await launchUrl(whatsappUrl, mode: LaunchMode.externalApplication)) {
            return;
          }
        }
        await Share.share(text, subject: 'Invoice ${delivery.id}');
        return;
      }

      // 2. ELSE generate invoice once
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Preparing invoice for sharing...')),
      );
      
      final bytes = await _generatePdfBytes(delivery);

      String? uploadedUrl;
      try {
        final base64String = base64Encode(bytes);
        final filename = 'Invoice_${delivery.id}.pdf';
        uploadedUrl = await _apiService.uploadPdfBase64(base64String, filename);
      } catch (e) {
        debugPrint('Cloud upload failed: $e');
      }

      // 3. Prefer sharing via local file first using share_plus
      try {
        final tempDir = await getTemporaryDirectory();
        final file = await File('${tempDir.path}/Invoice_${delivery.id}.pdf').create();
        await file.writeAsBytes(bytes);

        final text = uploadedUrl != null 
            ? 'Please find attached the invoice for delivery ${delivery.id}.\n$uploadedUrl'
            : 'Please find attached the invoice for delivery ${delivery.id}.';

        await Share.shareXFiles([XFile(file.path)], text: text);
        return;
      } catch (localFileError) {
        debugPrint('Local file share failed: $localFileError');
      }

      // 4. Ultimate fallback to sending just the URL if file share fails
      if (uploadedUrl == null) {
        throw Exception('Failed to generate cloud link and local sharing failed');
      }

      final phone = delivery.customerPhone?.replaceAll(RegExp(r'[^\d+]'), '') ?? '';
      final textForUrl = 'Please find attached the invoice for delivery ${delivery.id}.\n$uploadedUrl';

      if (phone.isNotEmpty) {
        final formattedPhone = phone.length == 10 ? '91$phone' : phone;
        final whatsappUrl = Uri.parse('https://wa.me/$formattedPhone?text=${Uri.encodeComponent(textForUrl)}');

        if (await launchUrl(whatsappUrl, mode: LaunchMode.externalApplication)) {
          return;
        }
      }

      await Share.share(textForUrl, subject: 'Invoice ${delivery.id}');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Share failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // ── Delivery actions ────────────────────────────────────────────────────────

  Future<void> _deleteDelivery(Delivery delivery) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Delivery'),
        content: const Text('Are you sure you want to delete this delivery?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      await _apiService.deleteDelivery(delivery.id);
      if (delivery.customerId != null) {
        await _apiService.syncCustomerBalance(delivery.customerId!);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Delivery deleted successfully')),
        );
        _fetchDeliveries();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _markAsCompleted(Delivery delivery) async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final updated = delivery.copyWith(status: 'completed');
      await _apiService.updateDelivery(delivery.id, updated);
      if (delivery.customerId != null) {
        await _apiService.syncCustomerBalance(delivery.customerId!);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Delivery marked as completed!')),
        );
        _fetchDeliveries();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // ── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Row(
          children: [
            Image.asset(
              'assets/images/logo.png',
              width: 32,
              height: 32,
              fit: BoxFit.contain,
            ),
            const SizedBox(width: 12),
            Text(
              'BSM Agro Industry',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.primaryGreen,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications, color: AppColors.primaryGreen),
            onPressed: () {},
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'LOGISTICS OVERVIEW',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryGreen,
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Delivery List',
                  style: GoogleFonts.inter(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                _buildFilterChip('All Deliveries', 'all'),
                const SizedBox(width: 12),
                _buildFilterChip('Pending', 'pending'),
                const SizedBox(width: 12),
                _buildFilterChip('Completed', 'completed'),
              ],
            ),
          ),
          const SizedBox(height: 24),
          // Delivery List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(
                        child: Text(
                          'Error: $_error',
                          style: const TextStyle(color: Colors.red),
                        ),
                      )
                    : _filteredDeliveries.isEmpty
                        ? Center(
                            child: Text(
                              _selectedFilter == 'all'
                                  ? 'No deliveries found.'
                                  : 'No $_selectedFilter deliveries found.',
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: _fetchDeliveries,
                            child: ListView.builder(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 24, vertical: 8),
                              itemCount: _filteredDeliveries.length,
                              itemBuilder: (context, index) {
                                final delivery = _filteredDeliveries[index];
                                return DeliveryCard(
                                  delivery: delivery,
                                  onEdit: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            EditDeliveryScreen(delivery: delivery),
                                      ),
                                    ).then((_) => _fetchDeliveries());
                                  },
                                  onDelete: () => _deleteDelivery(delivery),
                                  onMarkCompleted: delivery.status == 'pending'
                                      ? () => _markAsCompleted(delivery)
                                      : null,
                                  onViewInvoice: () =>
                                      _viewInvoicePdf(delivery),
                                  onShare: () => _shareInvoicePdf(delivery),
                                );
                              },
                            ),
                          ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AddDeliveryScreen()),
          ).then((_) => _fetchDeliveries());
        },
        backgroundColor: AppColors.primaryGreen,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: const Icon(Icons.add, color: Colors.white, size: 28),
      ),
    );
  }

  Widget _buildFilterChip(String label, String filterValue) {
    bool isSelected = _selectedFilter == filterValue;
    Color activeColor = filterValue == 'pending'
        ? Colors.orange
        : (filterValue == 'completed' ? Colors.green : AppColors.primaryGreen);

    return InkWell(
      onTap: () => setState(() => _selectedFilter = filterValue),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color:
              isSelected ? activeColor : Colors.grey.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: isSelected ? Colors.white : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

// ── DeliveryCard ──────────────────────────────────────────────────────────────

class DeliveryCard extends StatelessWidget {
  final Delivery delivery;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback? onMarkCompleted;
  final VoidCallback onViewInvoice;
  final VoidCallback onShare;

  const DeliveryCard({
    super.key,
    required this.delivery,
    required this.onEdit,
    required this.onDelete,
    this.onMarkCompleted,
    required this.onViewInvoice,
    required this.onShare,
  });

  Color _getPriorityColor() {
    switch (delivery.priority) {
      case 'CRITICAL':
      case 'HIGH':
        return AppColors.negativeBalance;
      case 'MEDIUM':
        return const Color(0xFFF57C00);
      default:
        return AppColors.primaryGreen;
    }
  }

  /// Displayed amount: backend invoice amount if available, otherwise computed
  /// grand total from product line items.
  double get _displayAmount {
    final invoiceAmount = delivery.invoice?.amount ?? 0;
    if (invoiceAmount > 0) return invoiceAmount;
    return delivery.grandTotal;
  }

  @override
  Widget build(BuildContext context) {
    Color priorityColor = _getPriorityColor();
    final String productSummary = delivery.products.isEmpty
        ? 'No products'
        : delivery.products.map((p) => p.name).join(', ');

    bool isCompleted = delivery.status == 'completed';
    final bool hasInvoice = delivery.products.isNotEmpty || delivery.items.isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Priority / status left border stripe
          Positioned(
            left: 0,
            top: 16,
            bottom: 16,
            child: Container(
              width: 3,
              decoration: BoxDecoration(
                color: isCompleted ? Colors.green : priorityColor,
                borderRadius: const BorderRadius.only(
                  topRight: Radius.circular(4),
                  bottomRight: Radius.circular(4),
                ),
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Header row ──────────────────────────────────────────────
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        delivery.customerName,
                        style: GoogleFonts.inter(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: (isCompleted ? Colors.green : priorityColor)
                            .withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        isCompleted
                            ? 'COMPLETED'
                            : '${delivery.priority} PRIORITY',
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: isCompleted ? Colors.green : priorityColor,
                        ),
                      ),
                    ),
                  ],
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Order ${delivery.id}',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    if (delivery.invoice?.invoiceNumber?.isNotEmpty == true)
                      Text(
                        'Invoice: ${delivery.invoice!.invoiceNumber}',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primaryGreen,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),

                // ── Product + amount row ─────────────────────────────────────
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        isCompleted ? Icons.check_circle : Icons.agriculture,
                        color: isCompleted
                            ? Colors.green
                            : AppColors.primaryGreen,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'PRODUCTS',
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textSecondary,
                              letterSpacing: 0.5,
                            ),
                          ),
                          Text(
                            productSummary,
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            '₹ ${_displayAmount.toStringAsFixed(0)}',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              color: AppColors.primaryGreen,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // ── Invoice action buttons ───────────────────────────────────
                if (hasInvoice) ...[
                  Row(
                    children: [
                      Expanded(
                        child: _InvoiceActionButton(
                          icon: Icons.receipt_long_outlined,
                          label: 'View Invoice',
                          color: AppColors.primaryGreen,
                          onTap: onViewInvoice,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _InvoiceActionButton(
                          icon: Icons.share_outlined,
                          label: 'Share',
                          color: Colors.blueAccent,
                          onTap: onShare,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],

                const Divider(height: 1),
                const SizedBox(height: 12),

                // ── Footer row (date + action icons) ────────────────────────
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      delivery.formattedDate,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    Row(
                      children: [
                        if (onMarkCompleted != null)
                          Tooltip(
                            message: 'Mark as Completed',
                            child: IconButton(
                              icon: const Icon(Icons.check,
                                  color: Colors.green, size: 20),
                              onPressed: onMarkCompleted,
                            ),
                          ),
                        IconButton(
                          icon: const Icon(Icons.edit,
                              color: Colors.blue, size: 20),
                          onPressed: onEdit,
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete,
                              color: Colors.red, size: 20),
                          onPressed: onDelete,
                        ),
                      ],
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
}

// ── Small action button used inside the card ─────────────────────────────────

class _InvoiceActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _InvoiceActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
