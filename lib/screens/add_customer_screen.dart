import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/app_colors.dart';
import '../models/customer_model.dart';
import '../services/api_service.dart';
import '../services/token_service.dart';
import 'package:permission_handler/permission_handler.dart';
import 'contact_picker_screen.dart';
import '../widgets/phone_field_with_country.dart';

import '../widgets/notification_bell.dart';

class AddCustomerScreen extends StatefulWidget {
  const AddCustomerScreen({super.key});

  @override
  State<AddCustomerScreen> createState() => _AddCustomerScreenState();
}

class _AddCustomerScreenState extends State<AddCustomerScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();

  String _fullPhoneNumber = '';
  String? _initialPhone;

  bool _isLoading = false;
  bool _showSelectionMode = true; // Show selection cards by default
  late ApiService _apiService;

  @override
  void initState() {
    super.initState();
    _initService();
  }

  Future<void> _initService() async {
    final tokenService = await TokenService.getInstance();
    _apiService = ApiService(tokenService);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _saveCustomer() async {
    final name = _nameController.text.trim();
    final address = _addressController.text.trim();

    if (name.isEmpty || _fullPhoneNumber.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Name and phone are required')));
      return;
    }

    setState(() => _isLoading = true);

    try {
      final customer = CustomerModel(name: name, phone: _fullPhoneNumber, address: address);
      final success = await _apiService.createCustomer(customer);
      
      setState(() => _isLoading = false);

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Customer added successfully')));
        Navigator.pop(context, true); // Return true to trigger reload
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to save customer: $e')));
      }
    }
  }

  Future<void> _handleImportContacts() async {
    final status = await Permission.contacts.request();
    
    if (status.isGranted) {
      if (!mounted) return;
      final result = await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const ContactPickerScreen()),
      );

      if (result != null && result is Map<String, String>) {
        setState(() {
          _nameController.text = result['name'] ?? '';
          _initialPhone = result['phone'] ?? '';
          _fullPhoneNumber = _initialPhone ?? '';
          _showSelectionMode = false; // Switch to manual mode with pre-filled data
        });
      }
    } else if (status.isDenied) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Contacts permission required')),
        );
      }
    } else if (status.isPermanentlyDenied) {
      openAppSettings();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: _showSelectionMode 
          ? IconButton(
              icon: const Icon(Icons.close, color: AppColors.textPrimary),
              onPressed: () => Navigator.pop(context),
            )
          : IconButton(
              icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
              onPressed: () => setState(() {
                _showSelectionMode = true;
                _initialPhone = null;
              }),
            ),
        title: Text(
          'Add Customer',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.bold,
            color: AppColors.primaryGreen,
          ),
        ),
        actions: [
          const NotificationBell(),
        ],
      ),
      body: _showSelectionMode ? _buildSelectionMode() : _buildManualForm(),
    );
  }

  Widget _buildSelectionMode() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'CHOOSE OPTION',
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: AppColors.primaryGreen,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'How would you like to add the customer?',
            style: GoogleFonts.inter(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 32),
          _buildSelectionCard(
            icon: Icons.contact_phone_outlined,
            title: 'Import from Contacts',
            subtitle: 'Select from your phone directory',
            onTap: _handleImportContacts,
            color: const Color(0xFFE8F5E9),
            iconColor: AppColors.primaryGreen,
          ),
          const SizedBox(height: 16),
          _buildSelectionCard(
            icon: Icons.edit_note_outlined,
            title: 'Add Manually',
            subtitle: 'Enter name and details manually',
            onTap: () => setState(() {
              _initialPhone = null;
              _showSelectionMode = false;
            }),
            color: const Color(0xFFE3F2FD),
            iconColor: Colors.blue,
          ),
        ],
      ),
    );
  }

  Widget _buildSelectionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    required Color color,
    required Color iconColor,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: iconColor, size: 28),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: AppColors.textHint),
          ],
        ),
      ),
    );
  }

  Widget _buildManualForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'NEW RELATIONSHIP',
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: AppColors.primaryGreen,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 8),
          RichText(
            text: TextSpan(
              style: GoogleFonts.inter(
                fontSize: 48,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
                height: 1.1,
              ),
              children: [
                const TextSpan(text: 'Expand your\n'),
                TextSpan(
                  text: 'Network.',
                  style: GoogleFonts.inter(color: AppColors.primaryGreen),
                ),
              ],
            ),
          ),
          const SizedBox(height: 48),
          _buildFieldGroup('Full Name', 'e.g. Samuel Green', _nameController),
          Padding(
            padding: const EdgeInsets.only(bottom: 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Phone Number',
                    style: GoogleFonts.inter(
                        fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                const SizedBox(height: 4),
                PhoneFieldWithCountry(
                  initialValue: _initialPhone,
                  hintText: '000-000-0000',
                  onChanged: (phone) {
                    _fullPhoneNumber = phone.completeNumber;
                  },
                ),
              ],
            ),
          ),
          _buildFieldGroup('Physical Address', 'Street, City, County', _addressController),
          const SizedBox(height: 24),
          // Category Slider
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.grey.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Customer Category',
                        style: GoogleFonts.inter(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        'Standard Wholesale',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: AppColors.primaryGreen),
              ],
            ),
          ),
          const SizedBox(height: 48),
          // Actions
          _buildActionButton(
            icon: Icons.person_add_outlined,
            label: 'Save Customer',
            onPressed: _isLoading ? () {} : _saveCustomer,
            color: _isLoading ? Colors.grey : AppColors.primaryGreen,
            textColor: Colors.white,
            isLoading: _isLoading,
          ),
          const SizedBox(height: 20),
          Center(
            child: TextButton(
              onPressed: () => setState(() {
                _initialPhone = null;
                _showSelectionMode = true;
              }),
              child: Text(
                'Cancel & Go Back',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ),
          const SizedBox(height: 60),
          Center(
            child: Text(
              'POWERED BY BSM AGRO INDUSTRY',
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: AppColors.textHint,
                letterSpacing: 1.0,
              ),
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildFieldGroup(String label, String hint, TextEditingController controller, {String? prefix}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          TextField(
            controller: controller,
            decoration: InputDecoration(
              prefixText: prefix,
              prefixStyle: GoogleFonts.inter(fontSize: 18, color: AppColors.textHint),
              hintText: hint,
              hintStyle: GoogleFonts.inter(fontSize: 18, color: AppColors.textHint),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
              enabledBorder: const UnderlineInputBorder(
                borderSide: BorderSide(color: AppColors.border, width: 1.5),
              ),
              focusedBorder: const UnderlineInputBorder(
                borderSide: BorderSide(color: AppColors.primaryGreen, width: 2.0),
              ),
            ),
            style: GoogleFonts.inter(fontSize: 18, color: AppColors.textPrimary),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    required Color color,
    required Color textColor,
    bool isLoading = false,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: textColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 0,
        ),
        icon: isLoading
            ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
            : Icon(icon, size: 24),
        label: Text(
          isLoading ? 'Saving...' : label,
          style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
