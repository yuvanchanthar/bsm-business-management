import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import '../../../models/delivery.dart';
import '../../../templates/classic_template.dart';
import '../../../templates/modern_template.dart';
import '../../../templates/gst_template.dart';
import '../../../templates/dark_template.dart';
import '../../../templates/corporate_template.dart';
import '../../../templates/base_invoice_template.dart';
import '../../../core/constants/app_constants.dart';

/// Factory service that maps a template ID to its concrete [BaseInvoiceTemplate]
/// and delegates PDF generation. All five templates are registered here.
class InvoiceGeneratorService {
  // Singleton instances — templates are stateless so one per app is fine.
  static const Map<String, BaseInvoiceTemplate> _registry = {
    AppConstants.kTemplateClassic:   ClassicTemplate(),
    AppConstants.kTemplateModern:    ModernTemplate(),
    AppConstants.kTemplateGst:       GstTemplate(),
    AppConstants.kTemplateDark:      DarkTemplate(),
    AppConstants.kTemplateCorporate: CorporateTemplate(),
  };

  const InvoiceGeneratorService();

  /// Generates a PDF for [delivery] using the template identified by [templateId].
  /// Falls back to [ClassicTemplate] when an unknown ID is supplied.
  Future<Uint8List> generate({
    required String templateId,
    required Delivery delivery,
  }) {
    final normalizedId = templateId.trim().toLowerCase();
    debugPrint('[InvoiceGeneratorService] Resolving template for ID: "$templateId" (Normalized: "$normalizedId")');
    
    final template = _registry[normalizedId] ?? const ClassicTemplate();
    debugPrint('[InvoiceGeneratorService] Selected template class: ${template.runtimeType}');
    
    return template.generate(delivery);
  }

  /// Returns all registered templates in display order.
  static List<BaseInvoiceTemplate> get allTemplates => _registry.values.toList();
}
