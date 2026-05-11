import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/app_colors.dart';
import '../widgets/primary_button.dart';
import '../models/delivery.dart';
import '../models/customer_model.dart';
import '../services/api_service.dart';
import '../services/token_service.dart';
import '../services/pdf_service.dart';
import 'package:printing/printing.dart';


class AddDeliveryScreen extends StatefulWidget {
  const AddDeliveryScreen({super.key});

  @override
  State<AddDeliveryScreen> createState() => _AddDeliveryScreenState();
}

class _AddDeliveryScreenState extends State<AddDeliveryScreen> {
  final _formKey = GlobalKey<FormState>();
  final _apiService = ApiService(TokenService.instance);
  final _pdfService = PdfService();

  String? _selectedCustomer;
  CustomerModel? _selectedCustomerModel;
  final _customerSearchController = TextEditingController();
  final _crewLeaderController = TextEditingController();
  final _gstController = TextEditingController();
  final _companyController = TextEditingController();
  final _addressController = TextEditingController();
  String _selectedPriority = 'NORMAL';
  bool _isLoading = false;

  // Each entry owns its own controllers to prevent state-shift on delete/add
  final List<ProductItemEntry> _productEntries = [ProductItemEntry()];
  
  final List<Map<String, TextEditingController>> _customFieldsControllers = [];

  List<CustomerModel> _allCustomers = [];
  List<CustomerModel> _filteredCustomers = [];
  bool _isFetchingCustomers = true;
  bool _showSuggestions = false;

  final List<String> _products = ['Raw Silk', 'Cotton Yarn', 'Silk Fabric', 'Waste Cotton'];

  @override
  void initState() {
    super.initState();
    _fetchCustomers();
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
      if (mounted) {
        setState(() {
          _isFetchingCustomers = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load customers: $e')),
        );
      }
    }
  }

  void _onCustomerSearchChanged(String query) {
    setState(() {
      // Only clear the selection when the user actively clears the field.
      // Do NOT reset on every keystroke — that causes the validation failure
      // where a tapped suggestion is immediately nulled out on next rebuild.
      if (query.isEmpty) {
        _selectedCustomer = null;
        _selectedCustomerModel = null;
        _showSuggestions = false;
        _filteredCustomers = [];
      } else {
        // If the user edits after selecting, invalidate only when text differs
        if (_selectedCustomer != null && query != _selectedCustomer) {
          _selectedCustomer = null;
          _selectedCustomerModel = null;
        }
        _showSuggestions = true;
        _filteredCustomers = _allCustomers
            .where((c) => c.name.toLowerCase().contains(query.toLowerCase()))
            .toList();
      }
    });
  }

  @override
  void dispose() {
    _crewLeaderController.dispose();
    _customerSearchController.dispose();
    _gstController.dispose();
    _companyController.dispose();
    _addressController.dispose();
    for (var field in _customFieldsControllers) {
      field['label']?.dispose();
      field['value']?.dispose();
    }
    super.dispose();
  }

  double get _calculateGrandTotal {
    return _productEntries.fold(0.0, (sum, item) => sum + item.subtotal);
  }

  // Called by each product card when its values change so the summary updates
  void _onProductChanged() {
    setState(() {});
  }

  Future<void> _handleConfirmDelivery() async {
    // Check customer first with a specific message
    if (_selectedCustomer == null || _selectedCustomerModel?.id == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please search and select a valid customer from the list')),
      );
      return;
    }

    // Validate form fields (shows inline errors on each field)
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fix the highlighted errors above')),
      );
      return;
    }

    final deliveryTotal = _calculateGrandTotal;
    if (deliveryTotal <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Delivery total must be greater than 0')),
      );
      return;
    }

    if (_productEntries.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Items list cannot be empty')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final List<ProductItem> items = _productEntries.map((entry) {
        return ProductItem(
          name: entry.productName ?? 'Unknown',
          quantity: entry.quantity,
          unit: entry.unit,
          pricingType: entry.pricingType,
          pricePerUnit: entry.pricePerUnit,
          // costPerUnit removed from UI; default is 0.0 in model
          costPerUnit: 0.0,
        );
      }).toList();

      final previousBalance = _selectedCustomerModel?.balance ?? 0.0;
      final deliveryTotal = _calculateGrandTotal;
      final finalTotal = Delivery.calculateFinalAmount(previousBalance, deliveryTotal);

      final customFieldsList = _customFieldsControllers.map((field) {
        return {
          'label': field['label']?.text.trim() ?? '',
          'value': field['value']?.text.trim() ?? '',
        };
      }).where((f) => f['label']!.isNotEmpty && f['value']!.isNotEmpty).toList();

      final delivery = Delivery.create(
        customerId: _selectedCustomerModel?.id,
        customerName: _selectedCustomer!,
        customerPhone: _selectedCustomerModel?.phone,
        previousBalance: previousBalance,
        updatedBalance: finalTotal,
        deliveryTotal: deliveryTotal,
        products: items,
        crewLeader: _crewLeaderController.text,
        priority: _selectedPriority,
        status: 'completed', // Ensure ledger sync isn't blocked by pending status
        gstNumber: _gstController.text.trim().isEmpty ? null : _gstController.text.trim(),
        companyName: _companyController.text.trim().isEmpty ? null : _companyController.text.trim(),
        address: _addressController.text.trim().isEmpty ? null : _addressController.text.trim(),
        customFields: customFieldsList,
      );

      final success = await _apiService.createDelivery(delivery);

      if (success) {
        // Explicitly sync the customer's master balance to prevent UI drift
        if (_selectedCustomerModel?.id != null) {
          await _apiService.syncCustomerBalance(_selectedCustomerModel!.id!);
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Delivery added successfully. Generating Receipt...')),
          );
          
          try {
            await Printing.layoutPdf(
              onLayout: (format) async => await _pdfService.generateReceipt(delivery),
              name: 'Delivery_Receipt_${delivery.id}.pdf',
            );
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Failed to preview PDF: $e'), backgroundColor: Colors.red),
              );
            }
          }

          if (mounted) Navigator.pop(context, true);
        }
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
        title: Text(
          'BSM Agro Industry',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.bold,
            color: AppColors.primaryGreen,
          ),
        ),
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
                  Text(
                    'Create Invoice',
                    style: GoogleFonts.inter(fontSize: 32, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Enter delivery details and pricing for multiple items.',
                    style: GoogleFonts.inter(fontSize: 14, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 32),

                  _buildSectionHeader('RECIPIENT DETAILS'),
                  _buildCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_isFetchingCustomers)
                          Row(
                            children: [
                              SizedBox(
                                width: 16, height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primaryGreen),
                              ),
                              const SizedBox(width: 12),
                              Text('Loading customers...', style: GoogleFonts.inter(color: AppColors.textSecondary)),
                            ],
                          )
                        else
                          TextFormField(
                            controller: _customerSearchController,
                            decoration: _inputDecoration('Search customer...', Icons.search),
                            onChanged: _onCustomerSearchChanged,
                            validator: (v) => _selectedCustomer == null ? 'Please select a valid customer' : null,
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
                                          _selectedCustomer = customer.name;
                                          _selectedCustomerModel = customer;
                                          _customerSearchController.text = customer.name;
                                          _showSuggestions = false;
                                          // Defocus the text field
                                          FocusScope.of(context).unfocus();
                                        });
                                      },
                                    );
                                  },
                                ),
                          ),
                        if (_selectedCustomerModel != null && !_showSuggestions)
                          Container(
                            margin: const EdgeInsets.only(top: 16),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: _selectedCustomerModel!.balance > 0 
                                  ? Colors.red.withValues(alpha: 0.05) 
                                  : (_selectedCustomerModel!.balance < 0 ? AppColors.primaryGreen.withValues(alpha: 0.1) : Colors.grey.withValues(alpha: 0.05)),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: _selectedCustomerModel!.balance > 0 ? Colors.red.withValues(alpha: 0.3) : (_selectedCustomerModel!.balance < 0 ? AppColors.primaryGreen.withValues(alpha: 0.5) : Colors.grey.withValues(alpha: 0.2))
                              )
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      _selectedCustomerModel!.balance > 0 ? Icons.warning_amber_rounded : (_selectedCustomerModel!.balance < 0 ? Icons.check_circle_outline : Icons.info_outline),
                                      color: _selectedCustomerModel!.balance > 0 ? Colors.red[700] : (_selectedCustomerModel!.balance < 0 ? AppColors.primaryGreen : AppColors.textSecondary),
                                      size: 20,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      _selectedCustomerModel!.balance > 0 ? 'Old Balance' : (_selectedCustomerModel!.balance < 0 ? 'Advance' : 'Clear Balance'),
                                      style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: _selectedCustomerModel!.balance > 0 ? Colors.red[700] : (_selectedCustomerModel!.balance < 0 ? AppColors.primaryGreen : AppColors.textSecondary)),
                                    ),
                                  ],
                                ),
                                Text(
                                  '₹ ${_selectedCustomerModel!.balance.abs().toStringAsFixed(2)}',
                                  style: GoogleFonts.inter(fontWeight: FontWeight.w900, fontSize: 16, color: _selectedCustomerModel!.balance > 0 ? Colors.red[700] : (_selectedCustomerModel!.balance < 0 ? AppColors.primaryGreen : AppColors.textSecondary)),
                                ),
                              ],
                            ),
                          ),
                        if (_selectedCustomerModel != null && !_showSuggestions && _selectedCustomerModel!.creditLimit > 0 && _selectedCustomerModel!.balance > _selectedCustomerModel!.creditLimit)
                          Container(
                            margin: const EdgeInsets.only(top: 8),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.red.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.warning, color: Colors.red, size: 16),
                                const SizedBox(width: 8),
                                Text(
                                  'Credit Limit Exceeded (₹${_selectedCustomerModel!.creditLimit.toStringAsFixed(0)})',
                                  style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.red),
                                ),
                              ],
                            ),
                          ),
                        const SizedBox(height: 16),
                        const Divider(),
                        const SizedBox(height: 16),
                        Text('Optional Invoice Fields', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _companyController,
                          decoration: _inputDecoration('Company Name', Icons.business_outlined),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _gstController,
                          decoration: _inputDecoration('GST Number', Icons.receipt_long_outlined),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _addressController,
                          decoration: _inputDecoration('Address', Icons.location_on_outlined),
                          maxLines: 2,
                        ),
                        const SizedBox(height: 16),
                        const Divider(),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Custom Invoice Fields', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                            TextButton.icon(
                              onPressed: () {
                                setState(() {
                                  _customFieldsControllers.add({
                                    'label': TextEditingController(),
                                    'value': TextEditingController(),
                                  });
                                });
                              },
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
                            child: Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: controllers['label'],
                                    decoration: _inputDecoration('Label (e.g. Vehicle)', Icons.label_outline),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: TextFormField(
                                    controller: controllers['value'],
                                    decoration: _inputDecoration('Value', Icons.edit_note),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
                                  onPressed: () {
                                    setState(() {
                                      controllers['label']?.dispose();
                                      controllers['value']?.dispose();
                                      _customFieldsControllers.removeAt(index);
                                    });
                                  },
                                ),
                              ],
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  _buildSectionHeader('INVENTORY & PRICING'),
                  // ValueKey(item) ensures Flutter tracks each card by object
                  // identity, preventing state-shift when items are deleted.
                  ..._productEntries.asMap().entries.map((entry) {
                    final index = entry.key;
                    final item = entry.value;
                    return _ProductItemCard(
                      key: ValueKey(item),
                      item: item,
                      index: index,
                      products: _products,
                      canDelete: _productEntries.length > 1,
                      onDelete: () => setState(() {
                        item.dispose();
                        _productEntries.removeAt(index);
                      }),
                      onChanged: _onProductChanged,
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
                  _buildCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextFormField(
                          controller: _crewLeaderController,
                          decoration: _inputDecoration('Crew leader name', Icons.engineering_outlined),
                          validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                        ),
                        const SizedBox(height: 20),
                        Text('Priority', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                        const SizedBox(height: 12),
                        Row(
                          children: ['NORMAL', 'HIGH', 'CRITICAL'].map((p) => _buildPriorityButton(p)).toList(),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),

                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: AppColors.primaryGreen,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primaryGreen.withValues(alpha: 0.3),
                          blurRadius: 15,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('DELIVERY TOTAL', style: GoogleFonts.inter(color: Colors.white.withValues(alpha: 0.8), fontWeight: FontWeight.bold, letterSpacing: 1, fontSize: 12)),
                            Text('₹ ${_calculateGrandTotal.toStringAsFixed(2)}', style: GoogleFonts.inter(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        if (_selectedCustomerModel != null && _selectedCustomerModel!.balance != 0)
                          ...[
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(_selectedCustomerModel!.balance > 0 ? 'OLD BALANCE' : 'ADVANCE', style: GoogleFonts.inter(color: Colors.white.withValues(alpha: 0.8), fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1)),
                                Text('₹ ${_selectedCustomerModel!.balance.abs().toStringAsFixed(2)}', style: GoogleFonts.inter(color: Colors.white, fontSize: 14)),
                              ],
                            ),
                          ],
                        const Divider(color: Colors.white24, height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('FINAL PAYABLE', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w900, letterSpacing: 1, fontSize: 16)),
                            Text('₹ ${Delivery.calculateFinalAmount(_selectedCustomerModel?.balance ?? 0.0, _calculateGrandTotal).toStringAsFixed(2)}', style: GoogleFonts.inter(color: Colors.yellow, fontSize: 28, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        const SizedBox(height: 16),
                        PrimaryButton(
                          text: 'Confirm & Generate PDF',
                          onPressed: _handleConfirmDelivery,
                          showArrow: false,
                          // color: Colors.white,
                          // textColor: AppColors.primaryGreen,
                        ),
                      ],
                    ),
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
                    Text('Finalizing Invoice...', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }



  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Text(
        title,
        style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textSecondary, letterSpacing: 1.2),
      ),
    );
  }

  Widget _buildCard({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: child,
    );
  }

  InputDecoration _inputDecoration(String hint, IconData icon) {
    return InputDecoration(
      hintText: hint,
      prefixIcon: Icon(icon, color: AppColors.textSecondary, size: 18),
      filled: true,
      fillColor: Colors.grey.withValues(alpha: 0.05),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    );
  }

  Widget _buildPriorityButton(String label) {
    bool isSelected = _selectedPriority == label;
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
            child: Text(
              label,
              style: GoogleFonts.inter(fontSize: 10, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, color: isSelected ? Colors.white : AppColors.textSecondary),
            ),
          ),
        ),
      ),
    );
  }
}

class ProductItemEntry {
  String? productName;
  double quantity = 0;
  String pricingType = 'Per KG';
  double pricePerUnit = 0;
  // costPerUnit removed from UI — kept in model for payload compatibility
  double get subtotal => quantity * pricePerUnit;
  String get unit => pricingType == 'Per KG' ? 'KG' : 'Bags';

  // Owned controllers prevent state-shift when list is mutated
  final TextEditingController priceController = TextEditingController();
  final TextEditingController qtyController = TextEditingController();

  void dispose() {
    priceController.dispose();
    qtyController.dispose();
  }
}

// ── Isolated product card widget ──────────────────────────────────────────────
// Extracted so each row manages its own controller state independently.
// This prevents the "state-shift" bug where deleting row N corrupts row N+1.
class _ProductItemCard extends StatefulWidget {
  final ProductItemEntry item;
  final int index;
  final List<String> products;
  final bool canDelete;
  final VoidCallback onDelete;
  final VoidCallback onChanged;

  const _ProductItemCard({
    super.key,
    required this.item,
    required this.index,
    required this.products,
    required this.canDelete,
    required this.onDelete,
    required this.onChanged,
  });

  @override
  State<_ProductItemCard> createState() => _ProductItemCardState();
}

class _ProductItemCardState extends State<_ProductItemCard> {
  late final TextEditingController _priceCtrl;
  late final TextEditingController _qtyCtrl;

  @override
  void initState() {
    super.initState();
    // Initialise from model so existing values survive parent rebuilds
    _priceCtrl = TextEditingController(
      text: widget.item.pricePerUnit > 0 ? widget.item.pricePerUnit.toString() : '',
    );
    _qtyCtrl = TextEditingController(
      text: widget.item.quantity > 0 ? widget.item.quantity.toString() : '',
    );
  }

  @override
  void dispose() {
    _priceCtrl.dispose();
    _qtyCtrl.dispose();
    super.dispose();
  }

  InputDecoration _inputDecoration(String hint, IconData icon) {
    return InputDecoration(
      hintText: hint,
      prefixIcon: Icon(icon, color: AppColors.textSecondary, size: 18),
      filled: true,
      fillColor: Colors.grey.withValues(alpha: 0.05),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    );
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    return Padding(
      padding: const EdgeInsets.only(bottom: 20.0),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Item #${widget.index + 1}',
                    style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: AppColors.primaryGreen)),
                if (widget.canDelete)
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                    onPressed: widget.onDelete,
                  ),
              ],
            ),
            const SizedBox(height: 12),
            // Bug fix: value: bound to model so dropdown survives parent setState
            DropdownButtonFormField<String>(
              value: item.productName,
              decoration: _inputDecoration('Product type', Icons.shopping_basket_outlined),
              items: widget.products
                  .map((p) => DropdownMenuItem(value: p, child: Text(p)))
                  .toList(),
              onChanged: (v) {
                setState(() => item.productName = v);
                widget.onChanged();
              },
              validator: (v) => v == null ? 'Select a product type' : null,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildToggle(item, 'Per KG'),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildToggle(item, 'Per Bag'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    controller: _priceCtrl,
                    decoration: _inputDecoration(
                      'Price / ${item.pricingType == 'Per KG' ? 'KG' : 'Bag'}',
                      Icons.payments_outlined,
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (v) {
                      item.pricePerUnit = double.tryParse(v) ?? 0;
                      widget.onChanged();
                    },
                    validator: (v) =>
                        (double.tryParse(v ?? '') ?? 0) <= 0 ? 'Enter a valid rate' : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 1,
                  child: TextFormField(
                    controller: _qtyCtrl,
                    decoration: _inputDecoration('Qty', Icons.numbers),
                    keyboardType: TextInputType.number,
                    onChanged: (v) {
                      item.quantity = double.tryParse(v) ?? 0;
                      widget.onChanged();
                    },
                    validator: (v) =>
                        (double.tryParse(v ?? '') ?? 0) <= 0 ? 'Enter qty' : null,
                  ),
                ),
              ],
            ),
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
                      style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary)),
                  Text('₹ ${item.subtotal.toStringAsFixed(2)}',
                      style: GoogleFonts.inter(
                          fontWeight: FontWeight.bold,
                          color: AppColors.primaryGreen)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToggle(ProductItemEntry item, String type) {
    final isSelected = item.pricingType == type;
    return InkWell(
      onTap: () {
        setState(() => item.pricingType = type);
        widget.onChanged();
      },
      child: Container(
        height: 44,
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryGreen.withValues(alpha: 0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: isSelected ? AppColors.primaryGreen : Colors.grey.withValues(alpha: 0.3)),
        ),
        alignment: Alignment.center,
        child: Text(
          type,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? AppColors.primaryGreen : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}
