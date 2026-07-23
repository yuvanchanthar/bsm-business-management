import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart' show rootBundle;
import '../core/stock_format.dart';
import '../models/invoice_model.dart';
import '../models/payment_model.dart';
import '../models/supplier_model.dart';
import '../models/customer_statement_model.dart';
import '../features/invoice/services/invoice_generator_service.dart';

class PdfService {
  // ── Cached resources (loaded once per app run) ────────────────────────────
  static Future<({pw.Font regular, pw.Font bold, pw.Font italic})>? _fontsFuture;

  static Future<({pw.Font regular, pw.Font bold, pw.Font italic})> _loadFonts() {
    return _fontsFuture ??= () async {
      final regular = await PdfGoogleFonts.robotoRegular();
      final bold = await PdfGoogleFonts.robotoBold();
      final italic = await PdfGoogleFonts.robotoItalic();
      return (regular: regular, bold: bold, italic: italic);
    }();
  }

  // ── Invoice PDF generator ────────────────────────────────────────────────
  Future<Uint8List> generateInvoice(InvoiceModel invoice) async {
    final delivery = invoice.toDelivery();
    return const InvoiceGeneratorService().generate(
      templateId: invoice.templateId,
      delivery: delivery,
    );
  }

  // ── Attendance Report generator ──────────────────────────────────────────
  Future<void> generateAttendanceReport({
    required String labourName,
    required String phone,
    required String period,
    required List<AttendanceRecord> records,
    required double dailyWage,
    required double openingBalance,
    required Map<String, dynamic> summary,
  }) async {
    final pdf = pw.Document();
    final fonts = await _loadFonts();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        theme: pw.ThemeData.withFont(
          base: fonts.regular,
          bold: fonts.bold,
          italic: fonts.italic,
        ),
        build: (context) => [
          _buildReportHeader(labourName, phone, period, dailyWage, openingBalance, fonts),
          pw.SizedBox(height: 20),
          _buildAttendanceTable(records, dailyWage, fonts),
          pw.SizedBox(height: 25),
          _buildReportSummary(summary, openingBalance, fonts),
        ],
      ),
    );

    await Printing.sharePdf(bytes: await pdf.save(), filename: 'attendance_report_${labourName.replaceAll(' ', '_')}.pdf');
  }

  pw.Widget _buildReportHeader(String name, String phone, String period, double dailyWage, double openingBalance, var fonts) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('Attendance Report', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold, color: PdfColor.fromInt(0xFF277533))),
            pw.Text(period, style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700)),
          ],
        ),
        pw.SizedBox(height: 12),
        pw.Container(height: 1, color: PdfColors.grey300),
        pw.SizedBox(height: 12),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('LABOUR DETAILS', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.grey600)),
                pw.SizedBox(height: 4),
                pw.Text(name, style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                if (phone.isNotEmpty) pw.Text(phone, style: pw.TextStyle(fontSize: 12, color: PdfColors.grey800)),
              ],
            ),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text('DAILY WAGE', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.grey600)),
                pw.Text('₹${dailyWage.toStringAsFixed(0)}/day', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 8),
                pw.Text('OPENING BALANCE', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.grey600)),
                pw.Text('₹${openingBalance.toStringAsFixed(0)}', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
              ],
            ),
          ],
        ),
      ],
    );
  }

  pw.Widget _buildAttendanceTable(List<AttendanceRecord> records, double dailyWage, var fonts) {
    return pw.TableHelper.fromTextArray(
      headers: ['Date', 'Status', 'Daily Wage', 'Earned'],
      data: records.map((rec) {
        final status = rec.status == 'present' ? 'full_day' : rec.status;
        String statusLabel = status == 'full_day' ? 'Full Day' : (status == 'half_day' ? 'Half Day' : 'Absent');
        double earned = status == 'full_day' ? dailyWage : (status == 'half_day' ? dailyWage * 0.5 : 0);
        return [
          rec.date,
          statusLabel,
          '₹${dailyWage.toStringAsFixed(0)}',
          '₹${earned.toStringAsFixed(0)}',
        ];
      }).toList(),
      border: null,
      headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 10),
      headerDecoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFF277533)),
      cellStyle: const pw.TextStyle(fontSize: 10),
      cellPadding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      oddRowDecoration: const pw.BoxDecoration(color: PdfColors.grey100),
      columnWidths: {
        0: const pw.FlexColumnWidth(2),
        1: const pw.FlexColumnWidth(2),
        2: const pw.FlexColumnWidth(1.5),
        3: const pw.FlexColumnWidth(1.5),
      },
    );
  }

  pw.Widget _buildReportSummary(Map<String, dynamic> summary, double openingBalance, var fonts) {
    final totalDue = summary['totalEarned'] + openingBalance;
    final pendingBalance = totalDue - summary['totalPaid'];

    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey50,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
        border: pw.Border.all(color: PdfColors.grey200),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('REPORT SUMMARY', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.grey600)),
          pw.SizedBox(height: 12),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              _buildSummaryItem('Full Days', '${summary['fullDays']}', fonts),
              _buildSummaryItem('Half Days', '${summary['halfDays']}', fonts),
              _buildSummaryItem('Absent', '${summary['absent']}', fonts),
              _buildSummaryItem('Worked Days', '${summary['workedDays']}', fonts, isBold: true),
            ],
          ),
          pw.SizedBox(height: 12),
          pw.Divider(color: PdfColors.grey300, thickness: 0.5),
          pw.SizedBox(height: 12),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  _buildSummaryItem('Current Period Earned', '₹${summary['totalEarned'].toStringAsFixed(0)}', fonts, isBold: true),
                  pw.SizedBox(height: 8),
                  _buildSummaryItem('Opening Balance', '₹${openingBalance.toStringAsFixed(0)}', fonts),
                ],
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  _buildSummaryItem('Total Due', '₹${totalDue.toStringAsFixed(0)}', fonts, isBold: true),
                  pw.SizedBox(height: 8),
                  _buildSummaryItem('Paid this month', '₹${summary['totalPaid'].toStringAsFixed(0)}', fonts),
                ],
              ),
              _buildSummaryItem('Pending Balance', '₹${pendingBalance.abs().toStringAsFixed(0)}', fonts, isBold: true, color: pendingBalance > 0 ? PdfColors.red : PdfColors.green),
            ],
          ),
        ],
      ),
    );
  }

  pw.Widget _buildSummaryItem(String label, String value, var fonts, {bool isBold = false, PdfColor? color}) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(label, style: pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
        pw.SizedBox(height: 4),
        pw.Text(value, style: pw.TextStyle(fontSize: 14, fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal, color: color)),
      ],
    );
  }

  // ── Supplier Ledger PDF generator ──────────────────────────────────────────
  Future<void> generateSupplierLedgerPdf({
    required String supplierName,
    required String phone,
    required double openingBalance,
    required List<SupplierPurchaseModel> purchases,
    required List<SupplierPaymentModel> payments,
    required double pendingBalance,
    required double advanceBalance,
  }) async {
    final pdf = pw.Document();
    final fonts = await _loadFonts();

    // Prepare sorted transactions
    final List<Map<String, dynamic>> txs = [];
    for (final p in purchases) {
      txs.add({
        'date': p.date,
        'type': 'Purchase',
        'desc': '${p.item} (${fmtStock(p.quantity)} ${p.unit})',
        'debit': p.totalAmount,
        'credit': 0.0,
      });
    }
    for (final pay in payments) {
      txs.add({
        'date': pay.date,
        'type': 'Payment',
        'desc': pay.note.isNotEmpty ? pay.note : 'Cash/Bank Payment',
        'debit': 0.0,
        'credit': pay.amount,
      });
    }
    txs.sort((a, b) => (a['date'] as DateTime).compareTo(b['date'] as DateTime));

    final df = DateFormat('dd MMM yyyy');

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        theme: pw.ThemeData.withFont(
          base: fonts.regular,
          bold: fonts.bold,
          italic: fonts.italic,
        ),
        build: (context) => [
          // Header
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('Supplier Ledger Statement', style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold, color: PdfColor.fromInt(0xFF6B1B9A))),
              pw.Text(DateFormat('dd/MM/yyyy').format(DateTime.now()), style: pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
            ],
          ),
          pw.SizedBox(height: 10),
          pw.Container(height: 1.5, color: PdfColor.fromInt(0xFF6B1B9A)),
          pw.SizedBox(height: 12),
          // Vendor & Balance Overview
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('SUPPLIER / VENDOR', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.grey600)),
                  pw.SizedBox(height: 3),
                  pw.Text(supplierName, style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
                  if (phone.isNotEmpty) pw.Text(phone, style: pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                ],
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text('OPENING BALANCE:  ₹${openingBalance.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.grey800)),
                  pw.SizedBox(height: 4),
                  if (advanceBalance > 0)
                    pw.Text('ADVANCE BALANCE:  ₹${advanceBalance.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.green))
                  else
                    pw.Text('PENDING BALANCE:  ₹${pendingBalance.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: pendingBalance > 0 ? PdfColors.red : PdfColors.green)),
                ],
              ),
            ],
          ),
          pw.SizedBox(height: 20),
          // Transaction Table
          pw.TableHelper.fromTextArray(
            headers: ['Date', 'Type', 'Description', 'Purchased (Dr)', 'Paid (Cr)'],
            data: txs.map((t) {
              final dateStr = df.format(t['date'] as DateTime);
              final debitVal = t['debit'] as double;
              final creditVal = t['credit'] as double;
              return [
                dateStr,
                t['type'],
                t['desc'],
                debitVal > 0 ? '₹${debitVal.toStringAsFixed(2)}' : '-',
                creditVal > 0 ? '₹${creditVal.toStringAsFixed(2)}' : '-',
              ];
            }).toList(),
            border: null,
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 9),
            headerDecoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFF6B1B9A)),
            cellStyle: const pw.TextStyle(fontSize: 9),
            cellPadding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            oddRowDecoration: const pw.BoxDecoration(color: PdfColors.grey100),
            columnWidths: {
              0: const pw.FlexColumnWidth(1.2),
              1: const pw.FlexColumnWidth(0.8),
              2: const pw.FlexColumnWidth(2.5),
              3: const pw.FlexColumnWidth(1.2),
              4: const pw.FlexColumnWidth(1.2),
            },
          ),
          pw.SizedBox(height: 20),
          // Footer / totals summary
          pw.Container(
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              color: PdfColors.grey100,
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Total Purchased: ₹${purchases.fold(0.0, (s, e) => s + e.totalAmount).toStringAsFixed(2)}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                pw.Text('Total Paid: ₹${payments.fold(0.0, (s, e) => s + e.amount).toStringAsFixed(2)}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
              ],
            ),
          ),
        ],
      ),
    );

    await Printing.sharePdf(
      bytes: await pdf.save(),
      filename: 'ledger_${supplierName.replaceAll(' ', '_')}.pdf',
    );
  }

  // ── Supplier Monthly Report PDF generator ──────────────────────────────────
  Future<void> generateSupplierMonthlyReportPdf({
    required String month,
    required List<dynamic> reportData,
  }) async {
    final pdf = pw.Document();
    final fonts = await _loadFonts();

    double grandTotalPurchased = 0.0;
    double grandTotalPaid = 0.0;
    double grandTotalPending = 0.0;

    for (final item in reportData) {
      grandTotalPurchased += double.tryParse(item['totalPurchased']?.toString() ?? '0') ?? 0.0;
      grandTotalPaid += double.tryParse(item['totalPaid']?.toString() ?? '0') ?? 0.0;
      grandTotalPending += double.tryParse(item['pendingBalance']?.toString() ?? '0') ?? 0.0;
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        theme: pw.ThemeData.withFont(
          base: fonts.regular,
          bold: fonts.bold,
          italic: fonts.italic,
        ),
        build: (context) => [
          // Header
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('Monthly Supplier Report', style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold, color: PdfColor.fromInt(0xFF0D47A1))),
              pw.Text(month, style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700)),
            ],
          ),
          pw.SizedBox(height: 10),
          pw.Container(height: 1.5, color: PdfColor.fromInt(0xFF0D47A1)),
          pw.SizedBox(height: 16),
          // Grand Totals Summary Row
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
            children: [
              pw.Column(
                children: [
                  pw.Text('TOTAL PURCHASED', style: pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
                  pw.SizedBox(height: 3),
                  pw.Text('₹${grandTotalPurchased.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.blueGrey900)),
                ],
              ),
              pw.Column(
                children: [
                  pw.Text('TOTAL PAID', style: pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
                  pw.SizedBox(height: 3),
                  pw.Text('₹${grandTotalPaid.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.green700)),
                ],
              ),
              pw.Column(
                children: [
                  pw.Text('TOTAL PENDING', style: pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
                  pw.SizedBox(height: 3),
                  pw.Text('₹${grandTotalPending.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.red700)),
                ],
              ),
            ],
          ),
          pw.SizedBox(height: 20),
          // Data Table
          pw.TableHelper.fromTextArray(
            headers: ['Supplier Name', 'Phone', 'Purchased', 'Paid', 'Pending Balance'],
            data: reportData.map((item) {
              final purchased = double.tryParse(item['totalPurchased']?.toString() ?? '0') ?? 0.0;
              final paid = double.tryParse(item['totalPaid']?.toString() ?? '0') ?? 0.0;
              final pending = double.tryParse(item['pendingBalance']?.toString() ?? '0') ?? 0.0;
              return [
                item['name']?.toString() ?? 'N/A',
                item['phone']?.toString() ?? '',
                '₹${purchased.toStringAsFixed(2)}',
                '₹${paid.toStringAsFixed(2)}',
                '₹${pending.toStringAsFixed(2)}',
              ];
            }).toList(),
            border: null,
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 9),
            headerDecoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFF0D47A1)),
            cellStyle: const pw.TextStyle(fontSize: 9),
            cellPadding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            oddRowDecoration: const pw.BoxDecoration(color: PdfColors.grey100),
            columnWidths: {
              0: const pw.FlexColumnWidth(2),
              1: const pw.FlexColumnWidth(1.2),
              2: const pw.FlexColumnWidth(1.2),
              3: const pw.FlexColumnWidth(1.2),
              4: const pw.FlexColumnWidth(1.2),
            },
          ),
        ],
      ),
    );

    await Printing.sharePdf(
      bytes: await pdf.save(),
      filename: 'supplier_monthly_report_${month.replaceAll(' ', '_')}.pdf',
    );
  }

  // ── Customer Statement PDF generator ─────────────────────────────────────────
  Future<Uint8List> generateCustomerStatementPdf(CustomerStatementModel statement) async {
    final pdf = pw.Document();
    final fonts = await _loadFonts();
    
    // Load Logo
    pw.MemoryImage? logoImage;
    try {
      final ByteData data = await rootBundle.load('assets/images/logo.png');
      logoImage = pw.MemoryImage(data.buffer.asUint8List());
    } catch (e) {
      print('Could not load logo image: $e');
    }

    final df = DateFormat('dd-MMM-yyyy');

    String periodStr = 'All Transactions';
    if (statement.period.startDate != null && statement.period.endDate != null) {
      periodStr = '${df.format(statement.period.startDate!)} to ${df.format(statement.period.endDate!)}';
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        theme: pw.ThemeData.withFont(
          base: fonts.regular,
          bold: fonts.bold,
          italic: fonts.italic,
        ),
        footer: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            pw.Divider(color: PdfColors.grey400, thickness: 0.5),
            pw.SizedBox(height: 4),
            pw.Text('Generated by BSM AGRO', style: pw.TextStyle(fontSize: 8, color: PdfColors.grey700, fontWeight: pw.FontWeight.bold)),
            pw.Text('This is a computer generated statement.', style: pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
            pw.SizedBox(height: 4),
            pw.Text('Page ${context.pageNumber} of ${context.pagesCount}', style: pw.TextStyle(fontSize: 8, color: PdfColors.grey500)),
          ]
        ),
        build: (context) => [
          // Header
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Row(
                children: [
                  if (logoImage != null)
                    pw.Container(
                      width: 50,
                      height: 50,
                      child: pw.Image(logoImage),
                    ),
                  if (logoImage != null) pw.SizedBox(width: 12),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('BSM AGRO', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold, color: PdfColor.fromInt(0xFF277533))),
                      pw.SizedBox(height: 2),
                      pw.Text('CUSTOMER STATEMENT', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700, letterSpacing: 1.2)),
                    ],
                  ),
                ],
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text('Generated: ${df.format(DateTime.now())}', style: pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                ],
              ),
            ],
          ),
          pw.SizedBox(height: 16),
          pw.Container(height: 2, color: PdfColor.fromInt(0xFF277533)),
          pw.SizedBox(height: 16),
          
          // Customer Details
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('CUSTOMER DETAILS', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.grey600)),
                  pw.SizedBox(height: 4),
                  pw.Text(statement.customer.name, style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                  if (statement.customer.phone.isNotEmpty) 
                    pw.Text(statement.customer.phone, style: pw.TextStyle(fontSize: 11, color: PdfColors.grey800)),
                ],
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text('STATEMENT PERIOD', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.grey600)),
                  pw.SizedBox(height: 4),
                  pw.Text(periodStr, style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
                ],
              ),
            ],
          ),
          pw.SizedBox(height: 24),
          
          // Ledger Table
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
            columnWidths: {
              0: const pw.FlexColumnWidth(1.5),
              1: const pw.FlexColumnWidth(3),
              2: const pw.FlexColumnWidth(1.2),
              3: const pw.FlexColumnWidth(1.2),
              4: const pw.FlexColumnWidth(1.2),
            },
            children: [
              // Header Row
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFF277533)),
                repeat: true,
                children: ['Date', 'Description', 'Debit (Dr)', 'Credit (Cr)', 'Balance'].map((h) => 
                  pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    child: pw.Text(
                      h, 
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 9), 
                      textAlign: (h == 'Date' || h == 'Description') ? pw.TextAlign.left : pw.TextAlign.right
                    ),
                  )
                ).toList(),
              ),
              // Data Rows
              ...statement.transactions.asMap().entries.map((entry) {
                final idx = entry.key;
                final t = entry.value;
                final isOpening    = t.type == 'opening_balance';
                final isCreditSale = t.type == 'credit_sale';
                final isDebit  = t.type == 'delivery' || t.type == 'invoice' || isOpening || isCreditSale;
                final isCredit = t.type == 'payment';

                final debitStr  = isDebit  && t.amount > 0 ? '₹${t.amount.toStringAsFixed(2)}' : '-';
                final creditStr = isCredit && t.amount > 0 ? '₹${t.amount.toStringAsFixed(2)}' : '-';

                // Build description label
                final String mainDesc = isCreditSale ? 'Credit Sale' : t.description;
                pw.Widget descWidget;
                if (t.items.isNotEmpty || isCreditSale) {
                  descWidget = pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(mainDesc, style: pw.TextStyle(fontSize: 9, fontWeight: isOpening ? pw.FontWeight.bold : null)),
                      pw.SizedBox(height: 4),
                      pw.Padding(
                        padding: const pw.EdgeInsets.only(left: 8),
                        child: pw.Column(
  crossAxisAlignment: pw.CrossAxisAlignment.start,
  children: [
    ...t.items.map((item) {
      String qtyStr = item.quantity.truncateToDouble() == item.quantity
          ? item.quantity.toInt().toString()
          : item.quantity.toStringAsFixed(1);
      final unit = (item.unit == null || item.unit!.isEmpty) ? 'Bag' : item.unit!;

      return pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 2),
        child: pw.Text(
          '• ${item.name} (Qty: $qtyStr $unit)',
          style: pw.TextStyle(
            fontSize: 8,
            color: PdfColors.grey700,
          ),
        ),
      );
    }),

    if (isCreditSale) ...[
      pw.SizedBox(height: 3),

      pw.Text(
        'Purchase : ₹${t.grandTotal.toStringAsFixed(0)}',
        style: pw.TextStyle(
          fontSize: 8,
          fontWeight: pw.FontWeight.bold,
        ),
      ),

      pw.Text(
        'Paid : ₹${t.paymentReceived.toStringAsFixed(0)}',
        style: pw.TextStyle(
          fontSize: 8,
          color: PdfColors.green700,
        ),
      ),

      pw.Text(
        'Balance : ₹${t.pendingAmount.toStringAsFixed(0)}',
        style: pw.TextStyle(
          fontSize: 8,
          color: PdfColors.red700,
          fontWeight: pw.FontWeight.bold,
        ),
      ),
    ]
  ],
),
                       
                      ),
                    ]
                  );
                } else {
                  descWidget = pw.Text(mainDesc, style: pw.TextStyle(fontSize: 9, fontWeight: isOpening ? pw.FontWeight.bold : null));
                }

                return pw.TableRow(
                  decoration: pw.BoxDecoration(
                    color: isOpening ? PdfColors.grey200 : (idx % 2 == 0 ? PdfColors.white : PdfColors.grey50)
                  ),
                  children: [
                    pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 8), 
                      child: pw.Text(df.format(t.date), style: const pw.TextStyle(fontSize: 9))
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 8), 
                      child: descWidget
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 8), 
                      child: pw.Text(debitStr, style: const pw.TextStyle(fontSize: 9), textAlign: pw.TextAlign.right)
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 8), 
                      child: pw.Text(creditStr, style: const pw.TextStyle(fontSize: 9), textAlign: pw.TextAlign.right)
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 8), 
                      child: pw.Text('₹${t.balance.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.right)
                    ),
                  ]
                );
              }),
            ]
          ),
          pw.SizedBox(height: 24),
          
          // Summary Section
          pw.Container(
            padding: const pw.EdgeInsets.all(16),
            decoration: pw.BoxDecoration(
              color: PdfColors.grey100,
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
              border: pw.Border.all(color: PdfColors.grey300),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('Total Deliveries', style: pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                    pw.SizedBox(height: 4),
                    pw.Text('₹${statement.summary.totalDeliveries.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColor.fromInt(0xFF277533))),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('Total Payments', style: pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                    pw.SizedBox(height: 4),
                    pw.Text('₹${statement.summary.totalPayments.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.blue700)),
                  ],
                ),
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: pw.BoxDecoration(
                    color: statement.summary.pendingBalance > 0 ? PdfColors.red50 : PdfColors.green50,
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                    border: pw.Border.all(
                      color: statement.summary.pendingBalance > 0 ? PdfColors.red300 : PdfColors.green300, 
                      width: 1.5
                    ),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        statement.summary.pendingBalance < 0 ? 'Advance Credit' : 'Pending Balance', 
                        style: pw.TextStyle(
                          fontSize: 12, 
                          fontWeight: pw.FontWeight.bold, 
                          color: statement.summary.pendingBalance > 0 ? PdfColors.red900 : PdfColors.green900
                        )
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        '₹${statement.summary.pendingBalance.abs().toStringAsFixed(2)}', 
                        style: pw.TextStyle(
                          fontSize: 18, 
                          fontWeight: pw.FontWeight.bold, 
                          color: statement.summary.pendingBalance > 0 ? PdfColors.red : PdfColor.fromInt(0xFF277533)
                        )
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    return pdf.save();
  }
}

