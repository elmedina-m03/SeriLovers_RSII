import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_colors.dart';

/// Admin top bar widget
class AdminTopbar extends StatelessWidget {
  /// Title text to display
  final String title;
  
  /// Optional action widget (e.g., Add button) to display on the right
  final Widget? action;

  const AdminTopbar({
    super.key,
    required this.title,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Container(
      height: 72,
      color: AppColors.primaryColor,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Title only (logo is now in top-left corner above sidebar)
          Text(
            title,
            style: theme.textTheme.titleLarge!.copyWith(
              color: AppColors.textLight,
            ),
          ),
          if (action != null) action!,
        ],
      ),
    );
  }
}

