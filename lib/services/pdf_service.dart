import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../models/delivery.dart';
import '../models/invoice_model.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';

class PdfService {
  // ── Cached resources (loaded once per app run) ────────────────────────────
  //
  // Font and asset loads are relatively expensive. These are safe to cache
  // because they are immutable and used across all PDF generations.
  static Future<({pw.Font regular, pw.Font bold, pw.Font italic})>? _fontsFuture;
  static Future<Uint8List>? _logoBytesFuture;

  static Future<({pw.Font regular, pw.Font bold, pw.Font italic})> _loadFonts() {
    return _fontsFuture ??= () async {
      final regular = await PdfGoogleFonts.robotoRegular();
      final bold = await PdfGoogleFonts.robotoBold();
      final italic = await PdfGoogleFonts.robotoItalic();
      return (regular: regular, bold: bold, italic: italic);
    }();
  }

  static Future<Uint8List> _loadLogoBytes() {
    return _logoBytesFuture ??= () async {
      final ByteData bytes = await rootBundle.load('assets/images/logo.png');
      return bytes.buffer.asUint8List();
    }();
  }

  Future<Uint8List> generateReceipt(Delivery delivery) async {
    print("Products: ${delivery.products}");
    print("Items: ${delivery.items}");
    
    final items = delivery.products.isNotEmpty ? delivery.products : delivery.items;

    final total = delivery.grandTotal > 0
        ? delivery.grandTotal
        : items.fold(0.0, (sum, item) => (sum as double) + item.total);
        
    final finalPayable = delivery.updatedBalance != 0
        ? delivery.updatedBalance
        : total;

    final fonts = await _loadFonts();
    final font = fonts.regular;
    final fontBold = fonts.bold;
    final fontItalic = fonts.italic;

    final pdf = pw.Document(
      theme: pw.ThemeData.withFont(
        base: font,
        bold: fontBold,
        italic: fontItalic,
      ),
    );

    // Theme Colors
    const primaryColor = PdfColor.fromInt(0xFF277533);
    const accentColor = PdfColor.fromInt(0xFFF1F8E9);
    
    // Load local asset logo
    final Uint8List logoBytes = await _loadLogoBytes();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              
              // ==============================
              // HEADER (Top Center)
              // ==============================
              pw.Center(
                child: pw.Column(
                  children: [
                    pw.Image(
                      pw.MemoryImage(logoBytes),
                      width: 80,
                      height: 80,
                    ),
                    pw.SizedBox(height: 12),
                    pw.Text(
                      'BSM Agro Industry',
                      style: pw.TextStyle(
                        font: fontBold,
                        color: primaryColor,
                        fontSize: 24,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      'Delivery Receipt',
                      style: pw.TextStyle(
                        font: fontBold,
                        fontSize: 16,
                        color: PdfColors.grey700,
                        letterSpacing: 2,
                      ),
                    ),
                  ],
                ),
              ),
              
              pw.SizedBox(height: 40),
              pw.Divider(color: PdfColors.grey400, thickness: 1),
              pw.SizedBox(height: 16),

              // ==============================
              // RECEIPT & CUSTOMER DETAILS
              // ==============================
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'CUSTOMER',
                        style: pw.TextStyle(font: fontBold, fontSize: 10, color: PdfColors.grey600),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        delivery.customerName,
                        style: pw.TextStyle(font: fontBold, fontSize: 14),
                      ),
                      if (delivery.invoice?.companyName?.isNotEmpty == true)
                        pw.Text('Company: ${delivery.invoice!.companyName}',
                            style: pw.TextStyle(font: font, fontSize: 12, color: PdfColors.black)),
                      if (delivery.invoice?.address?.isNotEmpty == true)
                        pw.Text('Address: ${delivery.invoice!.address}',
                            style: pw.TextStyle(font: font, fontSize: 12, color: PdfColors.black)),
                      if (delivery.customerPhone?.isNotEmpty == true)
                        pw.Text('Phone: ${delivery.customerPhone}',
                            style: pw.TextStyle(font: font, fontSize: 12, color: PdfColors.black)),
                      if (delivery.invoice?.gstNumber?.isNotEmpty == true)
                        pw.Text('GST: ${delivery.invoice!.gstNumber}',
                            style: pw.TextStyle(font: font, fontSize: 12, color: PdfColors.black)),
                      ...delivery.invoice?.customFields.map((field) => pw.Text(
                        '${field['label']}: ${field['value']}',
                        style: pw.TextStyle(font: font, fontSize: 12, color: PdfColors.black),
                      )).toList() ?? [],
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        'RECEIPT DETAILS',
                        style: pw.TextStyle(font: fontBold, fontSize: 10, color: PdfColors.grey600),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        'ID: ${delivery.id}',
                        style: pw.TextStyle(font: fontBold, fontSize: 12),
                      ),
                      pw.Text(
                        'Date: ${delivery.formattedDate}',
                        style: pw.TextStyle(font: font, fontSize: 12, color: PdfColors.black),
                      ),
                    ],
                  )
                ],
              ),
              pw.SizedBox(height: 32),

              // ==============================
              // DELIVERY DETAILS (Table)
              // ==============================
              pw.Container(
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: primaryColor, width: 2),
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                ),
                child: pw.Table(
                  columnWidths: {
                    0: const pw.FlexColumnWidth(3),
                    1: const pw.FlexColumnWidth(2),
                    2: const pw.FlexColumnWidth(2),
                    3: const pw.FlexColumnWidth(2),
                  },
                  children: [
                    // Table Header
                    pw.TableRow(
                      decoration: const pw.BoxDecoration(
                        color: accentColor,
                        borderRadius: pw.BorderRadius.vertical(top: pw.Radius.circular(6)),
                      ),
                      children: [
                        _buildTableCell('Product Type', font, fontBold, isHeader: true),
                        _buildTableCell('Quantity', font, fontBold, isHeader: true, align: pw.TextAlign.center),
                        _buildTableCell('Price/Unit', font, fontBold, isHeader: true, align: pw.TextAlign.right),
                        _buildTableCell('Total Amount', font, fontBold, isHeader: true, align: pw.TextAlign.right),
                      ],
                    ),
                    // Table Rows
                    ...items.map((item) => pw.TableRow(
                          decoration: const pw.BoxDecoration(
                            border: pw.Border(top: pw.BorderSide(color: PdfColors.grey300)),
                          ),
                          children: [
                            _buildTableCell(item.product, font, fontBold),
                            _buildTableCell('${item.qty} ${item.unit}', font, fontBold, align: pw.TextAlign.center),
                            _buildTableCell('₹ ${item.price.toStringAsFixed(2)}', font, fontBold, align: pw.TextAlign.right),
                            _buildTableCell('₹ ${item.total.toStringAsFixed(2)}', font, fontBold, align: pw.TextAlign.right),
                          ],
                        )),
                  ],
                ),
              ),
              pw.SizedBox(height: 24),

              // ==============================
              // FINANCIAL SUMMARY
              // ==============================
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.end,
                children: [
                  pw.Container(
                    width: 250,
                    child: pw.Column(
                      children: [
                        _buildSummaryRow('Delivery Total:', '₹ ${total.toStringAsFixed(2)}', font, fontBold),
                        
                        if (delivery.previousBalance != 0)
                          _buildSummaryRow(
                            delivery.previousBalance > 0 ? 'Old Balance:' : 'Advance:', 
                            '₹ ${delivery.previousBalance.abs().toStringAsFixed(2)}',
                            font, 
                            fontBold
                          ),
                          
                        pw.Divider(color: PdfColors.grey400),
                        pw.SizedBox(height: 4),
                        pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Text(
                              'FINAL PAYABLE',
                              style: pw.TextStyle(font: fontBold, fontSize: 14, color: primaryColor),
                            ),
                            pw.Text(
                              '₹ ${finalPayable.toStringAsFixed(2)}', 
                              style: pw.TextStyle(font: fontBold, fontSize: 16, color: primaryColor),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              
              pw.Spacer(),

              // ==============================
              // FOOTER
              // ==============================
              pw.Divider(color: PdfColors.grey400),
              pw.SizedBox(height: 8),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'Thank you for doing business with us!',
                        style: pw.TextStyle(font: fontItalic, fontSize: 12),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        'Generated: ${DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now())}',
                        style: pw.TextStyle(font: font, fontSize: 8, color: PdfColors.grey600),
                      ),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      pw.SizedBox(height: 20),
                      pw.Container(width: 100, height: 1, color: PdfColors.grey400),
                      pw.SizedBox(height: 4),
                      pw.Text('Authorized Signature', style: pw.TextStyle(font: font, fontSize: 8, color: PdfColors.grey600)),
                    ],
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  pw.Widget _buildTableCell(String text, pw.Font font, pw.Font fontBold, {bool isHeader = false, pw.TextAlign align = pw.TextAlign.left}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: pw.Text(
        text,
        textAlign: align,
        style: pw.TextStyle(
          font: isHeader ? fontBold : font,
          fontSize: 10,
          color: isHeader ? PdfColor.fromInt(0xFF277533) : PdfColors.black,
        ),
      ),
    );
  }

  pw.Widget _buildSummaryRow(String label, String value, pw.Font font, pw.Font fontBold) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 4),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(font: font, fontSize: 12),
          ),
          pw.Text(
            value,
            style: pw.TextStyle(font: fontBold, fontSize: 12),
          ),
        ],
      ),
    );
  }

  // ── Invoice-aware PDF generator ───────────────────────────────────────────

  /// Generates an invoice PDF from an [InvoiceModel].
  /// Renders an "UPDATED INVOICE" banner when [invoice.isUpdated] is true.
  Future<Uint8List> generateInvoice(InvoiceModel invoice) async {
    print("Products: ${invoice.products}");
    print("Items: ${invoice.items}");
    
    final items = invoice.products.isNotEmpty ? invoice.products : invoice.items;

    final total = invoice.totalAmount > 0
        ? invoice.totalAmount
        : items.fold(0.0, (sum, item) => (sum as double) + item.total);
        
    final finalPayable = invoice.finalAmount != 0
        ? invoice.finalAmount
        : total;

    final fonts = await _loadFonts();
    final font = fonts.regular;
    final fontBold = fonts.bold;
    final fontItalic = fonts.italic;

    final pdf = pw.Document(
      theme: pw.ThemeData.withFont(
        base: font,
        bold: fontBold,
        italic: fontItalic,
      ),
    );

    const primaryColor = PdfColor.fromInt(0xFF277533);
    const accentColor = PdfColor.fromInt(0xFFF1F8E9);
    const updatedColor = PdfColor.fromInt(0xFFE65100); // deep orange for UPDATED

    final Uint8List logoBytes = await _loadLogoBytes();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [

              // ── UPDATED INVOICE BANNER ─────────────────────────────────
              if (invoice.isUpdated)
                pw.Container(
                  width: double.infinity,
                  margin: const pw.EdgeInsets.only(bottom: 16),
                  padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                  decoration: const pw.BoxDecoration(
                    color: updatedColor,
                    borderRadius: pw.BorderRadius.all(pw.Radius.circular(6)),
                  ),
                  child: pw.Center(
                    child: pw.Text(
                      '★  UPDATED INVOICE  ★',
                      style: pw.TextStyle(
                        font: fontBold,
                        color: PdfColors.white,
                        fontSize: 13,
                        letterSpacing: 2,
                      ),
                    ),
                  ),
                ),

              // ── HEADER ─────────────────────────────────────────────────
              pw.Center(
                child: pw.Column(
                  children: [
                    pw.Image(pw.MemoryImage(logoBytes), width: 70, height: 70),
                    pw.SizedBox(height: 10),
                    pw.Text(
                      'BSM Agro Industry',
                      style: pw.TextStyle(
                        font: fontBold,
                        color: primaryColor,
                        fontSize: 22,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      invoice.isUpdated ? 'Updated Invoice' : 'Invoice',
                      style: pw.TextStyle(
                        font: fontBold,
                        fontSize: 14,
                        color: invoice.isUpdated ? updatedColor : PdfColors.grey700,
                        letterSpacing: 2,
                      ),
                    ),
                  ],
                ),
              ),

              pw.SizedBox(height: 28),
              pw.Divider(color: PdfColors.grey400, thickness: 1),
              pw.SizedBox(height: 14),

              // ── INVOICE & CUSTOMER META ────────────────────────────────
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('CUSTOMER',
                          style: pw.TextStyle(
                              font: fontBold, fontSize: 9, color: PdfColors.grey600)),
                      pw.SizedBox(height: 4),
                      pw.Text(invoice.customerName,
                          style: pw.TextStyle(font: fontBold, fontSize: 13)),
                      if (invoice.companyName?.isNotEmpty == true)
                        pw.Text('Company: ${invoice.companyName}',
                            style: pw.TextStyle(font: font, fontSize: 11, color: PdfColors.black)),
                      if (invoice.address?.isNotEmpty == true)
                        pw.Text('Address: ${invoice.address}',
                            style: pw.TextStyle(font: font, fontSize: 11, color: PdfColors.black)),
                      if (invoice.customerPhone.isNotEmpty)
                        pw.Text('Phone: ${invoice.customerPhone}',
                            style: pw.TextStyle(font: font, fontSize: 11, color: PdfColors.black)),
                      if (invoice.gstNumber?.isNotEmpty == true)
                        pw.Text('GST: ${invoice.gstNumber}',
                            style: pw.TextStyle(font: font, fontSize: 11, color: PdfColors.black)),
                      ...invoice.customFields.map((field) => pw.Text(
                        '${field['label']}: ${field['value']}',
                        style: pw.TextStyle(font: font, fontSize: 11, color: PdfColors.black),
                      )),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text('INVOICE DETAILS',
                          style: pw.TextStyle(
                              font: fontBold, fontSize: 9, color: PdfColors.grey600)),
                      pw.SizedBox(height: 4),
                      pw.Text(invoice.invoiceNumber,
                          style: pw.TextStyle(font: fontBold, fontSize: 11,
                              color: invoice.isUpdated ? updatedColor : primaryColor)),
                      pw.Text('Date: ${invoice.formattedDate}',
                          style: pw.TextStyle(font: font, fontSize: 11, color: PdfColors.black)),
                      pw.Text('Time: ${invoice.formattedTime}',
                          style: pw.TextStyle(font: font, fontSize: 10, color: PdfColors.grey)),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 28),

              // ── PRODUCTS TABLE ─────────────────────────────────────────
              pw.Container(
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: primaryColor, width: 2),
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                ),
                child: pw.Table(
                  columnWidths: {
                    0: const pw.FlexColumnWidth(3),
                    1: const pw.FlexColumnWidth(2),
                    2: const pw.FlexColumnWidth(2),
                    3: const pw.FlexColumnWidth(2),
                  },
                  children: [
                    pw.TableRow(
                      decoration: const pw.BoxDecoration(
                        color: accentColor,
                        borderRadius: pw.BorderRadius.vertical(top: pw.Radius.circular(6)),
                      ),
                      children: [
                        _buildTableCell('Product Type', font, fontBold, isHeader: true),
                        _buildTableCell('Quantity', font, fontBold, isHeader: true, align: pw.TextAlign.center),
                        _buildTableCell('Price/Unit', font, fontBold, isHeader: true, align: pw.TextAlign.right),
                        _buildTableCell('Total', font, fontBold, isHeader: true, align: pw.TextAlign.right),
                      ],
                    ),
                    ...items.map((item) => pw.TableRow(
                          decoration: const pw.BoxDecoration(
                            border: pw.Border(top: pw.BorderSide(color: PdfColors.grey300)),
                          ),
                          children: [
                            _buildTableCell(item.product, font, fontBold),
                            _buildTableCell('${item.qty} ${item.unit}',
                                font, fontBold, align: pw.TextAlign.center),
                            _buildTableCell('₹ ${item.price.toStringAsFixed(2)}',
                                font, fontBold, align: pw.TextAlign.right),
                            _buildTableCell('₹ ${item.total.toStringAsFixed(2)}',
                                font, fontBold, align: pw.TextAlign.right),
                          ],
                        )),
                  ],
                ),
              ),
              pw.SizedBox(height: 20),

              // ── FINANCIAL SUMMARY ──────────────────────────────────────
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.end,
                children: [
                  pw.Container(
                    width: 240,
                    child: pw.Column(
                      children: [
                        _buildSummaryRow('Delivery Total:',
                            '₹ ${total.toStringAsFixed(2)}', font, fontBold),
                        if (invoice.previousBalance != 0)
                          _buildSummaryRow(
                            invoice.previousBalance > 0 ? 'Old Balance:' : 'Advance:',
                            '₹ ${invoice.previousBalance.abs().toStringAsFixed(2)}', font, fontBold,
                          ),
                        pw.Divider(color: PdfColors.grey400),
                        pw.SizedBox(height: 4),
                        pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Text(
                              'FINAL PAYABLE',
                              style: pw.TextStyle(
                                  font: fontBold,
                                  fontSize: 13,
                                  color: primaryColor),
                            ),
                            pw.Text(
                              '₹ ${finalPayable.toStringAsFixed(2)}',
                              style: pw.TextStyle(
                                  font: fontBold,
                                  fontSize: 15,
                                  color: primaryColor),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              pw.Spacer(),

              // ── FOOTER ─────────────────────────────────────────────────
              pw.Divider(color: PdfColors.grey400),
              pw.SizedBox(height: 6),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'Thank you for doing business with us!',
                        style: pw.TextStyle(
                            font: fontItalic,
                            fontSize: 11),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        'Generated: ${DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now())}',
                        style: pw.TextStyle(font: font, fontSize: 8, color: PdfColors.grey600),
                      ),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      pw.SizedBox(height: 20),
                      pw.Container(width: 100, height: 1, color: PdfColors.grey400),
                      pw.SizedBox(height: 4),
                      pw.Text('Authorized Signature',
                          style: pw.TextStyle(font: font, fontSize: 8, color: PdfColors.grey600)),
                    ],
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }
}
