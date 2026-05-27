import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/delivery.dart';
import 'base_invoice_template.dart';

/// GST-style invoice with CGST / SGST tax breakdown rows (purple theme).
class GstTemplate extends BaseInvoiceTemplate {
  const GstTemplate();

  @override
  String get id => 'gst';

  @override
  String get name => 'GST';

  static const double _gstRate = 18.0; // 9% CGST + 9% SGST

  static Future<({pw.Font regular, pw.Font bold, pw.Font italic})>? _fontsFuture;
  static Future<Uint8List>? _logoByteFuture;

  static Future<({pw.Font regular, pw.Font bold, pw.Font italic})> _loadFonts() {
    return _fontsFuture ??= () async {
      final regular = await PdfGoogleFonts.latoRegular();
      final bold    = await PdfGoogleFonts.latoBold();
      final italic  = await PdfGoogleFonts.latoItalic();
      return (regular: regular, bold: bold, italic: italic);
    }();
  }

  static Future<Uint8List> _loadLogo() {
    return _logoByteFuture ??= () async {
      final data = await rootBundle.load('assets/images/logo.png');
      return data.buffer.asUint8List();
    }();
  }

  @override
  Future<Uint8List> generate(Delivery delivery) async {
    const primaryColor = PdfColor.fromInt(0xFF6A1B9A); // purple
    const accentBg     = PdfColor.fromInt(0xFFF3E5F5);
    const borderColor  = PdfColor.fromInt(0xFFBA68C8);

    final fonts      = await _loadFonts();
    final logoBytes  = await _loadLogo();
    final font       = fonts.regular;
    final fontBold   = fonts.bold;
    final fontItalic = fonts.italic;

    final items = delivery.products.isNotEmpty ? delivery.products : delivery.items;
    final subTotal = delivery.deliveryTotal > 0
        ? delivery.deliveryTotal
        : items.fold(0.0, (s, i) => s + i.totalAmount);
    final cgst = subTotal * (_gstRate / 2) / 100;
    final sgst = cgst;
    final totalWithGst = subTotal + cgst + sgst;
    final prevBal = delivery.previousBalance;
    final finalPayable = prevBal != 0 ? totalWithGst + prevBal : totalWithGst;

    final pdf = pw.Document(
      theme: pw.ThemeData.withFont(base: font, bold: fontBold, italic: fontItalic),
    );

    pdf.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(32),
      build: (ctx) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          // Header
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.Row(children: [
                pw.Image(pw.MemoryImage(logoBytes), width: 56, height: 56),
                pw.SizedBox(width: 12),
                pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                  pw.Text('BSM Agro Industry',
                      style: pw.TextStyle(font: fontBold, color: primaryColor, fontSize: 20)),
                  pw.Text('Tax Invoice (GST)',
                      style: pw.TextStyle(font: font, fontSize: 12, color: PdfColors.grey600)),
                ]),
              ]),
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: pw.BoxDecoration(
                  color: primaryColor,
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                ),
                child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
                  pw.Text('TAX INVOICE',
                      style: pw.TextStyle(font: fontBold, fontSize: 12,
                          color: PdfColors.white, letterSpacing: 1.5)),
                  pw.SizedBox(height: 2),
                  pw.Text('# ${delivery.id}',
                      style: pw.TextStyle(font: font, fontSize: 9, color: const PdfColor(1, 1, 1, 0.7))),
                  pw.Text(DateFormat('dd MMM yyyy').format(delivery.timestamp),
                      style: pw.TextStyle(font: font, fontSize: 9, color: const PdfColor(1, 1, 1, 0.7))),
                ]),
              ),
            ],
          ),
          pw.SizedBox(height: 16),
          pw.Divider(color: borderColor, thickness: 1),
          pw.SizedBox(height: 12),

          // Supplier + Buyer row
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Supplier (left)
              pw.Expanded(
                child: pw.Container(
                  padding: const pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(
                    color: accentBg,
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                  ),
                  child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                    pw.Text('SUPPLIER',
                        style: pw.TextStyle(font: fontBold, fontSize: 8,
                            color: primaryColor, letterSpacing: 1.5)),
                    pw.SizedBox(height: 4),
                    pw.Text('BSM Agro Industry',
                        style: pw.TextStyle(font: fontBold, fontSize: 12)),
                    pw.Text('GSTIN: BSM-AGRO-00000',
                        style: pw.TextStyle(font: font, fontSize: 10, color: PdfColors.grey700)),
                  ]),
                ),
              ),
              pw.SizedBox(width: 16),
              // Buyer (right)
              pw.Expanded(
                child: pw.Container(
                  padding: const pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: borderColor),
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                  ),
                  child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                    pw.Text('BUYER',
                        style: pw.TextStyle(font: fontBold, fontSize: 8,
                            color: primaryColor, letterSpacing: 1.5)),
                    pw.SizedBox(height: 4),
                    pw.Text(delivery.customerName,
                        style: pw.TextStyle(font: fontBold, fontSize: 12)),
                    if (delivery.customerPhone?.isNotEmpty == true)
                      pw.Text('Phone: ${delivery.customerPhone}',
                          style: pw.TextStyle(font: font, fontSize: 10, color: PdfColors.grey700)),
                    if (delivery.invoice?.gstNumber?.isNotEmpty == true)
                      pw.Text('GSTIN: ${delivery.invoice!.gstNumber}',
                          style: pw.TextStyle(font: font, fontSize: 10, color: PdfColors.grey700)),
                    if (delivery.invoice?.address?.isNotEmpty == true)
                      pw.Text(delivery.invoice!.address!,
                          style: pw.TextStyle(font: font, fontSize: 10, color: PdfColors.grey700)),
                  ]),
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 20),

          // Items table
          pw.Table(
            border: pw.TableBorder.all(color: borderColor, width: 0.5),
            columnWidths: const {
              0: pw.FlexColumnWidth(3),
              1: pw.FlexColumnWidth(1.5),
              2: pw.FlexColumnWidth(1.5),
              3: pw.FlexColumnWidth(1.5),
              4: pw.FlexColumnWidth(1.5),
            },
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: primaryColor),
                children: [
                  _hCell('Description', fontBold),
                  _hCell('Qty', fontBold, align: pw.TextAlign.center),
                  _hCell('Rate', fontBold, align: pw.TextAlign.right),
                  _hCell('GST %', fontBold, align: pw.TextAlign.center),
                  _hCell('Amount', fontBold, align: pw.TextAlign.right),
                ],
              ),
              ...items.map((item) => pw.TableRow(children: [
                _bCell(item.product, font),
                _bCell('${item.qty} ${item.unit}', font, align: pw.TextAlign.center),
                _bCell('₹ ${item.price.toStringAsFixed(2)}', font, align: pw.TextAlign.right),
                _bCell('${_gstRate.toInt()}%', font, align: pw.TextAlign.center),
                _bCell('₹ ${item.total.toStringAsFixed(2)}', font, align: pw.TextAlign.right),
              ])),
            ],
          ),
          pw.SizedBox(height: 16),

          // GST breakdown
          pw.Row(mainAxisAlignment: pw.MainAxisAlignment.end, children: [
            pw.Container(
              width: 260,
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: borderColor, width: 0.5),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
              ),
              child: pw.Column(children: [
                _sumRow('Taxable Amount', '₹ ${subTotal.toStringAsFixed(2)}', font, fontBold, accentBg),
                _sumRow('CGST (9%)', '₹ ${cgst.toStringAsFixed(2)}', font, fontBold, PdfColors.white),
                _sumRow('SGST (9%)', '₹ ${sgst.toStringAsFixed(2)}', font, fontBold, accentBg),
                _sumRow('Total (incl. GST)', '₹ ${totalWithGst.toStringAsFixed(2)}', font, fontBold, PdfColors.white),
                if (prevBal != 0)
                  _sumRow(
                    prevBal > 0 ? 'Old Balance' : 'Advance',
                    '₹ ${prevBal.abs().toStringAsFixed(2)}',
                    font, fontBold, accentBg,
                  ),
                pw.Container(
                  color: primaryColor,
                  padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                    pw.Text('NET PAYABLE',
                        style: pw.TextStyle(font: fontBold, fontSize: 11, color: PdfColors.white)),
                    pw.Text('₹ ${finalPayable.toStringAsFixed(2)}',
                        style: pw.TextStyle(font: fontBold, fontSize: 13, color: PdfColors.white)),
                  ]),
                ),
              ]),
            ),
          ]),

          pw.Spacer(),
          pw.Divider(color: borderColor),
          pw.SizedBox(height: 4),
          pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
            pw.Text('This is a computer generated invoice.',
                style: pw.TextStyle(font: fontItalic, fontSize: 9, color: PdfColors.grey600)),
            pw.Text(
              'Generated: ${DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now())}',
              style: pw.TextStyle(font: font, fontSize: 8, color: PdfColors.grey500),
            ),
          ]),
        ],
      ),
    ));

    return pdf.save();
  }

  pw.Widget _hCell(String t, pw.Font f, {pw.TextAlign align = pw.TextAlign.left}) =>
      pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: pw.Text(t, textAlign: align,
            style: pw.TextStyle(font: f, fontSize: 9, color: PdfColors.white)),
      );

  pw.Widget _bCell(String t, pw.Font f, {pw.TextAlign align = pw.TextAlign.left}) =>
      pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 7),
        child: pw.Text(t, textAlign: align, style: pw.TextStyle(font: f, fontSize: 10)),
      );

  pw.Widget _sumRow(
      String label, String value, pw.Font font, pw.Font fontBold, PdfColor bg) {
    return pw.Container(
      color: bg,
      padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
        pw.Text(label, style: pw.TextStyle(font: font, fontSize: 10, color: PdfColors.grey700)),
        pw.Text(value, style: pw.TextStyle(font: fontBold, fontSize: 10)),
      ]),
    );
  }
}
