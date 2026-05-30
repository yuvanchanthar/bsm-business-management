import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/app_colors.dart';
import '../models/supplier_model.dart';
import '../models/inventory_model.dart';
import '../services/supplier_service.dart';
import '../services/token_service.dart';

class EditSupplierPurchaseScreen extends StatefulWidget {
  final SupplierPurchaseModel purchase;
  final String supplierId;

  const EditSupplierPurchaseScreen({
    super.key,
    required this.purchase,
    required this.supplierId,
  });

  @override
  State<EditSupplierPurchaseScreen> createState() =>
      _EditSupplierPurchaseScreenState();
}

class _EditSupplierPurchaseScreenState
    extends State<EditSupplierPurchaseScreen> {
  final _qtyCtrl   = TextEditingController();
  final _unitCtrl  = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _noteCtrl  = TextEditingController();

  late DateTime  _selectedDate;
  DateTime?      _selectedDueDate;
  bool           _isLoading      = false;

  List<InventoryItemModel> _inventoryItems = [];
  bool    _isLoadingItems = false;
  String? _selectedItem;
  String? _selectedCategory;

  late SupplierService _service;
  bool _serviceReady = false;

  double get _computedTotal {
    final qty   = double.tryParse(_qtyCtrl.text)   ?? 0;
    final price = double.tryParse(_priceCtrl.text) ?? 0;
    return qty * price;
  }

  bool _fetchingPurchaseDetails = false;

  @override
  void initState() {
    super.initState();
    // Pre-fill from existing purchase as initial fallback
    _selectedItem     = widget.purchase.item;
    _selectedCategory = widget.purchase.category;
    _selectedDate     = widget.purchase.date;
    _selectedDueDate  = widget.purchase.dueDate;
    _qtyCtrl.text     = widget.purchase.quantity > 0 ? widget.purchase.quantity.toString() : '';
    _unitCtrl.text    = widget.purchase.unit;
    _priceCtrl.text   = widget.purchase.pricePerUnit > 0 ? widget.purchase.pricePerUnit.toString() : '';
    _noteCtrl.text    = widget.purchase.note;

    _qtyCtrl.addListener(() => setState(() {}));
    _priceCtrl.addListener(() => setState(() {}));
    _init();
  }

  Future<void> _init() async {
    final ts = await TokenService.getInstance();
    _service = SupplierService(ts);
    if (mounted) setState(() => _serviceReady = true);
    _fetchPurchaseDetails();
    _fetchInventory();
  }

  Future<void> _fetchPurchaseDetails() async {
    if (widget.purchase.id == null) return;
    if (mounted) setState(() => _fetchingPurchaseDetails = true);
    try {
      final purchases = await _service.getSupplierPurchasesRaw(widget.supplierId);
      final raw = purchases.firstWhere((p) => p.id == widget.purchase.id);
      
      if (mounted) {
        setState(() {
          _selectedItem = raw.item;
          _selectedCategory = raw.category;
          _selectedDate = raw.date;
          _selectedDueDate = raw.dueDate;
          
          // Map backend fields correctly to the controllers, convert double to String safely
          _qtyCtrl.text = raw.quantity > 0 ? raw.quantity.toString() : '';
          _unitCtrl.text = raw.unit;
          _priceCtrl.text = raw.pricePerUnit > 0 ? raw.pricePerUnit.toString() : '';
          _noteCtrl.text = raw.note;
          
          _fetchingPurchaseDetails = false;
        });
      }
    } catch (e) {
      print('[EditSupplierPurchaseScreen] Error fetching raw purchase details: $e');
      if (mounted) {
        setState(() => _fetchingPurchaseDetails = false);
      }
    }
  }

  Future<void> _fetchInventory() async {
    if (!mounted) return;
    setState(() => _isLoadingItems = true);
    try {
      final items = await _service.getInventory();
      if (!mounted) return;
      setState(() { _inventoryItems = items; _isLoadingItems = false; });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoadingItems = false);
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

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx)
            .copyWith(colorScheme: const ColorScheme.light(primary: Colors.purple)),
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
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx)
            .copyWith(colorScheme: const ColorScheme.light(primary: Colors.purple)),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _selectedDueDate = picked);
  }

  Future<void> _save() async {
    final item  = _selectedItem?.trim() ?? '';
    final qty   = double.tryParse(_qtyCtrl.text.trim())   ?? 0;
    final price = double.tryParse(_priceCtrl.text.trim()) ?? 0;

    if (item.isEmpty || qty <= 0 || price <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Item, quantity and price are required'),
            backgroundColor: Colors.orange),
      );
      return;
    }
    if (widget.purchase.id == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot edit: missing purchase ID')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final fmt = (DateTime d) =>
          '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

      final data = <String, dynamic>{
        'itemName':     item,
        'quantity':     qty,
        'unit':         _unitCtrl.text.trim(),
        'pricePerUnit': price,
        'totalAmount':  _computedTotal,
        'note':         _noteCtrl.text.trim(),
        'category':     _selectedCategory ?? 'Others',
        'date':         fmt(_selectedDate),
        if (_selectedDueDate != null) 'dueDate': fmt(_selectedDueDate!),
      };

      await _service.updatePurchase(widget.purchase.id!, data);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Purchase updated successfully'),
              backgroundColor: Colors.green),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  'Failed: ${e.toString().replaceAll('Exception: ', '')}'),
              backgroundColor: Colors.red),
        );
      }
    }
  }

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
        title: Text('Edit Purchase',
            style: GoogleFonts.inter(
                fontWeight: FontWeight.bold, color: Colors.purple)),
      ),
      body: _fetchingPurchaseDetails
          ? const Center(
              child: CircularProgressIndicator(color: Colors.purple),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Live total
            if (total > 0)
              Container(
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
                        style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.white70)),
                    Text('₹${total.toStringAsFixed(2)}',
                        style: GoogleFonts.inter(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white)),
                  ],
                ),
              ),

            // Item searchable field
            Text('Item / Product',
                style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary)),
            const SizedBox(height: 6),
            _buildItemSearchField(),
            if (_selectedItem != null) ...[
              const SizedBox(height: 8),
              Row(children: [
                if (_selectedCategory != null && _selectedCategory!.isNotEmpty)
                  _InfoChip(
                      icon: Icons.category_outlined,
                      label: _selectedCategory!,
                      color: Colors.purple),
                const SizedBox(width: 8),
                if (_unitCtrl.text.isNotEmpty)
                  _InfoChip(
                      icon: Icons.straighten_outlined,
                      label: _unitCtrl.text,
                      color: Colors.blueGrey),
              ]),
            ],
            const SizedBox(height: 24),

            // Qty & Unit
            Row(children: [
              Expanded(
                  child: _buildField('Quantity', '0', _qtyCtrl,
                      type: TextInputType.number)),
              const SizedBox(width: 16),
              Expanded(child: _buildField('Unit', 'kg, bags…', _unitCtrl)),
            ]),
            _buildField('Price per Unit (₹)', '0.00', _priceCtrl,
                type: TextInputType.number),
            _buildField('Note (Optional)', 'e.g. second batch', _noteCtrl),

            // Due Date
            Text('Due Date (Optional)',
                style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary)),
            const SizedBox(height: 6),
            GestureDetector(
              onTap: _pickDueDate,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(children: [
                  const Icon(Icons.calendar_today_outlined,
                      color: Colors.purple, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _selectedDueDate != null
                          ? '${_selectedDueDate!.day}/${_selectedDueDate!.month}/${_selectedDueDate!.year}'
                          : 'Select Due Date',
                      style: GoogleFonts.inter(
                          fontSize: 15,
                          color: _selectedDueDate != null
                              ? AppColors.textPrimary
                              : AppColors.textHint),
                    ),
                  ),
                  if (_selectedDueDate != null)
                    GestureDetector(
                      onTap: () => setState(() => _selectedDueDate = null),
                      child: const Icon(Icons.clear,
                          color: Colors.red, size: 18),
                    )
                  else
                    Text('SET',
                        style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.purple)),
                ]),
              ),
            ),
            const SizedBox(height: 24),

            // Purchase date
            Text('Purchase Date',
                style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary)),
            const SizedBox(height: 6),
            GestureDetector(
              onTap: _pickDate,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(children: [
                  const Icon(Icons.calendar_today_outlined,
                      color: Colors.purple, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
                      style: GoogleFonts.inter(
                          fontSize: 15, color: AppColors.textPrimary),
                    ),
                  ),
                  Text('CHANGE',
                      style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.purple)),
                ]),
              ),
            ),
            const SizedBox(height: 32),

            // Save button
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton.icon(
                onPressed: (_isLoading || !_serviceReady) ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purple,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
                icon: _isLoading
                    ? const SizedBox(
                        width: 22, height: 22,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.save_outlined),
                label: Text(
                  _isLoading ? 'Saving...' : 'Update Purchase',
                  style: GoogleFonts.inter(
                      fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildItemSearchField() {
    if (_isLoadingItems) {
      return Container(
        height: 54,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: const Center(
          child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: Colors.purple)),
        ),
      );
    }

    return Autocomplete<InventoryItemModel>(
      initialValue: TextEditingValue(text: _selectedItem ?? ''),
      optionsBuilder: (TextEditingValue textEditingValue) {
        final q = textEditingValue.text.toLowerCase().trim();
        if (q.isEmpty) return _inventoryItems;
        return _inventoryItems
            .where((item) => item.itemName.toLowerCase().contains(q));
      },
      displayStringForOption: (item) => item.itemName,
      onSelected: (InventoryItemModel selected) {
        setState(() {
          _selectedItem     = selected.itemName;
          _selectedCategory = selected.category ?? 'Others';
          _unitCtrl.text    = selected.unit;
        });
      },
      fieldViewBuilder:
          (context, fieldController, focusNode, onFieldSubmitted) {
        return TextField(
          controller: fieldController,
          focusNode: focusNode,
          onChanged: (_) {
            setState(() {
              _selectedItem     = null;
              _selectedCategory = null;
            });
          },
          decoration: InputDecoration(
            hintText: 'Search item…',
            hintStyle:
                GoogleFonts.inter(fontSize: 14, color: AppColors.textHint),
            prefixIcon:
                const Icon(Icons.search, color: Colors.purple, size: 20),
            suffixIcon: _selectedItem != null
                ? const Icon(Icons.check_circle,
                    color: Colors.green, size: 20)
                : null,
            fillColor: Colors.white,
            filled: true,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
                  const BorderSide(color: Colors.purple, width: 2),
            ),
          ),
          style: GoogleFonts.inter(
              fontSize: 15, color: AppColors.textPrimary),
        );
      },
      optionsViewBuilder: (context, onSelected, options) {
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 6,
            borderRadius: BorderRadius.circular(12),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 200),
              child: ListView.builder(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: options.length,
                itemBuilder: (context, index) {
                  final item = options.elementAt(index);
                  return InkWell(
                    onTap: () => onSelected(item),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      child: Row(children: [
                        Expanded(
                          child: Text(item.itemName,
                              style: GoogleFonts.inter(
                                  fontSize: 15,
                                  color: AppColors.textPrimary)),
                        ),
                        if (item.category != null)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.purple.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(item.category!,
                                style: GoogleFonts.inter(
                                    fontSize: 10,
                                    color: Colors.purple,
                                    fontWeight: FontWeight.bold)),
                          ),
                      ]),
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildField(String label, String hint, TextEditingController ctrl,
      {TextInputType type = TextInputType.text}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label,
            style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary)),
        const SizedBox(height: 4),
        TextField(
          controller: ctrl,
          keyboardType: type,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle:
                GoogleFonts.inter(fontSize: 16, color: AppColors.textHint),
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(vertical: 10),
            enabledBorder: const UnderlineInputBorder(
                borderSide: BorderSide(color: AppColors.border, width: 1.5)),
            focusedBorder: const UnderlineInputBorder(
                borderSide: BorderSide(color: Colors.purple, width: 2)),
          ),
          style: GoogleFonts.inter(
              fontSize: 16, color: AppColors.textPrimary),
        ),
      ]),
    );
  }
}

// ── Info chip ─────────────────────────────────────────────────────────────────

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _InfoChip(
      {required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 4),
        Text(label,
            style: GoogleFonts.inter(
                fontSize: 11, fontWeight: FontWeight.bold, color: color)),
      ]),
    );
  }
}
