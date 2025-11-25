import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dim.dart';

/// Challenges management screen placeholder
class ChallengesManagementScreen extends StatefulWidget {
  const ChallengesManagementScreen({super.key});

  @override
  State<ChallengesManagementScreen> createState() => _ChallengesManagementScreenState();
}

class _ChallengesManagementScreenState extends State<ChallengesManagementScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      body: const Center(
        child: Text('Challenges Management'),
      ),
    );
  }
}

