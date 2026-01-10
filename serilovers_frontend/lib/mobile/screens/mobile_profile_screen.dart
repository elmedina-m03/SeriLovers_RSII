import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import '../../providers/auth_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dim.dart';
import '../../core/widgets/image_with_placeholder.dart';
import 'mobile_status_screen.dart';
import 'mobile_statistics_screen.dart';
import 'mobile_settings_screen.dart';

/// Mobile profile screen showing user info and logout button
class MobileProfileScreen extends StatefulWidget {
  const MobileProfileScreen({super.key});

  @override
  State<MobileProfileScreen> createState() => _MobileProfileScreenState();
}

class _MobileProfileScreenState extends State<MobileProfileScreen> {

  /// Get user info from JWT token
  Map<String, String?> _getUserInfo(String? token) {
    if (token == null || token.isEmpty) {
      return {'email': 'Unknown', 'name': 'Unknown User', 'avatarUrl': null};
    }

    try {
      final decodedToken = JwtDecoder.decode(token);
      final email = decodedToken['email'] as String? ?? 
                   decodedToken['sub'] as String? ?? 
                   'Unknown';
      
      // Try to get name from token claim first, otherwise extract from email
      String name = decodedToken['name'] as String? ?? '';
      if (name.isEmpty) {
        if (email != 'Unknown') {
          final parts = email.split('@');
          if (parts.isNotEmpty) {
            final namePart = parts[0];
            // Capitalize first letter
            name = namePart[0].toUpperCase() + namePart.substring(1);
          }
        } else {
          name = 'User';
        }
      }
      
      final avatarUrl = decodedToken['avatarUrl'] as String?;
      return {'email': email, 'name': name, 'avatarUrl': avatarUrl};
    } catch (e) {
      return {'email': 'Unknown', 'name': 'Unknown User', 'avatarUrl': null};
    }
  }

  /// Prefer user info from AuthProvider.currentUser (fresh from backend),
  /// falling back to decoding the JWT if no cached user object is available.
  Map<String, String?> _getUserInfoFromAuth(AuthProvider authProvider) {
    final current = authProvider.currentUser;
    if (current != null) {
      final email = (current['email'] as String?) ??
          (current['userName'] as String?) ??
          'Unknown';

      String name = (current['name'] as String?) ?? '';
      if (name.isEmpty) {
        if (email != 'Unknown') {
          final parts = email.split('@');
          if (parts.isNotEmpty) {
            final namePart = parts[0];
            name = namePart[0].toUpperCase() + namePart.substring(1);
          }
        } else {
          name = 'User';
        }
      }

      final avatarUrl = current['avatarUrl'] as String?;
      return {
        'email': email,
        'name': name,
        'avatarUrl': avatarUrl,
      };
    }

    // Fallback: derive from token as before
    return _getUserInfo(authProvider.token);
  }

  /// Try to read joined date from JWT token if available
  DateTime? _getJoinedDate(String? token) {
    if (token == null || token.isEmpty) return null;
    try {
      final decoded = JwtDecoder.decode(token);
      final raw = decoded['dateCreated'] ?? decoded['createdAt'];
      if (raw == null) return null;

      if (raw is String) {
        // Expecting ISO 8601 string
        return DateTime.tryParse(raw);
      }
      if (raw is int) {
        // Assume seconds since epoch
        return DateTime.fromMillisecondsSinceEpoch(raw * 1000, isUtc: true).toLocal();
      }
    } catch (_) {
      return null;
    }
    return null;
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

  Future<void> _handleLogout(BuildContext context) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDim.radiusMedium),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              'Cancel',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryColor,
              foregroundColor: AppColors.textLight,
            ),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      await authProvider.logout();
      
      // Navigate to login screen
      if (context.mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil(
          '/mobile_login',
          (route) => false,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      appBar: AppBar(
        title: const Text('Profile'),
        backgroundColor: AppColors.primaryColor,
        foregroundColor: AppColors.textLight,
        elevation: 0,
        automaticallyImplyLeading: false, // No back button on profile screen
      ),
      body: SafeArea(
        child: Consumer<AuthProvider>(
          builder: (context, authProvider, child) {
            // Use freshly cached backend user data when available
            final userInfo = _getUserInfoFromAuth(authProvider);
            final initials = _getInitials(userInfo['email']!);
            final joinedDate = _getJoinedDate(authProvider.token);

            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                horizontal: AppDim.paddingLarge,
                vertical: AppDim.paddingMedium,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: AppDim.paddingSmall),

                  // User Avatar Circle
                  ClipOval(
                    child: ImageWithPlaceholder(
                      imageUrl: userInfo['avatarUrl'],
                      width: 75,
                      height: 75,
                      fit: BoxFit.cover,
                      placeholderIcon: Icons.person,
                      placeholderIconSize: 38,
                    ),
                  ),

                  const SizedBox(height: AppDim.paddingMedium),

                  // User Name
                  Text(
                    userInfo['name']!,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: AppDim.paddingSmall),

                  // Username (from email)
                  Text(
                    '@${userInfo['email']!.split('@')[0]}',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),

                  const SizedBox(height: AppDim.paddingLarge),

                  // Menu Items
                  _buildMenuCard(
                    context,
                    theme,
                    icon: Icons.edit,
                    title: 'Edit Profile',
                    onTap: () async {
                      final result = await Navigator.pushNamed(
                        context,
                        '/mobile_edit_profile',
                      );
                      if (result == true && mounted) {
                        // After a successful edit, AuthProvider.updateUser has already
                        // updated token and currentUser and notified listeners.
                        // Force a rebuild to show updated profile data
                        setState(() {});
                      }
                    },
                  ),
                  
                  _buildMenuCard(
                    context,
                    theme,
                    icon: Icons.bookmark,
                    title: 'Status',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const MobileStatusScreen(),
                        ),
                      );
                    },
                  ),
                  
                  _buildMenuCard(
                    context,
                    theme,
                    icon: Icons.bar_chart,
                    title: 'Statistics',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const MobileStatisticsScreen(),
                        ),
                      );
                    },
                  ),
                  
                  _buildMenuCard(
                    context,
                    theme,
                    icon: Icons.settings,
                    title: 'Settings',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const MobileSettingsScreen(),
                        ),
                      );
                    },
                  ),
                  
                  _buildMenuCard(
                    context,
                    theme,
                    icon: Icons.logout,
                    title: 'Log out',
                    onTap: () => _handleLogout(context),
                    isDestructive: true,
                  ),
                  
                  // Add bottom padding to prevent overflow
                  const SizedBox(height: AppDim.paddingMedium),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildMenuCard(
    BuildContext context,
    ThemeData theme, {
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: AppDim.paddingSmall),
      color: AppColors.cardBackground,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDim.radiusMedium),
      ),
      elevation: 2,
      child: ListTile(
        leading: Icon(
          icon,
          color: isDestructive ? AppColors.dangerColor : AppColors.primaryColor,
        ),
        title: Text(
          title,
          style: TextStyle(
            color: isDestructive ? AppColors.dangerColor : AppColors.textPrimary,
          ),
        ),
        trailing: Icon(
          Icons.chevron_right,
          color: AppColors.textSecondary,
        ),
        onTap: onTap,
      ),
    );
  }

}
