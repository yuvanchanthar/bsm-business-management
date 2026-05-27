import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:provider/provider.dart';
import '../core/app_colors.dart';
import '../models/delivery.dart';
import 'package:google_fonts/google_fonts.dart';
import '../features/invoice/presentation/providers/template_provider.dart';
import '../features/invoice/presentation/widgets/template_preview_widgets.dart';

import 'package:permission_handler/permission_handler.dart';
import 'package:open_filex/open_filex.dart';

class DeliverySuccessScreen extends StatefulWidget {
  final Delivery delivery;
  final Uint8List pdfData;
  final String templateId;

  const DeliverySuccessScreen({
    super.key,
    required this.delivery,
    required this.pdfData,
    required this.templateId,
  });

  @override
  State<DeliverySuccessScreen> createState() => _DeliverySuccessScreenState();
}

class _DeliverySuccessScreenState extends State<DeliverySuccessScreen> {
  bool _isDownloading = false;
  bool _isSharing = false;

  String get _fileName => 'INV-${widget.delivery.id}_${widget.templateId.toUpperCase()}_${DateTime.now().millisecondsSinceEpoch}.pdf';

  Future<void> _printPdf() async {
    try {
      await Printing.layoutPdf(
        onLayout: (format) => widget.pdfData,
        name: _fileName,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Print failed: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _sharePdf() async {
    if (_isSharing) return;
    setState(() => _isSharing = true);
    
    try {
      final tempDir = await getTemporaryDirectory();
      final file = await File('${tempDir.path}/$_fileName').create();
      await file.writeAsBytes(widget.pdfData);

      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Invoice for Delivery ${widget.delivery.id}',
        subject: 'Invoice $_fileName',
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Share failed: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isSharing = false);
    }
  }

  Future<void> _downloadPdf() async {
    if (_isDownloading) return;
    setState(() => _isDownloading = true);
    
    try {
      if (Platform.isAndroid) {
        // Scoped storage / Permissions
        final status = await Permission.storage.status;
        if (!status.isGranted) {
          await Permission.storage.request();
          // Android 13+ might not grant storage, but we can still write to Downloads using open_filex or MediaStore.
          // We will proceed anyway as path_provider can write to app dirs.
        }
      }

      Directory? directory;
      if (Platform.isAndroid) {
        // Try public downloads first
        directory = Directory('/storage/emulated/0/Download');
        if (!await directory.exists()) {
          directory = await getExternalStorageDirectory();
        }
      } else {
        directory = await getApplicationDocumentsDirectory();
      }

      final file = File('${directory!.path}/$_fileName');
      await file.writeAsBytes(widget.pdfData);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Saved: $_fileName'),
          backgroundColor: AppColors.primaryGreen,
          action: SnackBarAction(
            label: 'OPEN',
            textColor: Colors.white,
            onPressed: () => OpenFilex.open(file.path),
          ),
        ),
      );
      
      // Attempt to auto-open
      await OpenFilex.open(file.path);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Download failed: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isDownloading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TemplateProvider>();
    final template = provider.templateById(widget.templateId) ?? provider.templates.first;

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
          'Invoice Generated',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
            child: Column(
              children: [
                const Icon(
                  Icons.check_circle,
                  color: AppColors.primaryGreen,
                  size: 56,
                ),
                const SizedBox(height: 12),
                Text(
                  'Success!',
                  style: GoogleFonts.inter(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  'Invoice ${widget.delivery.id} is ready',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 15,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: getTemplateWidget(widget.templateId, template, widget.delivery),
                ),
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(24.0),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -5),
                ),
              ],
            ),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: _buildActionButton(
                      icon: Icons.print_outlined,
                      label: 'Print',
                      color: Colors.blueGrey,
                      onTap: _printPdf,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildActionButton(
                      icon: Icons.download_outlined,
                      label: 'Download',
                      color: AppColors.primaryGreen,
                      onTap: _downloadPdf,
                      isLoading: _isDownloading,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildActionButton(
                      icon: Icons.share_outlined,
                      label: 'Share',
                      color: Colors.blueAccent,
                      onTap: _sharePdf,
                      isLoading: _isSharing,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
    bool isLoading = false,
  }) {
    return Material(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: isLoading ? null : onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isLoading)
                SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                  ),
                )
              else
                Icon(icon, color: color, size: 24),
              const SizedBox(height: 6),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
