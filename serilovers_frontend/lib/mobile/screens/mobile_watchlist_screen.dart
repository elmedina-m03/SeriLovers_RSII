import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/watchlist_provider.dart';
import '../../providers/auth_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dim.dart';
import '../../models/series.dart';
import '../../core/widgets/image_with_placeholder.dart';

/// Mobile watchlist screen displaying watchlist items with poster thumbnails
class MobileWatchlistScreen extends StatefulWidget {
  const MobileWatchlistScreen({super.key});

  @override
  State<MobileWatchlistScreen> createState() => _MobileWatchlistScreenState();
}

class _MobileWatchlistScreenState extends State<MobileWatchlistScreen> {
  @override
  void initState() {
    super.initState();
    // Load watchlist when screen loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadWatchlist();
    });
  }

  Future<void> _loadWatchlist() async {
    final watchlistProvider = Provider.of<WatchlistProvider>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final token = authProvider.token;

    if (token != null && token.isNotEmpty) {
      try {
        await watchlistProvider.fetchWatchlist(token);
      } catch (error) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error loading watchlist: $error'),
              backgroundColor: AppColors.dangerColor,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    }
  }

  Future<void> _handleDelete(Series series) async {
    final watchlistProvider = Provider.of<WatchlistProvider>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final token = authProvider.token;

    if (token == null || token.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Authentication required. Please log in.'),
            backgroundColor: AppColors.dangerColor,
            duration: Duration(seconds: 3),
          ),
        );
      }
      return;
    }

    try {
      await watchlistProvider.removeFromWatchlist(series.id, token);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Removed from Watchlist'),
            backgroundColor: AppColors.successColor,
            duration: const Duration(seconds: 2),
            action: SnackBarAction(
              label: 'Undo',
              textColor: AppColors.textLight,
              onPressed: () async {
                try {
                  await watchlistProvider.addToWatchlist(series.id);
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
            backgroundColor: AppColors.dangerColor,
            duration: const Duration(seconds: 3),
          ),
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
        title: const Text('My Watchlist'),
        backgroundColor: AppColors.primaryColor,
        foregroundColor: AppColors.textLight,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.folder),
            tooltip: 'My Lists',
            onPressed: () {
              Navigator.pushNamed(context, '/my_lists');
            },
          ),
        ],
      ),
      body: Consumer<WatchlistProvider>(
        builder: (context, watchlistProvider, child) {
          // Show loading indicator
          if (watchlistProvider.isLoading) {
            return const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryColor),
              ),
            );
          }

          // Show empty state
          if (watchlistProvider.items.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.bookmark_border,
                    size: 64,
                    color: AppColors.textSecondary.withOpacity(0.5),
                  ),
                  const SizedBox(height: AppDim.paddingMedium),
                  Text(
                    'Your watchlist is empty',
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: AppDim.paddingSmall),
                  Text(
                    'Add series to your watchlist to see them here',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }

          // Show list of watchlist items
          return RefreshIndicator(
            onRefresh: _loadWatchlist,
            color: AppColors.primaryColor,
            child: ListView.builder(
              padding: const EdgeInsets.all(AppDim.paddingMedium),
              itemCount: watchlistProvider.items.length,
              itemBuilder: (context, index) {
                final series = watchlistProvider.items[index];
                return _buildWatchlistCard(series, context, theme);
              },
            ),
          );
        },
      ),
    );
  }

  /// Builds a watchlist card with poster thumbnail, title, and delete button
  Widget _buildWatchlistCard(Series series, BuildContext context, ThemeData theme) {
    return Dismissible(
      key: Key('watchlist_${series.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: AppDim.paddingMedium),
        decoration: BoxDecoration(
          color: AppColors.dangerColor,
          borderRadius: BorderRadius.circular(AppDim.radiusMedium),
        ),
        child: const Icon(
          Icons.delete,
          color: AppColors.textLight,
          size: 28,
        ),
      ),
      onDismissed: (direction) {
        _handleDelete(series);
      },
      child: Card(
        margin: const EdgeInsets.only(bottom: AppDim.paddingMedium),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDim.radiusMedium),
        ),
        elevation: 2,
        child: ListTile(
          contentPadding: const EdgeInsets.all(AppDim.paddingSmall),
          leading: _buildPosterThumbnail(series),
          title: Text(
            series.title,
            style: theme.textTheme.titleMedium?.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.bold,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: series.description != null && series.description!.isNotEmpty
              ? Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    series.description!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                )
              : null,
          isThreeLine: false,
          trailing: IconButton(
            icon: const Icon(Icons.delete_outline),
            color: AppColors.dangerColor,
            onPressed: () => _handleDelete(series),
            tooltip: 'Remove from watchlist',
          ),
          onTap: () {
            Navigator.pushNamed(
              context,
              '/series_detail',
              arguments: series,
            );
          },
        ),
      ),
    );
  }

  /// Builds a poster thumbnail placeholder
  Widget _buildPosterThumbnail(Series series) {
    return Container(
      width: 60,
      height: 90,
      decoration: BoxDecoration(
        color: AppColors.primaryColor.withOpacity(0.2),
        borderRadius: BorderRadius.circular(AppDim.radiusSmall),
      ),
      child: ImageWithPlaceholder(
        imageUrl: series.imageUrl,
        height: 60,
        width: 45,
        fit: BoxFit.cover,
        borderRadius: AppDim.radiusSmall,
        placeholderIcon: Icons.movie,
        placeholderIconSize: 24,
      ),
    );
  }
}

