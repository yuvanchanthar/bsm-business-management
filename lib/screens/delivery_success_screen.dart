import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import '../core/app_colors.dart';
import '../models/delivery.dart';
import 'package:google_fonts/google_fonts.dart';

class DeliverySuccessScreen extends StatelessWidget {
  final Delivery delivery;
  final Uint8List pdfData;

  const DeliverySuccessScreen({
    super.key,
    required this.delivery,
    required this.pdfData,
  });

  Future<void> _sharePdf(BuildContext context) async {
    final tempDir = await getTemporaryDirectory();
    final file = await File('${tempDir.path}/Delivery_${delivery.id}.pdf').create();
    await file.writeAsBytes(pdfData);

    await Share.shareXFiles(
      [XFile(file.path)],
      text: 'Delivery Receipt: ${delivery.id}',
    );
  }

  Future<void> _saveToLocal(BuildContext context) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/Delivery_${delivery.id}.pdf');
      await file.writeAsBytes(pdfData);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Saved to ${file.path}'),
            backgroundColor: AppColors.primaryGreen,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving file: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: AppColors.textPrimary),
          onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
        ),
        title: Text(
          'Delivery Success',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.bold,
            color: AppColors.primaryGreen,
          ),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              children: [
                const Icon(
                  Icons.check_circle_outline,
                  color: AppColors.primaryGreen,
                  size: 64,
                ),
                const SizedBox(height: 16),
                Text(
                  'Delivery Created Successfully',
                  style: GoogleFonts.inter(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  'ID: ${delivery.id}',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 24),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: PdfPreview(
                  build: (format) => pdfData,
                  maxPageWidth: 700,
                  canChangePageFormat: false,
                  canChangeOrientation: false,
                  canDebug: false,
                  actions: [
                    PdfPreviewAction(
                      icon: const Icon(Icons.share),
                      onPressed: (context, build, format) => _sharePdf(context),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => Printing.layoutPdf(onLayout: (format) => pdfData),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: AppColors.primaryGreen,
                      side: const BorderSide(color: AppColors.primaryGreen),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.print),
                    label: const Text('Print'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _saveToLocal(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryGreen,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.download),
                    label: const Text('Download'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
