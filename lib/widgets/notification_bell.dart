import 'package:flutter/material.dart';
import '../core/app_colors.dart';
import '../screens/notifications_screen.dart';

class NotificationBell extends StatelessWidget {
  final Color? color;

  const NotificationBell({
    super.key,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(
        Icons.notifications,
        color: color ?? AppColors.primaryGreen,
      ),
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const NotificationsScreen()),
        );
      },
      tooltip: 'Notifications',
    );
  }
}
