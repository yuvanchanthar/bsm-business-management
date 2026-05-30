import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/app_colors.dart';
import '../models/customer_model.dart';
import '../services/api_service.dart';
import '../services/token_service.dart';

import '../widgets/notification_bell.dart';
import '../widgets/phone_field_with_country.dart';

class EditCustomerScreen extends StatefulWidget {
  final CustomerModel customer;
  
  const EditCustomerScreen({super.key, required this.customer});

  @override
  State<EditCustomerScreen> createState() => _EditCustomerScreenState();
}

class _EditCustomerScreenState extends State<EditCustomerScreen> {
  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _addressController;

  String _fullPhoneNumber = '';

  bool _isLoading = false;
  late ApiService _apiService;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.customer.name);
    _phoneController = TextEditingController(text: widget.customer.phone);
    _fullPhoneNumber = widget.customer.phone;
    _addressController = TextEditingController(text: widget.customer.address);
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

  Future<void> _updateCustomer() async {
    final name = _nameController.text.trim();
    final address = _addressController.text.trim();

    if (name.isEmpty || _fullPhoneNumber.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Name and phone are required')));
      return;
    }

    setState(() => _isLoading = true);

    try {
      final updatedCustomer = CustomerModel(
        id: widget.customer.id,
        name: name,
        phone: _fullPhoneNumber,
        address: address,
        createdAt: widget.customer.createdAt,
      );
      
      final success = await _apiService.updateCustomer(widget.customer.id!, updatedCustomer);
      
      setState(() => _isLoading = false);

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Customer updated successfully')));
        Navigator.pop(context, true); // Return true to trigger reload
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to update customer: $e')));
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
        leading: Container(
          margin: const EdgeInsets.all(8),
          decoration: const BoxDecoration(
            image: DecorationImage(
              image: AssetImage('assets/images/logo.png'),
              fit: BoxFit.contain,
            ),
          ),
        ),
        title: Text(
          'Edit Customer',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.bold,
            color: AppColors.primaryGreen,
          ),
        ),
        actions: [
          const NotificationBell(),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'UPDATE RELATIONSHIP',
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
                  const TextSpan(text: 'Update your\n'),
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
                    initialValue: widget.customer.phone,
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
              icon: Icons.save,
              label: 'Save Changes',
              onPressed: _isLoading ? () {} : _updateCustomer,
              color: _isLoading ? Colors.grey : AppColors.primaryGreen,
              textColor: Colors.white,
              isLoading: _isLoading,
            ),
            const SizedBox(height: 20),
            Center(
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'Discard Changes',
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
