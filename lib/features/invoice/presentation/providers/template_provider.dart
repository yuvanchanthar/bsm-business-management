import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../../../../models/delivery.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../services/api_service.dart';
import '../../domain/entities/invoice_template.dart';
import '../../domain/usecases/get_default_template_usecase.dart';
import '../../domain/usecases/save_default_template_usecase.dart';
import '../../domain/usecases/generate_invoice_usecase.dart';

/// Central state manager for the invoice template system.
/// Exposed via [ChangeNotifierProvider] from [main.dart].
class TemplateProvider extends ChangeNotifier {
  final GetDefaultTemplateUsecase _getDefault;
  final SaveDefaultTemplateUsecase _saveDefault;
  final GenerateInvoiceUsecase _generate;
  final ApiService _apiService;

  TemplateProvider({
    required GetDefaultTemplateUsecase getDefault,
    required SaveDefaultTemplateUsecase saveDefault,
    required GenerateInvoiceUsecase generate,
    required ApiService apiService,
  })  : _getDefault = getDefault,
        _saveDefault = saveDefault,
        _generate = generate,
        _apiService = apiService;

  // ── State ─────────────────────────────────────────────────────────────────

  String? _selectedTemplateId;
  String? _defaultTemplateId;
  bool _isGenerating = false;
  String? _errorMessage;
  Uint8List? _generatedPdfBytes;

  // ── Getters ───────────────────────────────────────────────────────────────

  String? get selectedTemplateId => _selectedTemplateId;
  String? get defaultTemplateId  => _defaultTemplateId;
  bool    get isGenerating        => _isGenerating;
  String? get errorMessage        => _errorMessage;
  Uint8List? get generatedPdfBytes => _generatedPdfBytes;

  /// The ordered catalogue of all 5 available invoice templates.
  List<InvoiceTemplate> get templates => const [
    InvoiceTemplate(
      id: AppConstants.kTemplateClassic,
      name: 'Classic',
      description: 'Clean green-themed BSM receipt with logo header.',
      icon: Icons.description_outlined,
      primaryColor: Color(0xFF277533),
      accentColor: Color(0xFFF1F8E9),
      tagLine: 'Traditional · Professional',
    ),
    InvoiceTemplate(
      id: AppConstants.kTemplateModern,
      name: 'Modern',
      description: 'Bold blue header bar with alternating row layout.',
      icon: Icons.article_outlined,
      primaryColor: Color(0xFF1565C0),
      accentColor: Color(0xFFE3F2FD),
      tagLine: 'Contemporary · Sleek',
    ),
    InvoiceTemplate(
      id: AppConstants.kTemplateGst,
      name: 'GST',
      description: 'Tax invoice with CGST & SGST breakdown rows.',
      icon: Icons.receipt_long_outlined,
      primaryColor: Color(0xFF6A1B9A),
      accentColor: Color(0xFFF3E5F5),
      tagLine: 'Tax Compliant · Detailed',
    ),
    InvoiceTemplate(
      id: AppConstants.kTemplateDark,
      name: 'Dark',
      description: 'Dark background with violet accents. Digital use.',
      icon: Icons.dark_mode_outlined,
      primaryColor: Color(0xFFBB86FC),
      accentColor: Color(0xFF2D2D44),
      tagLine: 'Modern · Dark Mode',
    ),
    InvoiceTemplate(
      id: AppConstants.kTemplateCorporate,
      name: 'Corporate',
      description: 'Minimalist burnt-orange accents with thin-border table.',
      icon: Icons.business_center_outlined,
      primaryColor: Color(0xFFBF360C),
      accentColor: Color(0xFFFBE9E7),
      tagLine: 'Enterprise · Formal',
    ),
  ];

  // ── Actions ───────────────────────────────────────────────────────────────

  /// Selects a template (UI-only, does not persist).
  void selectTemplate(String id) {
    _selectedTemplateId = id;
    _errorMessage = null;
    notifyListeners();
  }

  /// Loads the persisted default template ID from storage.
  Future<void> loadDefaultTemplate() async {
    _defaultTemplateId = await _getDefault();
    notifyListeners();
  }

  /// Persists [id] as the new default template and updates local state.
  Future<void> setAsDefault(String id) async {
    await _saveDefault(id);
    _defaultTemplateId = id;
    notifyListeners();
  }

  /// Clears the stored default template preference.
  Future<void> clearDefault() async {
    await _saveDefault('');
    _defaultTemplateId = null;
    notifyListeners();
  }

  /// Generates a PDF for [delivery] using [templateId].
  /// Returns the raw bytes on success, null on failure.
  Future<Uint8List?> generateInvoice({
    required Delivery delivery,
    required String templateId,
  }) async {
    _isGenerating = true;
    _errorMessage = null;
    _generatedPdfBytes = null;
    notifyListeners();

    try {
      final bytes = await _generate(delivery: delivery, templateId: templateId);
      _generatedPdfBytes = bytes;
      return bytes;
    } catch (e) {
      _errorMessage = 'Failed to generate invoice: $e';
      return null;
    } finally {
      _isGenerating = false;
      notifyListeners();
    }
  }

  /// MANDATORY FLOW: Persists [templateId] to backend, re-fetches full delivery, 
  /// and generates PDF using the persisted state.
  Future<({Uint8List bytes, Delivery updatedDelivery})?> updateAndGenerateInvoice({
    required Delivery delivery,
    required String templateId,
  }) async {
    final invoiceId = delivery.invoice?.id;
    if (invoiceId == null || invoiceId.isEmpty) {
      _errorMessage = 'Cannot update template: No invoice ID found.';
      notifyListeners();
      return null;
    }

    _isGenerating = true;
    _errorMessage = null;
    notifyListeners();

    try {
      debugPrint('[TemplateProvider] PERSISTING template "$templateId" to invoice "$invoiceId"');
      
      // Step 1: Update backend
      final success = await _apiService.updateInvoiceTemplate(invoiceId, templateId);
      if (!success) throw Exception('Backend rejected template update');

      // Step 2: Re-fetch full delivery to get updated invoice object
      debugPrint('[TemplateProvider] RE-FETCHING delivery "${delivery.id}"');
      final fullDelivery = await _apiService.getDeliveryById(delivery.id);
      if (fullDelivery == null) throw Exception('Failed to re-fetch delivery after update');

      // Step 3: Generate PDF using the persisted templateId (from backend)
      final finalTemplateId = fullDelivery.invoice?.templateId ?? templateId;
      debugPrint('[TemplateProvider] GENERATING PDF using persisted ID: "$finalTemplateId"');
      
      final bytes = await _generate(delivery: fullDelivery, templateId: finalTemplateId);
      _generatedPdfBytes = bytes;

      return (bytes: bytes, updatedDelivery: fullDelivery);
    } catch (e) {
      _errorMessage = 'Update failed: $e';
      debugPrint('[TemplateProvider] ERROR: $_errorMessage');
      return null;
    } finally {
      _isGenerating = false;
      notifyListeners();
    }
  }

  /// Convenience: find a template entity by its ID.
  InvoiceTemplate? templateById(String id) {
    try {
      return templates.firstWhere((t) => t.id == id);
    } catch (_) {
      return null;
    }
  }
}
