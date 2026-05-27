import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../../core/app_colors.dart';
import '../../../../models/delivery.dart';
import '../../domain/entities/invoice_template.dart';
import '../providers/template_provider.dart';
import '../../../../screens/delivery_success_screen.dart';
import '../widgets/template_preview_widgets.dart';

/// Full-screen invoice preview for a selected template.
/// Shows a Flutter widget mockup of the invoice with a "SAMPLE TEMPLATE"
/// watermark. The actual PDF is only generated when "Use This Template" is tapped.
class TemplatePreviewScreen extends StatefulWidget {
  final InvoiceTemplate template;
  final Delivery delivery;
  final bool pickerMode;

  const TemplatePreviewScreen({
    super.key,
    required this.template,
    required this.delivery,
    this.pickerMode = false,
  });

  @override
  State<TemplatePreviewScreen> createState() => _TemplatePreviewScreenState();
}

class _TemplatePreviewScreenState extends State<TemplatePreviewScreen> {
  bool _settingDefault = false;
  bool _isGenerating   = false;

  /// Generates the PDF using the template this screen was opened with
  /// and navigates to the success screen. Reads provider fresh from context.
  Future<void> _useTemplate() async {
    if (_isGenerating) return;

    // If we're in picker mode, just pop back with the chosen ID.
    if (widget.pickerMode) {
      Navigator.pop(context, widget.template.id);
      return;
    }

    setState(() => _isGenerating = true);

    // Read provider fresh — never use a stale constructor-captured reference.
    final provider = context.read<TemplateProvider>();

    debugPrint('[TemplatePreview] Persisting and Generating with template: ${widget.template.id}');

    final result = await provider.updateAndGenerateInvoice(
      delivery: widget.delivery,
      templateId: widget.template.id, 
    );

    if (!mounted) return;
    setState(() => _isGenerating = false);

    if (result == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(provider.errorMessage ?? 'Failed to update and generate invoice'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final bytes = result.bytes;
    final updatedDelivery = result.updatedDelivery;

    debugPrint('[TemplatePreview] PDF generated (${bytes.length} bytes). Navigating to success.');

    // Pop back past preview + selection screens, then push success.
    Navigator.of(context).popUntil((route) => route.isFirst);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DeliverySuccessScreen(
          delivery: updatedDelivery,
          pdfData: bytes,
          templateId: updatedDelivery.invoice?.templateId ?? widget.template.id,
        ),
      ),
    );
  }

  Future<void> _toggleDefault() async {
    final provider = context.read<TemplateProvider>();
    setState(() => _settingDefault = true);
    try {
      if (provider.defaultTemplateId == widget.template.id) {
        await provider.clearDefault();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Default template cleared')),
          );
        }
      } else {
        await provider.setAsDefault(widget.template.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${widget.template.name} set as default'),
              backgroundColor: AppColors.primaryGreen,
            ),
          );
        }
      }
    } finally {
      if (mounted) setState(() => _settingDefault = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Watch for default-state changes only — generation state managed locally.
    final defaultTemplateId = context.select<TemplateProvider, String?>(
      (p) => p.defaultTemplateId,
    );
    final t = widget.template;
    final isDefault = defaultTemplateId == t.id;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          t.name,
          style: GoogleFonts.inter(
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: _settingDefault
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.primaryGreen,
                      ),
                    ),
                  )
                : TextButton.icon(
                    onPressed: _toggleDefault,
                    icon: Icon(
                      isDefault ? Icons.star : Icons.star_border,
                      color: isDefault ? Colors.amber : AppColors.textSecondary,
                      size: 20,
                    ),
                    label: Text(
                      isDefault ? 'Default' : 'Set Default',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isDefault ? Colors.amber : AppColors.textSecondary,
                      ),
                    ),
                  ),
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Tag line bar ──────────────────────────────────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: t.primaryColor.withValues(alpha: 0.08),
            child: Row(
              children: [
                Icon(t.icon, color: t.primaryColor, size: 15),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    t.tagLine,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: t.primaryColor,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  flex: 2,
                  child: Text(
                    t.description,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                    textAlign: TextAlign.right,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
              ],
            ),
          ),

          // ── Sample Invoice Preview ────────────────────────────────────
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Stack(
                children: [
                  getTemplateWidget(
                    widget.template.id,
                    widget.template,
                    widget.delivery,
                  ),
                  // Watermark — IgnorePointer so it doesn't block scroll
                  Positioned.fill(
                    child: IgnorePointer(
                      child: Center(
                        child: Transform.rotate(
                          angle: -0.5,
                          child: Text(
                            'SAMPLE TEMPLATE',
                            style: GoogleFonts.inter(
                              fontSize: 28,
                              fontWeight: FontWeight.w900,
                              color: Colors.black.withValues(alpha: 0.06),
                              letterSpacing: 4,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Bottom Action Bar ─────────────────────────────────────────
          Container(
            padding: EdgeInsets.fromLTRB(
              24,
              16,
              24,
              MediaQuery.of(context).padding.bottom + 16,
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 12,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton.icon(
                onPressed: _isGenerating ? null : _useTemplate,
                style: ElevatedButton.styleFrom(
                  backgroundColor: t.primaryColor,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: t.primaryColor.withValues(alpha: 0.6),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
                icon: _isGenerating
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.check_circle_outline, size: 22),
                label: Text(
                  _isGenerating ? 'Generating…' : 'Use This Template',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

