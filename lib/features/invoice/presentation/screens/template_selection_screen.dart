import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../../core/app_colors.dart';
import '../../../../models/delivery.dart';
import '../../domain/entities/invoice_template.dart';
import '../providers/template_provider.dart';
import '../../../invoice/presentation/screens/template_preview_screen.dart';
import '../../../../screens/delivery_success_screen.dart';

/// Displays a grid of all available invoice templates.
///
/// Two usage modes:
/// - Normal mode  (`pickerMode: false`): Navigated to after a delivery save.
///   Long-pressing or tapping generates the PDF immediately.
/// - Picker mode  (`pickerMode: true`): Opened by AddDeliveryScreen Step 2.
///   Selecting a template calls `Navigator.pop(context, templateId)` so the
///   caller can store the chosen ID locally before Step 3 generates the PDF.
class TemplateSelectionScreen extends StatelessWidget {
  final Delivery delivery;

  /// When true the screen acts as a template picker:
  /// selecting a template pops back with the chosen templateId.
  final bool pickerMode;

  const TemplateSelectionScreen({
    super.key,
    required this.delivery,
    this.pickerMode = false,
  });

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TemplateProvider>();

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
          pickerMode ? 'Pick a Template' : 'Choose Template',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        actions: [
          // Only show "Use Default" action in non-picker mode
          if (!pickerMode &&
              provider.defaultTemplateId != null &&
              provider.defaultTemplateId!.isNotEmpty)
            TextButton(
              onPressed: provider.isGenerating
                  ? null
                  : () => _generateWithTemplate(
                        context,
                        provider.defaultTemplateId!,
                      ),
              child: Text(
                'Use Default',
                style: GoogleFonts.inter(
                  color: AppColors.primaryGreen,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
      body: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Subtitle ─────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      pickerMode
                          ? 'Select an Invoice Template'
                          : 'Select an Invoice Template',
                      style: GoogleFonts.inter(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      pickerMode
                          ? 'Tap to preview  ·  Long-press to pick directly'
                          : 'Tap to preview  ·  Long-press to use directly',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),

              // ── Template Grid ───────────────────────────────────────
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final crossCount = constraints.maxWidth < 340 ? 1 : 2;
                    return GridView.builder(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 4),
                      gridDelegate:
                          SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: crossCount,
                        crossAxisSpacing: 14,
                        mainAxisSpacing: 14,
                        childAspectRatio: 0.80,
                      ),
                      itemCount: provider.templates.length,
                      itemBuilder: (context, index) {
                        final template = provider.templates[index];
                        final isDefault =
                            template.id == provider.defaultTemplateId;
                        return _TemplateCard(
                          template: template,
                          isDefault: isDefault,
                          onTap: () => _openPreview(context, template),
                          onLongPress: pickerMode
                              // Picker: return templateId immediately
                              ? () => Navigator.pop(context, template.id)
                              // Normal: generate PDF immediately
                              : () => _generateWithTemplate(
                                    context, template.id),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),

          // ── Full-screen loading overlay (only in normal mode) ─────────
          if (!pickerMode && provider.isGenerating)
            Container(
              color: Colors.black.withValues(alpha: 0.35),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 32, vertical: 24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(
                          color: AppColors.primaryGreen),
                      const SizedBox(height: 16),
                      Text(
                        'Generating invoice…',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _openPreview(BuildContext context, InvoiceTemplate template) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TemplatePreviewScreen(
          template: template,
          delivery: delivery,
          pickerMode: pickerMode,
        ),
      ),
    ).then((result) {
      // In picker mode the preview screen may also pop with a templateId.
      if (pickerMode && result is String && context.mounted) {
        Navigator.pop(context, result);
      }
    });
  }

  /// Generates invoice directly with [templateId] (long-press / Use Default).
  /// Only called in non-picker mode.
  Future<void> _generateWithTemplate(
    BuildContext context,
    String templateId,
  ) async {
    final provider = context.read<TemplateProvider>();

    debugPrint('[TemplateSelection] Persisting and Generating with template: $templateId');

    final result = await provider.updateAndGenerateInvoice(
      delivery: delivery,
      templateId: templateId,
    );

    if (!context.mounted) return;

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

    debugPrint('[TemplateSelection] PDF ready. Navigating to success screen.');

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => DeliverySuccessScreen(
          delivery: updatedDelivery,
          pdfData: bytes,
          templateId: updatedDelivery.invoice?.templateId ?? templateId,
        ),
      ),
    );
  }
}


// ── Template Card ──────────────────────────────────────────────────────────────

class _TemplateCard extends StatefulWidget {
  final InvoiceTemplate template;
  final bool isDefault;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _TemplateCard({
    required this.template,
    required this.isDefault,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  State<_TemplateCard> createState() => _TemplateCardState();
}

class _TemplateCardState extends State<_TemplateCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _scaleCtrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _scaleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
      lowerBound: 0.94,
      upperBound: 1.0,
      value: 1.0,
    );
    _scale = _scaleCtrl;
  }

  @override
  void dispose() {
    _scaleCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.template;
    return GestureDetector(
      onTap: widget.onTap,
      onLongPress: widget.onLongPress,
      onTapDown: (_) => _scaleCtrl.reverse(),
      onTapUp: (_) => _scaleCtrl.forward(),
      onTapCancel: () => _scaleCtrl.forward(),
      child: ScaleTransition(
        scale: _scale,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: widget.isDefault
                ? Border.all(color: t.primaryColor, width: 2.5)
                : Border.all(color: Colors.transparent),
            boxShadow: [
              BoxShadow(
                color: t.primaryColor.withValues(alpha: 0.12),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Color Preview Banner ───────────────────────────────
              Expanded(
                flex: 5,
                child: Stack(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            t.primaryColor,
                            t.primaryColor.withValues(alpha: 0.75),
                          ],
                        ),
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(18),
                        ),
                      ),
                      child: _buildMiniPreview(),
                    ),
                    if (widget.isDefault)
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            'DEFAULT',
                            style: GoogleFonts.inter(
                              fontSize: 7,
                              fontWeight: FontWeight.bold,
                              color: t.primaryColor,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              // ── Info section ───────────────────────────────────────
              Expanded(
                flex: 4,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(t.icon, color: t.primaryColor, size: 14),
                          const SizedBox(width: 5),
                          Flexible(
                            child: Text(
                              t.name,
                              style: GoogleFonts.inter(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: AppColors.textPrimary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        t.tagLine,
                        style: GoogleFonts.inter(
                          fontSize: 9,
                          color: t.primaryColor,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      Expanded(
                        child: Text(
                          t.description,
                          style: GoogleFonts.inter(
                            fontSize: 9,
                            color: AppColors.textSecondary,
                            height: 1.4,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Schematic mini-preview of an invoice — purely decorative skeleton.
  Widget _buildMiniPreview() {
    return Padding(
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Logo + company name skeleton
          Row(children: [
            Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(width: 5),
            Flexible(
              child: Container(
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ]),
          const SizedBox(height: 7),
          Container(height: 1, color: Colors.white.withValues(alpha: 0.3)),
          const SizedBox(height: 7),
          _fakeRow(0.5),
          const SizedBox(height: 3),
          _fakeRow(0.7),
          const SizedBox(height: 3),
          _fakeRow(0.4),
          const SizedBox(height: 7),
          Container(
            height: 9,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(height: 3),
          Container(
              height: 5, color: Colors.white.withValues(alpha: 0.15)),
          const SizedBox(height: 2),
          Container(
              height: 5, color: Colors.white.withValues(alpha: 0.15)),
        ],
      ),
    );
  }

  Widget _fakeRow(double widthFactor) {
    return FractionallySizedBox(
      widthFactor: widthFactor,
      child: Container(
        height: 4,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}
