import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dim.dart';

/// Series management screen placeholder
class SeriesManagementScreen extends StatefulWidget {
  const SeriesManagementScreen({super.key});

  @override
  State<SeriesManagementScreen> createState() => _SeriesManagementScreenState();
}

class _SeriesManagementScreenState extends State<SeriesManagementScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      body: const Center(
        child: Text('Series Management'),
      ),
    );
  }
}

