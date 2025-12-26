import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../theme/app_colors.dart';

/// Reusable widget for displaying images with a placeholder icon
/// Shows the image if available, otherwise shows a purple icon placeholder
class ImageWithPlaceholder extends StatelessWidget {
  /// The image URL (can be null or empty)
  final String? imageUrl;
  
  /// Width of the image
  final double? width;
  
  /// Height of the image
  final double? height;
  
  /// BoxFit for the image
  final BoxFit fit;
  
  /// Border radius for the image container
  final double borderRadius;
  
  /// Placeholder icon to show when no image
  final IconData placeholderIcon;
  
  /// Size of the placeholder icon
  final double placeholderIconSize;
  
  /// Background color for placeholder
  final Color? placeholderBackgroundColor;
  
  /// Whether this is a circular image (for avatars)
  final bool isCircular;
  
  /// Radius for circular images
  final double? radius;

  const ImageWithPlaceholder({
    super.key,
    this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius = 0,
    this.placeholderIcon = Icons.image,
    this.placeholderIconSize = 40,
    this.placeholderBackgroundColor,
    this.isCircular = false,
    this.radius,
  });

  /// Builds the full image URL from relative path with cache busting
  String? _getFullImageUrl() {
    // Trim and check for null/empty
    final trimmedUrl = imageUrl?.trim();
    if (trimmedUrl == null || trimmedUrl.isEmpty) {
      return null;
    }
    
    String finalUrl;
    
    // Handle file:// URLs - convert to HTTP URL
    if (trimmedUrl.startsWith('file://')) {
      // Extract the path from file:// URL (e.g., file:///uploads/avatars/... -> /uploads/avatars/...)
      var path = trimmedUrl.replaceFirst('file://', '');
      // Remove leading slashes if present (file:///uploads -> /uploads, but we want /uploads)
      if (path.startsWith('//')) {
        path = path.substring(1);
      }
      
      // Convert to HTTP URL using base URL
      var baseUrl = ApiService().baseUrl;
      if (baseUrl.isNotEmpty) {
        // Remove /api from the end of base URL if present (static files are at root, not /api)
        if (baseUrl.endsWith('/api')) {
          baseUrl = baseUrl.substring(0, baseUrl.length - 4);
        } else if (baseUrl.endsWith('/api/')) {
          baseUrl = baseUrl.substring(0, baseUrl.length - 5);
        }
        // Ensure path starts with /
        if (!path.startsWith('/')) {
          path = '/$path';
        }
        finalUrl = '$baseUrl$path';
      } else {
        // Fallback: if no base URL configured, treat as relative path
        finalUrl = path.startsWith('/') ? path : '/$path';
      }
    }
    // If already a full URL, use as is
    else if (trimmedUrl.startsWith('http://') || trimmedUrl.startsWith('https://')) {
      finalUrl = trimmedUrl;
    } else if (trimmedUrl.startsWith('/')) {
      // If it's a relative path (starts with /), prepend base URL
      // Note: Static files are served from root, not from /api, so we need to remove /api from base URL
      var baseUrl = ApiService().baseUrl;
      if (baseUrl.isNotEmpty) {
        // Remove /api from the end of base URL if present (static files are at root, not /api)
        if (baseUrl.endsWith('/api')) {
          baseUrl = baseUrl.substring(0, baseUrl.length - 4);
        } else if (baseUrl.endsWith('/api/')) {
          baseUrl = baseUrl.substring(0, baseUrl.length - 5);
        }
        finalUrl = '$baseUrl$trimmedUrl';
      } else {
        // Fallback: if no base URL configured, return as is
        finalUrl = trimmedUrl;
      }
    } else {
      // Otherwise return as is (might be a full URL without protocol)
      finalUrl = trimmedUrl;
    }
    
    // Add cache-busting query parameter based on URL hash (only changes when URL changes)
    final separator = finalUrl.contains('?') ? '&' : '?';
    return '$finalUrl${separator}v=${finalUrl.hashCode}';
  }

  /// Builds placeholder widget
  Widget _buildPlaceholder() {
    final bgColor = placeholderBackgroundColor ?? 
                   AppColors.primaryColor.withOpacity(0.2);
    
    if (isCircular) {
      return CircleAvatar(
        radius: radius ?? (height != null ? height! / 2 : 20),
        backgroundColor: bgColor,
        child: Icon(
          placeholderIcon,
          size: placeholderIconSize,
          color: AppColors.primaryColor,
        ),
      );
    }
    
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      child: Center(
        child: Icon(
          placeholderIcon,
          size: placeholderIconSize,
          color: AppColors.primaryColor,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final fullImageUrl = _getFullImageUrl();
    
    // If no image URL, show placeholder
    if (fullImageUrl == null) {
      return _buildPlaceholder();
    }
    
    // Build image widget
    Widget imageWidget = Image.network(
      fullImageUrl,
      width: width,
      height: height,
      fit: fit,
      errorBuilder: (context, error, stackTrace) {
        return _buildPlaceholder();
      },
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: AppColors.primaryColor.withOpacity(0.1),
            borderRadius: isCircular 
                ? null 
                : BorderRadius.circular(borderRadius),
          ),
          child: Center(
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(
                AppColors.primaryColor,
              ),
            ),
          ),
        );
      },
    );
    
    // Apply circular clipping if needed
    if (isCircular) {
      return ClipOval(
        child: imageWidget,
      );
    }
    
    // Apply border radius if specified
    if (borderRadius > 0) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: imageWidget,
      );
    }
    
    return imageWidget;
  }
}

/// Specialized widget for user avatars
class AvatarImage extends StatelessWidget {
  final String? avatarUrl;
  final double radius;
  final String? initials;
  final IconData placeholderIcon;

  const AvatarImage({
    super.key,
    this.avatarUrl,
    this.radius = 20,
    this.initials,
    this.placeholderIcon = Icons.person,
  });

  @override
  Widget build(BuildContext context) {
    // If we have initials and no avatar, show initials
    if ((avatarUrl == null || avatarUrl!.isEmpty) && initials != null) {
      return CircleAvatar(
        key: ValueKey('avatar_initials_$initials'),
        radius: radius,
        backgroundColor: AppColors.primaryColor,
        child: Text(
          initials!,
          style: TextStyle(
            color: AppColors.textLight,
            fontWeight: FontWeight.bold,
            fontSize: radius * 0.6,
          ),
        ),
      );
    }
    
    // Otherwise use ImageWithPlaceholder with key based on avatarUrl to force rebuild
    return ImageWithPlaceholder(
      key: ValueKey('avatar_${avatarUrl ?? 'none'}'),
      imageUrl: avatarUrl,
      isCircular: true,
      radius: radius,
      placeholderIcon: placeholderIcon,
      placeholderIconSize: radius * 0.8,
    );
  }
}

