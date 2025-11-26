import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import '../../providers/auth_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dim.dart';

/// Mobile profile screen showing user info and logout button
class MobileProfileScreen extends StatelessWidget {
  const MobileProfileScreen({super.key});

  /// Get user info from JWT token
  Map<String, String> _getUserInfo(String? token) {
    if (token == null || token.isEmpty) {
      return {'email': 'Unknown', 'name': 'Unknown User'};
    }

    try {
      final decodedToken = JwtDecoder.decode(token);
      final email = decodedToken['email'] as String? ?? 
                   decodedToken['sub'] as String? ?? 
                   'Unknown';
      
      // Extract name from email (use part before @)
      String name = 'User';
      if (email != 'Unknown') {
        final parts = email.split('@');
        if (parts.isNotEmpty) {
          final namePart = parts[0];
          // Capitalize first letter
          name = namePart[0].toUpperCase() + namePart.substring(1);
        }
      }
      
      return {'email': email, 'name': name};
    } catch (e) {
      return {'email': 'Unknown', 'name': 'Unknown User'};
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
      ),
      body: SafeArea(
        child: Consumer<AuthProvider>(
          builder: (context, authProvider, child) {
            final userInfo = _getUserInfo(authProvider.token);
            final initials = _getInitials(userInfo['email']!);

            return SingleChildScrollView(
              padding: const EdgeInsets.all(AppDim.paddingLarge),
              child: Column(
                children: [
                  const SizedBox(height: AppDim.paddingLarge),

                  // User Avatar Circle
                  CircleAvatar(
                    radius: 60,
                    backgroundColor: AppColors.primaryColor,
                    child: Text(
                      initials,
                      style: const TextStyle(
                        color: AppColors.textLight,
                        fontWeight: FontWeight.bold,
                        fontSize: 36,
                      ),
                    ),
                  ),

                  const SizedBox(height: AppDim.paddingLarge),

                  // User Name
                  Text(
                    userInfo['name']!,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: AppDim.paddingSmall),

                  // User Email
                  Text(
                    userInfo['email']!,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),

                  const SizedBox(height: AppDim.paddingLarge * 2),

                  // Logout Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _handleLogout(context),
                      icon: const Icon(Icons.logout),
                      label: const Text(
                        'Logout',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryColor,
                        foregroundColor: AppColors.textLight,
                        padding: const EdgeInsets.symmetric(
                          vertical: AppDim.paddingMedium,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppDim.radiusMedium),
                        ),
                        elevation: 4,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
