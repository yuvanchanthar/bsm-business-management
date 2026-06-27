import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/app_colors.dart';
import '../models/customer_model.dart';
import '../models/inventory_model.dart';
import '../services/api_service.dart';
import '../services/supplier_service.dart';
import '../services/token_service.dart';
import 'credit_invoice_preview_screen.dart';

class CreditSaleProduct {
  InventoryItemModel? item;
  double quantity;
  double price;
  CreditSaleProduct({this.item, this.quantity = 0, this.price = 0});
  double get total => quantity * price;
}

class CreditSaleScreen extends StatefulWidget {
  const CreditSaleScreen({super.key});
  @override
  State<CreditSaleScreen> createState() => _CreditSaleScreenState();
}

class _CreditSaleScreenState extends State<CreditSaleScreen> {
  static const _green = AppColors.primaryGreen;

  final _apiService = ApiService(TokenService.instance);
  late final SupplierService _supplierService;

  List<CustomerModel> _allCustomers = [];
  List<CustomerModel> _filteredCustomers = [];
  bool _isFetchingCustomers = true;
  bool _showSuggestions = false;

  List<InventoryItemModel> _inventoryItems = [];
  bool _isLoadingInventory = true;
  bool _isSaving = false;

  String? _selectedCustomerName;
  CustomerModel? _selectedCustomer;
  final _customerSearchController = TextEditingController();

  final List<CreditSaleProduct> _products = [CreditSaleProduct()];
  double _paymentReceived = 0;
  final _paymentReceivedCtrl = TextEditingController(text: '0');
  final _notesCtrl = TextEditingController();

  // ── Computed ────────────────────────────────────────────────────────────────
  double get _grandTotal => _products.fold(0, (s, p) => s + p.total);
  double get _currentSalePending => (_grandTotal - _paymentReceived).clamp(0, double.infinity);
  double get _prevBalance => _selectedCustomer?.balance ?? 0;
  double get _newTotalBalance => _prevBalance + _currentSalePending;

  @override
  void initState() {
    super.initState();
    _supplierService = SupplierService(TokenService.instance);
    _fetchCustomers();
    _fetchInventory();
  }

  Future<void> _fetchCustomers() async {
    try {
      final customers = await _apiService.getCustomers();
      if (mounted) {
        setState(() {
          _allCustomers = customers;
          _isFetchingCustomers = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isFetchingCustomers = false);
    }
  }

  Future<void> _fetchInventory() async {
    try {
      final items = await _supplierService.getInventory();
      if (mounted) {
        setState(() {
          _inventoryItems = items;
          _isLoadingInventory = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingInventory = false);
    }
  }

  void _onCustomerSearchChanged(String query) {
    setState(() {
      if (query.isEmpty) {
        _selectedCustomerName = null;
        _selectedCustomer = null;
        _showSuggestions = false;
        _filteredCustomers = [];
      } else {
        if (_selectedCustomerName != null && query != _selectedCustomerName) {
          _selectedCustomerName = null;
          _selectedCustomer = null;
        }
        _showSuggestions = true;
        _filteredCustomers = _allCustomers
            .where((c) => c.name.toLowerCase().contains(query.toLowerCase()) || 
                          c.phone.contains(query))
            .toList();
      }
    });
  }

  @override
  void dispose() {
    _paymentReceivedCtrl.dispose();
    _notesCtrl.dispose();
    _customerSearchController.dispose();
    super.dispose();
  }

  void _addProduct() => setState(() => _products.add(CreditSaleProduct()));
  void _removeProduct(int i) {
    if (_products.length == 1) return;
    setState(() => _products.removeAt(i));
  }

  Future<void> _handleSave() async {
    if (_selectedCustomer == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a valid customer.')));
      return;
    }
    
    // Check if there is an empty product
    if (_products.any((p) => p.item == null || p.quantity <= 0)) {
       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please fill all product details with quantity > 0.')));
       return;
    }

    if (_paymentReceived > _grandTotal) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Payment Received cannot be greater than Grand Total.'),
        backgroundColor: Colors.red,
      ));
      return;
    }

    // Check duplicate products
    final itemIds = _products.map((p) => p.item!.id).toSet();
    if (itemIds.length < _products.length) {
       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Duplicate products are not allowed.'),
        backgroundColor: Colors.red,
      ));
      return;
    }

    // Validate stock
    for (var p in _products) {
      if (p.quantity > p.item!.currentStock) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Insufficient stock for ${p.item!.itemName}. Available: ${p.item!.currentStock}'),
          backgroundColor: Colors.red,
        ));
        return;
      }
    }

    setState(() => _isSaving = true);

    try {
      final payload = {
  'customerId': _selectedCustomer!.id,
  'items': _products.map((p) => {
    'inventoryId': p.item!.id,
    'itemName': p.item!.itemName,
    'quantity': p.quantity,
    'unit': p.item!.unit,
    'price': p.price,
    'total': p.total,
  }).toList(),
  'grandTotal': _grandTotal,
  'paymentReceived': _paymentReceived,
  'notes': _notesCtrl.text.trim(),
};
      

      final response = await _apiService.createCreditSale(payload);

      if (mounted) {
        setState(() => _isSaving = false);
        // Navigate to invoice preview
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => CreditInvoicePreviewScreen(
          invoiceData: response,
        )));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e.toString().replaceAll('Exception: ', '')),
          backgroundColor: Colors.red,
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _green.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.receipt_long, color: _green, size: 20),
          ),
          const SizedBox(width: 10),
          Text('Credit Sale', style: GoogleFonts.inter(
            fontSize: 20, fontWeight: FontWeight.bold, color: _green)),
        ]),
      ),
      body: Stack(
        children: [
          GestureDetector(
            onTap: () => FocusScope.of(context).unfocus(),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 140),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _sectionLabel('Customer'),
                const SizedBox(height: 8),
                _buildCustomerSearch(),
                if (_selectedCustomer != null && !_showSuggestions) ...[
                  const SizedBox(height: 12),
                  _CustomerSummaryCard(customer: _selectedCustomer!),
                ] else if (_selectedCustomer == null && !_showSuggestions) ...[
                  const SizedBox(height: 12),
                  _EmptyStateHint(icon: Icons.person_search, text: 'Search & select a customer to begin'),
                ],
                const SizedBox(height: 24),
                _sectionLabel('Products'),
                const SizedBox(height: 8),
                if (_isLoadingInventory)
                   Center(child: Padding(
                     padding: const EdgeInsets.all(20.0),
                     child: CircularProgressIndicator(color: AppColors.primaryGreen),
                   ))
                else
                  ..._products.asMap().entries.map((e) => _ProductRow(
                    index: e.key,
                    product: e.value,
                    inventoryItems: _inventoryItems,
                    canRemove: _products.length > 1,
                    onRemove: () => _removeProduct(e.key),
                    onChanged: () => setState(() {}),
                  )),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _isLoadingInventory ? null : _addProduct,
                  icon: const Icon(Icons.add, size: 18),
                  label: Text('Add Another Product', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _green,
                    side: const BorderSide(color: _green),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  ),
                ),
                const SizedBox(height: 24),
                _sectionLabel('Sale Summary'),
                const SizedBox(height: 8),
                _SaleSummaryCard(
                  grandTotal: _grandTotal,
                  paymentReceived: _paymentReceived,
                  currentSalePending: _currentSalePending,
                  prevBalance: _prevBalance,
                  newTotalBalance: _newTotalBalance,
                  paymentReceivedCtrl: _paymentReceivedCtrl,
                  onPaymentChanged: (v) => setState(() => _paymentReceived = double.tryParse(v) ?? 0),
                ),
                const SizedBox(height: 16),
                _sectionLabel('Notes (Optional)'),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white, borderRadius: BorderRadius.circular(12),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
                  ),
                  child: TextField(
                    controller: _notesCtrl,
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: 'e.g. Delivered at farm, partial payment expected by Friday',
                      hintStyle: GoogleFonts.inter(color: AppColors.textHint, fontSize: 13),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.all(14),
                    ),
                    style: GoogleFonts.inter(fontSize: 14, color: AppColors.textPrimary),
                  ),
                ),
              ]),
            ),
          ),
          if (_isSaving)
            Container(
              color: Colors.black.withValues(alpha: 0.3),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(color: AppColors.primaryGreen),
                      const SizedBox(height: 16),
                      Text('Saving Sale...', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: _BottomActions(
        onSave: _isSaving ? null : _handleSave,
      ),
    );
  }

  Widget _buildCustomerSearch() {
    return Column(
      children: [
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
            border: Border.all(color: _selectedCustomer != null ? AppColors.primaryGreen.withValues(alpha: 0.4) : AppColors.border),
          ),
          child: TextField(
            controller: _customerSearchController,
            decoration: InputDecoration(
              hintText: _isFetchingCustomers ? 'Loading customers...' : 'Search customer by name or phone...',
              hintStyle: GoogleFonts.inter(color: AppColors.textSecondary),
              prefixIcon: const Icon(Icons.search, color: AppColors.primaryGreen),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            ),
            onChanged: _onCustomerSearchChanged,
          ),
        ),
        if (_showSuggestions)
          Container(
            margin: const EdgeInsets.only(top: 8),
            constraints: const BoxConstraints(maxHeight: 200),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 5,
                  offset: const Offset(0, 2),
                ),
              ]
            ),
            child: _filteredCustomers.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text('No customers found', style: GoogleFonts.inter(color: Colors.grey[600])),
                )
              : ListView.builder(
                  shrinkWrap: true,
                  padding: EdgeInsets.zero,
                  itemCount: _filteredCustomers.length,
                  itemBuilder: (context, index) {
                    final customer = _filteredCustomers[index];
                    return ListTile(
                      title: Text(customer.name, style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                      subtitle: Text(customer.phone, style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary)),
                      onTap: () {
                        setState(() {
                          _selectedCustomerName = customer.name;
                          _selectedCustomer = customer;
                          _customerSearchController.text = customer.name;
                          _showSuggestions = false;
                          FocusScope.of(context).unfocus();
                        });
                      },
                    );
                  },
                ),
          ),
      ],
    );
  }

  Widget _sectionLabel(String label) => Text(label,
    style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold,
        color: AppColors.textSecondary, letterSpacing: 0.5));
}

// ── Customer Summary Card ─────────────────────────────────────────────────────

class _CustomerSummaryCard extends StatelessWidget {
  final CustomerModel customer;
  const _CustomerSummaryCard({required this.customer});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.primaryGreen.withValues(alpha: 0.3)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(children: [
        Row(children: [
          CircleAvatar(radius: 20, backgroundColor: AppColors.primaryGreen.withValues(alpha: 0.12),
            child: Text(customer.name.isNotEmpty ? customer.name[0].toUpperCase() : '?', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.primaryGreen))),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(customer.name, style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
            Text(customer.phone, style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary)),
          ])),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: customer.balance > 0 ? Colors.red.withValues(alpha: 0.08) : Colors.green.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              customer.balance > 0 ? 'OUTSTANDING' : 'CLEARED',
              style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.bold,
                color: customer.balance > 0 ? Colors.red : Colors.green),
            ),
          ),
        ]),
        const SizedBox(height: 14),
        const Divider(height: 1),
        const SizedBox(height: 14),
        Row(children: [
          _StatCol('Current Balance', '₹${customer.balance.toStringAsFixed(0)}', customer.balance > 0 ? Colors.red : Colors.green),
        ]),
      ]),
    );
  }
}

class _StatCol extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _StatCol(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) {
    return Expanded(child: Column(children: [
      Text(label, style: GoogleFonts.inter(fontSize: 9, color: AppColors.textSecondary, fontWeight: FontWeight.w600), textAlign: TextAlign.center),
      const SizedBox(height: 3),
      Text(value, style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold, color: color), textAlign: TextAlign.center),
    ]));
  }
}

// ── Product Row ───────────────────────────────────────────────────────────────

class _ProductRow extends StatefulWidget {
  final int index;
  final CreditSaleProduct product;
  final List<InventoryItemModel> inventoryItems;
  final bool canRemove;
  final VoidCallback onRemove;
  final VoidCallback onChanged;
  
  const _ProductRow({
    required this.index, 
    required this.product, 
    required this.inventoryItems, 
    required this.canRemove, 
    required this.onRemove, 
    required this.onChanged
  });
  
  @override
  State<_ProductRow> createState() => _ProductRowState();
}

class _ProductRowState extends State<_ProductRow> {
  late TextEditingController _qtyCtrl;
  late TextEditingController _priceCtrl;

  @override
  void initState() {
    super.initState();
    _qtyCtrl = TextEditingController(text: widget.product.quantity > 0 ? widget.product.quantity.toStringAsFixed(0) : '');
    _priceCtrl = TextEditingController(text: widget.product.price > 0 ? widget.product.price.toStringAsFixed(0) : '');
  }

  @override
  void dispose() {
    _qtyCtrl.dispose();
    _priceCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.product;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 28, height: 28,
            decoration: BoxDecoration(color: AppColors.primaryGreen.withValues(alpha: 0.1), shape: BoxShape.circle),
            alignment: Alignment.center,
            child: Text('${widget.index + 1}', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primaryGreen)),
          ),
          const SizedBox(width: 8),
          Text('Product ${widget.index + 1}', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
          const Spacer(),
          if (widget.canRemove)
            GestureDetector(
              onTap: widget.onRemove,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(color: Colors.red.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(6)),
                child: const Icon(Icons.close, size: 16, color: Colors.red),
              ),
            ),
        ]),
        const SizedBox(height: 12),
        DropdownButtonFormField<InventoryItemModel>(
          value: widget.inventoryItems.contains(p.item) ? p.item : null,
          isExpanded: true,
          decoration: InputDecoration(
            labelText: 'Inventory Item',
            prefixIcon: const Icon(Icons.inventory_2_outlined, size: 18),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            isDense: true,
          ),
          hint: Text('Select item', style: GoogleFonts.inter(fontSize: 13)),
          items: widget.inventoryItems.map((item) => DropdownMenuItem(
            value: item,
            child: Row(children: [
              Expanded(child: Text(item.itemName, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600))),
              Text('${item.currentStock.toStringAsFixed(0)} ${item.unit}',
                style: GoogleFonts.inter(fontSize: 11, color: item.currentStock < 10 ? Colors.red : AppColors.textSecondary)),
            ]),
          )).toList(),
          onChanged: (v) => setState(() {
            p.item = v;
            if (v != null) {
              // Note: the prompt didn't specify where default price comes from in real inventory,
              // as InventoryItemModel doesn't have defaultPrice. Let's leave price as is or reset to 0.
              // Wait, I will just not touch price or keep it 0 and let user type it.
            }
            widget.onChanged();
          }),
        ),
        if (p.item != null) ...[
          const SizedBox(height: 6),
          Row(children: [
            const Icon(Icons.inventory_2_outlined, size: 12, color: AppColors.textSecondary),
            const SizedBox(width: 4),
            Text('Available: ${p.item!.currentStock.toStringAsFixed(0)} ${p.item!.unit}',
              style: GoogleFonts.inter(fontSize: 11, color: p.item!.currentStock < 10 ? Colors.red : AppColors.textSecondary)),
          ]),
        ],
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: TextFormField(
            controller: _qtyCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'Quantity',
              suffixText: p.item?.unit ?? '',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
            onChanged: (v) { p.quantity = double.tryParse(v) ?? 0; widget.onChanged(); },
          )),
          const SizedBox(width: 10),
          Expanded(child: TextFormField(
            controller: _priceCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'Price / Unit',
              prefixText: '₹',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
            onChanged: (v) { p.price = double.tryParse(v) ?? 0; widget.onChanged(); },
          )),
        ]),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.primaryGreen.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('Total', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
            Text('₹${p.total.toStringAsFixed(2)}',
              style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.primaryGreen)),
          ]),
        ),
      ]),
    );
  }
}

// ── Sale Summary Card ─────────────────────────────────────────────────────────

class _SaleSummaryCard extends StatelessWidget {
  final double grandTotal, paymentReceived, currentSalePending, prevBalance, newTotalBalance;
  final TextEditingController paymentReceivedCtrl;
  final ValueChanged<String> onPaymentChanged;
  
  const _SaleSummaryCard({
    required this.grandTotal, 
    required this.paymentReceived, 
    required this.currentSalePending,
    required this.prevBalance, 
    required this.newTotalBalance,
    required this.paymentReceivedCtrl, 
    required this.onPaymentChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(children: [
        _Row('Grand Total', '₹${grandTotal.toStringAsFixed(2)}', AppColors.textPrimary),
        const SizedBox(height: 10),
        Row(children: [
          Text('Payment Received', style: GoogleFonts.inter(fontSize: 14, color: AppColors.textSecondary)),
          const Spacer(),
          SizedBox(width: 120, child: TextFormField(
            controller: paymentReceivedCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            textAlign: TextAlign.end,
            decoration: InputDecoration(
              prefixText: '₹',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            ),
            style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.blue),
            onChanged: onPaymentChanged,
          )),
        ]),
        const Padding(padding: EdgeInsets.symmetric(vertical: 10), child: Divider()),
        _Row('Current Sale Pending', '₹${currentSalePending.toStringAsFixed(2)}', AppColors.primaryGreen, bold: true, large: true),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: prevBalance > 0 ? Colors.red.withValues(alpha: 0.05) : AppColors.primaryGreen.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: prevBalance > 0 ? Colors.red.withValues(alpha: 0.2) : AppColors.primaryGreen.withValues(alpha: 0.2)),
          ),
          child: Column(children: [
            _Row('Previous Balance', '₹${prevBalance.toStringAsFixed(0)}', prevBalance > 0 ? Colors.red : AppColors.textSecondary),
            const SizedBox(height: 6),
            _Row('Current Sale Pending', '₹${currentSalePending.toStringAsFixed(0)}', AppColors.primaryGreen),
            const SizedBox(height: 8),
            const Divider(height: 1),
            const SizedBox(height: 8),
            _Row('Current Balance', '₹${newTotalBalance.toStringAsFixed(0)}',
              newTotalBalance > 0 ? Colors.red : AppColors.primaryGreen, bold: true, large: true),
          ]),
        ),
      ]),
    );
  }
}

class _Row extends StatelessWidget {
  final String label, value;
  final Color color;
  final bool bold, large;
  const _Row(this.label, this.value, this.color, {this.bold = false, this.large = false});

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(label, style: GoogleFonts.inter(fontSize: large ? 14 : 13, color: AppColors.textSecondary, fontWeight: bold ? FontWeight.w600 : FontWeight.normal)),
      Text(value, style: GoogleFonts.inter(fontSize: large ? 16 : 14, fontWeight: bold ? FontWeight.bold : FontWeight.w600, color: color)),
    ]);
  }
}

// ── Empty State Hint ──────────────────────────────────────────────────────────

class _EmptyStateHint extends StatelessWidget {
  final IconData icon;
  final String text;
  const _EmptyStateHint({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 20),
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border, style: BorderStyle.solid),
      ),
      child: Column(children: [
        Icon(icon, size: 36, color: AppColors.textHint),
        const SizedBox(height: 8),
        Text(text, style: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary)),
      ]),
    );
  }
}

// ── Bottom Action Bar ─────────────────────────────────────────────────────────

class _BottomActions extends StatelessWidget {
  final VoidCallback? onSave;
  const _BottomActions({required this.onSave});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(16, 12, 16, MediaQuery.of(context).padding.bottom + 12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 12, offset: const Offset(0, -4))],
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        SizedBox(width: double.infinity, child: ElevatedButton.icon(
          onPressed: onSave,
          icon: const Icon(Icons.save_outlined, size: 18),
          label: Text('Save Credit Sale', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 15)),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primaryGreen, foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            elevation: 0,
            disabledBackgroundColor: Colors.grey.withValues(alpha: 0.5),
          ),
        )),
      ]),
    );
  }
}
