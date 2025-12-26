import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// SeriLovers logo widget
/// 
/// Displays the SeriLovers logo in either full (icon + text) or icon-only mode.
/// Supports both colored (for light backgrounds) and white (for purple backgrounds) versions.
class SeriLoversLogo extends StatelessWidget {
  /// Whether to show the full logo (icon + text) or just the icon
  final bool showFullLogo;
  
  /// Height of the logo (width will be calculated proportionally)
  final double height;
  
  /// Whether to use white version (for purple backgrounds)
  /// If true, uses white logos. If false, uses colored logos.
  final bool useWhiteVersion;

  const SeriLoversLogo({
    super.key,
    this.showFullLogo = true,
    this.height = 40,
    this.useWhiteVersion = false,
  });

  @override
  Widget build(BuildContext context) {
    String assetPath;
    
    if (useWhiteVersion) {
      assetPath = showFullLogo
          ? 'assets/images/serilovers_logo_full_white.svg'
          : 'assets/images/serilovers_logo_icon_white.svg';
    } else {
      assetPath = showFullLogo
          ? 'assets/images/serilovers_logo_full.svg'
          : 'assets/images/serilovers_logo_icon.svg';
    }
    
    return SvgPicture.asset(
      assetPath,
      height: height,
      fit: BoxFit.contain,
    );
  }
}

