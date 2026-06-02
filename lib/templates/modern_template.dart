import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/delivery.dart';
import 'base_invoice_template.dart';

/// Modern deep-blue invoice with bold header bar and alternating row colors.
class ModernTemplate extends BaseInvoiceTemplate {
  const ModernTemplate();

  @override
  String get id => 'modern';

  @override
  String get name => 'Modern';

  static Future<({pw.Font regular, pw.Font bold, pw.Font italic})>? _fontsFuture;
  static Future<Uint8List>? _logoByteFuture;

  static Future<({pw.Font regular, pw.Font bold, pw.Font italic})> _loadFonts() {
    return _fontsFuture ??= () async {
      final regular = await PdfGoogleFonts.nunitoRegular();
      final bold    = await PdfGoogleFonts.nunitoBold();
      final italic  = await PdfGoogleFonts.nunitoItalic();
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
    const primaryColor = PdfColor.fromInt(0xFF1565C0);
    const accentBg     = PdfColor.fromInt(0xFFE3F2FD);

    final fonts      = await _loadFonts();
    final logoBytes  = await _loadLogo();
    final font       = fonts.regular;
    final fontBold   = fonts.bold;
    final fontItalic = fonts.italic;

    final items = delivery.products.isNotEmpty ? delivery.products : delivery.items;
    final total = delivery.deliveryTotal > 0
        ? delivery.deliveryTotal
        : items.fold(0.0, (s, i) => s + i.totalAmount);
    final finalPayable = delivery.updatedBalance != 0 ? delivery.updatedBalance : total;

    final pdf = pw.Document(
      theme: pw.ThemeData.withFont(base: font, bold: fontBold, italic: fontItalic),
    );

    pdf.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(32),
      build: (ctx) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          // Header bar
          pw.Container(
            color: primaryColor,
            width: double.infinity,
            padding: const pw.EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Row(children: [
                  pw.Image(pw.MemoryImage(logoBytes), width: 48, height: 48),
                  pw.SizedBox(width: 12),
                  pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                    pw.Text('BSM Agro Industry',
                        style: pw.TextStyle(font: fontBold, color: PdfColors.white, fontSize: 18)),
                    pw.Text('Delivery Invoice',
                        style: pw.TextStyle(font: font, color: const PdfColor(1, 1, 1, 0.7), fontSize: 11)),
                  ]),
                ]),
                pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
                  pw.Text('INVOICE',
                      style: pw.TextStyle(font: fontBold, fontSize: 22, color: PdfColors.white, letterSpacing: 3)),
                  pw.Text('# ${delivery.id}',
                      style: pw.TextStyle(font: font, fontSize: 9, color: const PdfColor(1, 1, 1, 0.7))),
                  pw.Text(DateFormat('dd MMM yyyy').format(delivery.timestamp),
                      style: pw.TextStyle(font: font, fontSize: 9, color: const PdfColor(1, 1, 1, 0.7))),
                ]),
              ],
            ),
          ),
          pw.SizedBox(height: 20),

          // Bill To
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                pw.Text('BILL TO',
                    style: pw.TextStyle(font: fontBold, fontSize: 9, color: primaryColor, letterSpacing: 1.5)),
                pw.SizedBox(height: 4),
                pw.Text(delivery.customerName,
                    style: pw.TextStyle(font: fontBold, fontSize: 14)),
                if (delivery.customerPhone?.isNotEmpty == true)
                  pw.Text(delivery.customerPhone!,
                      style: pw.TextStyle(font: font, fontSize: 11, color: PdfColors.grey700)),
                if (delivery.invoice?.companyName?.isNotEmpty == true)
                  pw.Text(delivery.invoice!.companyName!,
                      style: pw.TextStyle(font: font, fontSize: 11, color: PdfColors.grey700)),
                if (delivery.invoice?.address?.isNotEmpty == true)
                  pw.Text(delivery.invoice!.address!,
                      style: pw.TextStyle(font: font, fontSize: 11, color: PdfColors.grey700)),
                if (delivery.invoice?.gstNumber?.isNotEmpty == true)
                  pw.Text('GST: ${delivery.invoice!.gstNumber}',
                      style: pw.TextStyle(font: font, fontSize: 11, color: PdfColors.grey700)),
                if (delivery.vehicleNumber?.isNotEmpty == true)
                  pw.Text('Vehicle Number: ${delivery.vehicleNumber}',
                      style: pw.TextStyle(font: font, fontSize: 11, color: PdfColors.grey700)),
                ...delivery.invoice?.customFields.map((f) =>
                    pw.Text('${f['label']}: ${f['value']}',
                        style: pw.TextStyle(font: font, fontSize: 11, color: PdfColors.grey700))) ?? [],
              ]),
              pw.Container(
                padding: const pw.EdgeInsets.all(14),
                decoration: const pw.BoxDecoration(
                  color: accentBg,
                  borderRadius: pw.BorderRadius.all(pw.Radius.circular(8)),
                ),
                child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
                  _metaRow('Priority:', delivery.priority, font, fontBold),
                  _metaRow('Status:', delivery.status.toUpperCase(), font, fontBold),
                ]),
              ),
            ],
          ),
          pw.SizedBox(height: 24),

          // Table
          pw.Table(
            columnWidths: const {
              0: pw.FlexColumnWidth(3),
              1: pw.FlexColumnWidth(2),
              2: pw.FlexColumnWidth(2),
              3: pw.FlexColumnWidth(2),
            },
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: primaryColor),
                children: [
                  _hCell('ITEM', fontBold),
                  _hCell('QTY', fontBold, align: pw.TextAlign.center),
                  _hCell('RATE', fontBold, align: pw.TextAlign.right),
                  _hCell('TOTAL', fontBold, align: pw.TextAlign.right),
                ],
              ),
              ...items.asMap().entries.map((e) => pw.TableRow(
                decoration: pw.BoxDecoration(color: e.key.isOdd ? accentBg : PdfColors.white),
                children: [
                  _bCell(e.value.product, font),
                  _bCell('${e.value.qty} ${e.value.unit}', font, align: pw.TextAlign.center),
                  _bCell('₹ ${e.value.price.toStringAsFixed(2)}', font, align: pw.TextAlign.right),
                  _bCell('₹ ${e.value.total.toStringAsFixed(2)}', font, align: pw.TextAlign.right),
                ],
              )),
            ],
          ),
          pw.SizedBox(height: 20),

          // Totals
          pw.Row(mainAxisAlignment: pw.MainAxisAlignment.end, children: [
            pw.Container(
              width: 240,
              child: pw.Column(children: [
                _tRow('Subtotal', '₹ ${total.toStringAsFixed(2)}', font, fontBold),
                if (delivery.previousBalance != 0)
                  _tRow(
                    delivery.previousBalance > 0 ? 'Old Balance' : 'Advance',
                    '₹ ${delivery.previousBalance.abs().toStringAsFixed(2)}',
                    font, fontBold,
                  ),
                pw.SizedBox(height: 6),
                pw.Container(
                  color: primaryColor,
                  padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                    pw.Text('AMOUNT DUE',
                        style: pw.TextStyle(font: fontBold, fontSize: 12, color: PdfColors.white)),
                    pw.Text('₹ ${finalPayable.toStringAsFixed(2)}',
                        style: pw.TextStyle(font: fontBold, fontSize: 14, color: PdfColors.white)),
                  ]),
                ),
              ]),
            ),
          ]),

          pw.Spacer(),
          pw.Divider(color: PdfColors.grey300),
          pw.SizedBox(height: 4),
          pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
            pw.Text('Thank you for your business!',
                style: pw.TextStyle(font: fontItalic, fontSize: 10, color: PdfColors.grey600)),
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
        padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        child: pw.Text(t, textAlign: align,
            style: pw.TextStyle(font: f, fontSize: 9, color: PdfColors.white, letterSpacing: 1)),
      );

  pw.Widget _bCell(String t, pw.Font f, {pw.TextAlign align = pw.TextAlign.left}) =>
      pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: pw.Text(t, textAlign: align, style: pw.TextStyle(font: f, fontSize: 10)),
      );

  pw.Widget _metaRow(String label, String value, pw.Font font, pw.Font fontBold) =>
      pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 2),
        child: pw.Row(children: [
          pw.Text('$label ', style: pw.TextStyle(font: font, fontSize: 10, color: PdfColors.grey600)),
          pw.Text(value, style: pw.TextStyle(font: fontBold, fontSize: 10)),
        ]),
      );

  pw.Widget _tRow(String label, String value, pw.Font font, pw.Font fontBold) =>
      pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 3),
        child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
          pw.Text(label, style: pw.TextStyle(font: font, fontSize: 11, color: PdfColors.grey700)),
          pw.Text(value, style: pw.TextStyle(font: fontBold, fontSize: 11)),
        ]),
      );
}
