import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dim.dart';
import '../../models/challenge.dart';
import '../../providers/auth_provider.dart';
import '../providers/mobile_challenges_provider.dart';

/// Mobile challenges screen showing available challenges and user progress
class MobileChallengesScreen extends StatefulWidget {
  const MobileChallengesScreen({super.key});

  @override
  State<MobileChallengesScreen> createState() => _MobileChallengesScreenState();
}

class _MobileChallengesScreenState extends State<MobileChallengesScreen> {
  final ScrollController _scrollController = ScrollController();
  bool _isLoadingMore = false;

  DateTime? _lastLoadTime;
  static const _cacheTimeout = Duration(seconds: 10); // Cache for 10 seconds

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadChallenges();
    });

    // Listen for scroll to implement pagination
    _scrollController.addListener(_onScroll);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Refresh when returning to this screen (e.g., after completing a series)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_isLoadingMore) {
        final now = DateTime.now();
        if (_lastLoadTime == null || 
            now.difference(_lastLoadTime!) > _cacheTimeout) {
          _loadChallenges();
        }
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent * 0.8) {
      // Load more when scrolled 80% down
      _loadMoreChallenges();
    }
  }

  Future<void> _loadChallenges() async {
    try {
      final provider = Provider.of<MobileChallengesProvider>(context, listen: false);
      await provider.fetchAvailableChallenges();
      
      // Load user progress if logged in
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      if (authProvider.isAuthenticated) {
        await provider.fetchMyProgress();
      }
      
      if (mounted) {
        setState(() {
          _lastLoadTime = DateTime.now();
        });
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

  Future<void> _loadMoreChallenges() async {
    if (_isLoadingMore) return;
    
    setState(() {
      _isLoadingMore = true;
    });

    try {
      final provider = Provider.of<MobileChallengesProvider>(context, listen: false);
      final nextPage = provider.currentPage + 1;
      await provider.fetchAvailableChallenges(page: nextPage);
    } catch (e) {
      // Silently fail for pagination
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingMore = false;
        });
      }
    }
  }

  Future<void> _handleStartChallenge(Challenge challenge) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (!authProvider.isAuthenticated) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please login to start challenges'),
          backgroundColor: AppColors.dangerColor,
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.cardBackground,
        title: Text(
          'Start Challenge',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: Text(
          'Do you want to start "${challenge.name}"?',
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
              foregroundColor: AppColors.primaryColor,
            ),
            child: const Text('Start'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final provider = Provider.of<MobileChallengesProvider>(context, listen: false);
        await provider.startChallenge(challenge.id);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Started "${challenge.name}" successfully!'),
              backgroundColor: AppColors.successColor,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error starting challenge: $e'),
              backgroundColor: AppColors.dangerColor,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final authProvider = Provider.of<AuthProvider>(context);

    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      appBar: AppBar(
        title: const Text('Challenges'),
        backgroundColor: AppColors.primaryColor,
        foregroundColor: AppColors.textLight,
        elevation: 0,
      ),
      body: SafeArea(
        child: Consumer<MobileChallengesProvider>(
          builder: (context, provider, child) {
            if (provider.isLoading && provider.availableChallenges.isEmpty) {
              return const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryColor),
                ),
              );
            }

            if (provider.availableChallenges.isEmpty) {
              return _buildEmptyState(theme);
            }

            return RefreshIndicator(
              onRefresh: _loadChallenges,
              color: AppColors.primaryColor,
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDim.paddingMedium,
                  vertical: AppDim.paddingMedium,
                ),
                itemCount: provider.availableChallenges.length + (_isLoadingMore ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index >= provider.availableChallenges.length) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(AppDim.paddingMedium),
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryColor),
                        ),
                      ),
                    );
                  }

                  final challenge = provider.availableChallenges[index];
                  final progress = provider.getProgressForChallenge(challenge.id);
                  final hasStarted = provider.hasStartedChallenge(challenge.id);

                  return _buildChallengeCard(
                    challenge,
                    progress,
                    hasStarted,
                    authProvider.isAuthenticated,
                    theme,
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.flag_outlined,
            size: 80,
            color: AppColors.textSecondary.withOpacity(0.5),
          ),
          const SizedBox(height: AppDim.paddingLarge),
          Text(
            'No challenges available',
            style: theme.textTheme.titleLarge?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppDim.paddingSmall),
          Text(
            'Check back later for new challenges!',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChallengeCard(
    Challenge challenge,
    Map<String, dynamic>? progress,
    bool hasStarted,
    bool isAuthenticated,
    ThemeData theme,
  ) {
    final progressCount = progress?['progressCount'] as int? ?? 0;
    final status = progress?['status'] as String? ?? 'NotStarted';
    final isCompleted = status == 'Completed';
    final isInProgress = status == 'InProgress' || hasStarted;

    final progressColor = isCompleted
        ? AppColors.successColor
        : isInProgress
            ? AppColors.primaryColor
            : AppColors.textSecondary;

    final progressPercentage = challenge.targetCount > 0
        ? (progressCount / challenge.targetCount).clamp(0.0, 1.0)
        : 0.0;

    return Card(
      margin: const EdgeInsets.only(bottom: AppDim.paddingMedium),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDim.radiusMedium),
      ),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(AppDim.paddingMedium),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title and Status
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        challenge.name,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      if (challenge.description != null && challenge.description!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          challenge.description!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: AppDim.paddingSmall),
                // Status badge
                if (isInProgress || isCompleted)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: progressColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(AppDim.radiusSmall),
                      border: Border.all(
                        color: progressColor.withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      isCompleted ? 'Completed' : 'In Progress',
                      style: TextStyle(
                        color: progressColor,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: AppDim.paddingMedium),

            // Difficulty, Goal, and Participants
            Row(
              children: [
                // Difficulty chip
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _getDifficultyColor(challenge.difficulty).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(AppDim.radiusSmall),
                  ),
                  child: Text(
                    challenge.difficulty,
                    style: TextStyle(
                      color: _getDifficultyColor(challenge.difficulty),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: AppDim.paddingSmall),
                // Goal text
                Text(
                  'Goal: ${challenge.targetCount}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Spacer(),
                // Participants count
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.people_outline,
                      size: 14,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${challenge.participantsCount}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: AppDim.paddingMedium),

            // Progress bar (only if started)
            if (isInProgress || isCompleted) ...[
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Progress',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        '$progressCount / ${challenge.targetCount}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AppDim.radiusSmall),
                    child: LinearProgressIndicator(
                      value: progressPercentage,
                      minHeight: 8,
                      backgroundColor: AppColors.textSecondary.withOpacity(0.1),
                      valueColor: AlwaysStoppedAnimation<Color>(progressColor),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${(progressPercentage * 100).toStringAsFixed(0)}% complete',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ] else ...[
              // Start Challenge Button
              if (isAuthenticated)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _handleStartChallenge(challenge),
                    icon: const Icon(Icons.flag, size: 18),
                    label: const Text('Start Challenge'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryColor,
                      foregroundColor: AppColors.textLight,
                      padding: const EdgeInsets.symmetric(
                        vertical: AppDim.paddingSmall,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppDim.radiusMedium),
                      ),
                    ),
                  ),
                )
              else
                Text(
                  'Login to start this challenge',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                    fontStyle: FontStyle.italic,
                  ),
                  textAlign: TextAlign.center,
                ),
            ],
          ],
        ),
      ),
    );
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
        return AppColors.textSecondary;
    }
  }
}
