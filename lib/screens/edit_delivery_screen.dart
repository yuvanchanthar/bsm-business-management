import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../core/app_colors.dart';
import '../widgets/primary_button.dart';
import '../models/delivery.dart';
import '../models/invoice_model.dart';
import '../models/category_model.dart';
import '../services/api_service.dart';
import '../services/token_service.dart';
import '../services/pdf_service.dart';
import 'package:printing/printing.dart';
import '../services/supplier_service.dart';
import 'add_delivery_screen.dart'; // ProductItemEntry

// Sentinel value used as the dropdown key for the "+ Add New Item" row.
const _kAddNew = '__ADD_NEW__';

class EditDeliveryScreen extends StatefulWidget {
  final Delivery delivery;
  const EditDeliveryScreen({super.key, required this.delivery});

  @override
  State<EditDeliveryScreen> createState() => _EditDeliveryScreenState();
}

class _EditDeliveryScreenState extends State<EditDeliveryScreen> {
  final _formKey = GlobalKey<FormState>();
  final _apiService = ApiService(TokenService.instance);
  final _pdfService = PdfService();

  String? _selectedCustomer;
  final _crewLeaderController = TextEditingController();
  final _gstController = TextEditingController();
  final _companyController = TextEditingController();
  final _addressController = TextEditingController();
  String _selectedPriority = 'NORMAL';
  bool _isLoading = false;

  final List<ProductItemEntry> _productEntries = [];
  final List<Map<String, TextEditingController>> _customFieldsControllers = [];

  List<String> _customers = [];
  bool _isLoadingCustomers = false;
  String? _customerLoadError;

  // Dynamic product list from backend
  List<GroupedItemModel> _groupedItems = [];
  bool _isLoadingProducts = false;
  String? _productLoadError;

  @override
  void initState() {
    super.initState();
    _selectedCustomer = widget.delivery.customerName;
    if ((_selectedCustomer ?? '').isNotEmpty) {
      _customers = [_selectedCustomer!];
    }
    _crewLeaderController.text = widget.delivery.crewLeader;
    _gstController.text = widget.delivery.invoice?.gstNumber ?? '';
    _companyController.text = widget.delivery.invoice?.companyName ?? '';
    _addressController.text = widget.delivery.invoice?.address ?? '';
    _selectedPriority = widget.delivery.priority;

    _fetchCustomers();
    _fetchProducts();

    for (var item in widget.delivery.products) {
      final entry = ProductItemEntry();
      entry.productName = item.name;
      entry.quantity = item.quantity;
      entry.pricingType = item.pricingType;
      entry.pricePerUnit = item.pricePerUnit;
      _productEntries.add(entry);
    }
    if (_productEntries.isEmpty) _productEntries.add(ProductItemEntry());

    final existingFields = widget.delivery.invoice?.customFields ?? [];
    for (var field in existingFields) {
      _customFieldsControllers.add({
        'label': TextEditingController(text: field['label']?.toString() ?? ''),
        'value': TextEditingController(text: field['value']?.toString() ?? ''),
      });
    }
  }

  Future<void> _fetchCustomers() async {
    if (!mounted) return;
    setState(() { _isLoadingCustomers = true; _customerLoadError = null; });
    try {
      final customers = await _apiService.getCustomers();
      final names = customers.map((c) => c.name.trim()).where((n) => n.isNotEmpty).toList();
      final set = <String>{
        ...names,
        if ((_selectedCustomer ?? '').trim().isNotEmpty) _selectedCustomer!.trim(),
      };
      if (!mounted) return;
      setState(() { _customers = set.toList()..sort(); _isLoadingCustomers = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _customerLoadError = e.toString(); _isLoadingCustomers = false; });
    }
  }

  Future<void> _fetchProducts() async {
    if (!mounted) return;
    setState(() { _isLoadingProducts = true; _productLoadError = null; });
    try {
      final ts = await TokenService.getInstance();
      final supplierService = SupplierService(ts);
      final groups = await supplierService.getGroupedItemsDropdown();

      if (!mounted) return;
      setState(() { _groupedItems = groups; _isLoadingProducts = false; });
    } catch (e) {
      if (!mounted) return;
      // Fallback: keep existing delivery item names in a dummy group so UI doesn't break
      final fallbackNames = widget.delivery.products
          .map((p) => p.name.trim())
          .where((n) => n.isNotEmpty)
          .toSet()
          .toList()..sort();
          
      setState(() {
        _groupedItems = [GroupedItemModel(category: 'Existing Items', items: fallbackNames)];
        _productLoadError = e.toString();
        _isLoadingProducts = false;
      });
    }
  }

  @override
  void dispose() {
    _crewLeaderController.dispose();
    _gstController.dispose();
    _companyController.dispose();
    _addressController.dispose();
    for (final entry in _productEntries) { entry.dispose(); }
    for (var field in _customFieldsControllers) {
      field['label']?.dispose();
      field['value']?.dispose();
    }
    super.dispose();
  }

  double get _calculateGrandTotal =>
      _productEntries.fold(0.0, (sum, item) => sum + item.subtotal);

  // Add New Item functionality is now completely handled in Inventory manager.

  Future<void> _handleUpdateDelivery() async {
    if (!_formKey.currentState!.validate() || _selectedCustomer == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all required fields')),
      );
      return;
    }
    setState(() => _isLoading = true);
    try {
      final items = _productEntries.map((entry) => ProductItem(
        name: entry.productName ?? 'Unknown',
        quantity: entry.quantity,
        unit: entry.unit,
        pricingType: entry.pricingType,
        pricePerUnit: entry.pricePerUnit,
      )).toList();

      final updatedDelivery = Delivery(
        id: widget.delivery.id,
        customerName: _selectedCustomer!,
        products: items,
        crewLeader: _crewLeaderController.text,
        priority: _selectedPriority,
        status: widget.delivery.status,
        timestamp: widget.delivery.timestamp,
        invoice: DeliveryInvoice(
          id: widget.delivery.invoice?.id ?? '',
          amount: _calculateGrandTotal,
          pdfUrl: widget.delivery.invoice?.pdfUrl,
          gstNumber: _gstController.text.trim().isEmpty ? null : _gstController.text.trim(),
          companyName: _companyController.text.trim().isEmpty ? null : _companyController.text.trim(),
          address: _addressController.text.trim().isEmpty ? null : _addressController.text.trim(),
          customFields: _customFieldsControllers.map((f) => {
            'label': f['label']?.text.trim() ?? '',
            'value': f['value']?.text.trim() ?? '',
          }).where((f) => f['label']!.isNotEmpty && f['value']!.isNotEmpty).toList(),
        ),
      );

      final success = await _apiService.updateDelivery(widget.delivery.id, updatedDelivery);
      if (success && mounted) {
        if (widget.delivery.customerId != null) {
          await _apiService.syncCustomerBalance(widget.delivery.customerId!);
        }
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Delivery updated! Preparing updated invoice...')),
        );
        try {
          final invoice = InvoiceModel.fromDelivery(updatedDelivery, 'updated');
          final pdfBytes = await _pdfService.generateInvoice(invoice);
          final dir = await getTemporaryDirectory();
          final file = File('${dir.path}/Updated_Invoice_${widget.delivery.id}.pdf');
          await file.writeAsBytes(pdfBytes, flush: true);
          if (mounted) {
            await Share.shareXFiles(
              [XFile(file.path, mimeType: 'application/pdf')],
              subject: 'Updated Invoice — ${updatedDelivery.customerName}',
              text: 'Please find the updated invoice for delivery ${widget.delivery.id}.',
            );
          }
        } catch (_) {
          try {
            final invoice = InvoiceModel.fromDelivery(updatedDelivery, 'updated');
            await Printing.layoutPdf(
              onLayout: (format) async => _pdfService.generateInvoice(invoice),
              name: 'Updated_Invoice_${widget.delivery.id}.pdf',
            );
          } catch (_) {}
        }
        if (mounted) Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
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
        title: Text('Edit Invoice',
          style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: AppColors.primaryGreen)),
      ),
      body: Stack(
        children: [
          Form(
            key: _formKey,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Edit Invoice',
                    style: GoogleFonts.inter(fontSize: 32, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text('Modify delivery details and pricing.',
                    style: GoogleFonts.inter(fontSize: 14, color: AppColors.textSecondary)),
                  const SizedBox(height: 32),

                  _buildSectionHeader('RECIPIENT DETAILS'),
                  _buildCard(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      DropdownButtonFormField<String>(
                        initialValue: _selectedCustomer,
                        decoration: _inputDecoration('Select customer', Icons.person_outline),
                        items: _customers.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                        onChanged: (v) => setState(() => _selectedCustomer = v),
                        validator: (v) => v == null ? 'Required' : null,
                      ),
                      if (_isLoadingCustomers || _customerLoadError != null) ...[
                        const SizedBox(height: 10),
                        Row(children: [
                          if (_isLoadingCustomers)
                            const SizedBox(width: 14, height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primaryGreen))
                          else
                            const Icon(Icons.info_outline, size: 16, color: Colors.orange),
                          const SizedBox(width: 8),
                          Expanded(child: Text(
                            _isLoadingCustomers ? 'Loading customers...' : 'Could not refresh customers.',
                            style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary),
                          )),
                        ]),
                      ],
                      const SizedBox(height: 16),
                      const Divider(),
                      const SizedBox(height: 16),
                      Text('Optional Invoice Fields',
                        style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                      const SizedBox(height: 12),
                      TextFormField(controller: _companyController,
                        decoration: _inputDecoration('Company Name', Icons.business_outlined)),
                      const SizedBox(height: 12),
                      TextFormField(controller: _gstController,
                        decoration: _inputDecoration('GST Number', Icons.receipt_long_outlined)),
                      const SizedBox(height: 12),
                      TextFormField(controller: _addressController,
                        decoration: _inputDecoration('Address', Icons.location_on_outlined), maxLines: 2),
                      const SizedBox(height: 16),
                      const Divider(),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Custom Invoice Fields',
                            style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                          TextButton.icon(
                            onPressed: () => setState(() => _customFieldsControllers.add({
                              'label': TextEditingController(),
                              'value': TextEditingController(),
                            })),
                            icon: const Icon(Icons.add, size: 16),
                            label: const Text('Add Field'),
                            style: TextButton.styleFrom(
                              foregroundColor: AppColors.primaryGreen,
                              textStyle: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold),
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                          ),
                        ],
                      ),
                      if (_customFieldsControllers.isNotEmpty) const SizedBox(height: 12),
                      ..._customFieldsControllers.asMap().entries.map((entry) {
                        final index = entry.key;
                        final controllers = entry.value;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Row(children: [
                            Expanded(child: TextFormField(
                              controller: controllers['label'],
                              decoration: _inputDecoration('Label', Icons.label_outline),
                            )),
                            const SizedBox(width: 8),
                            Expanded(child: TextFormField(
                              controller: controllers['value'],
                              decoration: _inputDecoration('Value', Icons.edit_note),
                            )),
                            IconButton(
                              icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
                              onPressed: () => setState(() {
                                controllers['label']?.dispose();
                                controllers['value']?.dispose();
                                _customFieldsControllers.removeAt(index);
                              }),
                            ),
                          ]),
                        );
                      }),
                    ],
                  )),
                  const SizedBox(height: 24),

                  _buildSectionHeader('INVENTORY & PRICING'),

                  // Products loading indicator
                  if (_isLoadingProducts)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(children: [
                        const SizedBox(width: 16, height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primaryGreen)),
                        const SizedBox(width: 10),
                        Text('Loading products...', style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary)),
                      ]),
                    ),
                  if (_productLoadError != null && !_isLoadingProducts)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(children: [
                        const Icon(Icons.warning_amber_rounded, size: 16, color: Colors.orange),
                        const SizedBox(width: 8),
                        Expanded(child: Text('Could not load products from server. Using cached values.',
                          style: GoogleFonts.inter(fontSize: 12, color: Colors.orange.shade700))),
                        TextButton(
                          onPressed: _fetchProducts,
                          child: Text('Retry', style: GoogleFonts.inter(fontSize: 12, color: AppColors.primaryGreen, fontWeight: FontWeight.bold)),
                        ),
                      ]),
                    ),

                  ..._productEntries.asMap().entries.map((entry) {
                    final index = entry.key;
                    final item = entry.value;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 20.0),
                      child: _buildCard(child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Item #${index + 1}',
                                style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: AppColors.primaryGreen)),
                              if (_productEntries.length > 1)
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                                  onPressed: () => setState(() => _productEntries.removeAt(index)),
                                ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          // ── Dynamic Product Dropdown ─────────────────────
                          DropdownButtonFormField<String>(
                            initialValue: _buildSafeDropdownValue(item.productName),
                            decoration: _inputDecoration('Select product', Icons.shopping_basket_outlined),
                            isExpanded: true,
                            items: () {
                              List<DropdownMenuItem<String>> items = [];
                              for (var group in _groupedItems) {
                                items.add(DropdownMenuItem(
                                  value: 'HEADER_${group.category}',
                                  enabled: false,
                                  child: Text(group.category, style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: AppColors.primaryGreen, fontSize: 13)),
                                ));
                                for (var itemName in group.items) {
                                  items.add(DropdownMenuItem(
                                    value: itemName,
                                    child: Padding(
                                      padding: const EdgeInsets.only(left: 16.0),
                                      child: Text(itemName, overflow: TextOverflow.ellipsis),
                                    ),
                                  ));
                                }
                              }
                              return items;
                            }(),
                            onChanged: (v) {
                              setState(() => item.productName = v);
                            },
                            validator: (v) =>
                              (v == null) ? 'Select a product type' : null,
                          ),
                          const SizedBox(height: 16),

                          Row(children: [
                            Expanded(child: _buildPricingTypeToggle(item, 'Per KG')),
                            const SizedBox(width: 8),
                            Expanded(child: _buildPricingTypeToggle(item, 'Per Bag')),
                          ]),
                          const SizedBox(height: 16),

                          Row(children: [
                            Expanded(flex: 2, child: TextFormField(
                              initialValue: item.pricePerUnit.toString(),
                              decoration: _inputDecoration(
                                'Price / ${item.pricingType == 'Per KG' ? 'KG' : 'Bag'}',
                                Icons.payments_outlined),
                              keyboardType: TextInputType.number,
                              onChanged: (v) => setState(() => item.pricePerUnit = double.tryParse(v) ?? 0),
                              validator: (v) => (double.tryParse(v ?? '') ?? 0) <= 0 ? 'Invalid rate' : null,
                            )),
                            const SizedBox(width: 12),
                            Expanded(child: TextFormField(
                              initialValue: item.quantity.toString(),
                              decoration: _inputDecoration('Qty', Icons.numbers),
                              keyboardType: TextInputType.number,
                              onChanged: (v) => setState(() => item.quantity = double.tryParse(v) ?? 0),
                              validator: (v) => (double.tryParse(v ?? '') ?? 0) <= 0 ? '?' : null,
                            )),
                          ]),
                          const SizedBox(height: 16),

                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: AppColors.primaryGreen.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Subtotal:',
                                  style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                                Text('₹ ${item.subtotal.toStringAsFixed(2)}',
                                  style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: AppColors.primaryGreen)),
                              ],
                            ),
                          ),
                        ],
                      )),
                    );
                  }),

                  Center(
                    child: TextButton.icon(
                      onPressed: () => setState(() => _productEntries.add(ProductItemEntry())),
                      icon: const Icon(Icons.add_circle_outline, size: 20),
                      label: const Text('Add Another Product'),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.primaryGreen,
                        textStyle: GoogleFonts.inter(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  _buildSectionHeader('RESOURCES & PRIORITY'),
                  _buildCard(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextFormField(
                        controller: _crewLeaderController,
                        decoration: _inputDecoration('Crew leader name', Icons.engineering_outlined),
                        validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: 20),
                      Text('Priority',
                        style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                      const SizedBox(height: 12),
                      Row(
                        children: ['NORMAL', 'HIGH', 'CRITICAL']
                            .map((p) => _buildPriorityButton(p))
                            .toList(),
                      ),
                    ],
                  )),
                  const SizedBox(height: 32),

                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: AppColors.primaryGreen,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [BoxShadow(
                        color: AppColors.primaryGreen.withValues(alpha: 0.3),
                        blurRadius: 15, offset: const Offset(0, 8),
                      )],
                    ),
                    child: Column(children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('GRAND TOTAL',
                            style: GoogleFonts.inter(color: Colors.white.withValues(alpha: 0.8),
                              fontWeight: FontWeight.bold, letterSpacing: 1)),
                          Text('₹ ${_calculateGrandTotal.toStringAsFixed(2)}',
                            style: GoogleFonts.inter(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 16),
                      PrimaryButton(text: 'Update Delivery', onPressed: _handleUpdateDelivery, showArrow: false),
                    ]),
                  ),
                  const SizedBox(height: 60),
                ],
              ),
            ),
          ),
          if (_isLoading)
            Container(
              color: Colors.black.withValues(alpha: 0.5),
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: Colors.white),
                    SizedBox(height: 16),
                    Text('Updating Invoice...', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Guards against item.productName not being in _groupedItems yet (e.g. race
  /// condition on first load). Returns null so the dropdown shows the hint.
  String? _buildSafeDropdownValue(String? name) {
    if (name == null || name.isEmpty) return null;
    final validValues = _groupedItems.expand((g) => g.items).toSet();
    if (validValues.contains(name)) return name;
    return null;
  }

  Widget _buildPricingTypeToggle(ProductItemEntry item, String type) {
    final isSelected = item.pricingType == type;
    return InkWell(
      onTap: () => setState(() => item.pricingType = type),
      child: Container(
        height: 44,
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryGreen.withValues(alpha: 0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: isSelected ? AppColors.primaryGreen : Colors.grey.withValues(alpha: 0.3)),
        ),
        alignment: Alignment.center,
        child: Text(type,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? AppColors.primaryGreen : AppColors.textSecondary,
          )),
      ),
    );
  }

  Widget _buildSectionHeader(String title) => Padding(
    padding: const EdgeInsets.only(bottom: 12.0),
    child: Text(title,
      style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold,
        color: AppColors.textSecondary, letterSpacing: 1.2)),
  );

  Widget _buildCard({required Widget child}) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 4))],
    ),
    child: child,
  );

  InputDecoration _inputDecoration(String hint, IconData icon) => InputDecoration(
    hintText: hint,
    prefixIcon: Icon(icon, color: AppColors.textSecondary, size: 18),
    filled: true,
    fillColor: Colors.grey.withValues(alpha: 0.05),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
  );

  Widget _buildPriorityButton(String label) {
    final isSelected = _selectedPriority == label;
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: InkWell(
          onTap: () => setState(() => _selectedPriority = label),
          child: Container(
            height: 44,
            decoration: BoxDecoration(
              color: isSelected ? AppColors.primaryGreen : Colors.grey.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.center,
            child: Text(label,
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? Colors.white : AppColors.textSecondary,
              )),
          ),
        ),
      ),
    );
  }
}
