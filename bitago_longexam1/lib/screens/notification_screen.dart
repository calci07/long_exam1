import 'package:flutter/material.dart';
import '../widgets/custom_info.dart';

class NotificationScreen extends StatelessWidget {
  const NotificationScreen({super.key});
  @override
  Widget build(BuildContext context) => const CustomInfo(
    message: 'No notifications yet.',
    icon: Icons.notifications_none,
  );
}
