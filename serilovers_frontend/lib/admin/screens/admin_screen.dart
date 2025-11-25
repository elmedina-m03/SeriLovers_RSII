import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../widgets/admin_sidebar.dart';
import '../widgets/admin_topbar.dart';
import 'admin_home_screen.dart';
import 'admin_series_screen.dart';
import 'admin_users_screen.dart';
import 'admin_actors_screen.dart';
import 'admin_challenges_screen.dart';
import 'admin_statistics_screen.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dim.dart';
import '../../providers/auth_provider.dart';

/// Main admin screen that wraps AdminDashboardLayout
class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  int _selectedIndex = 0;

  void _handleMenuItemSelected(int index) {
    if (index == 6) {
      // Logout (index 6)
      _handleLogout();
    } else {
      setState(() {
        _selectedIndex = index;
      });
    }
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
        return const AdminHomeScreen();
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
        // Logout - should not show content, handled by callback
        return const AdminHomeScreen();
      default:
        return const AdminHomeScreen();
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Container(
      color: AppColors.backgroundColor,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Row(
          children: [
            // Left side: Admin Sidebar
            AdminSidebar(
              selectedIndex: _selectedIndex,
              onItemSelected: _handleMenuItemSelected,
            ),
            // Spacing between sidebar and content
            SizedBox(width: AppDim.padding),
            // Right side: Content area
            Expanded(
              child: Column(
                children: [
                  // Top bar with selected tab title
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
