import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../core/app_colors.dart';
import '../core/stock_format.dart';
import '../models/delivery.dart';
import '../models/customer_model.dart';
import '../models/inventory_model.dart';
import '../models/category_model.dart';
import '../services/api_service.dart';
import '../services/supplier_service.dart';
import '../services/token_service.dart';
import '../features/invoice/presentation/providers/template_provider.dart';
import '../features/invoice/presentation/screens/template_selection_screen.dart';
import 'delivery_success_screen.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';

class AddDeliveryScreen extends StatefulWidget {
  const AddDeliveryScreen({super.key});

  @override
  State<AddDeliveryScreen> createState() => _AddDeliveryScreenState();
}

class _AddDeliveryScreenState extends State<AddDeliveryScreen> {
  final _formKey = GlobalKey<FormState>();
  final _apiService = ApiService(TokenService.instance);

  String? _selectedCustomer;
  CustomerModel? _selectedCustomerModel;
  final _customerSearchController = TextEditingController();
  final _crewLeaderController = TextEditingController();
  final _gstController = TextEditingController();
  final _companyController = TextEditingController();
  final _addressController = TextEditingController();
  final _vehicleNumberController = TextEditingController();
  String _selectedPriority = 'NORMAL';

  // ── 3-step flow state ────────────────────────────────────────────────────
  bool _isSaving = false;           // Step 1: saving delivery
  bool _isGenerating = false;        // Step 3: generating invoice PDF
  Delivery? _savedDelivery;          // Set after successful SAVE
  String? _localTemplateId;          // Set after CHOOSE TEMPLATE returns

  // Each entry owns its own controllers to prevent state-shift on delete/add
  final List<ProductItemEntry> _productEntries = [ProductItemEntry()];
  
  final List<Map<String, TextEditingController>> _customFieldsControllers = [];

  List<CustomerModel> _allCustomers = [];
  List<CustomerModel> _filteredCustomers = [];
  bool _isFetchingCustomers = true;
  bool _showSuggestions = false;

  List<GroupedItemModel> _groupedItems = [];
  List<InventoryItemModel> _inventoryItems = [];
  bool _isLoadingInventory = true;

  bool get _hasInsufficientStock {
    // While inventory is still loading, never block the Save button.
    if (_isLoadingInventory) return false;
    for (final entry in _productEntries) {
      if (entry.productName == null) continue;
      final invItem = _inventoryItems.firstWhere(
        (item) => item.itemName == entry.productName,
        orElse: () => InventoryItemModel(itemName: '', currentStock: 0, unit: '', threshold: 0),
      );
      if (invItem.itemName.isEmpty) continue;
      // Only block if both entry and inventory are in the same unit (Bags).
      // Cross-unit conversion (KG -> Bags) is handled by the backend — never compare raw here.
      if (invItem.unit == entry.inventoryUnit && entry.quantity > invItem.currentStock) {
        return true;
      }
    }
    return false;
  }

  @override
  void initState() {
    super.initState();
    _fetchCustomers();
    _fetchInventory();
  }

  Future<void> _fetchInventory() async {
    try {
      final ts = await TokenService.getInstance();
      final supplierService = SupplierService(ts);
      final items = await supplierService.getInventory();
      final groups = await supplierService.getGroupedItemsDropdown();
      if (mounted) {
        setState(() {
          _inventoryItems = items;
          _groupedItems = groups;
          _isLoadingInventory = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingInventory = false;
        });
      }
    }
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
    _vehicleNumberController.dispose();
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

  Future<void> _handleSaveDelivery() async {
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

    setState(() => _isSaving = true);

    try {
      final List<ProductItem> items = _productEntries.map((entry) {
        return ProductItem(
          name: entry.productName ?? 'Unknown',
          quantity: entry.quantity,
          // inventoryUnit is independent of pricingType — never derive one from the other.
          unit: entry.inventoryUnit,
          pricingType: entry.pricingType,
          pricePerUnit: entry.pricePerUnit,
          costPerUnit: 0.0,
        );
      }).toList();

      final previousBalance = _selectedCustomerModel?.balance ?? 0.0;
      final deliveryTotalCalc = _calculateGrandTotal;
      final finalTotal = Delivery.calculateFinalAmount(previousBalance, deliveryTotalCalc);

      final customFieldsList = _customFieldsControllers.map((field) {
        return {
          'label': field['label']?.text.trim() ?? '',
          'value': field['value']?.text.trim() ?? '',
        };
      }).where((f) => f['label']!.isNotEmpty && f['value']!.isNotEmpty).toList();

      print('---------- DEBUG CREATE DELIVERY ----------');
      print('Status being sent: pending');
      print('-------------------------------------------');

      final delivery = Delivery.create(
        customerId: _selectedCustomerModel?.id,
        customerName: _selectedCustomer!,
        customerPhone: _selectedCustomerModel?.phone,
        previousBalance: previousBalance,
        updatedBalance: finalTotal,
        deliveryTotal: deliveryTotalCalc,
        products: items,
        crewLeader: _crewLeaderController.text,
        priority: _selectedPriority,
        status: 'pending',
        gstNumber: _gstController.text.trim().isEmpty ? null : _gstController.text.trim(),
        companyName: _companyController.text.trim().isEmpty ? null : _companyController.text.trim(),
        address: _addressController.text.trim().isEmpty ? null : _addressController.text.trim(),
        customFields: customFieldsList,
        vehicleNumber: _vehicleNumberController.text.trim().isEmpty ? null : _vehicleNumberController.text.trim(),
      );

      final createdDelivery = await _apiService.createDelivery(delivery);

      if (createdDelivery != null) {
        // Sync customer balance
        if (_selectedCustomerModel?.id != null) {
          await _apiService.syncCustomerBalance(_selectedCustomerModel!.id!);
        }
        if (mounted) {
          // IMPORTANT: Re-fetch the full delivery object by ID. 
          // The initial 'createDelivery' response might not have the fully populated 
          // nested invoice data if the backend generates it in a post-save hook.
          final fullDelivery = await _apiService.getDeliveryById(createdDelivery.id);
          
          setState(() {
            _savedDelivery = fullDelivery ?? createdDelivery;
            // Pre-select default template if available
            final defaultId = context.read<TemplateProvider>().defaultTemplateId;
            if (defaultId != null && defaultId.isNotEmpty) {
              _localTemplateId = defaultId;
            }
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Delivery saved! Now choose a template and generate the invoice.'),
              duration: Duration(seconds: 3),
            ),
          );
          // Refresh inventory so stock quantities reflect what was deducted.
          _fetchInventory();
          _triggerDeliveryCreatedSMS(fullDelivery ?? createdDelivery);
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to save delivery.'), backgroundColor: Colors.red),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving delivery: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _triggerDeliveryCreatedSMS(Delivery delivery) async {
    final customerPhone = delivery.customerPhone;
    if (customerPhone == null || customerPhone.isEmpty) return;

    final StringBuffer productsBuffer = StringBuffer();
    for (var p in delivery.products) {
      productsBuffer.writeln('${p.name} - ${fmtStock(p.quantity)} ${p.unit}');
    }

    final String message = '''
BSM Agro Industry

Dear ${delivery.customerName},

Your delivery order has been created successfully.

Ordered Products:

${productsBuffer.toString().trim()}

Order Amount: ₹${NumberFormat('#,##,###').format(delivery.deliveryTotal)}

Previous Balance: ₹${NumberFormat('#,##,###').format(delivery.previousBalance)}
Current Balance: ₹${NumberFormat('#,##,###').format(delivery.updatedBalance)}

Thank you,
BSM Agro Industry''';

    final cleanPhone = customerPhone.replaceAll(RegExp(r'\\D'), '');
    final encodedMessage = Uri.encodeComponent(message);

    final Uri url = Uri.parse(
  'sms:$cleanPhone?body=$encodedMessage'
);
    //final Uri url = Uri.parse('sms:$cleanPhone?body=\${Uri.encodeComponent(message)}');
    
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    }
  }

  /// Step 2: Open TemplateSelectionScreen as a PICKER.
  /// It returns a String (the chosen templateId) via Navigator.pop.
  Future<void> _handleChooseTemplate() async {
    final delivery = _savedDelivery;
    if (delivery == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please save the delivery first.')),
      );
      return;
    }

    // Navigate to TemplateSelectionScreen in picker mode.
    // It calls Navigator.pop(context, templateId) when user selects a template.
    final chosen = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => TemplateSelectionScreen(
          delivery: delivery,
          pickerMode: true,
        ),
      ),
    );

    if (chosen != null && mounted) {
      setState(() => _localTemplateId = chosen);
      final templateName = context.read<TemplateProvider>().templateById(chosen)?.name ?? chosen;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Template selected: $templateName'),
          backgroundColor: AppColors.primaryGreen,
        ),
      );
    }
  }

  Future<void> _handleGenerateInvoice() async {
    final delivery = _savedDelivery;
    final templateId = _localTemplateId;
    if (delivery == null || templateId == null) return;
    if (_isGenerating) return;

    setState(() => _isGenerating = true);
    try {
      debugPrint('[AddDelivery] Persisting and Generating invoice for delivery ${delivery.id} with template $templateId');
      final provider = context.read<TemplateProvider>();
      
      // Step 1: Compare re-fetched delivery customFields with local delivery state
      final localCustomFields = _customFieldsControllers.map((field) {
        return {
          'label': field['label']?.text.trim() ?? '',
          'value': field['value']?.text.trim() ?? '',
        };
      }).where((f) => f['label']!.isNotEmpty && f['value']!.isNotEmpty).toList();

      Delivery deliveryToGenerate = delivery;
      
      // Step 2 & 3: If fetched is missing customFields but local has them, merge and use.
      if ((delivery.invoice?.customFields.isEmpty ?? true) && localCustomFields.isNotEmpty) {
        final mergedInvoice = delivery.invoice?.copyWith(customFields: localCustomFields) ?? DeliveryInvoice(
          id: '',
          amount: delivery.deliveryTotal,
          customFields: localCustomFields,
        );
        deliveryToGenerate = delivery.copyWith(invoice: mergedInvoice);
      }

      final result = await provider.updateAndGenerateInvoice(
        delivery: deliveryToGenerate,
        templateId: templateId,
      );

      if (!mounted) return;

      if (result == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(provider.errorMessage ?? 'Failed to update and generate invoice'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      final bytes = result.bytes;
      final updatedDelivery = result.updatedDelivery;

      // Navigate to success screen — pop all the way home first so back button
      // returns to Dashboard, not the now-stale form.
      Navigator.of(context).popUntil((route) => route.isFirst);
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => DeliverySuccessScreen(
            delivery: updatedDelivery,
            pdfData: bytes,
            templateId: updatedDelivery.invoice?.templateId ?? templateId,
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error generating invoice: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isGenerating = false);
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
                                          _addressController.text = customer.address.isNotEmpty ? customer.address : '';
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
                      groupedItems: _groupedItems,
                      inventoryItems: _inventoryItems,
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
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _vehicleNumberController,
                          decoration: _inputDecoration('Vehicle Number (e.g. TN 37 AB 1234)', Icons.directions_car_outlined),
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

                  // ── TOTALS SUMMARY CARD ─────────────────────────────────
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
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // ── 3-STEP ACTION FLOW ───────────────────────────────────

                  // Step progress indicator
                  _buildStepIndicator(),
                  const SizedBox(height: 20),

                  // STEP 1: SAVE
                  _buildActionStep(
                    stepNumber: 1,
                    title: _savedDelivery != null ? '✓  Delivery Saved' : 'Save Delivery',
                    subtitle: _hasInsufficientStock
                        ? 'Not enough stock available'
                        : (_savedDelivery != null
                            ? 'Delivery recorded successfully'
                            : 'Save the delivery without generating an invoice'),
                    icon: _hasInsufficientStock
                        ? Icons.error_outline
                        : (_savedDelivery != null ? Icons.check_circle : Icons.save_outlined),
                    color: _hasInsufficientStock
                        ? Colors.red
                        : (_savedDelivery != null ? Colors.green : AppColors.primaryGreen),
                    isCompleted: _savedDelivery != null,
                    isLoading: _isSaving,
                    isEnabled: _savedDelivery == null && !_isSaving && !_hasInsufficientStock,
                    onTap: _handleSaveDelivery,
                  ),
                  const SizedBox(height: 12),

                  // STEP 2: CHOOSE TEMPLATE
                  _buildActionStep(
                    stepNumber: 2,
                    title: _localTemplateId != null
                        ? '✓  Template: ${context.read<TemplateProvider>().templateById(_localTemplateId!)?.name ?? _localTemplateId}'
                        : 'Choose Template',
                    subtitle: _localTemplateId != null
                        ? 'Tap to change the selected template'
                        : 'Pick an invoice layout for this delivery',
                    icon: _localTemplateId != null ? Icons.palette : Icons.palette_outlined,
                    color: _localTemplateId != null ? Colors.blue : (_savedDelivery != null ? AppColors.primaryGreen : Colors.grey),
                    isCompleted: _localTemplateId != null,
                    isLoading: false,
                    isEnabled: _savedDelivery != null,
                    onTap: _handleChooseTemplate,
                  ),
                  const SizedBox(height: 12),

                  // STEP 3: GENERATE INVOICE
                  _buildActionStep(
                    stepNumber: 3,
                    title: 'Generate Invoice',
                    subtitle: _localTemplateId == null
                        ? 'Choose a template first'
                        : 'Generate PDF & open preview screen',
                    icon: Icons.receipt_long,
                    color: (_savedDelivery != null && _localTemplateId != null)
                        ? const Color(0xFF6A1B9A)
                        : Colors.grey,
                    isCompleted: false,
                    isLoading: _isGenerating,
                    isEnabled: _savedDelivery != null && _localTemplateId != null && !_isGenerating,
                    onTap: _handleGenerateInvoice,
                    isPrimary: true,
                  ),

                  const SizedBox(height: 60),
                ],
              ),
            ),
          ),
          if (_isSaving || _isGenerating)
            Container(
              color: Colors.black.withValues(alpha: 0.5),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(color: Colors.white),
                    const SizedBox(height: 16),
                    Text(
                      _isSaving ? 'Saving Delivery...' : 'Generating Invoice...',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ── Step progress strip ──────────────────────────────────────────────────
  Widget _buildStepIndicator() {
    return Row(
      children: [
        _buildStepDot(1, _savedDelivery != null),
        Expanded(child: Divider(color: _savedDelivery != null ? AppColors.primaryGreen : Colors.grey.shade300, thickness: 2)),
        _buildStepDot(2, _localTemplateId != null),
        Expanded(child: Divider(color: _localTemplateId != null ? AppColors.primaryGreen : Colors.grey.shade300, thickness: 2)),
        _buildStepDot(3, false),
      ],
    );
  }

  Widget _buildStepDot(int step, bool done) {
    return Container(
      width: 32, height: 32,
      decoration: BoxDecoration(
        color: done ? AppColors.primaryGreen : Colors.grey.shade200,
        shape: BoxShape.circle,
        border: Border.all(color: done ? AppColors.primaryGreen : Colors.grey.shade400, width: 2),
      ),
      alignment: Alignment.center,
      child: done
          ? const Icon(Icons.check, color: Colors.white, size: 16)
          : Text('$step', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey.shade600)),
    );
  }

  // ── Individual action step button ────────────────────────────────────────
  Widget _buildActionStep({
    required int stepNumber,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required bool isCompleted,
    required bool isLoading,
    required bool isEnabled,
    required VoidCallback onTap,
    bool isPrimary = false,
  }) {
    return AnimatedOpacity(
      opacity: isEnabled || isCompleted ? 1.0 : 0.45,
      duration: const Duration(milliseconds: 250),
      child: Material(
        color: isPrimary && isEnabled
            ? color
            : isCompleted
                ? color.withValues(alpha: 0.08)
                : Colors.white,
        borderRadius: BorderRadius.circular(16),
        elevation: isEnabled && !isCompleted ? 2 : 0,
        child: InkWell(
          onTap: isEnabled || isCompleted ? onTap : null,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isCompleted ? color.withValues(alpha: 0.4) : Colors.grey.shade200,
                width: 1.5,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(
                    color: isPrimary && isEnabled ? Colors.white.withValues(alpha: 0.2) : color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: isLoading
                      ? Padding(
                          padding: const EdgeInsets.all(10),
                          child: CircularProgressIndicator(strokeWidth: 2.5, color: isPrimary ? Colors.white : color),
                        )
                      : Icon(icon, color: isPrimary && isEnabled ? Colors.white : color, size: 22),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: isPrimary && isEnabled ? Colors.white : (isCompleted ? color : AppColors.textPrimary),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: isPrimary && isEnabled ? Colors.white70 : AppColors.textSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Icon(
                  isCompleted ? Icons.edit_outlined : Icons.chevron_right,
                  color: isPrimary && isEnabled ? Colors.white70 : color.withValues(alpha: 0.6),
                  size: 20,
                ),
              ],
            ),
          ),
        ),
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

  /// The pricing mode for calculating the invoice subtotal.
  /// 'Per KG' or 'Per Bag'.
  /// This ONLY affects price calculations — never inventory deduction.
  String pricingType = 'Per KG';

  /// The inventory unit sent to the backend for stock deduction.
  /// 'KG' or 'Bags'.
  /// This is completely INDEPENDENT from pricingType.
  String inventoryUnit = 'KG';

  double pricePerUnit = 0;
  // costPerUnit removed from UI — kept in model for payload compatibility
  double get subtotal => quantity * pricePerUnit;

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
  final List<GroupedItemModel> groupedItems;
  final List<InventoryItemModel> inventoryItems;
  final bool canDelete;
  final VoidCallback onDelete;
  final VoidCallback onChanged;

  const _ProductItemCard({
    super.key,
    required this.item,
    required this.index,
    required this.groupedItems,
    required this.inventoryItems,
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
    _priceCtrl = TextEditingController(
      text: widget.item.pricePerUnit > 0 ? widget.item.pricePerUnit.toString() : '',
    );
    _qtyCtrl = TextEditingController(
      text: widget.item.quantity > 0 ? fmtStock(widget.item.quantity) : '',
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

    List<DropdownMenuItem<String>> buildDropdownItems() {
      List<DropdownMenuItem<String>> items = [];
      for (var group in widget.groupedItems) {
        // Group Header (disabled)
        items.add(DropdownMenuItem(
          value: 'HEADER_${group.category}',
          enabled: false,
          child: Text(
            group.category, 
            style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: AppColors.primaryGreen, fontSize: 13),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ));
        // Group Items
        for (var itemName in group.items) {
          final invItem = widget.inventoryItems.firstWhere(
            (inv) => inv.itemName == itemName,
            orElse: () => InventoryItemModel(itemName: itemName, currentStock: 0, unit: '', threshold: 0),
          );
          items.add(DropdownMenuItem(
            value: itemName,
            child: Padding(
              padding: const EdgeInsets.only(left: 8.0),
              child: Text(
                '$itemName (Stock: ${fmtStock(invItem.currentStock)} ${invItem.unit})', 
                style: GoogleFonts.inter(color: AppColors.textPrimary),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ));
        }
      }
      return items;
    }

    final validValues = widget.groupedItems.expand((g) => g.items).toSet();
    final safeDropdownValue =
        (item.productName != null && validValues.contains(item.productName))
            ? item.productName
            : null;

    if (safeDropdownValue == null && item.productName != null) {
      item.productName = null;
    }

    // ── Live stock preview ──────────────────────────────────────────────────
    final selectedInvItem = widget.inventoryItems.firstWhere(
      (inv) => inv.itemName == item.productName,
      orElse: () =>
          InventoryItemModel(itemName: '', currentStock: 0, unit: '', threshold: 0),
    );
    final showPreview =
        item.productName != null && selectedInvItem.itemName.isNotEmpty;

    // Cross-unit stock preview:
    // If the user enters quantity in the same unit as inventory, subtract directly.
    // Cross-unit (e.g. 30 KG against 100 Bag inventory) cannot be computed client-side
    // without bagWeight — show a neutral display instead of a wrong number.
    final sameUnit = selectedInvItem.unit == item.inventoryUnit;
    final remaining = sameUnit ? (selectedInvItem.currentStock - item.quantity) : 0.0;
    final exceedsStock = sameUnit
        ? (item.quantity > 0 && item.quantity > selectedInvItem.currentStock)
        : false; // Let backend validate cross-unit quantities

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
            DropdownButtonFormField<String>(
              isExpanded: true,
              value: safeDropdownValue,
              decoration: _inputDecoration('Select product', Icons.shopping_basket_outlined).copyWith(
                contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
              ),
              items: buildDropdownItems(),
              onChanged: (v) {
                setState(() => item.productName = v);
                widget.onChanged();
              },
              validator: (v) => v == null ? 'Select a product type' : null,
            ),
            const SizedBox(height: 16),

            // ── Pricing Type (Per KG / Per Bag) ──────────────────────────
            // Controls price calculation ONLY. Never modifies inventoryUnit.
            Text('Pricing Type',
              style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(child: _buildPricingToggle(item, 'Per KG')),
                const SizedBox(width: 8),
                Expanded(child: _buildPricingToggle(item, 'Per Bag')),
              ],
            ),
            const SizedBox(height: 12),

            // ── Inventory Unit (KG / Bags) ────────────────────────────────
            // Controls the unit sent to backend for stock deduction.
            // Completely independent from Pricing Type.
            Text('Inventory Unit',
              style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(child: _buildInventoryUnitToggle(item, 'KG')),
                const SizedBox(width: 8),
                Expanded(child: _buildInventoryUnitToggle(item, 'Bags')),
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
            if (showPreview) ...[
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      () {
                        if (exceedsStock) return 'Not enough stock available';
                        if (!sameUnit) {
                          // Cross-unit: show current stock only, backend handles conversion
                          return 'Stock: ${selectedInvItem.currentStock.toStringAsFixed(2)} ${selectedInvItem.unit} (backend converts ${item.inventoryUnit} → ${selectedInvItem.unit})';
                        }
                        return 'Remaining: ${remaining.toStringAsFixed(2)} ${selectedInvItem.unit}';
                      }(),
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: exceedsStock ? Colors.red : (!sameUnit ? Colors.orange : Colors.green),
                      ),
                    ),
                  ),
                  if (exceedsStock)
                    const Icon(Icons.error_outline, color: Colors.red, size: 16),
                ],
              ),
            ]
          ],
        ),
      ),
    );
  }

  /// Pricing type toggle — affects price calculation only.
  Widget _buildPricingToggle(ProductItemEntry item, String type) {
    final isSelected = item.pricingType == type;
    return InkWell(
      onTap: () {
        // Only update pricingType. Never touch inventoryUnit.
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

  /// Inventory unit toggle — controls the unit sent to backend for stock deduction.
  /// Completely independent from pricingType.
  Widget _buildInventoryUnitToggle(ProductItemEntry item, String unit) {
    final isSelected = item.inventoryUnit == unit;
    return InkWell(
      onTap: () {
        // Only update inventoryUnit. Never touch pricingType.
        setState(() => item.inventoryUnit = unit);
        widget.onChanged();
      },
      child: Container(
        height: 44,
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue.withValues(alpha: 0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: isSelected ? Colors.blue : Colors.grey.withValues(alpha: 0.3)),
        ),
        alignment: Alignment.center,
        child: Text(
          unit,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? Colors.blue : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}
