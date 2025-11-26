import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:provider/provider.dart';
import '../providers/mobile_navigation_provider.dart';

/// Mobile bottom navigation bar widget
class MobileBottomNav extends StatelessWidget {
  const MobileBottomNav({super.key});

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      // Force mobile layout for Chrome
    }
    
    return Consumer<MobileNavigationProvider>(
      builder: (context, navProvider, child) {
        return BottomNavigationBar(
          currentIndex: navProvider.currentIndex,
          onTap: (index) => navProvider.setIndex(index),
          type: BottomNavigationBarType.fixed,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.category),
              label: 'Categories',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.list),
              label: 'Lists',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person),
              label: 'Profile',
            ),
          ],
        );
      },
    );
  }
}

