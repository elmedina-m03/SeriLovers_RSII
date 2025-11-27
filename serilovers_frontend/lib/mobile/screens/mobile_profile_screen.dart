import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import 'package:intl/intl.dart';
import '../../providers/auth_provider.dart';
import '../../providers/theme_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dim.dart';

/// Mobile profile screen showing user info and logout button
class MobileProfileScreen extends StatefulWidget {
  const MobileProfileScreen({super.key});

  @override
  State<MobileProfileScreen> createState() => _MobileProfileScreenState();
}

class _MobileProfileScreenState extends State<MobileProfileScreen> {
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
      ),
      body: SafeArea(
        child: Consumer<AuthProvider>(
          builder: (context, authProvider, child) {
            final userInfo = _getUserInfo(authProvider.token);
            final initials = _getInitials(userInfo['email']!);
            final joinedDate = _getJoinedDate(authProvider.token);

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

                  const SizedBox(height: AppDim.paddingLarge),

                  // Joined date card (if available)
                  if (joinedDate != null)
                    Card(
                      color: AppColors.cardBackground,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppDim.radiusMedium),
                      ),
                      elevation: 2,
                      child: ListTile(
                        leading: Icon(
                          Icons.event_available,
                          color: AppColors.primaryColor,
                        ),
                        title: const Text('Joined'),
                        subtitle: Text(
                          DateFormat('MMM d, yyyy').format(joinedDate),
                        ),
                      ),
                    ),

                  const SizedBox(height: AppDim.paddingLarge),

                  // Dark Mode Toggle
                  Consumer<ThemeProvider>(
                    builder: (context, themeProvider, child) {
                      return Card(
                        color: AppColors.cardBackground,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppDim.radiusMedium),
                        ),
                        elevation: 2,
                        child: ListTile(
                          leading: Icon(
                            themeProvider.isDarkMode ? Icons.dark_mode : Icons.light_mode,
                            color: AppColors.primaryColor,
                          ),
                          title: const Text('Dark Mode'),
                          subtitle: Text(
                            themeProvider.isDarkMode ? 'Enabled' : 'Disabled',
                          ),
                          trailing: Switch(
                            value: themeProvider.isDarkMode,
                            onChanged: (value) {
                              themeProvider.toggleDarkMode();
                            },
                            activeColor: AppColors.primaryColor,
                          ),
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: AppDim.paddingMedium),

                  // Edit Profile Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        final result = await Navigator.pushNamed(
                          context,
                          '/mobile_edit_profile',
                        );
                        if (result == true && mounted) {
                          // Refresh the screen if profile was updated
                          setState(() {});
                        }
                      },
                      icon: const Icon(Icons.edit),
                      label: const Text(
                        'Edit Profile',
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

                  const SizedBox(height: AppDim.paddingMedium),

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
