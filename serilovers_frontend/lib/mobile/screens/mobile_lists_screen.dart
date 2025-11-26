import 'package:flutter/material.dart';

/// Mobile lists (watchlist) screen placeholder
class MobileListsScreen extends StatelessWidget {
  const MobileListsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Lists'),
      ),
      body: const Center(
        child: Text('Lists Screen'),
      ),
    );
  }
}

