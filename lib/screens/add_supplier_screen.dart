import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:permission_handler/permission_handler.dart';
import '../core/app_colors.dart';
import '../models/supplier_model.dart';
import '../services/supplier_service.dart';
import '../services/token_service.dart';
import 'contact_picker_screen.dart';
import '../widgets/phone_field_with_country.dart';

class AddSupplierScreen extends StatefulWidget {
  const AddSupplierScreen({super.key});

  @override
  State<AddSupplierScreen> createState() => _AddSupplierScreenState();
}

class _AddSupplierScreenState extends State<AddSupplierScreen> {
  final _nameCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _openingBalanceCtrl = TextEditingController();
  
  String _fullPhoneNumber = '';
  String? _initialPhone; // for prefilling from contacts
  
  bool _isLoading = false;
  bool _showSelectionMode = true;
  late SupplierService _service;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final ts = await TokenService.getInstance();
    _service = SupplierService(ts);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _addressCtrl.dispose();
    _openingBalanceCtrl.dispose();
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
          _nameCtrl.text = result['name'] ?? '';
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

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty || _fullPhoneNumber.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Name and phone are required')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final opBal = double.tryParse(_openingBalanceCtrl.text.trim()) ?? 0.0;
      final supplier = SupplierModel(
        name: name,
        phone: _fullPhoneNumber,
        address: _addressCtrl.text.trim(),
        openingBalance: opBal,
      );
      await _service.addSupplier(supplier);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Supplier added successfully'), backgroundColor: Colors.green),
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
        title: Text(
          'Add Supplier',
          style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Colors.purple),
        ),
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
              color: Colors.purple,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'How would you like to add the supplier?',
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
            color: Colors.purple.withValues(alpha: 0.1),
            iconColor: Colors.purple,
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
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'NEW VENDOR',
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Colors.purple,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          RichText(
            text: TextSpan(
              style: GoogleFonts.inter(
                fontSize: 40,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
                height: 1.15,
              ),
              children: [
                const TextSpan(text: 'Add your\n'),
                TextSpan(
                  text: 'Supplier.',
                  style: GoogleFonts.inter(color: Colors.purple),
                ),
              ],
            ),
          ),
          const SizedBox(height: 48),
          _buildField('Supplier Name', 'e.g. Raja Trading Co.', _nameCtrl),
          Padding(
            padding: const EdgeInsets.only(bottom: 28),
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
                  focusColor: Colors.purple,
                  onChanged: (phone) {
                    _fullPhoneNumber = phone.completeNumber;
                  },
                ),
              ],
            ),
          ),
          _buildField('Address (Optional)', 'Street, City', _addressCtrl),
          _buildField('Opening Balance (Optional)', '0.00', _openingBalanceCtrl,
              type: TextInputType.number),
          const SizedBox(height: 32),
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
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.inventory_2_outlined),
              label: Text(
                _isLoading ? 'Saving...' : 'Save Supplier',
                style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildField(String label, String hint, TextEditingController ctrl,
      {TextInputType type = TextInputType.text}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: GoogleFonts.inter(
                  fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
          const SizedBox(height: 4),
          TextField(
            controller: ctrl,
            keyboardType: type,
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: GoogleFonts.inter(fontSize: 18, color: AppColors.textHint),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
              enabledBorder: const UnderlineInputBorder(
                  borderSide: BorderSide(color: AppColors.border, width: 1.5)),
              focusedBorder: const UnderlineInputBorder(
                  borderSide: BorderSide(color: Colors.purple, width: 2)),
            ),
            style: GoogleFonts.inter(fontSize: 18, color: AppColors.textPrimary),
          ),
        ],
      ),
    );
  }
}
