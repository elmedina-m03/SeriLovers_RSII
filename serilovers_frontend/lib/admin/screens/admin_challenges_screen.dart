import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dim.dart';
import '../../core/widgets/admin_data_table_config.dart';
import '../../models/challenge.dart';
import '../providers/admin_challenge_provider.dart';
import 'challenges/challenge_form_dialog.dart';

/// Admin challenges management screen with DataTable
class AdminChallengesScreen extends StatefulWidget {
  const AdminChallengesScreen({super.key});

  @override
  State<AdminChallengesScreen> createState() => _AdminChallengesScreenState();
}

class _AdminChallengesScreenState extends State<AdminChallengesScreen> {
  final _horizontalScrollController = ScrollController();
  final _verticalScrollController = ScrollController();
  final _progressHorizontalScrollController = ScrollController();
  final _progressVerticalScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadChallenges();
      _loadSummary();
      _loadUserProgress();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Refresh data when navigating back to this screen (e.g., after user activity changes)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _loadUserProgress();
        _loadSummary();
      }
    });
  }

  @override
  void dispose() {
    _horizontalScrollController.dispose();
    _verticalScrollController.dispose();
    _progressHorizontalScrollController.dispose();
    _progressVerticalScrollController.dispose();
    super.dispose();
  }

  /// Load challenges from provider and create default if empty
  Future<void> _loadChallenges() async {
    try {
      final provider = Provider.of<AdminChallengeProvider>(context, listen: false);
      await provider.fetchAll();
      
      // If no challenges exist, create a default one
      if (provider.items.isEmpty && mounted) {
        await _createDefaultChallenge(provider);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading challenges: $e'),
            backgroundColor: AppColors.dangerColor,
          ),
        );
      }
    }
  }

  /// Create a default challenge if none exist
  Future<void> _createDefaultChallenge(AdminChallengeProvider provider) async {
    try {
      final defaultChallengeData = {
        'name': 'Watch 10 Series',
        'description': 'Complete watching 10 different series to complete this challenge!',
        'difficulty': 1, // Easy
        'targetCount': 10,
      };
      
      await provider.createChallenge(defaultChallengeData);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Default challenge created successfully'),
            backgroundColor: AppColors.successColor,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      // Silently fail - user can create manually
      print('Could not create default challenge: $e');
    }
  }

  /// Load summary including top watchers
  Future<void> _loadSummary() async {
    try {
      final provider = Provider.of<AdminChallengeProvider>(context, listen: false);
      await provider.fetchSummary();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading summary: $e'),
            backgroundColor: AppColors.dangerColor,
          ),
        );
      }
    }
  }

  /// Load user challenge progress
  Future<void> _loadUserProgress() async {
    try {
      final provider = Provider.of<AdminChallengeProvider>(context, listen: false);
      await provider.fetchUserProgress();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading user progress: $e'),
            backgroundColor: AppColors.dangerColor,
          ),
        );
      }
    }
  }


  /// Handle adding a new challenge
  Future<void> _handleAddChallenge() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => const ChallengeFormDialog(),
    );

    if (result == true) {
      await _loadChallenges();
    }
  }

  /// Handle editing a challenge
  Future<void> _handleEditChallenge(Challenge challenge) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => ChallengeFormDialog(challenge: challenge),
    );

    if (result == true) {
      await _loadChallenges();
    }
  }

  /// Handle deleting a challenge
  Future<void> _handleDeleteChallenge(Challenge challenge) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.cardBackground,
        title: Text(
          'Delete Challenge',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: Text(
          'Are you sure you want to delete "${challenge.name}"?\n\nThis action cannot be undone.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.dangerColor,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final provider = Provider.of<AdminChallengeProvider>(context, listen: false);
        await provider.deleteChallenge(challenge.id);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('"${challenge.name}" deleted successfully'),
              backgroundColor: AppColors.successColor,
            ),
          );
        }
        
        await _loadChallenges();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error deleting challenge: $e'),
              backgroundColor: AppColors.dangerColor,
            ),
          );
        }
      }
    }
  }

  Color _getDifficultyColor(String difficulty) {
    switch (difficulty.toLowerCase()) {
      case 'easy':
        return AppColors.successColor;
      case 'medium':
        return Colors.orange;
      case 'hard':
        return AppColors.dangerColor;
      case 'expert':
        return Colors.purple;
      default:
        return AppColors.textPrimary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return SafeArea(
      child: Container(
        color: AppColors.backgroundColor,
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(AppDim.paddingMedium),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Add button and refresh button at top-right
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          ElevatedButton.icon(
                            onPressed: () async {
                              await _loadUserProgress();
                              await _loadSummary();
                            },
                            icon: const Icon(Icons.refresh, size: 20),
                            label: const Text('Refresh'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.infoColor,
                              foregroundColor: AppColors.textLight,
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppDim.paddingMedium,
                                vertical: AppDim.paddingSmall,
                              ),
                            ),
                          ),
                          const SizedBox(width: AppDim.paddingSmall),
                          ElevatedButton.icon(
                            onPressed: _handleAddChallenge,
                            icon: const Icon(Icons.add, size: 20),
                            label: const Text('Add Challenge'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primaryColor,
                              foregroundColor: AppColors.textLight,
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppDim.paddingMedium,
                                vertical: AppDim.paddingSmall,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppDim.paddingSmall),
                      // DataTable with proper scrolling and mobile responsiveness
                      SizedBox(
                        height: constraints.maxWidth < 800 ? 300 : 350,
                        child: LayoutBuilder(
                          builder: (context, tableConstraints) {
                            final isMobile = tableConstraints.maxWidth < 800;
                            
                            return Consumer<AdminChallengeProvider>(
                              builder: (context, provider, child) {
                                if (provider.isLoading) {
                                  return const SizedBox(
                                    height: 200,
                                    child: Center(child: CircularProgressIndicator()),
                                  );
                                }

                                if (provider.items.isEmpty) {
                                  return const SizedBox(
                                    height: 200,
                                    child: Center(
                                      child: Text('No challenges found'),
                                    ),
                                  );
                                }

                                return Scrollbar(
                                  controller: _verticalScrollController,
                                  thumbVisibility: true,
                                  child: SingleChildScrollView(
                                    controller: _verticalScrollController,
                                    scrollDirection: Axis.vertical,
                                    child: Scrollbar(
                                      controller: _horizontalScrollController,
                                      thumbVisibility: true,
                                      child: SingleChildScrollView(
                                        controller: _horizontalScrollController,
                                        scrollDirection: Axis.horizontal,
                                          child: ConstrainedBox(
                                            constraints: BoxConstraints(
                                              minWidth: tableConstraints.maxWidth,
                                            ),
                                          child: DataTable(
                                            headingRowColor: AdminDataTableConfig.getTableProperties()['headingRowColor'] as MaterialStateProperty<Color>,
                                            dataRowColor: AdminDataTableConfig.getTableProperties()['dataRowColor'] as MaterialStateProperty<Color>,
                                            headingRowHeight: AdminDataTableConfig.headingRowHeight,
                                            dataRowMinHeight: AdminDataTableConfig.dataRowMinHeight,
                                            dataRowMaxHeight: AdminDataTableConfig.dataRowMaxHeight,
                                            columns: [
                                              DataColumn(
                                                label: AdminDataTableConfig.getColumnLabel('ID'),
                                                numeric: true,
                                              ),
                                              DataColumn(
                                                label: AdminDataTableConfig.getColumnLabel('Name'),
                                              ),
                                              DataColumn(
                                                label: AdminDataTableConfig.getColumnLabel('Participants'),
                                                numeric: true,
                                              ),
                                              DataColumn(
                                                label: AdminDataTableConfig.getColumnLabel('Goal'),
                                                numeric: true,
                                              ),
                                              DataColumn(
                                                label: AdminDataTableConfig.getColumnLabel('Actions'),
                                              ),
                                            ],
                                            rows: provider.items.map((challenge) {
                                              return DataRow(
                                                cells: [
                                                  DataCell(
                                                    Text(
                                                      challenge.id.toString(),
                                                      style: AdminDataTableConfig.getCellTextStyle(theme.textTheme),
                                                    ),
                                                  ),
                                                  DataCell(
                                                    Column(
                                                      crossAxisAlignment: CrossAxisAlignment.start,
                                                      mainAxisSize: MainAxisSize.min,
                                                      children: [
                                                        Text(
                                                          challenge.name,
                                                          style: AdminDataTableConfig.getCellTextStyle(theme.textTheme).copyWith(
                                                            fontWeight: FontWeight.w500,
                                                          ),
                                                        ),
                                                        if (challenge.description != null && challenge.description!.isNotEmpty)
                                                          Text(
                                                            challenge.description!,
                                                            style: AdminDataTableConfig.getCellSmallTextStyle(theme.textTheme).copyWith(
                                                              color: AppColors.textSecondary,
                                                            ),
                                                            maxLines: 1,
                                                            overflow: TextOverflow.ellipsis,
                                                          ),
                                                      ],
                                                    ),
                                                  ),
                                                  DataCell(
                                                    Text(
                                                      challenge.participantsCount.toString(),
                                                      style: AdminDataTableConfig.getCellTextStyle(theme.textTheme),
                                                    ),
                                                  ),
                                                  DataCell(
                                                    Text(
                                                      challenge.targetCount.toString(),
                                                      style: AdminDataTableConfig.getCellTextStyle(theme.textTheme),
                                                    ),
                                                  ),
                                                  DataCell(
                                                    Row(
                                                      mainAxisSize: MainAxisSize.min,
                                                      children: [
                                                        SizedBox(
                                                          width: AdminDataTableConfig.actionButtonSize,
                                                          child: IconButton(
                                                            icon: const Icon(Icons.edit, size: AdminDataTableConfig.actionIconSize),
                                                            color: AppColors.primaryColor,
                                                            onPressed: () => _handleEditChallenge(challenge),
                                                            tooltip: 'Edit',
                                                            padding: EdgeInsets.zero,
                                                            constraints: const BoxConstraints(
                                                              minWidth: AdminDataTableConfig.actionButtonSize,
                                                              minHeight: AdminDataTableConfig.actionButtonSize,
                                                            ),
                                                          ),
                                                        ),
                                                        const SizedBox(width: 2),
                                                        SizedBox(
                                                          width: AdminDataTableConfig.actionButtonSize,
                                                          child: IconButton(
                                                            icon: const Icon(Icons.delete, size: AdminDataTableConfig.actionIconSize),
                                                            color: AppColors.dangerColor,
                                                            onPressed: () => _handleDeleteChallenge(challenge),
                                                            tooltip: 'Delete',
                                                            padding: EdgeInsets.zero,
                                                            constraints: const BoxConstraints(
                                                              minWidth: AdminDataTableConfig.actionButtonSize,
                                                              minHeight: AdminDataTableConfig.actionButtonSize,
                                                            ),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ],
                                              );
                                            }).toList(),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 12),
                      
                      // User Challenge Progress Table
                      Text(
                        'User Challenge Progress',
                        style: theme.textTheme.titleLarge?.copyWith(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: constraints.maxWidth < 800 ? 250 : 300,
                        child: LayoutBuilder(
                          builder: (context, tableConstraints) {
                            return Consumer<AdminChallengeProvider>(
                              builder: (context, provider, child) {
                                if (provider.isLoadingProgress) {
                                  return const SizedBox(
                                    height: 200,
                                    child: Center(child: CircularProgressIndicator()),
                                  );
                                }

                                if (provider.userProgress.isEmpty) {
                                  return const SizedBox(
                                    height: 200,
                                    child: Center(
                                      child: Text('No user progress data available'),
                                    ),
                                  );
                                }

                                return Scrollbar(
                                  controller: _progressVerticalScrollController,
                                  thumbVisibility: true,
                                  child: SingleChildScrollView(
                                    controller: _progressVerticalScrollController,
                                    scrollDirection: Axis.vertical,
                                    child: Scrollbar(
                                      controller: _progressHorizontalScrollController,
                                      thumbVisibility: true,
                                      child: SingleChildScrollView(
                                        controller: _progressHorizontalScrollController,
                                        scrollDirection: Axis.horizontal,
                                        child: ConstrainedBox(
                                          constraints: BoxConstraints(
                                            minWidth: tableConstraints.maxWidth,
                                          ),
                                          child: DataTable(
                                          headingRowColor: AdminDataTableConfig.getTableProperties()['headingRowColor'] as MaterialStateProperty<Color>,
                                          dataRowColor: AdminDataTableConfig.getTableProperties()['dataRowColor'] as MaterialStateProperty<Color>,
                                          headingRowHeight: AdminDataTableConfig.headingRowHeight,
                                          dataRowMinHeight: AdminDataTableConfig.dataRowMinHeight,
                                          dataRowMaxHeight: AdminDataTableConfig.dataRowMaxHeight,
                                          columns: [
                                            DataColumn(
                                              label: AdminDataTableConfig.getColumnLabel('ID'),
                                              numeric: true,
                                            ),
                                            DataColumn(
                                              label: AdminDataTableConfig.getColumnLabel('User'),
                                            ),
                                            DataColumn(
                                              label: AdminDataTableConfig.getColumnLabel('Watched Series'),
                                              numeric: true,
                                            ),
                                            DataColumn(
                                              label: AdminDataTableConfig.getColumnLabel('Goal'),
                                              numeric: true,
                                            ),
                                            DataColumn(
                                              label: AdminDataTableConfig.getColumnLabel('Progress'),
                                            ),
                                            DataColumn(
                                              label: AdminDataTableConfig.getColumnLabel('Status'),
                                            ),
                                          ],
                                          rows: provider.userProgress.map((progress) {
                                            final progressPercent = progress['progress'] as int? ?? 0;
                                            final isCompleted = progress['status'] == 'Completed';
                                            
                                            return DataRow(
                                              cells: [
                                                DataCell(
                                                  Text(
                                                    progress['id'].toString(),
                                                    style: AdminDataTableConfig.getCellTextStyle(theme.textTheme),
                                                  ),
                                                ),
                                                DataCell(
                                                  Text(
                                                    progress['userName'] as String? ?? 'Unknown',
                                                    style: AdminDataTableConfig.getCellTextStyle(theme.textTheme),
                                                  ),
                                                ),
                                                DataCell(
                                                  Text(
                                                    (progress['watchedSeries'] as int? ?? 0).toString(),
                                                    style: AdminDataTableConfig.getCellTextStyle(theme.textTheme),
                                                  ),
                                                ),
                                                DataCell(
                                                  Text(
                                                    (progress['goal'] as int? ?? 0).toString(),
                                                    style: AdminDataTableConfig.getCellTextStyle(theme.textTheme),
                                                  ),
                                                ),
                                                DataCell(
                                                  SizedBox(
                                                    width: 100,
                                                    child: Column(
                                                      crossAxisAlignment: CrossAxisAlignment.start,
                                                      mainAxisSize: MainAxisSize.min,
                                                      children: [
                                                        LinearProgressIndicator(
                                                          value: progressPercent / 100,
                                                          backgroundColor: AppColors.textSecondary.withOpacity(0.1),
                                                          valueColor: AlwaysStoppedAnimation<Color>(
                                                            isCompleted ? AppColors.successColor : AppColors.primaryColor,
                                                          ),
                                                          minHeight: 6,
                                                        ),
                                                        const SizedBox(height: 2),
                                                        Text(
                                                          '$progressPercent%',
                                                          style: AdminDataTableConfig.getCellSmallTextStyle(theme.textTheme).copyWith(
                                                            color: AppColors.textSecondary,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                                DataCell(
                                                  Container(
                                                    padding: AdminDataTableConfig.cellPadding,
                                                    decoration: BoxDecoration(
                                                      color: isCompleted 
                                                          ? AppColors.successColor.withOpacity(0.1)
                                                          : AppColors.primaryColor.withOpacity(0.1),
                                                      borderRadius: BorderRadius.circular(AppDim.borderRadius),
                                                    ),
                                                    child: Text(
                                                      isCompleted ? 'Completed' : 'Processing',
                                                      style: AdminDataTableConfig.getCellSmallTextStyle(theme.textTheme).copyWith(
                                                        color: isCompleted 
                                                            ? AppColors.successColor
                                                            : AppColors.primaryColor,
                                                        fontWeight: FontWeight.w500,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            );
                                          }).toList(),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 12),
                      
                      // Top 3 Watchers Cards
                      Text(
                        'Top 3 Watchers',
                        style: theme.textTheme.titleLarge?.copyWith(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Consumer<AdminChallengeProvider>(
                        builder: (context, provider, child) {
                          if (provider.isLoadingSummary) {
                            return const SizedBox(
                              height: 100,
                              child: Center(child: CircularProgressIndicator()),
                            );
                          }
                          
                          if (provider.topWatchers.isEmpty) {
                            return Card(
                              color: AppColors.cardBackground,
                              child: Padding(
                                padding: const EdgeInsets.all(AppDim.paddingMedium),
                                child: Center(
                                  child: Text(
                                    'No watcher data available',
                                    style: TextStyle(color: AppColors.textSecondary),
                                  ),
                                ),
                              ),
                            );
                          }
                          
                          // Use responsive layout based on screen width
                          final screenWidth = MediaQuery.of(context).size.width;
                          final isMobile = screenWidth < 600;
                          
                          if (isMobile) {
                            // Mobile: Stack cards vertically
                            return Column(
                              mainAxisSize: MainAxisSize.min,
                              children: provider.topWatchers.take(3).toList().asMap().entries.map((entry) {
                                final index = entry.key;
                                final watcher = entry.value;
                                return Padding(
                                  padding: EdgeInsets.only(
                                    bottom: index < provider.topWatchers.length - 1 
                                        ? AppDim.paddingMedium 
                                        : 0,
                                  ),
                                  child: _buildWatcherCard(context, theme, watcher, index),
                                );
                              }).toList(),
                            );
                          } else {
                            // Desktop: Row layout
                            return Row(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: provider.topWatchers.take(3).toList().asMap().entries.map((entry) {
                                final index = entry.key;
                                final watcher = entry.value;
                                return Expanded(
                                  child: Padding(
                                    padding: EdgeInsets.only(
                                      right: index < provider.topWatchers.length - 1 
                                          ? AppDim.paddingMedium 
                                          : 0,
                                    ),
                                    child: _buildWatcherCard(context, theme, watcher, index),
                                  ),
                                );
                              }).toList(),
                            );
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildWatcherCard(BuildContext context, ThemeData theme, Map<String, dynamic> watcher, int index) {
    // Use watchedSeriesCount (series where user watched 100% of episodes) instead of ratings + watchlist
    final totalWatched = watcher['watchedSeriesCount'] as int? ?? 0;
    
    return Card(
      color: AppColors.cardBackground,
      child: Padding(
        padding: const EdgeInsets.all(AppDim.paddingMedium),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Profile picture/avatar placeholder
                CircleAvatar(
                  radius: 24,
                  backgroundColor: AppColors.primaryColor.withOpacity(0.2),
                  child: Text(
                    (watcher['userName'] as String? ?? watcher['email'] as String? ?? 'U')
                        .substring(0, 1)
                        .toUpperCase(),
                    style: TextStyle(
                      color: AppColors.primaryColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ),
                const SizedBox(width: AppDim.paddingSmall),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        watcher['userName'] as String? ?? 'User',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        watcher['email'] as String? ?? 'Unknown',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                // Rank badge
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.primaryColor.withOpacity(0.2),
                  ),
                  child: Center(
                    child: Text(
                      '${index + 1}',
                      style: TextStyle(
                        color: AppColors.primaryColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppDim.paddingMedium),
            // Watched series count (main metric)
            Container(
              padding: const EdgeInsets.all(AppDim.paddingSmall),
              decoration: BoxDecoration(
                color: AppColors.primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(AppDim.radiusSmall),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.play_circle_outline,
                    color: AppColors.primaryColor,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '$totalWatched',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryColor,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Watched',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppDim.paddingSmall),
            // Stats row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem(
                  Icons.star,
                  'Ratings',
                  (watcher['ratingsCount'] as int? ?? 0).toString(),
                ),
                _buildStatItem(
                  Icons.bookmark,
                  'Watchlist',
                  (watcher['watchlistCount'] as int? ?? 0).toString(),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(IconData icon, String label, String value) {
    return Column(
      children: [
        Icon(icon, color: AppColors.primaryColor, size: 20),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

