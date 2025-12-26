import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Shared configuration for admin DataTables
/// Ensures consistent, compact sizing across all admin screens
class AdminDataTableConfig {
  // Row heights - compact but readable
  static const double headingRowHeight = 40.0;
  static const double dataRowMinHeight = 40.0;
  static const double dataRowMaxHeight = 52.0;

  // Font sizes - slightly reduced for compactness
  static const double headingFontSize = 13.0;
  static const double cellFontSize = 12.0;
  static const double cellSmallFontSize = 11.0;

  // Icon sizes - compact
  static const double actionIconSize = 18.0;
  static const double actionButtonSize = 36.0;

  // Padding - reduced
  static const EdgeInsets cellPadding = EdgeInsets.symmetric(horizontal: 8, vertical: 4);

  /// Get standard DataTable properties for admin screens
  static Map<String, dynamic> getTableProperties() {
    return {
      'headingRowHeight': headingRowHeight,
      'dataRowMinHeight': dataRowMinHeight,
      'dataRowMaxHeight': dataRowMaxHeight,
      'headingRowColor': MaterialStateProperty.all(AppColors.cardBackground),
      'dataRowColor': MaterialStateProperty.all(AppColors.cardBackground),
    };
  }

  /// Get compact text style for table cells
  static TextStyle getCellTextStyle(TextTheme textTheme) {
    return textTheme.bodyMedium?.copyWith(
      fontSize: cellFontSize,
    ) ?? TextStyle(fontSize: cellFontSize);
  }

  /// Get compact small text style for table cells
  static TextStyle getCellSmallTextStyle(TextTheme textTheme) {
    return textTheme.bodySmall?.copyWith(
      fontSize: cellSmallFontSize,
    ) ?? TextStyle(fontSize: cellSmallFontSize);
  }

  /// Get compact heading text style
  static TextStyle getHeadingTextStyle(TextTheme textTheme) {
    return textTheme.titleSmall?.copyWith(
      fontSize: headingFontSize,
      fontWeight: FontWeight.w600,
    ) ?? TextStyle(fontSize: headingFontSize, fontWeight: FontWeight.w600);
  }

  /// Get compact DataColumn label
  static Widget getColumnLabel(String text, {bool numeric = false}) {
    return Text(
      text,
      style: TextStyle(
        fontSize: headingFontSize,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

