import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/app_colors.dart';

class ContactPickerScreen extends StatefulWidget {
  const ContactPickerScreen({super.key});

  @override
  State<ContactPickerScreen> createState() => _ContactPickerScreenState();
}

class _ContactPickerScreenState extends State<ContactPickerScreen> {
  List<Contact> _contacts = [];
  List<Contact> _filteredContacts = [];
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchContacts();
  }

  Future<void> _fetchContacts() async {
    try {
      final contacts = await FlutterContacts.getContacts(withProperties: true, withPhoto: true);
      if (mounted) {
        setState(() {
          _contacts = contacts;
          _filteredContacts = contacts;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error fetching contacts: $e')));
      }
    }
  }

  void _filterContacts(String query) {
    setState(() {
      _filteredContacts = _contacts
          .where((contact) =>
              contact.displayName.toLowerCase().contains(query.toLowerCase()) ||
              contact.phones.any((p) => p.number.contains(query)))
          .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          'Select Contact',
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
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              controller: _searchController,
              onChanged: _filterContacts,
              decoration: InputDecoration(
                hintText: 'Search contacts...',
                prefixIcon: const Icon(Icons.search, color: AppColors.primaryGreen),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
              ),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: AppColors.primaryGreen))
                : _filteredContacts.isEmpty
                    ? Center(
                        child: Text(
                          'No contacts found',
                          style: GoogleFonts.inter(color: AppColors.textSecondary),
                        ),
                      )
                    : ListView.builder(
                        itemCount: _filteredContacts.length,
                        itemBuilder: (context, index) {
                          final contact = _filteredContacts[index];
                          final phone = contact.phones.isNotEmpty ? contact.phones.first.number : 'No number';
                          
                          return ListTile(
                            onTap: () {
                              if (contact.phones.isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Selected contact has no mobile number')),
                                );
                                return;
                              }
                              Navigator.pop(context, {
                                'name': contact.displayName,
                                'phone': phone,
                              });
                            },
                            leading: CircleAvatar(
                              backgroundColor: AppColors.primaryGreen.withValues(alpha: 0.1),
                              child: contact.photo != null
                                  ? ClipOval(child: Image.memory(contact.photo!, fit: BoxFit.cover, width: 40, height: 40))
                                  : Text(
                                      contact.displayName.isNotEmpty ? contact.displayName[0].toUpperCase() : '?',
                                      style: GoogleFonts.inter(color: AppColors.primaryGreen, fontWeight: FontWeight.bold),
                                    ),
                            ),
                            title: Text(
                              contact.displayName,
                              style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                            ),
                            subtitle: Text(
                              phone,
                              style: GoogleFonts.inter(color: AppColors.textSecondary, fontSize: 13),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
