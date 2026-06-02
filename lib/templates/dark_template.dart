import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/delivery.dart';
import 'base_invoice_template.dart';

/// Dark-mode invoice — dark background with light text and vibrant accents.
class DarkTemplate extends BaseInvoiceTemplate {
  const DarkTemplate();

  @override
  String get id => 'dark';

  @override
  String get name => 'Dark';

  static Future<({pw.Font regular, pw.Font bold, pw.Font italic})>? _fontsFuture;
  static Future<Uint8List>? _logoByteFuture;

  static Future<({pw.Font regular, pw.Font bold, pw.Font italic})> _loadFonts() {
    return _fontsFuture ??= () async {
      final regular = await PdfGoogleFonts.poppinsRegular();
      final bold    = await PdfGoogleFonts.poppinsBold();
      final italic  = await PdfGoogleFonts.poppinsItalic();
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
    const bgColor      = PdfColor.fromInt(0xFF1C1C2E);
    const cardColor    = PdfColor.fromInt(0xFF2D2D44);
    const accentColor  = PdfColor.fromInt(0xFFBB86FC); // violet accent
    const textColor    = PdfColors.white;
    const mutedColor   = PdfColor.fromInt(0xFFB0B0C8);

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
      margin: pw.EdgeInsets.zero,
      build: (ctx) => pw.Container(
        color: bgColor,
        width: double.infinity,
        height: double.infinity,
        padding: const pw.EdgeInsets.all(36),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // Header
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Row(children: [
                  pw.Image(pw.MemoryImage(logoBytes), width: 50, height: 50),
                  pw.SizedBox(width: 12),
                  pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                    pw.Text('BSM Agro Industry',
                        style: pw.TextStyle(font: fontBold, color: accentColor, fontSize: 18)),
                    pw.Text('Delivery Invoice',
                        style: pw.TextStyle(font: font, color: mutedColor, fontSize: 11)),
                  ]),
                ]),
                pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
                  pw.Text('INVOICE',
                      style: pw.TextStyle(font: fontBold, fontSize: 20,
                          color: accentColor, letterSpacing: 3)),
                  pw.Text('# ${delivery.id}',
                      style: pw.TextStyle(font: font, fontSize: 9, color: mutedColor)),
                  pw.Text(DateFormat('dd MMM yyyy').format(delivery.timestamp),
                      style: pw.TextStyle(font: font, fontSize: 9, color: mutedColor)),
                ]),
              ],
            ),
            pw.SizedBox(height: 20),
            pw.Divider(color: accentColor, thickness: 0.5),
            pw.SizedBox(height: 16),

            // Customer card
            pw.Container(
              padding: const pw.EdgeInsets.all(14),
              decoration: const pw.BoxDecoration(
                color: cardColor,
                borderRadius: pw.BorderRadius.all(pw.Radius.circular(8)),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                    pw.Text('BILL TO',
                        style: pw.TextStyle(font: fontBold, fontSize: 8, color: accentColor, letterSpacing: 1.5)),
                    pw.SizedBox(height: 4),
                    pw.Text(delivery.customerName,
                        style: pw.TextStyle(font: fontBold, fontSize: 13, color: textColor)),
                    if (delivery.customerPhone?.isNotEmpty == true)
                      pw.Text(delivery.customerPhone!,
                          style: pw.TextStyle(font: font, fontSize: 10, color: mutedColor)),
                    if (delivery.invoice?.companyName?.isNotEmpty == true)
                      pw.Text(delivery.invoice!.companyName!,
                          style: pw.TextStyle(font: font, fontSize: 10, color: mutedColor)),
                    if (delivery.invoice?.address?.isNotEmpty == true)
                      pw.Text(delivery.invoice!.address!,
                          style: pw.TextStyle(font: font, fontSize: 10, color: mutedColor)),
                    if (delivery.vehicleNumber?.isNotEmpty == true)
                      pw.Text('Vehicle Number: ${delivery.vehicleNumber}',
                          style: pw.TextStyle(font: font, fontSize: 10, color: mutedColor)),
                    ...delivery.invoice?.customFields.map((f) =>
                        pw.Text('${f['label']}: ${f['value']}',
                            style: pw.TextStyle(font: font, fontSize: 10, color: mutedColor))) ?? [],
                  ]),
                  pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
                    _metaRow('Crew:', delivery.crewLeader, font, fontBold, mutedColor, textColor),
                    _metaRow('Priority:', delivery.priority, font, fontBold, mutedColor, accentColor),
                  ]),
                ],
              ),
            ),
            pw.SizedBox(height: 20),

            // Table
            pw.Container(
              decoration: const pw.BoxDecoration(
                color: cardColor,
                borderRadius: pw.BorderRadius.all(pw.Radius.circular(8)),
              ),
              child: pw.Table(
                columnWidths: const {
                  0: pw.FlexColumnWidth(3),
                  1: pw.FlexColumnWidth(2),
                  2: pw.FlexColumnWidth(2),
                  3: pw.FlexColumnWidth(2),
                },
                children: [
                  pw.TableRow(
                    decoration: pw.BoxDecoration(
                      color: accentColor,
                      borderRadius: const pw.BorderRadius.vertical(top: pw.Radius.circular(8)),
                    ),
                    children: [
                      _hCell('PRODUCT', fontBold, color: bgColor),
                      _hCell('QTY', fontBold, color: bgColor, align: pw.TextAlign.center),
                      _hCell('RATE', fontBold, color: bgColor, align: pw.TextAlign.right),
                      _hCell('AMOUNT', fontBold, color: bgColor, align: pw.TextAlign.right),
                    ],
                  ),
                  ...items.asMap().entries.map((e) {
                    final rowBg = e.key.isOdd
                        ? const PdfColor.fromInt(0xFF25253C)
                        : cardColor;
                    return pw.TableRow(
                      decoration: pw.BoxDecoration(color: rowBg),
                      children: [
                        _bCell(e.value.product, font, textColor),
                        _bCell('${e.value.qty} ${e.value.unit}', font, mutedColor, align: pw.TextAlign.center),
                        _bCell('₹ ${e.value.price.toStringAsFixed(2)}', font, textColor, align: pw.TextAlign.right),
                        _bCell('₹ ${e.value.total.toStringAsFixed(2)}', font, accentColor, align: pw.TextAlign.right),
                      ],
                    );
                  }),
                ],
              ),
            ),
            pw.SizedBox(height: 20),

            // Totals
            pw.Row(mainAxisAlignment: pw.MainAxisAlignment.end, children: [
              pw.Container(
                width: 240,
                padding: const pw.EdgeInsets.all(14),
                decoration: const pw.BoxDecoration(
                  color: cardColor,
                  borderRadius: pw.BorderRadius.all(pw.Radius.circular(8)),
                ),
                child: pw.Column(children: [
                  _tRow('Subtotal', '₹ ${total.toStringAsFixed(2)}', font, fontBold, mutedColor, textColor),
                  if (delivery.previousBalance != 0)
                    _tRow(
                      delivery.previousBalance > 0 ? 'Old Balance' : 'Advance',
                      '₹ ${delivery.previousBalance.abs().toStringAsFixed(2)}',
                      font, fontBold, mutedColor, textColor,
                    ),
                  pw.SizedBox(height: 6),
                  pw.Divider(color: accentColor, thickness: 0.5),
                  pw.SizedBox(height: 6),
                  pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                    pw.Text('TOTAL DUE',
                        style: pw.TextStyle(font: fontBold, fontSize: 12, color: accentColor)),
                    pw.Text('₹ ${finalPayable.toStringAsFixed(2)}',
                        style: pw.TextStyle(font: fontBold, fontSize: 14, color: accentColor)),
                  ]),
                ]),
              ),
            ]),

            pw.Spacer(),
            pw.Divider(color: accentColor, thickness: 0.3),
            pw.SizedBox(height: 4),
            pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
              pw.Text('* Not recommended for printing (dark theme)',
                  style: pw.TextStyle(font: fontItalic, fontSize: 8, color: mutedColor)),
              pw.Text(
                'Generated: ${DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now())}',
                style: pw.TextStyle(font: font, fontSize: 7, color: mutedColor),
              ),
            ]),
          ],
        ),
      ),
    ));

    return pdf.save();
  }

  pw.Widget _hCell(String t, pw.Font f,
      {pw.TextAlign align = pw.TextAlign.left, required PdfColor color}) =>
      pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        child: pw.Text(t, textAlign: align,
            style: pw.TextStyle(font: f, fontSize: 9, color: color, letterSpacing: 0.8)),
      );

  pw.Widget _bCell(String t, pw.Font f, PdfColor color,
      {pw.TextAlign align = pw.TextAlign.left}) =>
      pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: pw.Text(t, textAlign: align, style: pw.TextStyle(font: f, fontSize: 10, color: color)),
      );

  pw.Widget _metaRow(
      String label, String value, pw.Font font, pw.Font fontBold, PdfColor labelColor, PdfColor valueColor) =>
      pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 2),
        child: pw.Row(children: [
          pw.Text('$label ', style: pw.TextStyle(font: font, fontSize: 10, color: labelColor)),
          pw.Text(value, style: pw.TextStyle(font: fontBold, fontSize: 10, color: valueColor)),
        ]),
      );

  pw.Widget _tRow(
      String label, String value, pw.Font font, pw.Font fontBold, PdfColor labelColor, PdfColor valueColor) =>
      pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 3),
        child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
          pw.Text(label, style: pw.TextStyle(font: font, fontSize: 11, color: labelColor)),
          pw.Text(value, style: pw.TextStyle(font: fontBold, fontSize: 11, color: valueColor)),
        ]),
      );
}
