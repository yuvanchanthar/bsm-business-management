import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/app_colors.dart';
import '../models/inventory_model.dart';
import '../repositories/inventory_repository.dart';

class AddExistingStockDialog extends StatefulWidget {
  /// Pre-select a specific item. Pass null to let user choose.
  final InventoryItemModel? preSelectedItem;

  /// All items to show in dropdown if preSelectedItem is null.
  final List<InventoryItemModel> allItems;

  /// Called after stock is successfully added so callers can refresh.
  final VoidCallback onSaved;

  const AddExistingStockDialog({
    super.key,
    this.preSelectedItem,
    required this.allItems,
    required this.onSaved,
  });

  @override
  State<AddExistingStockDialog> createState() => _AddExistingStockDialogState();
}

class _AddExistingStockDialogState extends State<AddExistingStockDialog> {
  final _formKey  = GlobalKey<FormState>();
  final _qtyCtrl  = TextEditingController();
  final _noteCtrl = TextEditingController();
  final _repo     = InventoryRepository();

  InventoryItemModel? _selectedItem;
  String _reason  = 'Manual Entry';
  bool _isSaving  = false;

  static const _teal = Color(0xFF00897B);

  static const _reasons = [
    'Supplier Purchase',
    'Manual Entry',
    'Stock Adjustment',
    'Returned Stock',
  ];

  @override
  void initState() {
    super.initState();
    _selectedItem = widget.preSelectedItem;
  }

  @override
  void dispose() {
    _qtyCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedItem == null) {
      _showSnack('Please select an item', isError: true);
      return;
    }
    if (_selectedItem!.id == null) {
      _showSnack('Selected item has no ID — cannot update', isError: true);
      return;
    }

    setState(() => _isSaving = true);
    try {
      await _repo.addStock(
        itemId:   _selectedItem!.id!,
        quantity: double.parse(_qtyCtrl.text.trim()),
        reason:   _reason,
        notes:    _noteCtrl.text.trim(),
      );
      if (!mounted) return;
      _showSnack('Stock updated: +${_qtyCtrl.text.trim()} ${_selectedItem!.unit}');
      widget.onSaved();
      Navigator.pop(context);
    } catch (e) {
      if (mounted) _showSnack(e.toString().replaceAll('Exception: ', ''), isError: true);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? Colors.red : _teal,
      behavior: SnackBarBehavior.floating,
    ));
  }

  @override
  Widget build(BuildContext context) {
    // Deduplicate by id for the dropdown
    final seen = <String>{};
    final items = widget.allItems
        .where((i) => i.id != null && seen.add(i.id!))
        .toList();

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                // ── Header ────────────────────────────────────────────────
                Row(children: [
                  Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(
                      color: _teal.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.add_chart_outlined, color: _teal, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Add Existing Stock',
                      style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                    Text('Increase stock for an existing item.',
                      style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary)),
                  ])),
                ]),
                const SizedBox(height: 24),

                // ── Select Item ───────────────────────────────────────────
                if (widget.preSelectedItem != null) ...[
                  Text('Item', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: _teal.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _teal.withValues(alpha: 0.3)),
                    ),
                    child: Row(children: [
                      const Icon(Icons.inventory_2_outlined, color: _teal, size: 18),
                      const SizedBox(width: 10),
                      Expanded(child: Text(widget.preSelectedItem!.itemName,
                        style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: _teal))),
                      Text('${widget.preSelectedItem!.currentStock.toStringAsFixed(0)} ${widget.preSelectedItem!.unit} in stock',
                        style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary)),
                    ]),
                  ),
                ] else ...[
                  DropdownButtonFormField<InventoryItemModel>(
                    value: _selectedItem,
                    decoration: InputDecoration(
                      labelText: 'Select Item',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      prefixIcon: const Icon(Icons.inventory_2_outlined),
                    ),
                    items: items.map((item) => DropdownMenuItem(
                      value: item,
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                        Text(item.itemName, style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                        Text('Stock: ${item.currentStock.toStringAsFixed(0)} ${item.unit}',
                          style: GoogleFonts.inter(fontSize: 11, color: AppColors.textSecondary)),
                      ]),
                    )).toList(),
                    onChanged: (v) => setState(() => _selectedItem = v),
                    validator: (v) => v == null ? 'Select an item' : null,
                    hint: Text('Choose item', style: GoogleFonts.inter()),
                  ),
                ],
                const SizedBox(height: 16),

                // ── Current stock preview ─────────────────────────────────
                if (_selectedItem != null && widget.preSelectedItem == null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(children: [
                        Icon(Icons.bar_chart, color: _teal, size: 16),
                        const SizedBox(width: 8),
                        Text('Current Stock: ',
                          style: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary)),
                        Text('${_selectedItem!.currentStock.toStringAsFixed(0)} ${_selectedItem!.unit}',
                          style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: _teal)),
                      ]),
                    ),
                  ),

                // ── Quantity ──────────────────────────────────────────────
                TextFormField(
                  controller: _qtyCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: 'Quantity to Add',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    prefixIcon: const Icon(Icons.add_circle_outline),
                    suffix: _selectedItem != null
                        ? Text(_selectedItem!.unit, style: GoogleFonts.inter(color: AppColors.textSecondary))
                        : null,
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Required';
                    final d = double.tryParse(v.trim());
                    if (d == null || d <= 0) return 'Enter a valid quantity';
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // ── Reason ────────────────────────────────────────────────
                DropdownButtonFormField<String>(
                  value: _reason,
                  decoration: InputDecoration(
                    labelText: 'Reason',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    prefixIcon: const Icon(Icons.category_outlined),
                  ),
                  items: _reasons.map((r) => DropdownMenuItem(
                    value: r,
                    child: Text(r, style: GoogleFonts.inter()),
                  )).toList(),
                  onChanged: (v) => setState(() => _reason = v ?? _reason),
                ),
                const SizedBox(height: 16),

                // ── Notes ─────────────────────────────────────────────────
                TextFormField(
                  controller: _noteCtrl,
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: 'Notes (Optional)',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    prefixIcon: const Icon(Icons.notes_outlined),
                    hintText: 'e.g. Received from Raja Feeds on 25 May',
                  ),
                ),
                const SizedBox(height: 24),

                // ── Actions ───────────────────────────────────────────────
                Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                  TextButton(
                    onPressed: _isSaving ? null : () => Navigator.pop(context),
                    child: Text('Cancel', style: GoogleFonts.inter(color: AppColors.textSecondary)),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: _isSaving ? null : _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _teal,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: _isSaving
                        ? const SizedBox(width: 18, height: 18,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Icon(Icons.check, size: 18),
                    label: Text(_isSaving ? 'Saving...' : 'Add Stock',
                      style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
                  ),
                ]),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
