import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:permission_handler/permission_handler.dart';
import '../core/app_colors.dart';
import '../models/labour_model.dart';
import '../services/api_service.dart';
import '../services/token_service.dart';
import 'contact_picker_screen.dart';
import '../widgets/phone_field_with_country.dart';

class AddLabourScreen extends StatefulWidget {
  const AddLabourScreen({super.key});

  @override
  State<AddLabourScreen> createState() => _AddLabourScreenState();
}

class _AddLabourScreenState extends State<AddLabourScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _roleController = TextEditingController();
  final _wageController = TextEditingController();
  
  String _fullPhoneNumber = '';
  String? _initialPhone; // for prefilling from contacts
  
  bool _isLoading = false;
  bool _showSelectionMode = true;

  @override
  void dispose() {
    _nameController.dispose();
    _roleController.dispose();
    _wageController.dispose();
    super.dispose();
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
          _showSelectionMode = false;
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

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;
    
    if (_fullPhoneNumber.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid phone number')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final tokenService = await TokenService.getInstance();
      final apiService = ApiService(tokenService);

      final labour = LabourModel(
        name: _nameController.text.trim(),
        phone: _fullPhoneNumber,
        role: _roleController.text.trim(),
        dailyWage: double.parse(_wageController.text.trim()),
      );

      await apiService.createLabour(labour);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Labour added successfully'), backgroundColor: Colors.green),
        );
        Navigator.pop(context, true);
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
        leading: _showSelectionMode 
          ? IconButton(
              icon: const Icon(Icons.close, color: AppColors.textPrimary),
              onPressed: () => Navigator.pop(context),
            )
          : IconButton(
              icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
              onPressed: () => setState(() {
                _showSelectionMode = true;
                _initialPhone = null; // clear prepopulated phone on back
              }),
            ),
        title: Text('Onboard Labour', style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: AppColors.primaryGreen)),
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
            'How would you like to add the labour?',
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
            const Icon(Icons.chevron_right, color: AppColors.textHint),
          ],
        ),
      ),
    );
  }

  Widget _buildManualForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('New Personnel', style: GoogleFonts.inter(fontSize: 28, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text('Fill in the details to onboard a new labour.', style: GoogleFonts.inter(fontSize: 14, color: AppColors.textSecondary)),
            const SizedBox(height: 32),

            _buildLabel('Full Name'),
            _buildField(_nameController, 'e.g. Ravi Kumar', Icons.person_outline, validator: (v) => v == null || v.isEmpty ? 'Required' : null),
            const SizedBox(height: 20),

            _buildLabel('Phone Number'),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              padding: const EdgeInsets.only(left: 12, right: 8, top: 4),
              child: PhoneFieldWithCountry(
                initialValue: _initialPhone,
                hintText: 'e.g. 9876543210',
                decoration: InputDecoration(
                  hintText: 'e.g. 9876543210',
                  hintStyle: GoogleFonts.inter(color: AppColors.textHint, fontSize: 14),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  errorBorder: InputBorder.none,
                  focusedErrorBorder: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onChanged: (phone) {
                  _fullPhoneNumber = phone.completeNumber;
                },
              ),
            ),
            const SizedBox(height: 20),

            _buildLabel('Role / Designation'),
            _buildField(_roleController, 'e.g. Field Hand, Supervisor', Icons.work_outline,
                validator: (v) => v == null || v.isEmpty ? 'Required' : null),
            const SizedBox(height: 20),

            _buildLabel('Daily Wage (₹)'),
            _buildField(_wageController, 'e.g. 600', Icons.payments_outlined,
                keyboardType: TextInputType.number,
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Required';
                  if (double.tryParse(v) == null) return 'Enter a valid number';
                  return null;
                }),
            const SizedBox(height: 40),

            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _handleSave,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryGreen,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                child: _isLoading
                    ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : Text('Save Labour', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(text, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textSecondary, letterSpacing: 0.8)),
    );
  }

  Widget _buildField(
    TextEditingController controller,
    String hint,
    IconData icon, {
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: validator,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: Icon(icon, color: AppColors.textSecondary, size: 18),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primaryGreen, width: 2)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        hintStyle: GoogleFonts.inter(color: AppColors.textHint, fontSize: 14),
      ),
      style: GoogleFonts.inter(fontSize: 14, color: AppColors.textPrimary),
    );
  }
}
