import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import '../widgets/admin_sidebar.dart';
import '../widgets/admin_topbar.dart';
import 'admin_home_screen.dart';
import 'admin_series_screen.dart';
import 'admin_users_screen.dart';
import 'admin_actors_screen.dart';
import 'admin_challenges_screen.dart';
import 'admin_statistics_screen.dart';
import 'admin_reviews_screen.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dim.dart';
import '../../providers/auth_provider.dart';
import '../../core/widgets/serilovers_logo.dart';

/// Main admin screen that wraps AdminDashboardLayout
class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => AdminScreenState();
}

class AdminScreenState extends State<AdminScreen> {
  int _selectedIndex = 0;

  void _handleMenuItemSelected(int index) {
    if (index == 7) {
      // Logout (index 7)
      _handleLogout();
    } else {
      setState(() {
        _selectedIndex = index;
      });
    }
  }

  /// Public method to navigate to a specific screen (used by child screens)
  void navigateToScreen(int index) {
    _handleMenuItemSelected(index);
  }

  Future<void> _handleLogout() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    await authProvider.logout();
    if (mounted) {
      Navigator.pushReplacementNamed(context, '/login');
    }
  }

  Widget _getContentForIndex(int index) {
    switch (index) {
      case 0:
        return AdminHomeScreen(
          onNavigateToScreen: navigateToScreen,
        );
      case 1:
        return const AdminSeriesScreen();
      case 2:
        return const AdminUsersScreen();
      case 3:
        return const AdminActorsScreen();
      case 4:
        return const AdminChallengesScreen();
      case 5:
        return const AdminStatisticsScreen();
      case 6:
        return const AdminReviewsScreen();
      case 7:
        // Logout - should not show content, handled by callback
        return AdminHomeScreen(
          onNavigateToScreen: navigateToScreen,
        );
      default:
        return AdminHomeScreen(
          onNavigateToScreen: navigateToScreen,
        );
    }
  }

  String _getTabTitle(int index) {
    switch (index) {
      case 0:
        return 'Admin Home';
      case 1:
        return 'Series Management';
      case 2:
        return 'Users Management';
      case 3:
        return 'Actors Management';
      case 4:
        return 'Challenges Management';
      case 5:
        return 'Statistics';
      case 6:
        return 'Reviews Management';
      case 7:
        return 'Admin Home'; // Should not reach here
      default:
        return 'Admin Home';
    }
  }

  Widget? _getActionForIndex(int index) {
    // Only show Add button for management screens (not Home or Statistics)
    if (index == 1 || index == 2 || index == 3 || index == 4) {
      return null; // Will be handled by individual screens
    }
    return null;
  }

  /// Check if user is authenticated and is an admin
  bool _isAdmin() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final token = authProvider.token;
    
    if (token == null || token.isEmpty) {
      return false;
    }
    
    try {
      final decodedToken = JwtDecoder.decode(token);
      final role = decodedToken['role'] as String? ?? 
                   (decodedToken['http://schemas.microsoft.com/ws/2008/06/identity/claims/role'] as String?) ?? 
                   'User';
      return role == 'Admin';
    } catch (e) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final authProvider = Provider.of<AuthProvider>(context);
    
    // Check authentication and admin role
    if (!authProvider.isAuthenticated || !_isAdmin()) {
      // Redirect to login after a frame
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Navigator.pushReplacementNamed(context, '/login');
        }
      });
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }
    
    return Container(
      color: AppColors.backgroundColor,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Row(
          children: [
            // Left side: Logo + Sidebar
            Column(
              children: [
                // Logo in absolute top-left corner
                Container(
                  width: AppDim.sidebarWidth,
                  height: 80,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  decoration: BoxDecoration(
                    color: AppColors.primaryColor,
                    border: Border(
                      bottom: BorderSide(
                        color: AppColors.textSecondary.withOpacity(0.2),
                        width: 1,
                      ),
                    ),
                  ),
                  alignment: Alignment.centerLeft,
                  child: const SeriLoversLogo(
                    showFullLogo: true,
                    height: 40,
                    useWhiteVersion: true,
                  ),
                ),
                // Sidebar below logo
                Expanded(
                  child: AdminSidebar(
                    selectedIndex: _selectedIndex,
                    onItemSelected: _handleMenuItemSelected,
                  ),
                ),
              ],
            ),
            // Spacing between sidebar and content
            SizedBox(width: AppDim.padding),
            // Right side: Content area
            Expanded(
              child: Column(
                children: [
                  // Top bar with selected tab title (no logo)
                  AdminTopbar(
                    title: _getTabTitle(_selectedIndex),
                    action: _getActionForIndex(_selectedIndex),
                  ),
                  // Actual selected screen content with proper scrolling
                  Expanded(
                    child: Container(
                      color: AppColors.backgroundColor,
                      child: _getContentForIndex(_selectedIndex),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
