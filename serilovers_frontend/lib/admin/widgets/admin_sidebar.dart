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
      final email = decodedToken['email'] as String? ?? decodedToken['sub'] as String? ?? 'Unknown';
      final role = decodedToken['role'] as String? ?? 
                   (decodedToken['http://schemas.microsoft.com/ws/2008/06/identity/claims/role'] as String?) ?? 
                   'User';
      final avatarUrl = decodedToken['avatarUrl'] as String?;
      return {'email': email, 'role': role, 'avatarUrl': avatarUrl};
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
          // Menu Items
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                _buildMenuItem(0, Icons.home, 'Home'),
                const SizedBox(height: 20),
                _buildMenuItem(1, Icons.movie, 'Series'),
                const SizedBox(height: 20),
                _buildMenuItem(2, Icons.people, 'Users'),
                const SizedBox(height: 20),
                _buildMenuItem(3, Icons.person, 'Actors'),
                const SizedBox(height: 20),
                _buildMenuItem(4, Icons.emoji_events, 'Challenges'),
                const SizedBox(height: 20),
                _buildMenuItem(5, Icons.bar_chart, 'Statistics'),
              ],
            ),
          ),
          // User info and logout at bottom
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(
                  color: AppColors.textSecondary.withOpacity(0.2),
                  width: 1,
                ),
              ),
            ),
            child: Column(
              children: [
                // User info with avatar
                Row(
                  children: [
                    // Circular avatar with image or initials
                    AvatarImage(
                      avatarUrl: userInfo['avatarUrl'],
                      radius: 20,
                      initials: initials,
                      placeholderIcon: Icons.person,
                    ),
                    const SizedBox(width: 12),
                    // User name and role
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            userInfo['email']!,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            userInfo['role']!,
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Logout button
                _buildMenuItem(6, Icons.logout, 'Logout', isDestructive: true),
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
        padding: const EdgeInsets.only(left: 20, right: 16, top: 12, bottom: 12),
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
              size: 24,
              color: isSelected
                  ? AppColors.primaryColor
                  : (isDestructive ? AppColors.dangerColor : AppColors.iconColor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 16,
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

