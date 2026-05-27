import 'dart:typed_data';
import '../../models/delivery.dart';

/// Abstract base for all invoice PDF templates.
/// Each subclass provides its own visual design while sharing the
/// same interface so [InvoiceGeneratorService] can dispatch uniformly.
abstract class BaseInvoiceTemplate {
  const BaseInvoiceTemplate();

  String get id;
  String get name;

  /// Generates and returns the raw PDF bytes for [delivery].
  Future<Uint8List> generate(Delivery delivery);
}
