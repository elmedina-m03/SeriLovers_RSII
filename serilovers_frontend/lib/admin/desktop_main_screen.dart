import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'widgets/admin_sidebar.dart';
import 'screens/admin_home_screen.dart';
import 'screens/series_management_screen.dart';
import 'screens/users_management_screen.dart';
import 'screens/actors_management_screen.dart';
import 'screens/challenges_management_screen.dart';
import 'screens/statistics_screen.dart';
import '../core/theme/app_colors.dart';
import '../providers/auth_provider.dart';

/// Desktop main screen for admin panel
class DesktopMainScreen extends StatefulWidget {
  const DesktopMainScreen({super.key});

  @override
  State<DesktopMainScreen> createState() => _DesktopMainScreenState();
}

class _DesktopMainScreenState extends State<DesktopMainScreen> {
  int _selectedIndex = 0;

  void _handleItemSelected(int index) {
    if (index == 6) {
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
        return const SeriesManagementScreen();
      case 2:
        return const UsersManagementScreen();
      case 3:
        return const ActorsManagementScreen();
      case 4:
        return const ChallengesManagementScreen();
      case 5:
        return const StatisticsScreen();
      case 6:
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          // Left side: Admin Sidebar
          AdminSidebar(
            selectedIndex: _selectedIndex,
            onItemSelected: _handleItemSelected,
          ),
          // Right side: Content area
          Expanded(
            child: Column(
              children: [
                // Header with selected tab title
                Container(
                  height: 64,
                  color: AppColors.primaryColor,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  alignment: Alignment.centerLeft,
                  child: Text(
                    _getTabTitle(_selectedIndex),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                // Actual selected screen content
                Expanded(
                  child: _getContentForIndex(_selectedIndex),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

