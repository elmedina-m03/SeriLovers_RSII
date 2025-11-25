import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dim.dart';

/// Admin button widget with consistent styling
class AdminButton extends StatelessWidget {
  /// Button text
  final String text;
  
  /// Callback when button is pressed
  final VoidCallback? onPressed;
  
  /// Optional width
  final double? width;
  
  /// Optional height
  final double? height;

  const AdminButton({
    super.key,
    required this.text,
    this.onPressed,
    this.width,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryColor,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDim.borderRadius),
          ),
        ),
        child: Text(text),
      ),
    );
  }
}

