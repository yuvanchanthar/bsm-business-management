import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/delivery.dart';
import 'base_invoice_template.dart';

/// Corporate invoice — minimalist right-aligned header, thin border table,
/// burnt-orange accent color.
class CorporateTemplate extends BaseInvoiceTemplate {
  const CorporateTemplate();

  @override
  String get id => 'corporate';

  @override
  String get name => 'Corporate';

  static Future<({pw.Font regular, pw.Font bold, pw.Font italic})>? _fontsFuture;
  static Future<Uint8List>? _logoByteFuture;

  static Future<({pw.Font regular, pw.Font bold, pw.Font italic})> _loadFonts() {
    return _fontsFuture ??= () async {
      final regular = await PdfGoogleFonts.openSansRegular();
      final bold    = await PdfGoogleFonts.openSansBold();
      final italic  = await PdfGoogleFonts.openSansItalic();
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
    const primaryColor = PdfColor.fromInt(0xFFBF360C); // burnt-orange
    const accentBg     = PdfColor.fromInt(0xFFFBE9E7);
    const lineColor    = PdfColor.fromInt(0xFFBDBDBD);

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
      margin: const pw.EdgeInsets.all(36),
      build: (ctx) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          // Header — logo left, invoice details right
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                pw.Image(pw.MemoryImage(logoBytes), width: 60, height: 60),
                pw.SizedBox(height: 6),
                pw.Text('BSM Agro Industry',
                    style: pw.TextStyle(font: fontBold, fontSize: 16, color: primaryColor)),
                pw.Text('Corporate Invoice',
                    style: pw.TextStyle(font: font, fontSize: 10, color: PdfColors.grey600)),
              ]),
              pw.Spacer(),
              pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
                pw.Text('INVOICE',
                    style: pw.TextStyle(font: fontBold, fontSize: 28,
                        color: primaryColor, letterSpacing: 2)),
                pw.SizedBox(height: 4),
                pw.Text('# ${delivery.id}',
                    style: pw.TextStyle(font: fontBold, fontSize: 11, color: PdfColors.grey700)),
                pw.Text('Date: ${DateFormat('dd MMM yyyy').format(delivery.timestamp)}',
                    style: pw.TextStyle(font: font, fontSize: 11, color: PdfColors.grey600)),
              ]),
            ],
          ),
          pw.SizedBox(height: 6),
          pw.Container(height: 3, color: primaryColor),
          pw.Container(height: 1, color: lineColor),
          pw.SizedBox(height: 18),

          // Bill to / From
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                  pw.Text('FROM',
                      style: pw.TextStyle(font: fontBold, fontSize: 8,
                          color: primaryColor, letterSpacing: 1.5)),
                  pw.SizedBox(height: 4),
                  pw.Text('BSM Agro Industry',
                      style: pw.TextStyle(font: fontBold, fontSize: 12)),
                  pw.Text('India',
                      style: pw.TextStyle(font: font, fontSize: 11, color: PdfColors.grey700)),
                ]),
              ),
              pw.Expanded(
                child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                  pw.Text('BILL TO',
                      style: pw.TextStyle(font: fontBold, fontSize: 8,
                          color: primaryColor, letterSpacing: 1.5)),
                  pw.SizedBox(height: 4),
                  pw.Text(delivery.customerName,
                      style: pw.TextStyle(font: fontBold, fontSize: 12)),
                  if (delivery.customerPhone?.isNotEmpty == true)
                    pw.Text('Tel: ${delivery.customerPhone}',
                        style: pw.TextStyle(font: font, fontSize: 11, color: PdfColors.grey700)),
                  if (delivery.invoice?.companyName?.isNotEmpty == true)
                    pw.Text(delivery.invoice!.companyName!,
                        style: pw.TextStyle(font: font, fontSize: 11, color: PdfColors.grey700)),
                  if (delivery.invoice?.address?.isNotEmpty == true)
                    pw.Text(delivery.invoice!.address!,
                        style: pw.TextStyle(font: font, fontSize: 11, color: PdfColors.grey700)),
                  if (delivery.invoice?.gstNumber?.isNotEmpty == true)
                    pw.Text('GSTIN: ${delivery.invoice!.gstNumber}',
                        style: pw.TextStyle(font: font, fontSize: 11, color: PdfColors.grey700)),
                  if (delivery.vehicleNumber?.isNotEmpty == true)
                    pw.Text('Vehicle Number: ${delivery.vehicleNumber}',
                        style: pw.TextStyle(font: font, fontSize: 11, color: PdfColors.grey700)),
                  ...delivery.invoice?.customFields.map((f) =>
                      pw.Text('${f['label']}: ${f['value']}',
                          style: pw.TextStyle(font: font, fontSize: 11, color: PdfColors.grey700))) ?? [],
                ]),
              ),
            ],
          ),
          pw.SizedBox(height: 24),

          // Table — thin borders
          pw.Table(
            border: pw.TableBorder(
              top: pw.BorderSide(color: primaryColor, width: 1.5),
              bottom: pw.BorderSide(color: primaryColor, width: 1.5),
              horizontalInside: pw.BorderSide(color: lineColor, width: 0.5),
            ),
            columnWidths: const {
              0: pw.FlexColumnWidth(3),
              1: pw.FlexColumnWidth(2),
              2: pw.FlexColumnWidth(2),
              3: pw.FlexColumnWidth(2),
            },
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: accentBg),
                children: [
                  _hCell('Description', fontBold, primaryColor),
                  _hCell('Quantity', fontBold, primaryColor, align: pw.TextAlign.center),
                  _hCell('Unit Price', fontBold, primaryColor, align: pw.TextAlign.right),
                  _hCell('Line Total', fontBold, primaryColor, align: pw.TextAlign.right),
                ],
              ),
              ...items.map((item) => pw.TableRow(children: [
                _bCell(item.product, font),
                _bCell('${item.qty} ${item.unit}', font, align: pw.TextAlign.center),
                _bCell('₹ ${item.price.toStringAsFixed(2)}', font, align: pw.TextAlign.right),
                _bCell('₹ ${item.total.toStringAsFixed(2)}', font, align: pw.TextAlign.right),
              ])),
            ],
          ),
          pw.SizedBox(height: 18),

          // Totals — right aligned, no box
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
                pw.SizedBox(height: 4),
                pw.Container(height: 1.5, color: primaryColor),
                pw.SizedBox(height: 6),
                pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                  pw.Text('TOTAL DUE',
                      style: pw.TextStyle(font: fontBold, fontSize: 13, color: primaryColor)),
                  pw.Text('₹ ${finalPayable.toStringAsFixed(2)}',
                      style: pw.TextStyle(font: fontBold, fontSize: 15, color: primaryColor)),
                ]),
              ]),
            ),
          ]),

          pw.Spacer(),
          pw.Container(height: 1, color: lineColor),
          pw.SizedBox(height: 8),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                pw.Text('Thank you for your continued business.',
                    style: pw.TextStyle(font: fontItalic, fontSize: 10, color: PdfColors.grey700)),
                pw.SizedBox(height: 2),
                pw.Text(
                  'Generated: ${DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now())}',
                  style: pw.TextStyle(font: font, fontSize: 8, color: PdfColors.grey500),
                ),
              ]),
              pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.center, children: [
                pw.SizedBox(height: 24),
                pw.Container(width: 110, height: 1, color: lineColor),
                pw.SizedBox(height: 4),
                pw.Text('Authorized Signatory',
                    style: pw.TextStyle(font: font, fontSize: 8, color: PdfColors.grey500)),
              ]),
            ],
          ),
        ],
      ),
    ));

    return pdf.save();
  }

  pw.Widget _hCell(String t, pw.Font f, PdfColor color,
      {pw.TextAlign align = pw.TextAlign.left}) =>
      pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        child: pw.Text(t, textAlign: align,
            style: pw.TextStyle(font: f, fontSize: 9, color: color, letterSpacing: 0.8)),
      );

  pw.Widget _bCell(String t, pw.Font f, {pw.TextAlign align = pw.TextAlign.left}) =>
      pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: pw.Text(t, textAlign: align, style: pw.TextStyle(font: f, fontSize: 10)),
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
