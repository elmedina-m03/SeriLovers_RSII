import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dim.dart';
import '../../providers/auth_provider.dart';
import '../../core/widgets/image_with_placeholder.dart';

/// Admin sidebar widget with vertical menu items
class AdminSidebar extends StatelessWidget {
  /// Currently selected menu index (0-6)
  final int selectedIndex;
  
  /// Callback when a menu item is tapped
  final Function(int) onItemSelected;

  const AdminSidebar({
    super.key,
    required this.selectedIndex,
    required this.onItemSelected,
  });

  /// Get user info from JWT token
  Map<String, String?> _getUserInfo(String? token) {
    if (token == null || token.isEmpty) {
      return {'email': 'Unknown', 'role': 'Unknown', 'avatarUrl': null};
    }
    
    try {
      final decodedToken = JwtDecoder.decode(token);
      
      // Get user display name - try multiple claim names
      // Priority: name (username) > email > sub (user ID)
      String? displayName = decodedToken['name'] as String?;
      if (displayName == null || displayName.isEmpty) {
        displayName = decodedToken['email'] as String?;
      }
      if (displayName == null || displayName.isEmpty) {
        // Try sub (user ID) as last resort
        final sub = decodedToken['sub'] as String?;
        if (sub != null) {
          displayName = 'User $sub';
        }
      }
      displayName ??= 'Unknown';
      
      // Get role - handle both string and list
      String role = 'User';
      dynamic roleClaim = decodedToken['role'];
      if (roleClaim is String) {
        role = roleClaim;
      } else if (roleClaim is List && roleClaim.isNotEmpty) {
        // Get first role or Admin if available
        if (roleClaim.contains('Admin')) {
          role = 'Admin';
        } else {
          role = roleClaim[0].toString();
        }
      } else {
        // Try alternative claim name
        final altRoleClaim = decodedToken['http://schemas.microsoft.com/ws/2008/06/identity/claims/role'];
        if (altRoleClaim is String) {
          role = altRoleClaim;
        } else if (altRoleClaim is List && altRoleClaim.isNotEmpty) {
          if (altRoleClaim.contains('Admin')) {
            role = 'Admin';
          } else {
            role = altRoleClaim[0].toString();
          }
        }
      }
      
      final avatarUrl = decodedToken['avatarUrl'] as String?;
      return {'email': displayName, 'role': role, 'avatarUrl': avatarUrl};
    } catch (e) {
      return {'email': 'Unknown', 'role': 'Unknown', 'avatarUrl': null};
    }
  }

  /// Get initials from email or name
  String _getInitials(String email) {
    if (email == 'Unknown') return 'U';
    final parts = email.split('@');
    if (parts.isNotEmpty) {
      final namePart = parts[0];
      if (namePart.length >= 2) {
        return namePart.substring(0, 2).toUpperCase();
      }
      return namePart[0].toUpperCase();
    }
    return 'U';
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final userInfo = _getUserInfo(authProvider.token);
    final initials = _getInitials(userInfo['email']!);
    
    return Container(
      width: AppDim.sidebarWidth,
      color: AppColors.sidebarColor,
      child: Column(
        children: [
          // Menu Items (logo is now above sidebar in AdminScreen)
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              children: [
                _buildMenuItem(0, Icons.home, 'Home'),
                const SizedBox(height: 12),
                _buildMenuItem(1, Icons.movie, 'Series'),
                const SizedBox(height: 12),
                _buildMenuItem(2, Icons.people, 'Users'),
                const SizedBox(height: 12),
                _buildMenuItem(3, Icons.person, 'Actors'),
                const SizedBox(height: 12),
                _buildMenuItem(4, Icons.emoji_events, 'Challenges'),
                const SizedBox(height: 12),
                _buildMenuItem(5, Icons.bar_chart, 'Statistics'),
                const SizedBox(height: 12),
                _buildMenuItem(6, Icons.rate_review, 'Reviews'),
              ],
            ),
          ),
          // User info and logout at bottom
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(
                  color: AppColors.textSecondary.withOpacity(0.2),
                  width: 1,
                ),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // User info with avatar
                Row(
                  children: [
                    // Circular avatar with image or initials
                    AvatarImage(
                      avatarUrl: userInfo['avatarUrl'],
                      radius: 18,
                      initials: initials,
                      placeholderIcon: Icons.person,
                    ),
                    const SizedBox(width: 10),
                    // User name and role
                    Flexible(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            userInfo['email']!,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            userInfo['role']!,
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.textSecondary,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Logout button (index 7)
                _buildMenuItem(7, Icons.logout, 'Logout', isDestructive: true),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Builds a single menu item
  Widget _buildMenuItem(
    int index,
    IconData icon,
    String label, {
    bool isDestructive = false,
  }) {
    final isSelected = selectedIndex == index;
    
    return InkWell(
      onTap: () => onItemSelected(index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primaryColor.withOpacity(0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(AppDim.radiusMedium),
          border: isSelected
              ? Border.all(
                  color: AppColors.primaryColor.withOpacity(0.3),
                  width: 1,
                )
              : null,
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 22,
              color: isSelected
                  ? AppColors.primaryColor
                  : (isDestructive ? AppColors.dangerColor : AppColors.iconColor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  color: isSelected
                      ? AppColors.primaryColor
                      : (isDestructive ? AppColors.dangerColor : AppColors.textPrimary),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

