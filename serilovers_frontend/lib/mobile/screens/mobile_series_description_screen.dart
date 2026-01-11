import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dim.dart';
import '../../models/series.dart';
import '../../core/widgets/image_with_placeholder.dart';
import '../../providers/watchlist_provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/reminder_service.dart';
import 'package:provider/provider.dart';
import '../widgets/mobile_page_route.dart';

/// Screen showing extended series description with full layout matching detail screen
class MobileSeriesDescriptionScreen extends StatefulWidget {
  final Series series;

  const MobileSeriesDescriptionScreen({
    super.key,
    required this.series,
  });

  @override
  State<MobileSeriesDescriptionScreen> createState() => _MobileSeriesDescriptionScreenState();
}

class _MobileSeriesDescriptionScreenState extends State<MobileSeriesDescriptionScreen> {
  late Series _series;
  bool _isReminderEnabled = false;
  final ReminderService _reminderService = ReminderService();

  @override
  void initState() {
    super.initState();
    _series = widget.series;
    _loadReminderState();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      body: CustomScrollView(
        slivers: [
          // AppBar with banner
          SliverAppBar(
            expandedHeight: 250,
            pinned: true,
            backgroundColor: AppColors.primaryColor,
            flexibleSpace: FlexibleSpaceBar(
              background: _buildBanner(context),
            ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textLight),
          onPressed: () => Navigator.of(context).pop(),
        ),
            actions: [],
          ),

          // Content
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(AppDim.paddingMedium),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title
                  Text(
                    _series.title,
                    style: theme.textTheme.headlineMedium?.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: AppDim.paddingSmall),

                  // Release year and season/episode info
                  Row(
                    children: [
                      Text(
                        '${_series.releaseDate.year}',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      if (_series.seasons.isNotEmpty) ...[
                        const SizedBox(width: AppDim.paddingSmall),
                        Text(
                          '• ${_series.totalSeasons} season${_series.totalSeasons > 1 ? 's' : ''}',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(width: AppDim.paddingSmall),
                        Text(
                          '• ${_series.totalEpisodes} episodes',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ],
                  ),

                  const SizedBox(height: AppDim.paddingSmall),

                  // Genres as Chips
                  if (_series.genres.isNotEmpty)
                    Wrap(
                      spacing: AppDim.paddingSmall,
                      runSpacing: AppDim.paddingSmall,
                      children: _series.genres.map((genre) {
                        return Chip(
                          label: Text(
                            genre,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          backgroundColor: AppColors.primaryColor.withOpacity(0.1),
                          labelStyle: const TextStyle(
                            color: AppColors.primaryColor,
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppDim.paddingSmall,
                            vertical: 4,
                          ),
                        );
                      }).toList(),
                    ),

                  const SizedBox(height: AppDim.paddingMedium),
                  
                  // Rating Display
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppDim.paddingMedium,
                          vertical: AppDim.paddingSmall,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primaryColor,
                          borderRadius: BorderRadius.circular(AppDim.radiusMedium),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.star,
                              color: AppColors.textLight,
                              size: 20,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _series.rating.toStringAsFixed(1),
                              style: const TextStyle(
                                color: AppColors.textLight,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: AppDim.paddingMedium),
                      if (_series.ratingsCount > 0)
                        Text(
                          '(${_series.ratingsCount} reviews)',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                    ],
                  ),

                  const SizedBox(height: AppDim.paddingLarge),

                  // Full Description
                  if (_series.description != null && _series.description!.isNotEmpty) ...[
                    Text(
                      'Description',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: AppDim.paddingSmall),
                    Text(
                      _series.description!,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: AppColors.textPrimary,
                        height: 1.6,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: AppDim.paddingLarge),
                  ],

                  // Actors Section
                  if (_series.actors.isNotEmpty) ...[
                    Text(
                      'Cast',
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: AppDim.paddingMedium),
                    SizedBox(
                      height: 100,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.symmetric(horizontal: AppDim.paddingMedium),
                        itemCount: _series.actors.length,
                        itemBuilder: (context, index) {
                          final actor = _series.actors[index];
                          return Padding(
                            padding: const EdgeInsets.only(right: AppDim.paddingSmall),
                            child: _buildActorCard(actor, context, theme),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: AppDim.paddingLarge),
                  ],

                  // Remind me for new episode button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _toggleReminder(),
                      icon: Icon(_isReminderEnabled ? Icons.notifications : Icons.notifications_outlined),
                      label: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(_isReminderEnabled ? 'Reminder enabled' : 'Remind me for new episode'),
                          const SizedBox(width: 4),
                          const Icon(Icons.arrow_forward, size: 18),
                        ],
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _isReminderEnabled 
                            ? AppColors.successColor 
                            : AppColors.primaryColor,
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

                  // Add to list button
                  Consumer<WatchlistProvider>(
                    builder: (context, watchlistProvider, child) {
                      return SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () => _showAddToListDialog(context, _series),
                          icon: const Icon(Icons.add),
                          label: const Text(
                            'Add to list',
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
                      );
                    },
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBanner(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Series Image
        ImageWithPlaceholder(
          imageUrl: _series.imageUrl,
          width: double.infinity,
          height: double.infinity,
          fit: BoxFit.cover,
          placeholderIcon: Icons.movie,
          placeholderIconSize: 80,
          placeholderBackgroundColor: AppColors.primaryColor,
        ),
        // Gradient overlay
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.transparent,
                AppColors.backgroundColor.withOpacity(0.7),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// Builds an actor card for horizontal list
  Widget _buildActorCard(Actor actor, BuildContext context, ThemeData theme) {
    return Container(
      width: 80,
      margin: const EdgeInsets.only(right: AppDim.paddingMedium),
      child: Column(
        children: [
          // Actor Avatar with image
          ImageWithPlaceholder(
            imageUrl: actor.imageUrl,
            width: 60,
            height: 60,
            fit: BoxFit.cover,
            isCircular: true,
            radius: 30,
            placeholderIcon: Icons.person,
            placeholderIconSize: 30,
          ),
          const SizedBox(height: AppDim.paddingSmall),
          // Actor Name
          Text(
            actor.fullName,
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  /// Load reminder state for this series
  Future<void> _loadReminderState() async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final token = authProvider.token;
      if (token != null && token.isNotEmpty) {
        final isEnabled = await _reminderService.isReminderEnabled(widget.series.id, token: token);
        if (mounted) {
          setState(() {
            _isReminderEnabled = isEnabled;
          });
        }
      }
    } catch (_) {
      // Silently fail - reminder state will default to false
    }
  }

  /// Toggle reminder for new episodes
  Future<void> _toggleReminder() async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final token = authProvider.token;
      if (token == null || token.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please log in to enable reminders'),
              backgroundColor: AppColors.dangerColor,
            ),
          );
        }
        return;
      }

      if (_isReminderEnabled) {
        // Disable reminder
        await _reminderService.disableReminder(_series.id, token: token);
      } else {
        // Enable reminder
        await _reminderService.enableReminder(_series.id, _series.title, token: token);
      }
      
      // Reload reminder state from API to ensure consistency
      if (mounted) {
        await _loadReminderState();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(_isReminderEnabled 
                  ? 'You will be notified when new episodes of ${_series.title} are available'
                  : 'Reminder disabled'),
              backgroundColor: AppColors.successColor,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating reminder: $e'),
            backgroundColor: AppColors.dangerColor,
          ),
        );
      }
    }
  }

  Future<void> _showAddToListDialog(BuildContext context, Series series) async {
    final watchlistProvider = Provider.of<WatchlistProvider>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final token = authProvider.token;

    if (token == null || token.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please log in to add series to lists'),
          backgroundColor: AppColors.dangerColor,
        ),
      );
      return;
    }

    // Load user's lists if not already loaded
    try {
      final decoded = JwtDecoder.decode(token);
      final rawId = decoded['userId'] ?? decoded['id'] ?? decoded['nameid'] ?? decoded['sub'];
      int? userId;
      if (rawId is int) {
        userId = rawId;
      } else if (rawId is String) {
        userId = int.tryParse(rawId);
      }
      
      if (userId != null && watchlistProvider.lists.isEmpty) {
        await watchlistProvider.loadUserWatchlists(userId);
      }
    } catch (_) {
      // Silently fail
    }

    if (!mounted) return;

    // Show dialog with user's lists
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Add to List'),
          content: SizedBox(
            width: double.maxFinite,
            child: watchlistProvider.lists.isEmpty
                ? const Text('No lists available. Create a list first.')
                : ListView.builder(
                    shrinkWrap: true,
                    itemCount: watchlistProvider.lists.length,
                    itemBuilder: (context, index) {
                      final list = watchlistProvider.lists[index];
                      return ListTile(
                        title: Text(list.name),
                        onTap: () async {
                          Navigator.pop(context);
                          try {
                            await watchlistProvider.addSeries(list.id, series.id);
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Added ${series.title} to ${list.name}'),
                                  backgroundColor: AppColors.successColor,
                                ),
                              );
                            }
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Error: $e'),
                                  backgroundColor: AppColors.dangerColor,
                                ),
                              );
                            }
                          }
                        },
                      );
                    },
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );
  }
}
