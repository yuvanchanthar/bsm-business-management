import 'package:flutter/material.dart';

/// Immutable entity representing a single invoice template.
/// Holds only presentation metadata — PDF generation is done via
/// [BaseInvoiceTemplate] subclasses in the templates layer.
class InvoiceTemplate {
  final String id;
  final String name;
  final String description;
  final IconData icon;
  final Color primaryColor;
  final Color accentColor;
  final String tagLine;

  const InvoiceTemplate({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.primaryColor,
    required this.accentColor,
    required this.tagLine,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is InvoiceTemplate && other.id == id);

  @override
  int get hashCode => id.hashCode;
}
