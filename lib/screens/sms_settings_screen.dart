import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/app_colors.dart';
import '../services/sms_settings_service.dart';

class SmsSettingsScreen extends StatefulWidget {
  const SmsSettingsScreen({super.key});

  @override
  State<SmsSettingsScreen> createState() => _SmsSettingsScreenState();
}

class _SmsSettingsScreenState extends State<SmsSettingsScreen> {
  final SmsSettingsService _smsService = SmsSettingsService();
  String _selectedMode = 'my_number';
  int _selectedSim = 0;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    await _smsService.init();
    setState(() {
      _selectedMode = _smsService.smsMode;
      _selectedSim = _smsService.simIndex;
    });
  }

  Future<void> _saveSettings() async {
    setState(() => _isSaving = true);
    await _smsService.saveSettings(mode: _selectedMode, simIndex: _selectedSim);
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Settings saved successfully'),
          backgroundColor: AppColors.primaryGreen,
          behavior: SnackBarBehavior.floating,
        ),
      );
      setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          'SMS Settings',
          style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: AppColors.primaryGreen),
        ),
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Send SMS from:',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Selection Cards
                  Row(
                    children: [
                      Expanded(
                        child: _buildModeCard(
                          id: 'my_number',
                          icon: Icons.phone_android_outlined,
                          title: 'My Number',
                          isSelected: _selectedMode == 'my_number',
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildModeCard(
                          id: 'bsm_sms',
                          icon: Icons.rocket_launch_outlined,
                          title: 'BSM SMS',
                          isSelected: _selectedMode == 'bsm_sms',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  
                  // Dynamic Content
                  if (_selectedMode == 'my_number') _buildMyNumberSection() else _buildBsmSmsSection(),
                ],
              ),
            ),
          ),
          
          // Fixed Save Button
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: ElevatedButton(
              onPressed: _isSaving ? null : _saveSettings,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryGreen,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(56),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
              child: _isSaving
                  ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : Text('SAVE', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModeCard({
    required String id,
    required IconData icon,
    required String title,
    required bool isSelected,
  }) {
    return InkWell(
      onTap: () => setState(() => _selectedMode = id),
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 24),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryGreen.withValues(alpha: 0.05) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.primaryGreen : Colors.white,
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 32,
              color: isSelected ? AppColors.primaryGreen : AppColors.textHint,
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isSelected ? AppColors.primaryGreen : AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMyNumberSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Select SIM card for SMS',
          style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<int>(
              value: _selectedSim,
              isExpanded: true,
              items: const [
                DropdownMenuItem(value: 0, child: Text('Default')),
                DropdownMenuItem(value: 1, child: Text('SIM 1')),
                DropdownMenuItem(value: 2, child: Text('SIM 2')),
              ],
              onChanged: (val) {
                if (val != null) setState(() => _selectedSim = val);
              },
            ),
          ),
        ),
        const SizedBox(height: 32),
        _buildBenefitList([
          'SMS automatically sent with each entry',
          'Customer receives SMS from your trusted number',
          'Complete details with SMS',
        ]),
        const SizedBox(height: 32),
        _buildPreviewCard(
          title: 'Hi, Entry added for ₹200',
          balance: 'Balance: ₹500',
          footer: 'Max SMS Limit: As per your mobile plan',
        ),
      ],
    );
  }

  Widget _buildBsmSmsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Limit Card
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF277533), Color(0xFF1B5E20)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: AppColors.primaryGreen.withValues(alpha: 0.3),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Free SMS limit card',
                style: GoogleFonts.inter(color: Colors.white.withValues(alpha: 0.8), fontSize: 12),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '0 SMS sent',
                        style: GoogleFonts.inter(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'this month',
                        style: GoogleFonts.inter(color: Colors.white.withValues(alpha: 0.7), fontSize: 14),
                      ),
                    ],
                  ),
                  Container(
                    height: 40,
                    width: 1,
                    color: Colors.white.withValues(alpha: 0.2),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '100 Monthly',
                        style: GoogleFonts.inter(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'SMS limit',
                        style: GoogleFonts.inter(color: Colors.white.withValues(alpha: 0.7), fontSize: 14),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),
        _buildBenefitList([
          'SMS received from BSM number',
          'Limited details on basic SMS',
          'Can be marked promotional',
        ], icon: Icons.info_outline),
        const SizedBox(height: 32),
        _buildPreviewCard(
          title: 'You gave: ₹400',
          balance: 'Balance: ₹200\nSent by: BSM Agro',
          footer: 'Max SMS Limit: 100/month',
          isBsm: true,
        ),
      ],
    );
  }

  Widget _buildBenefitList(List<String> benefits, {IconData icon = Icons.check_circle_outline}) {
    return Column(
      children: benefits.map((b) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          children: [
            Icon(icon, color: AppColors.primaryGreen, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                b,
                style: GoogleFonts.inter(fontSize: 14, color: AppColors.textPrimary),
              ),
            ),
          ],
        ),
      )).toList(),
    );
  }

  Widget _buildPreviewCard({
    required String title,
    required String balance,
    required String footer,
    bool isBsm = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'SMS PREVIEW',
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: AppColors.textHint,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 15),
              ),
              const SizedBox(height: 8),
              Text(
                balance,
                style: GoogleFonts.inter(color: AppColors.textSecondary, fontSize: 14),
              ),
              const SizedBox(height: 12),
              Text(
                'Check history:',
                style: GoogleFonts.inter(color: AppColors.textSecondary, fontSize: 13),
              ),
              Text(
                'https://bsm.com/t/XXX',
                style: GoogleFonts.inter(color: Colors.blue, fontSize: 13, decoration: TextDecoration.underline),
              ),
              const SizedBox(height: 12),
              Text(
                'Thank you\nBSM Agro',
                style: GoogleFonts.inter(color: AppColors.textSecondary, fontSize: 13),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Center(
          child: Text(
            footer,
            style: GoogleFonts.inter(fontSize: 12, color: AppColors.textHint, fontWeight: FontWeight.w500),
          ),
        ),
      ],
    );
  }
}
