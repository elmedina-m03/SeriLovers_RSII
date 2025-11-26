import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dim.dart';

/// Mobile category detail screen showing series for a specific genre
class MobileCategoryDetailScreen extends StatelessWidget {
  final String genre;

  const MobileCategoryDetailScreen({
    super.key,
    required this.genre,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      appBar: AppBar(
        title: Text(genre),
        backgroundColor: AppColors.primaryColor,
        foregroundColor: AppColors.textLight,
        elevation: 0,
      ),
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.category,
                size: 64,
                color: AppColors.primaryColor.withOpacity(0.5),
              ),
              const SizedBox(height: AppDim.paddingMedium),
              Text(
                'Series in $genre',
                style: theme.textTheme.titleLarge?.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: AppDim.paddingSmall),
              Text(
                'Coming soon...',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

