import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/app_colors.dart';
import '../models/inventory_model.dart';
import '../repositories/inventory_repository.dart';
import '../core/stock_format.dart';
import '../models/category_model.dart';

/// Dialog for editing an existing inventory item.
/// Pre-fills [item] values; on save calls PUT /inventory/:id via [InventoryRepository].
class EditInventoryItemDialog extends StatefulWidget {
  final InventoryItemModel item;
  final List<CategoryModel> categories;
  final VoidCallback onSaved;

  const EditInventoryItemDialog({
    super.key,
    required this.item,
    required this.categories,
    required this.onSaved,
  });

  @override
  State<EditInventoryItemDialog> createState() => _EditInventoryItemDialogState();
}

class _EditInventoryItemDialogState extends State<EditInventoryItemDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _unitCtrl;
  late final TextEditingController _thresholdCtrl;
  late final TextEditingController stockController;
  late final TextEditingController stockNoteController;

  String? _selectedCategory;
  bool _isSaving = false;

  static const _teal = Color(0xFF00897B);
  final _repo = InventoryRepository();

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.item.itemName);
    _unitCtrl = TextEditingController(text: widget.item.unit);
    _thresholdCtrl = TextEditingController(
      text: fmtStock(widget.item.threshold),
    );
    stockController = TextEditingController(
      text: fmtStock(widget.item.currentStock),
    );
    stockNoteController = TextEditingController();
    // Pre-select category if a matching one exists in the list.
    // item.category may be null when the item was created via /inventory/item
    // (which stores categoryName) — in that case the dropdown starts empty.
    final cat = widget.item.category;
    if (cat != null && cat.isNotEmpty) {
      final match = widget.categories.any((c) => c.name.toLowerCase() == cat.toLowerCase());
      if (match) _selectedCategory = cat;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _unitCtrl.dispose();
    _thresholdCtrl.dispose();
    stockController.dispose();
    stockNoteController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final stockText = stockController.text.trim();
    final parsedStock = double.tryParse(stockText);
    if (stockText.isEmpty || parsedStock == null || parsedStock < 0) {
      _showSnack("Please enter a valid stock value", Colors.red);
      return;
    }

    final id = widget.item.id;
    if (id == null) {
      _showSnack('Cannot update: item has no ID.', Colors.red);
      return;
    }

    setState(() => _isSaving = true);
    try {
      final originalStock = widget.item.currentStock;
      double? currentStockToSend;
      String? stockCorrectionNoteToSend;

      if (parsedStock != originalStock) {
        currentStockToSend = parsedStock;
        stockCorrectionNoteToSend = stockNoteController.text.trim();
      }

      await _repo.updateItem(
        id,
        itemName: _nameCtrl.text.trim(),
        categoryName: _selectedCategory,
        unit: _unitCtrl.text.trim(),
        lowStockThreshold:
            double.tryParse(_thresholdCtrl.text.trim()) ?? widget.item.threshold,
        currentStock: currentStockToSend,
        stockCorrectionNote: stockCorrectionNoteToSend,
      );

      if (!mounted) return;
      _showSnack('Item updated successfully!', Colors.green);
      widget.onSaved();
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      _showSnack(e.toString().replaceAll('Exception: ', ''), Colors.red);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showSnack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: GoogleFonts.inter(fontSize: 13, color: Colors.white)),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      margin: const EdgeInsets.all(16),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Header ─────────────────────────────────────────────────
                Row(children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _teal.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.edit_outlined, color: _teal, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Edit Item',
                            style: GoogleFonts.inter(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary)),
                        Text('Update inventory item details',
                            style: GoogleFonts.inter(
                                fontSize: 12, color: AppColors.textSecondary)),
                      ],
                    ),
                  ),
                ]),
                const SizedBox(height: 24),

                // ── Item Name ───────────────────────────────────────────────
                TextFormField(
                  controller: _nameCtrl,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    labelText: 'Item Name',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    prefixIcon: const Icon(Icons.inventory_2_outlined),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: _teal, width: 2),
                    ),
                  ),
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'Item name is required' : null,
                ),
                const SizedBox(height: 16),

                // ── Category Dropdown ───────────────────────────────────────
                DropdownButtonFormField<String>(
                  initialValue: _selectedCategory,
                  decoration: InputDecoration(
                    labelText: 'Category',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    prefixIcon: const Icon(Icons.category_outlined),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: _teal, width: 2),
                    ),
                  ),
                  hint: Text('Select Category', style: GoogleFonts.inter(fontSize: 14)),
                  items: widget.categories.map((c) {
                    return DropdownMenuItem<String>(
                      value: c.name,
                      child: Text(c.name, style: GoogleFonts.inter()),
                    );
                  }).toList(),
                  onChanged: (v) => setState(() => _selectedCategory = v),
                  // Category is optional on edit — backend only updates it if sent
                ),
                const SizedBox(height: 16),

                // ── Unit & Threshold row ────────────────────────────────────
                Row(children: [
                  Expanded(
                    child: TextFormField(
                      controller: _unitCtrl,
                      decoration: InputDecoration(
                        labelText: 'Unit (e.g. kg, bags)',
                        border:
                            OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: _teal, width: 2),
                        ),
                      ),
                      validator: (v) =>
                          v == null || v.trim().isEmpty ? 'Required' : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _thresholdCtrl,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: 'Low Stock At',
                        border:
                            OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: _teal, width: 2),
                        ),
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Required';
                        if (double.tryParse(v.trim()) == null) return 'Invalid number';
                        return null;
                      },
                    ),
                  ),
                ]),
                const SizedBox(height: 16),

                // ── Stock Correction Row ────────────────────────────────────
                Row(children: [
                  Expanded(
                    child: TextFormField(
                      initialValue: fmtStock(widget.item.currentStock),
                      enabled: false,
                      style: GoogleFonts.inter(color: Colors.grey[600]),
                      decoration: InputDecoration(
                        labelText: 'Current Stock',
                        labelStyle: GoogleFonts.inter(color: Colors.grey[500]),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey[300]!),
                        ),
                        disabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey[300]!),
                        ),
                        prefixIcon: Icon(Icons.inventory_2_outlined, color: Colors.grey[400]),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: stockController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: 'New Stock Value',
                        hintText: 'Enter corrected stock count',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: _teal, width: 2),
                        ),
                        prefixIcon: const Icon(Icons.edit_note),
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Required';
                        final val = double.tryParse(v.trim());
                        if (val == null || val < 0) return 'Must be >= 0';
                        return null;
                      },
                    ),
                  ),
                ]),
                const SizedBox(height: 16),

                // ── Correction Note ──────────────────────────────────────────
                TextFormField(
                  controller: stockNoteController,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    labelText: 'Correction Note (optional)',
                    hintText: 'e.g. Physical count correction, Damaged bags removed',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    prefixIcon: const Icon(Icons.comment_outlined),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: _teal, width: 2),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // ── Action Buttons ──────────────────────────────────────────
                Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                  TextButton(
                    onPressed: _isSaving ? null : () => Navigator.pop(context),
                    child: Text('Cancel',
                        style: GoogleFonts.inter(color: AppColors.textSecondary)),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: _isSaving ? null : _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _teal,
                      foregroundColor: Colors.white,
                      padding:
                          const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: _isSaving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2))
                        : const Icon(Icons.save_outlined, size: 18),
                    label: Text(
                      _isSaving ? 'Saving…' : 'Update',
                      style: GoogleFonts.inter(fontWeight: FontWeight.bold),
                    ),
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
