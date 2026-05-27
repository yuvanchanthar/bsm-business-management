import 'dart:typed_data';
import '../../../../models/delivery.dart';
import '../../../invoice/services/invoice_generator_service.dart';

/// Coordinates invoice PDF generation for a given delivery + template choice.
/// Delegates the actual rendering to [InvoiceGeneratorService].
class GenerateInvoiceUsecase {
  final InvoiceGeneratorService _generatorService;

  const GenerateInvoiceUsecase(this._generatorService);

  /// Returns raw PDF bytes ready for display or sharing.
  Future<Uint8List> call({
    required Delivery delivery,
    required String templateId,
  }) =>
      _generatorService.generate(templateId: templateId, delivery: delivery);
}
