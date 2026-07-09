import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../core/app_colors.dart';
import 'package:url_launcher/url_launcher.dart';

class CreditInvoicePreviewScreen extends StatelessWidget {
  final Map<String, dynamic> invoiceData;

  const CreditInvoicePreviewScreen({
    super.key,
    required this.invoiceData,
  });

  static const _green = AppColors.primaryGreen;

  String get _invoiceNumber => invoiceData['invoiceNumber']?.toString() ?? 'INV-PENDING';
  String get _customerName => invoiceData['customerName']?.toString() ?? invoiceData['customer']?.toString() ?? 'Unknown Customer';
  String get _customerPhone => invoiceData['customerPhone']?.toString() ?? '';
  String get _notes => invoiceData['notes']?.toString() ?? '';

  double _parse(dynamic val) {
    if (val == null) return 0.0;
    if (val is num) return val.toDouble();
    if (val is String) return double.tryParse(val) ?? 0.0;
    return 0.0;
  }

  double get _previousBalance => _parse(invoiceData['previousBalance']);
  double get _grandTotal => _parse(invoiceData['grandTotal'] ?? invoiceData['totalAmount'] ?? invoiceData['amount']);
  double get _paymentReceived => _parse(invoiceData['paymentReceived']);
  double get _pendingAmount => _parse(invoiceData['pendingAmount'] ?? invoiceData['currentSalePending'] ?? (_grandTotal - _paymentReceived));
  double get _currentBalance => _parse(invoiceData['currentBalance'] ?? invoiceData['updatedBalance'] ?? (_previousBalance + _pendingAmount));
  double get _outstandingPayment => _parse(invoiceData['outstandingPayment']);
  double get _finalOutstanding =>
    _currentBalance - _outstandingPayment;

  String get _dateString {
    final rawDate = invoiceData['createdAt'] ?? invoiceData['date'];
    final date = rawDate != null ? (DateTime.tryParse(rawDate.toString())?.toLocal() ?? DateTime.now()) : DateTime.now();
    const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  List<Map<String, dynamic>> get _items {
    final raw = invoiceData['items'] ?? invoiceData['products'];
    if (raw is List) {
      return raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }
    return [];
  }

  Future<void> _handlePrint(BuildContext context) async {
    try {
      final pdfBytes = await _generatePdf();
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdfBytes,
        name: 'Credit_Sale_Invoice_$_invoiceNumber',
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error printing: $e')));
      }
    }
  }

  Future<void> _handleShare(BuildContext context) async {
    debugPrint("Phone: $_customerPhone");
    try {
      final pdfBytes = await _generatePdf();
      await Printing.sharePdf(
        bytes: pdfBytes,
        filename: 'Credit_Sale_Invoice_$_invoiceNumber.pdf',
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error sharing: $e')));
      }
    }
  }
  Future<void> _sendCustomerSms(BuildContext context) async {
  String message = '''
BSM AGRO

Dear $_customerName,

Your account has been updated.

Previous Balance : ₹${_previousBalance.toStringAsFixed(0)}

Purchase Amount : ₹${_grandTotal.toStringAsFixed(0)}

Payment Received : ₹${_paymentReceived.toStringAsFixed(0)}

Balance Added : ₹${_pendingAmount.toStringAsFixed(0)}
''';

if (_outstandingPayment > 0) {
  message += '''

Outstanding Payment Received : ₹${_outstandingPayment.toStringAsFixed(0)}
''';
}

message += '''

Current Outstanding : ₹${_finalOutstanding.toStringAsFixed(0)}

For any queries, please contact us.

Thank you,
BSM AGRO
''';

  final uri = Uri(
    scheme: 'sms',
    path: _customerPhone,
    queryParameters: {
      'body': message,
    },
  );

  if (await canLaunchUrl(uri)) {
    await launchUrl(uri);
  } else {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to open SMS application'),
        ),
      );
    }
  }
}

  Future<Uint8List> _generatePdf() async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('BSM Agro Industry', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
                      pw.SizedBox(height: 4),
                      pw.Text('Reliable Feed & Crop Solutions', style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey700)),
                      pw.SizedBox(height: 20),
                      pw.Text('CREDIT SALE INVOICE', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: PdfColors.green800)),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text('INVOICE', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600)),
                      pw.Text(_invoiceNumber, style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                      pw.SizedBox(height: 8),
                      pw.Text('DATE', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600)),
                      pw.Text(_dateString, style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 30),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('BILL TO', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.grey600)),
                      pw.SizedBox(height: 4),
                      pw.Text(_customerName, style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
                      pw.Text(_customerPhone, style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey700)),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text('PREV. BALANCE', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.grey600)),
                      pw.SizedBox(height: 4),
                      pw.Text('Rs ${_previousBalance.toStringAsFixed(0)}', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: _previousBalance > 0 ? PdfColors.red : PdfColors.green)),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 30),
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey300, width: 1),
                columnWidths: {
                  0: const pw.FlexColumnWidth(3),
                  1: const pw.FlexColumnWidth(1),
                  2: const pw.FlexColumnWidth(1),
                  3: const pw.FlexColumnWidth(1),
                },
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                    children: [
                      pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('ITEM', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold))),
                      pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('QTY', textAlign: pw.TextAlign.center, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold))),
                      pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('PRICE', textAlign: pw.TextAlign.center, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold))),
                      pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('TOTAL', textAlign: pw.TextAlign.right, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold))),
                    ],
                  ),
                  ..._items.map((item) {
                    final name = item['product']?.toString() ?? item['itemName']?.toString() ?? 'Item';
                    final qty = _parse(item['qty'] ?? item['quantity']);
                    final unit = item['unit']?.toString() ?? '';
                    final displayUnit = unit.isEmpty ? 'Bag' : unit;
                    final price = _parse(item['price']);
                    final total = _parse(item['total'] ?? item['totalAmount']);
                    return pw.TableRow(
                      children: [
                        pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text(name, style: const pw.TextStyle(fontSize: 11))),
                        pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('${qty.toStringAsFixed(0)} $displayUnit', textAlign: pw.TextAlign.center, style: const pw.TextStyle(fontSize: 11))),
                        pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text(price.toStringAsFixed(0), textAlign: pw.TextAlign.center, style: const pw.TextStyle(fontSize: 11))),
                        pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text(total.toStringAsFixed(2), textAlign: pw.TextAlign.right, style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold))),
                      ],
                    );
                  }),
                ],
              ),
              pw.SizedBox(height: 20),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.end,
                children: [
                  pw.Container(
                    width: 250,
                    child: pw.Column(
                      children: [
                        pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                          pw.Text('Grand Total', style: const pw.TextStyle(fontSize: 12)),
                          pw.Text('Rs ${_grandTotal.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                        ]),
                        pw.SizedBox(height: 4),
                        pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                          pw.Text('Payment Received', style: const pw.TextStyle(fontSize: 12)),
                          pw.Text('- Rs ${_paymentReceived.toStringAsFixed(2)}', style: const pw.TextStyle(fontSize: 12)),
                        ]),
                        pw.Divider(color: PdfColors.grey300),
                        pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                          pw.Text('Current Sale Pending', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                          pw.Text('Rs ${_pendingAmount.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.green800)),
                        ]),
                      ],
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 20),
              pw.Container(
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  color: _finalOutstanding > 0 ? PdfColors.red50 : PdfColors.green50,
                  border: pw.Border.all(color: _finalOutstanding > 0 ? PdfColors.red200 : PdfColors.green200),
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                ),
                child: pw.Column(
                  children: [
                    pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                      pw.Text('Previous Balance', style: const pw.TextStyle(fontSize: 12)),
                      pw.Text('Rs ${_previousBalance.toStringAsFixed(0)}', style: pw.TextStyle(fontSize: 12, color: _previousBalance > 0 ? PdfColors.red : PdfColors.grey700)),
                    ]),
                    pw.SizedBox(height: 4),
                    pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                      pw.Text('Current Sale Pending', style: const pw.TextStyle(fontSize: 12)),
                      pw.Text('Rs ${_pendingAmount.toStringAsFixed(0)}', style: pw.TextStyle(fontSize: 12, color: PdfColors.green800)),
                    ]),
                    if (_outstandingPayment > 0) ...[
                      pw.SizedBox(height: 4),
                      pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                        pw.Text('Payment Towards Previous Balance', style: pw.TextStyle(fontSize: 12, color: PdfColors.green800)),
                        pw.Text('- Rs ${_outstandingPayment.toStringAsFixed(0)}', style: pw.TextStyle(fontSize: 12, color: PdfColors.green800)),
                      ]),
                    ],
                    pw.Divider(color: _finalOutstanding > 0 ? PdfColors.red200 : PdfColors.green200),
                    pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                      pw.Text('Current Outstanding', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                      pw.Text('Rs ${_finalOutstanding.toStringAsFixed(0)}', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: _finalOutstanding > 0 ? PdfColors.red : PdfColors.green800)),
                    ]),
                  ],
                ),
              ),
              if (_notes.isNotEmpty) ...[
                pw.SizedBox(height: 20),
                pw.Text('Notes:', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 4),
                pw.Text(_notes, style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey700)),
              ],
              pw.Spacer(),
              pw.Divider(color: PdfColors.grey300),
              pw.SizedBox(height: 8),
              pw.Center(
                child: pw.Text('Thank you for your business!', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.green800)),
              ),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  @override
  Widget build(BuildContext context) {
    debugPrint("========== CREDIT INVOICE ==========");
  debugPrint(invoiceData.toString());
  debugPrint("Items: ${invoiceData['items']}");
  debugPrint("Products: ${invoiceData['products']}");
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F0),
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Invoice Preview', style: GoogleFonts.inter(
          fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
        actions: [
          IconButton(
  onPressed: () => _sendCustomerSms(context),
  icon: const Icon(
    Icons.sms_outlined,
    color: Colors.orange,
  ),
),
          TextButton.icon(
            onPressed: () => _handlePrint(context),
            icon: const Icon(Icons.print_outlined, size: 18, color: _green),
            label: Text('Print', style: GoogleFonts.inter(color: _green, fontWeight: FontWeight.w600)),
          ),
          TextButton.icon(
            onPressed: () => _handleShare(context),
            icon: const Icon(Icons.share_outlined, size: 18, color: Colors.deepPurple),
            label: Text('Share', style: GoogleFonts.inter(color: Colors.deepPurple, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 20, offset: const Offset(0, 6))],
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                // ── Header ──────────────────────────────────────────────────────
                Container(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [_green, const Color(0xFF1B5E20)],
                      begin: Alignment.topLeft, end: Alignment.bottomRight,
                    ),
                    borderRadius: const BorderRadius.only(topLeft: Radius.circular(16), topRight: Radius.circular(16)),
                  ),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Container(
                        width: 48, height: 48,
                        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(12)),
                        alignment: Alignment.center,
                        child: const Icon(Icons.agriculture, color: Colors.white, size: 26),
                      ),
                      const SizedBox(width: 14),
                      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('BSM Agro Industry', style: GoogleFonts.inter(
                          fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                        Text('Credit Sale Invoice', style: GoogleFonts.inter(
                          fontSize: 12, color: Colors.white.withValues(alpha: 0.8))),
                      ]),
                      const Spacer(),
                      Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                        Text('INVOICE', style: GoogleFonts.inter(
                          fontSize: 10, color: Colors.white.withValues(alpha: 0.7), letterSpacing: 1.5)),
                        Text(_invoiceNumber, style: GoogleFonts.inter(
                          fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white)),
                      ]),
                    ]),
                    const SizedBox(height: 16),
                    Row(children: [
                      _HeaderPill(label: 'DATE', value: _dateString),
                      const SizedBox(width: 10),
                      _HeaderPill(label: 'STATUS', value: 'CREDIT SALE'),
                    ]),
                  ]),
                ),

                // ── Bill To ──────────────────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('BILL TO', style: GoogleFonts.inter(
                        fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.textSecondary, letterSpacing: 1.2)),
                      const SizedBox(height: 6),
                      Text(_customerName, style: GoogleFonts.inter(
                        fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                      Text(_customerPhone, style: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary)),
                    ])),
                    Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                      Text('PREV. BALANCE', style: GoogleFonts.inter(
                        fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.textSecondary, letterSpacing: 1.2)),
                      const SizedBox(height: 6),
                      Text('₹${_previousBalance.toStringAsFixed(0)}',
                        style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold,
                          color: _previousBalance > 0 ? Colors.red : Colors.green)),
                    ]),
                  ]),
                ),

                // ── Items Table ───────────────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                  child: Column(children: [
                    // Header row
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: _green.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(children: [
                        Expanded(flex: 3, child: Text('ITEM', style: _tableHeader())),
                        Expanded(child: Text('QTY', style: _tableHeader(), textAlign: TextAlign.center)),
                        Expanded(child: Text('PRICE', style: _tableHeader(), textAlign: TextAlign.center)),
                        Expanded(child: Text('TOTAL', style: _tableHeader(), textAlign: TextAlign.end)),
                      ]),
                    ),
                    const SizedBox(height: 4),
                    ..._items.map((item) {
                      final name = item['product']?.toString() ?? item['itemName']?.toString() ?? 'Item';
                      final qty = _parse(item['qty'] ?? item['quantity']);
                      final unit = item['unit']?.toString() ?? '';
                      final displayUnit = unit.isEmpty ? 'Bag' : unit;
                      final price = _parse(item['price']);
                      final total = _parse(item['total'] ?? item['totalAmount']);
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          border: Border(bottom: BorderSide(color: AppColors.border.withValues(alpha: 0.5))),
                        ),
                        child: Row(children: [
                          Expanded(flex: 3, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(name, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                          ])),
                          Expanded(child: Text('${qty.toStringAsFixed(0)} $displayUnit', style: GoogleFonts.inter(fontSize: 13, color: AppColors.textPrimary), textAlign: TextAlign.center)),
                          Expanded(child: Text('₹${price.toStringAsFixed(0)}', style: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary), textAlign: TextAlign.center)),
                          Expanded(child: Text('₹${total.toStringAsFixed(2)}', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary), textAlign: TextAlign.end)),
                        ]),
                      );
                    }),
                  ]),
                ),

                // ── Totals ────────────────────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                  child: Column(children: [
                    _TotalRow('Grand Total', '₹${_grandTotal.toStringAsFixed(2)}', AppColors.textPrimary),
                    if (_paymentReceived > 0) _TotalRow('Payment Received', '- ₹${_paymentReceived.toStringAsFixed(2)}', Colors.blue),
                    const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Divider()),
                    _TotalRow('Current Sale Pending', '₹${_pendingAmount.toStringAsFixed(2)}', _green, bold: true, large: true),
                  ]),
                ),

                // ── Outstanding Balance ────────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: _finalOutstanding > 0 ? Colors.red.withValues(alpha: 0.04) : _green.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: _finalOutstanding > 0 ? Colors.red.withValues(alpha: 0.25) : _green.withValues(alpha: 0.25)),
                    ),
                    child: Column(children: [
                      _TotalRow('Previous Balance', '₹${_previousBalance.toStringAsFixed(0)}',
                        _previousBalance > 0 ? Colors.red : AppColors.textSecondary),
                      const SizedBox(height: 4),
                      _TotalRow('Current Sale Pending', '₹${_pendingAmount.toStringAsFixed(0)}', _green),
                      if (_outstandingPayment > 0) ...[
                        const SizedBox(height: 4),
                        _TotalRow('Payment Towards Previous Balance', '- ₹${_outstandingPayment.toStringAsFixed(0)}', Colors.green),
                      ],
                      const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Divider()),
                      _TotalRow('Current Outstanding', '₹${_finalOutstanding.toStringAsFixed(0)}',
                        _finalOutstanding > 0 ? Colors.red : _green, bold: true, large: true),
                    ]),
                  ),
                ),

                // ── Notes ─────────────────────────────────────────────────────────
                if (_notes.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50, borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const Icon(Icons.notes_outlined, size: 16, color: AppColors.textSecondary),
                        const SizedBox(width: 8),
                        Expanded(child: Text(_notes, style: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary))),
                      ]),
                    ),
                  ),

                // ── Footer ────────────────────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
                  child: Column(children: [
                    const Divider(),
                    const SizedBox(height: 12),
                    Text('Thank you for your business!', style: GoogleFonts.inter(
                      fontSize: 14, fontWeight: FontWeight.bold, color: _green)),
                    const SizedBox(height: 4),
                    Text('BSM Agro Industry — Reliable Feed & Crop Solutions',
                      style: GoogleFonts.inter(fontSize: 11, color: AppColors.textSecondary), textAlign: TextAlign.center),
                  ]),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }

  TextStyle _tableHeader() => GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold,
      color: AppColors.textSecondary, letterSpacing: 0.8);
}

class _HeaderPill extends StatelessWidget {
  final String label, value;
  const _HeaderPill({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(6)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Text('$label  ', style: GoogleFonts.inter(fontSize: 9, color: Colors.white.withValues(alpha: 0.7), letterSpacing: 0.8)),
        Text(value, style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white)),
      ]),
    );
  }
}

class _TotalRow extends StatelessWidget {
  final String label, value;
  final Color color;
  final bool bold, large;
  const _TotalRow(this.label, this.value, this.color, {this.bold = false, this.large = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label, style: GoogleFonts.inter(fontSize: large ? 14 : 13, color: AppColors.textSecondary,
          fontWeight: bold ? FontWeight.w600 : FontWeight.normal)),
        Text(value, style: GoogleFonts.inter(fontSize: large ? 17 : 14, fontWeight: bold ? FontWeight.bold : FontWeight.w600, color: color)),
      ]),
    );
  }
}
