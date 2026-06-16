import 'package:flutter/material.dart';
import '../core/app_colors.dart';
import 'package:google_fonts/google_fonts.dart';
import '../screens/customer_details_screen.dart';
enum CustomerType { wholesale, overdue, none }

class CustomerCard extends StatelessWidget {
  final String? id;
  final String name;
  final String role;
  final String phone;
  final double balance;
  final CustomerType type;
  final bool isLedger;
  final bool showAvatar;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onViewDetailsClosed;


  const CustomerCard({
    super.key,
    this.id,
    required this.name,
    required this.role,
    required this.phone,
    required this.balance,
    this.type = CustomerType.none,
    this.isLedger = true,
    this.showAvatar = false,
    this.onEdit,
    this.onDelete,
    this.onViewDetailsClosed,
  });

  @override
  Widget build(BuildContext context) {
    // balance > 0  → customer owes us money (Pending)
    // balance < 0  → customer has overpaid (Advance)
    // balance == 0 → settled (Clear)
    final isPending = balance > 0;
    final isAdvance = balance < 0;
    final pendingAmount  = isPending ? balance : 0.0;
    final advanceAmount  = isAdvance ? balance.abs() : 0.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                role.toUpperCase(),
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.0,
                  color: AppColors.textSecondary,
                ),
              ),
              if (type != CustomerType.none)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: type == CustomerType.wholesale
                        ? AppColors.wholesaleBadgeBg
                        : AppColors.overdueBadgeBg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    type == CustomerType.wholesale ? 'WHOLESALE' : 'OVERDUE',
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: type == CustomerType.wholesale
                          ? AppColors.wholesaleBadgeText
                          : AppColors.overdueBadgeText,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              if (showAvatar) ...[
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.green.shade200,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.person, color: AppColors.primaryGreen),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        if (!showAvatar)
                          const Icon(
                            Icons.phone,
                            size: 14,
                            color: AppColors.textSecondary,
                          ),
                        if (!showAvatar) const SizedBox(width: 4),
                        Text(
                          phone,
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (isLedger)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Pending balance column
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'PENDING',
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '₹${pendingAmount.toStringAsFixed(0)}',
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: isPending ? Colors.red.shade700 : AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  // Divider
                  Container(
                    width: 1,
                    height: 32,
                    color: Colors.grey.shade200,
                  ),
                  // Advance balance column
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'ADVANCE',
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '₹${advanceAmount.toStringAsFixed(0)}',
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: isAdvance ? AppColors.primaryGreen : AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            )
          else
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isPending ? 'PENDING' : (isAdvance ? 'ADVANCE' : 'BALANCE'),
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      '₹${(isPending ? pendingAmount : (isAdvance ? advanceAmount : 0.0)).toStringAsFixed(0)}',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isPending ? Colors.red.shade700 : AppColors.primaryGreen,
                      ),
                    ),
                  ],
                ),
                ElevatedButton(
                  onPressed: () {},
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey.shade200,
                    foregroundColor: AppColors.textPrimary,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(
                    'Collect Payment',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          if (isLedger) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () async {
                      if (id != null) {
                        final result = await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => CustomerDetailsScreen(customerId: id!),
                          ),
                        );
                        if (result == true && onViewDetailsClosed != null) {
                          onViewDetailsClosed!();
                        }
                      }
                    },
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.transparent),
                    ),
                    child: Text(
                      'View Details',
                      style: GoogleFonts.inter(
                        color: AppColors.primaryGreen,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                if (onEdit != null || onDelete != null)
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert, color: AppColors.textPrimary),
                    onSelected: (value) {
                      if (value == 'edit') {
                        onEdit?.call();
                      } else if (value == 'delete') {
                        onDelete?.call();
                      }
                    },
                    itemBuilder: (context) => [
                      if (onEdit != null)
                        PopupMenuItem(
                          value: 'edit',
                          child: Row(
                            children: [
                              const Icon(Icons.edit, size: 20, color: AppColors.textPrimary),
                              const SizedBox(width: 12),
                              Text('Edit', style: GoogleFonts.inter()),
                            ],
                          ),
                        ),
                      if (onDelete != null)
                        PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              const Icon(Icons.delete, size: 20, color: Colors.red),
                              const SizedBox(width: 12),
                              Text('Delete', style: GoogleFonts.inter(color: Colors.red)),
                            ],
                          ),
                        ),
                    ],
                  )
                else
                  IconButton(
                    icon: const Icon(Icons.more_vert),
                    onPressed: () {},
                    color: AppColors.textPrimary,
                  ),
              ],
            ),
          ]
        ],
      ),
    );
  }
}
