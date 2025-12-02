import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dim.dart';
import '../../models/series.dart';
import '../../core/widgets/image_with_placeholder.dart';

/// Screen showing extended series description with image on top
class MobileSeriesDescriptionScreen extends StatelessWidget {
  final Series series;

  const MobileSeriesDescriptionScreen({
    super.key,
    required this.series,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textLight),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          series.title,
          style: const TextStyle(color: AppColors.textLight),
        ),
        backgroundColor: AppColors.primaryColor,
        foregroundColor: AppColors.textLight,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Big Series Image on Top
            Container(
              width: double.infinity,
              height: 300,
              decoration: BoxDecoration(
                color: AppColors.primaryColor.withOpacity(0.1),
              ),
              child: ImageWithPlaceholder(
                imageUrl: series.imageUrl,
                width: double.infinity,
                height: double.infinity,
                fit: BoxFit.cover,
                placeholderIcon: Icons.movie,
                placeholderIconSize: 80,
                placeholderBackgroundColor: AppColors.primaryColor,
              ),
            ),
            
            // Extended Description
            Padding(
              padding: const EdgeInsets.all(AppDim.paddingLarge),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Series Title
                  Text(
                    series.title,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: AppDim.paddingMedium),
                  
                  // Extended Description
                  if (series.description != null && series.description!.isNotEmpty)
                    Text(
                      series.description!,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: AppColors.textPrimary,
                        height: 1.6,
                        fontSize: 16,
                      ),
                    )
                  else
                    Text(
                      'No description available for this series.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

