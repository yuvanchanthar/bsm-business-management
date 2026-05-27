import 'package:flutter/material.dart';
import 'supplier_list_screen.dart';

/// Entry-point kept to preserve navigation compatibility.
/// Immediately hands off to SupplierListScreen.
class SupplierScreen extends StatelessWidget {
  const SupplierScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const SupplierListScreen();
  }
}
