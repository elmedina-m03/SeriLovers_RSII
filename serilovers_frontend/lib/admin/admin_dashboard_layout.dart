import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import 'screens/admin_home_screen.dart';
import 'screens/series_management_screen.dart';
import 'screens/users_management_screen.dart';
import 'screens/actors_management_screen.dart';
import 'screens/challenges_management_screen.dart';
import 'screens/statistics_screen.dart';

/// Admin dashboard layout with responsive sidebar
/// 
/// Displays a left sidebar (250px) with menu items when screen width >= 600px.
/// On smaller screens, shows only the main content.
class AdminDashboardLayout extends StatefulWidget {
  /// Currently selected menu index (0-6)
  final int selectedIndex;
  
  /// Callback when a menu item is tapped (index 0-6)
  final Function(int) onMenuItemSelected;

  const AdminDashboardLayout({
    super.key,
    required this.selectedIndex,
    required this.onMenuItemSelected,
  });

  @override
  State<AdminDashboardLayout> createState() => _AdminDashboardLayoutState();
}

class _AdminDashboardLayoutState extends State<AdminDashboardLayout> {
  /// Breakpoint for desktop layout (600px)
  static const double _desktopBreakpoint = 600;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= _desktopBreakpoint;

    // Get content based on selectedIndex
    final content = _getContentForIndex(widget.selectedIndex);
    final appBarTitle = _getAppBarTitle(widget.selectedIndex);

    if (!isDesktop) {
      // Mobile/tablet: Show only main content with app bar
      return Scaffold(
        appBar: appBarTitle != null
            ? AppBar(
                title: Text(appBarTitle),
              )
            : null,
        body: content,
      );
    }

    // Desktop: Show sidebar + main content
    return Scaffold(
      body: Row(
        children: [
          // Left Sidebar (250px)
          _buildSidebar(),
          // Main Content Area
          Expanded(
            child: Column(
              children: [
                // App Bar
                if (appBarTitle != null)
                  Container(
                    height: 64,
                    color: AppColors.primaryColor,
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    alignment: Alignment.centerLeft,
                    child: Text(
                      appBarTitle,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                // Main Content
                Expanded(
                  child: content,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Builds the left sidebar with menu items
  Widget _buildSidebar() {
    return Container(
      width: 250,
      color: Colors.white,
      child: Column(
        children: [
          // Logo/Header Section
          Container(
            height: 80,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primaryColor,
              border: Border(
                bottom: BorderSide(
                  color: Colors.grey.shade200,
                  width: 1,
                ),
              ),
            ),
            child: const Center(
              child: Text(
                'Admin Panel',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          // Menu Items
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                _buildMenuItem(0, Icons.home, 'Home'),
                _buildMenuItem(1, Icons.movie, 'Series'),
                _buildMenuItem(2, Icons.people, 'Users'),
                _buildMenuItem(3, Icons.person, 'Actors'),
                _buildMenuItem(4, Icons.emoji_events, 'Challenges'),
                _buildMenuItem(5, Icons.bar_chart, 'Statistics'),
                const Divider(height: 32),
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
    final isSelected = widget.selectedIndex == index;
    
    return InkWell(
      onTap: () => widget.onMenuItemSelected(index),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primaryColor.withOpacity(0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
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
                  : (isDestructive ? Colors.red.shade600 : Colors.grey.shade700),
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
                      : (isDestructive ? Colors.red.shade600 : Colors.grey.shade800),
                ),
              ),
            ),
            if (isSelected)
              Container(
                width: 4,
                height: 24,
                decoration: BoxDecoration(
                  color: AppColors.primaryColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Gets the content widget based on selectedIndex
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
        // Logout - should not show content, handled by callback
        return const AdminHomeScreen();
      default:
        return const AdminHomeScreen();
    }
  }

  /// Gets the app bar title based on selectedIndex
  String? _getAppBarTitle(int index) {
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
        return null; // Logout
      default:
        return 'Admin Home';
    }
  }
}

