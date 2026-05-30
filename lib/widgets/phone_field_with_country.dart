import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import 'package:intl_phone_field/phone_number.dart';
import '../core/app_colors.dart';

class PhoneFieldWithCountry extends StatelessWidget {
  final String? initialValue;
  final String hintText;
  final void Function(PhoneNumber)? onChanged;
  final bool autofocus;
  final Color focusColor;
  final InputDecoration? decoration;

  const PhoneFieldWithCountry({
    super.key,
    this.initialValue,
    this.hintText = 'Phone Number',
    this.onChanged,
    this.autofocus = false,
    this.focusColor = AppColors.primaryGreen,
    this.decoration,
  });

  @override
  Widget build(BuildContext context) {
    return IntlPhoneField(
      initialValue: initialValue,
      autofocus: autofocus,
      dropdownIconPosition: IconPosition.trailing,
      flagsButtonPadding: const EdgeInsets.only(right: 8),
      showDropdownIcon: true,
      decoration: decoration ?? InputDecoration(
        hintText: hintText,
        hintStyle: GoogleFonts.inter(fontSize: 18, color: AppColors.textHint),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(vertical: 12),
        enabledBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: AppColors.border, width: 1.5),
        ),
        focusedBorder: UnderlineInputBorder(
          borderSide: BorderSide(color: focusColor, width: 2.0),
        ),
        errorBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: Colors.red, width: 1.5),
        ),
        focusedErrorBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: Colors.red, width: 2.0),
        ),
      ),
      style: GoogleFonts.inter(fontSize: 18, color: AppColors.textPrimary),
      initialCountryCode: 'IN',
      onChanged: onChanged,
      keyboardType: TextInputType.phone,
    );
  }
}
