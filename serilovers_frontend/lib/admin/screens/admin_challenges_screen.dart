import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dim.dart';
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
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadChallenges();
      _loadSummary();
    });
  }

  /// Load challenges from provider
  Future<void> _loadChallenges() async {
    try {
      final provider = Provider.of<AdminChallengeProvider>(context, listen: false);
      await provider.fetchAll();
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
    
    return Container(
      color: AppColors.backgroundColor,
      child: Padding(
        padding: const EdgeInsets.all(AppDim.paddingLarge),
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight,
                ),
                child: IntrinsicHeight(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
            // Add button at top-right
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
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
            const SizedBox(height: AppDim.paddingMedium),
            // DataTable
            SizedBox(
              height: 400, // Fixed height for table with vertical scroll
              child: Consumer<AdminChallengeProvider>(
                builder: (context, provider, child) {
                  if (provider.isLoading) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (provider.items.isEmpty) {
                    return Center(
                      child: Text(
                        'No challenges found',
                        style: theme.textTheme.bodyLarge,
                      ),
                    );
                  }

                  return SingleChildScrollView(
                    scrollDirection: Axis.vertical,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                      headingRowColor: MaterialStateProperty.all(AppColors.cardBackground),
                      dataRowColor: MaterialStateProperty.resolveWith((states) {
                        if (states.contains(MaterialState.selected)) {
                          return AppColors.primaryColor.withOpacity(0.1);
                        }
                        return AppColors.cardBackground;
                      }),
                      columns: const [
                        DataColumn(
                          label: Text('Name'),
                        ),
                        DataColumn(
                          label: Text('Difficulty'),
                        ),
                        DataColumn(
                          label: Text('Target'),
                          numeric: true,
                        ),
                        DataColumn(
                          label: Text('Participants'),
                          numeric: true,
                        ),
                        DataColumn(
                          label: Text('Actions'),
                        ),
                      ],
                      rows: provider.items.map((challenge) {
                        return DataRow(
                          cells: [
                            DataCell(
                              Text(
                                challenge.name,
                                style: theme.textTheme.bodyMedium,
                              ),
                            ),
                            DataCell(
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: _getDifficultyColor(challenge.difficulty).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(AppDim.borderRadius),
                                ),
                                child: Text(
                                  challenge.difficulty,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: _getDifficultyColor(challenge.difficulty),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ),
                            DataCell(
                              Text(
                                challenge.targetCount.toString(),
                                style: theme.textTheme.bodyMedium,
                              ),
                            ),
                            DataCell(
                              Text(
                                challenge.participantsCount.toString(),
                                style: theme.textTheme.bodyMedium,
                              ),
                            ),
                            DataCell(
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.edit),
                                    color: AppColors.primaryColor,
                                    onPressed: () => _handleEditChallenge(challenge),
                                    tooltip: 'Edit',
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete),
                                    color: AppColors.dangerColor,
                                    onPressed: () => _handleDeleteChallenge(challenge),
                                    tooltip: 'Delete',
                                  ),
                                ],
                              ),
                            ),
                          ],
                        );
                      }).toList(),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: AppDim.paddingLarge),
            
            // Top 3 Watchers Cards
            Text(
              'Top 3 Watchers',
              style: theme.textTheme.titleLarge?.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppDim.paddingMedium),
            Consumer<AdminChallengeProvider>(
              builder: (context, provider, child) {
                if (provider.isLoadingSummary) {
                  return const Center(child: CircularProgressIndicator());
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
                
                return Row(
                  children: provider.topWatchers.take(3).toList().asMap().entries.map((entry) {
                    final index = entry.key;
                    final watcher = entry.value;
                    return Expanded(
                      child: Card(
                        color: AppColors.cardBackground,
                        margin: EdgeInsets.only(
                          right: index < provider.topWatchers.length - 1 
                              ? AppDim.paddingMedium 
                              : 0,
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(AppDim.paddingMedium),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 40,
                                    height: 40,
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
                                          fontSize: 18,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: AppDim.paddingSmall),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          watcher['email'] as String? ?? 'Unknown',
                                          style: theme.textTheme.titleMedium?.copyWith(
                                            fontWeight: FontWeight.bold,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        Text(
                                          watcher['userName'] as String? ?? 'User ID: ${watcher['id']}',
                                          style: theme.textTheme.bodySmall?.copyWith(
                                            color: AppColors.textSecondary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: AppDim.paddingSmall),
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
                      ),
                    );
                  }).toList(),
                );
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

