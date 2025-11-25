import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dim.dart';

/// Actors management screen placeholder
class ActorsManagementScreen extends StatefulWidget {
  const ActorsManagementScreen({super.key});

  @override
  State<ActorsManagementScreen> createState() => _ActorsManagementScreenState();
}

class _ActorsManagementScreenState extends State<ActorsManagementScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      body: const Center(
        child: Text('Actors Management'),
      ),
    );
  }
}

