import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/delivery.dart';
import 'base_invoice_template.dart';

/// Classic green-themed invoice — the original BSM Agro receipt style.
class ClassicTemplate extends BaseInvoiceTemplate {
  const ClassicTemplate();

  @override
  String get id => 'classic';

  @override
  String get name => 'Classic';

  // ── Cached resources ──────────────────────────────────────────────────────
  static Future<({pw.Font regular, pw.Font bold, pw.Font italic})>? _fontsFuture;
  static Future<Uint8List>? _logoByteFuture;

  static Future<({pw.Font regular, pw.Font bold, pw.Font italic})> _loadFonts() {
    return _fontsFuture ??= () async {
      final regular = await PdfGoogleFonts.robotoRegular();
      final bold    = await PdfGoogleFonts.robotoBold();
      final italic  = await PdfGoogleFonts.robotoItalic();
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
    const primaryColor = PdfColor.fromInt(0xFF277533);
    const accentColor  = PdfColor.fromInt(0xFFF1F8E9);

    final fonts     = await _loadFonts();
    final logoBytes = await _loadLogo();
    final font      = fonts.regular;
    final fontBold  = fonts.bold;
    final fontItalic= fonts.italic;

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
          // ── Header ──────────────────────────────────────────────────────
          pw.Center(
            child: pw.Column(children: [
              pw.Image(pw.MemoryImage(logoBytes), width: 72, height: 72),
              pw.SizedBox(height: 10),
              pw.Text('BSM Agro Industry',
                  style: pw.TextStyle(font: fontBold, color: primaryColor, fontSize: 22)),
              pw.SizedBox(height: 4),
              pw.Text('DELIVERY RECEIPT',
                  style: pw.TextStyle(font: fontBold, fontSize: 13,
                      color: PdfColors.grey700, letterSpacing: 2)),
            ]),
          ),
          pw.SizedBox(height: 32),
          pw.Divider(color: PdfColors.grey400),
          pw.SizedBox(height: 14),

          // ── Customer + Receipt Meta ──────────────────────────────────────
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                pw.Text('BILL TO', style: pw.TextStyle(font: fontBold, fontSize: 9, color: PdfColors.grey600)),
                pw.SizedBox(height: 4),
                pw.Text(delivery.customerName,
                    style: pw.TextStyle(font: fontBold, fontSize: 14)),
                if (delivery.customerPhone?.isNotEmpty == true)
                  pw.Text('Phone: ${delivery.customerPhone}',
                      style: pw.TextStyle(font: font, fontSize: 11)),
                if (delivery.invoice?.companyName?.isNotEmpty == true)
                  pw.Text('Company: ${delivery.invoice!.companyName}',
                      style: pw.TextStyle(font: font, fontSize: 11)),
                if (delivery.invoice?.address?.isNotEmpty == true)
                  pw.Text('Address: ${delivery.invoice!.address}',
                      style: pw.TextStyle(font: font, fontSize: 11)),
                if (delivery.invoice?.gstNumber?.isNotEmpty == true)
                  pw.Text('GST: ${delivery.invoice!.gstNumber}',
                      style: pw.TextStyle(font: font, fontSize: 11)),
                if (delivery.vehicleNumber?.isNotEmpty == true)
                  pw.Text('Vehicle Number: ${delivery.vehicleNumber}',
                      style: pw.TextStyle(font: font, fontSize: 11)),
                ...delivery.invoice?.customFields.map((f) =>
                    pw.Text('${f['label']}: ${f['value']}',
                        style: pw.TextStyle(font: font, fontSize: 11))) ?? [],
              ]),
              pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
                pw.Text('RECEIPT DETAILS',
                    style: pw.TextStyle(font: fontBold, fontSize: 9, color: PdfColors.grey600)),
                pw.SizedBox(height: 4),
                pw.Text('ID: ${delivery.id}',
                    style: pw.TextStyle(font: fontBold, fontSize: 11, color: primaryColor)),
                pw.Text('Date: ${delivery.formattedDate}',
                    style: pw.TextStyle(font: font, fontSize: 11)),
              ]),
            ],
          ),
          pw.SizedBox(height: 28),

          // ── Items Table ──────────────────────────────────────────────────
          pw.Container(
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: primaryColor, width: 2),
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
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
                  decoration: const pw.BoxDecoration(
                    color: accentColor,
                    borderRadius: pw.BorderRadius.vertical(top: pw.Radius.circular(6)),
                  ),
                  children: [
                    _cell('Product', font, fontBold, isHeader: true),
                    _cell('Qty', font, fontBold, isHeader: true, align: pw.TextAlign.center),
                    _cell('Price/Unit', font, fontBold, isHeader: true, align: pw.TextAlign.right),
                    _cell('Amount', font, fontBold, isHeader: true, align: pw.TextAlign.right),
                  ],
                ),
                ...items.map((item) => pw.TableRow(
                  decoration: const pw.BoxDecoration(
                      border: pw.Border(top: pw.BorderSide(color: PdfColors.grey300))),
                  children: [
                    _cell(item.product, font, fontBold),
                    _cell('${item.qty} ${item.unit}', font, fontBold, align: pw.TextAlign.center),
                    _cell('₹ ${item.price.toStringAsFixed(2)}', font, fontBold, align: pw.TextAlign.right),
                    _cell('₹ ${item.total.toStringAsFixed(2)}', font, fontBold, align: pw.TextAlign.right),
                  ],
                )),
              ],
            ),
          ),
          pw.SizedBox(height: 20),

          // ── Summary ──────────────────────────────────────────────────────
          pw.Row(mainAxisAlignment: pw.MainAxisAlignment.end, children: [
            pw.Container(width: 240, child: pw.Column(children: [
              _summaryRow('Delivery Total:', '₹ ${total.toStringAsFixed(2)}', font, fontBold),
              if (delivery.previousBalance != 0)
                _summaryRow(
                  delivery.previousBalance > 0 ? 'Old Balance:' : 'Advance:',
                  '₹ ${delivery.previousBalance.abs().toStringAsFixed(2)}',
                  font, fontBold,
                ),
              pw.Divider(color: PdfColors.grey400),
              pw.SizedBox(height: 4),
              pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                pw.Text('FINAL PAYABLE',
                    style: pw.TextStyle(font: fontBold, fontSize: 13, color: primaryColor)),
                pw.Text('₹ ${finalPayable.toStringAsFixed(2)}',
                    style: pw.TextStyle(font: fontBold, fontSize: 15, color: primaryColor)),
              ]),
            ])),
          ]),

          pw.Spacer(),

          // ── Footer ──────────────────────────────────────────────────────
          pw.Divider(color: PdfColors.grey400),
          pw.SizedBox(height: 6),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                pw.Text('Thank you for your business!',
                    style: pw.TextStyle(font: fontItalic, fontSize: 11)),
                pw.SizedBox(height: 4),
                pw.Text(
                  'Generated: ${DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now())}',
                  style: pw.TextStyle(font: font, fontSize: 8, color: PdfColors.grey600),
                ),
              ]),
              pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.center, children: [
                pw.SizedBox(height: 20),
                pw.Container(width: 100, height: 1, color: PdfColors.grey400),
                pw.SizedBox(height: 4),
                pw.Text('Authorized Signature',
                    style: pw.TextStyle(font: font, fontSize: 8, color: PdfColors.grey600)),
              ]),
            ],
          ),
        ],
      ),
    ));

    return pdf.save();
  }

  pw.Widget _cell(String text, pw.Font font, pw.Font fontBold,
      {bool isHeader = false, pw.TextAlign align = pw.TextAlign.left}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: pw.Text(text,
          textAlign: align,
          style: pw.TextStyle(
            font: isHeader ? fontBold : font,
            fontSize: 10,
            color: isHeader ? const PdfColor.fromInt(0xFF277533) : PdfColors.black,
          )),
    );
  }

  pw.Widget _summaryRow(String label, String value, pw.Font font, pw.Font fontBold) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 4),
      child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
        pw.Text(label, style: pw.TextStyle(font: font, fontSize: 12)),
        pw.Text(value, style: pw.TextStyle(font: fontBold, fontSize: 12)),
      ]),
    );
  }
}
