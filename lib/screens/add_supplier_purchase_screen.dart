import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../core/app_colors.dart';
import '../models/supplier_model.dart';
import '../models/category_model.dart';
import '../services/supplier_service.dart';
import '../services/token_service.dart';

class AddSupplierPurchaseScreen extends StatefulWidget {
  final String supplierId;
  final String supplierName;

  const AddSupplierPurchaseScreen({
    super.key,
    required this.supplierId,
    required this.supplierName,
  });

  @override
  State<AddSupplierPurchaseScreen> createState() => _AddSupplierPurchaseScreenState();
}

class _AddSupplierPurchaseScreenState extends State<AddSupplierPurchaseScreen> {
  final _qtyCtrl   = TextEditingController();
  final _unitCtrl  = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _noteCtrl  = TextEditingController();

  DateTime  _selectedDate     = DateTime.now();
  DateTime? _selectedDueDate;
  String?   _base64Image;
  bool      _isLoading        = false;

  // Dynamic product selection
  List<GroupedItemModel> _groupedItems = [];
  bool  _isLoadingProducts = false;
  String? _selectedItem;       // the chosen product name

  late SupplierService _service;

  double get _computedTotal {
    final qty   = double.tryParse(_qtyCtrl.text)   ?? 0;
    final price = double.tryParse(_priceCtrl.text) ?? 0;
    return qty * price;
  }

  @override
  void initState() {
    super.initState();
    _qtyCtrl.addListener(() => setState(() {}));
    _priceCtrl.addListener(() => setState(() {}));
    _init();
    _fetchProducts();
  }

  Future<void> _init() async {
    final ts = await TokenService.getInstance();
    _service = SupplierService(ts);
  }

  Future<void> _fetchProducts() async {
    if (!mounted) return;
    setState(() => _isLoadingProducts = true);
    try {
      final groups = await _service.getGroupedItemsDropdown();
      if (!mounted) return;
      setState(() { _groupedItems = groups; _isLoadingProducts = false; });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoadingProducts = false);
    }
  }

  @override
  void dispose() {
    _qtyCtrl.dispose();
    _unitCtrl.dispose();
    _priceCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  // ── Date pickers ────────────────────────────────────────────────────────

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(primary: Colors.purple),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _pickDueDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDueDate ?? DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(
            primary: Colors.purple,
            onPrimary: Colors.white,
            onSurface: AppColors.textPrimary,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _selectedDueDate = picked);
  }

  // ── Image picker ─────────────────────────────────────────────────────────

  Future<void> _pickBillImage() async {
    try {
      final picker = ImagePicker();
      final source = await showModalBottomSheet<ImageSource>(
        context: context,
        builder: (context) => SafeArea(
          child: Wrap(children: [
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Photo Gallery'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Camera'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
          ]),
        ),
      );
      if (source == null) return;
      final image = await picker.pickImage(source: source, imageQuality: 70);
      if (image != null) {
        final bytes = await image.readAsBytes();
        setState(() => _base64Image = 'data:image/jpeg;base64,${base64Encode(bytes)}');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to pick image: $e')),
        );
      }
    }
  }

  // ── Add new product ───────────────────────────────────────────────────────
  // Note: Add new item is now handled exclusively via the Inventory Manager screen.

  // ── Save ──────────────────────────────────────────────────────────────────

  Future<void> _save() async {
    final item  = _selectedItem?.trim() ?? '';
    final qty   = double.tryParse(_qtyCtrl.text.trim())   ?? 0;
    final price = double.tryParse(_priceCtrl.text.trim()) ?? 0;

    if (item.isEmpty || qty <= 0 || price <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select an item, enter quantity and price')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final purchase = SupplierPurchaseModel(
        supplierId: widget.supplierId,
        item:         item,
        quantity:     qty,
        unit:         _unitCtrl.text.trim(),
        pricePerUnit: price,
        totalAmount:  _computedTotal,
        note:         _noteCtrl.text.trim(),
        date:         _selectedDate,
        category:     item,            // use product name as category fallback
        dueDate:      _selectedDueDate,
        invoiceImage: _base64Image,
      );
      await _service.addPurchase(purchase);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Purchase recorded, Stock updated automatically'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final total = _computedTotal;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Add Purchase',
          style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Colors.purple)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // ── Supplier badge ────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.purple.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.inventory_2_outlined, size: 16, color: Colors.purple),
                const SizedBox(width: 6),
                Text(widget.supplierName,
                  style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.purple)),
              ]),
            ),
            const SizedBox(height: 24),

            // ── Live total ────────────────────────────────────────────────
            if (total > 0)
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.only(bottom: 24),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.purple,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Total Amount',
                      style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white70)),
                    Text('₹${total.toStringAsFixed(2)}',
                      style: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
                  ],
                ),
              ),

            // ── Item / Product dropdown ───────────────────────────────────
            Text('Item / Product',
              style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
            const SizedBox(height: 6),
            _isLoadingProducts
                ? Container(
                    height: 54,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: const Center(
                      child: SizedBox(
                        width: 20, height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.purple),
                      ),
                    ),
                  )
                : DropdownButtonFormField<String>(
                    initialValue: _selectedItem,
                    isExpanded: true,
                    decoration: InputDecoration(
                      hintText: 'Select or add a product',
                      hintStyle: GoogleFonts.inter(fontSize: 14, color: AppColors.textHint),
                      fillColor: Colors.white,
                      filled: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Colors.purple, width: 2),
                      ),
                    ),
                    icon: const Icon(Icons.arrow_drop_down, color: Colors.purple),
                    dropdownColor: Colors.white,
                    items: () {
                      List<DropdownMenuItem<String>> items = [];
                      for (var group in _groupedItems) {
                        items.add(DropdownMenuItem(
                          value: 'HEADER_${group.category}',
                          enabled: false,
                          child: Text(group.category, style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Colors.purple, fontSize: 13)),
                        ));
                        for (var itemName in group.items) {
                          items.add(DropdownMenuItem(
                            value: itemName,
                            child: Padding(
                              padding: const EdgeInsets.only(left: 16.0),
                              child: Text(itemName, style: GoogleFonts.inter(fontSize: 15, color: AppColors.textPrimary)),
                            ),
                          ));
                        }
                      }
                      return items;
                    }(),
                    onChanged: (val) {
                      setState(() => _selectedItem = val);
                    },
                  ),
            const SizedBox(height: 24),

            // ── Qty & Unit ───────────────────────────────────────────────
            Row(children: [
              Expanded(child: _buildField('Quantity', '0', _qtyCtrl, type: TextInputType.number)),
              const SizedBox(width: 16),
              Expanded(child: _buildField('Unit', 'kg, bags…', _unitCtrl)),
            ]),

            _buildField('Price per Unit (₹)', '0.00', _priceCtrl, type: TextInputType.number),
            _buildField('Note (Optional)', 'e.g. first batch', _noteCtrl),

            // ── Due Date ──────────────────────────────────────────────────
            Text('Due Date (Optional)',
              style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
            const SizedBox(height: 6),
            GestureDetector(
              onTap: _pickDueDate,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(children: [
                  const Icon(Icons.calendar_today_outlined, color: Colors.purple, size: 20),
                  const SizedBox(width: 12),
                  Expanded(child: Text(
                    _selectedDueDate != null
                        ? '${_selectedDueDate!.day}/${_selectedDueDate!.month}/${_selectedDueDate!.year}'
                        : 'Select Due Date',
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      color: _selectedDueDate != null ? AppColors.textPrimary : AppColors.textHint,
                    ),
                  )),
                  if (_selectedDueDate != null)
                    GestureDetector(
                      onTap: () => setState(() => _selectedDueDate = null),
                      child: const Icon(Icons.clear, color: Colors.red, size: 18),
                    )
                  else
                    Text('SET', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.purple)),
                ]),
              ),
            ),
            const SizedBox(height: 24),

            // ── Bill image ────────────────────────────────────────────────
            Text('Attach Bill Image (Optional)',
              style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
            const SizedBox(height: 8),
            if (_base64Image == null)
              OutlinedButton.icon(
                onPressed: _pickBillImage,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  side: const BorderSide(color: AppColors.border),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.add_photo_alternate_outlined, color: Colors.purple),
                label: Text('Choose Photo',
                  style: GoogleFonts.inter(color: Colors.purple, fontWeight: FontWeight.bold)),
              )
            else
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Container(
                    height: 180,
                    color: Colors.grey.shade100,
                    child: Stack(fit: StackFit.expand, children: [
                      Image.memory(base64Decode(_base64Image!.split(',')[1]), fit: BoxFit.cover),
                      Positioned(
                        top: 8, right: 8,
                        child: CircleAvatar(
                          backgroundColor: Colors.black54, radius: 16,
                          child: IconButton(
                            icon: const Icon(Icons.close, color: Colors.white, size: 16),
                            onPressed: () => setState(() => _base64Image = null),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ),
                      ),
                    ]),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text('Bill image selected',
                      style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary),
                      textAlign: TextAlign.center),
                  ),
                ]),
              ),
            const SizedBox(height: 24),

            // ── Purchase date ─────────────────────────────────────────────
            GestureDetector(
              onTap: _pickDate,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(children: [
                  const Icon(Icons.calendar_today_outlined, color: Colors.purple, size: 20),
                  const SizedBox(width: 12),
                  Expanded(child: Text(
                    '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
                    style: GoogleFonts.inter(fontSize: 15, color: AppColors.textPrimary),
                  )),
                  Text('CHANGE',
                    style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.purple)),
                ]),
              ),
            ),

            const SizedBox(height: 32),

            // ── Save button ───────────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purple,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
                icon: _isLoading
                    ? const SizedBox(width: 22, height: 22,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.shopping_bag_outlined),
                label: Text(
                  _isLoading ? 'Saving...' : 'Record Purchase',
                  style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildField(String label, String hint, TextEditingController ctrl,
      {TextInputType type = TextInputType.text}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label,
          style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
        const SizedBox(height: 4),
        TextField(
          controller: ctrl,
          keyboardType: type,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.inter(fontSize: 16, color: AppColors.textHint),
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(vertical: 10),
            enabledBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: AppColors.border, width: 1.5)),
            focusedBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: Colors.purple, width: 2)),
          ),
          style: GoogleFonts.inter(fontSize: 16, color: AppColors.textPrimary),
        ),
      ]),
    );
  }
}
