import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/watchlist_provider.dart';
import '../providers/auth_provider.dart';
import '../widgets/series_card.dart';

/// Screen that displays the user's watchlist
class WatchlistScreen extends StatefulWidget {
  const WatchlistScreen({super.key});

  @override
  State<WatchlistScreen> createState() => _WatchlistScreenState();
}

class _WatchlistScreenState extends State<WatchlistScreen> {
  @override
  void initState() {
    super.initState();
    // Load watchlist when screen loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final watchlistProvider = Provider.of<WatchlistProvider>(context, listen: false);
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final token = authProvider.token;
      
      if (token != null && token.isNotEmpty) {
        watchlistProvider.fetchWatchlist(token).catchErrorr((error) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Error loading watchlist: $error'),
                backgroundColor: Colors.red,
                duration: const Duration(seconds: 5),
              ),
            );
          }
        });
      }
    });
  }

  /// Check if running on mobile (not web and not Windows)
  bool get _isMobile {
    if (kIsWeb) return false;
    if (Platform.isWindows) return false;
    return true; // iOS, Android, Linux, macOS
  }

  /// Handle delete action for a series
  Future<void> _handleDelete(int seriesId, String seriesTitle) async {
    final watchlistProvider = Provider.of<WatchlistProvider>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final token = authProvider.token;
    
    if (token == null || token.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Authentication required. Please log in.'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );
      }
      return;
    }
    
    try {
      await watchlistProvider.removeFromWatchlist(seriesId, token);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Removed from Watchlist'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
            action: SnackBarAction(
              label: 'Undo',
              textColor: Colors.white,
              onPressed: () async {
                // Re-add to watchlist
                try {
                  await watchlistProvider.addToWatchlist(seriesId);
                } catch (e) {
                  // Ignore undo errors
                }
              },
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error removing from watchlist: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Watchlist'),
      ),
      body: Consumer<WatchlistProvider>(
        builder: (context, watchlistProvider, child) {
          // Show loading indicator
          if (watchlistProvider.isLoading) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          // Show empty state
          if (watchlistProvider.items.isEmpty) {
            return const Center(
              child: Text(
                'Your watchlist is empty',
                style: TextStyle(
                  fontSize: 18,
                  color: Colors.grey,
                ),
              ),
            );
          }

          // Show list of series in watchlist
          return RefreshIndicator(
            onRefresh: () async {
              final authProvider = Provider.of<AuthProvider>(context, listen: false);
              final token = authProvider.token;
              if (token != null && token.isNotEmpty) {
                await watchlistProvider.fetchWatchlist(token);
              }
            },
            child: ListView.builder(
              itemCount: watchlistProvider.items.length,
              itemBuilder: (context, index) {
                final series = watchlistProvider.items[index];
                
                // For mobile: wrap in Dismissible for swipe-to-delete
                if (_isMobile) {
                  return Dismissible(
                    key: Key('watchlist_${series.id}'),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 20),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Icon(
                        Icons.delete,
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                    onDismissed: (direction) {
                      _handleDelete(series.id, series.title);
                    },
                    child: SeriesCard(series: series),
                  );
                } else {
                  // For web/Windows: show delete IconButton
                  // Wrap in IntrinsicHeight to align button with card
                  return IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: SeriesCard(series: series),
                        ),
                        Container(
                          margin: const EdgeInsets.only(right: 8),
                          child: Center(
                            child: IconButton(
                              icon: const Icon(Icons.delete_outline),
                              color: Colors.red,
                              onPressed: () => _handleDelete(series.id, series.title),
                              tooltip: 'Remove from watchlist',
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }
              },
            ),
          );
        },
      ),
    );
  }
}

