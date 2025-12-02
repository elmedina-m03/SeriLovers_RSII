import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import 'package:intl/intl.dart';
import '../../providers/auth_provider.dart';
import '../../providers/theme_provider.dart';
import '../../providers/episode_progress_provider.dart';
import '../../providers/series_provider.dart';
import '../../services/episode_progress_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dim.dart';
import '../../core/widgets/image_with_placeholder.dart';
import '../../models/series.dart';
import '../../models/episode_progress.dart';
import '../widgets/mobile_page_route.dart';
import 'mobile_status_screen.dart';
import 'mobile_statistics_screen.dart';
import 'mobile_series_detail_screen.dart';

/// Mobile profile screen showing user info and logout button
class MobileProfileScreen extends StatefulWidget {
  const MobileProfileScreen({super.key});

  @override
  State<MobileProfileScreen> createState() => _MobileProfileScreenState();
}

class _MobileProfileScreenState extends State<MobileProfileScreen> {
  List<Series> _recentlyWatchedSeries = [];
  bool _isLoadingWatchedHistory = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadWatchedHistory();
    });
  }

  Future<void> _loadWatchedHistory() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (!authProvider.isAuthenticated) return;

    setState(() {
      _isLoadingWatchedHistory = true;
    });

    try {
      final progressService = EpisodeProgressService();
      final seriesProvider = Provider.of<SeriesProvider>(context, listen: false);
      final token = authProvider.token;

      if (token == null || token.isEmpty) {
        if (mounted) {
          setState(() {
            _recentlyWatchedSeries = [];
            _isLoadingWatchedHistory = false;
          });
        }
        return;
      }

      // Load user progress from service
      final userProgress = await progressService.getUserProgress(token: token);

      if (userProgress.isEmpty) {
        if (mounted) {
          setState(() {
            _recentlyWatchedSeries = [];
            _isLoadingWatchedHistory = false;
          });
        }
        return;
      }

      // Get unique series IDs from progress, ordered by most recent watched date
      final seriesProgressMap = <int, DateTime>{};
      for (final progress in userProgress) {
        if (progress.seriesId > 0) {
          final watchedDate = progress.watchedAt;
          if (!seriesProgressMap.containsKey(progress.seriesId) ||
              watchedDate.isAfter(seriesProgressMap[progress.seriesId]!)) {
            seriesProgressMap[progress.seriesId] = watchedDate;
          }
        }
      }

      // Sort by most recent watched date
      final sortedSeriesIds = seriesProgressMap.entries
          .toList()
          ..sort((a, b) => b.value.compareTo(a.value));
      final seriesIds = sortedSeriesIds.map((e) => e.key).take(10).toList();

      // Load all series to get details
      await seriesProvider.fetchSeries(page: 1, pageSize: 200);

      // Get series details for recently watched
      final recentlyWatched = <Series>[];
      for (final seriesId in seriesIds) {
        final series = seriesProvider.getById(seriesId);
        if (series != null) {
          recentlyWatched.add(series);
        }
      }

      if (mounted) {
        setState(() {
          _recentlyWatchedSeries = recentlyWatched;
          _isLoadingWatchedHistory = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingWatchedHistory = false;
        });
      }
    }
  }

  /// Get user info from JWT token
  Map<String, String?> _getUserInfo(String? token) {
    if (token == null || token.isEmpty) {
      return {'email': 'Unknown', 'name': 'Unknown User', 'avatarUrl': null};
    }

    try {
      final decodedToken = JwtDecoder.decode(token);
      final email = decodedToken['email'] as String? ?? 
                   decodedToken['sub'] as String? ?? 
                   'Unknown';
      
      // Try to get name from token claim first, otherwise extract from email
      String name = decodedToken['name'] as String? ?? '';
      if (name.isEmpty) {
        if (email != 'Unknown') {
          final parts = email.split('@');
          if (parts.isNotEmpty) {
            final namePart = parts[0];
            // Capitalize first letter
            name = namePart[0].toUpperCase() + namePart.substring(1);
          }
        } else {
          name = 'User';
        }
      }
      
      final avatarUrl = decodedToken['avatarUrl'] as String?;
      return {'email': email, 'name': name, 'avatarUrl': avatarUrl};
    } catch (e) {
      return {'email': 'Unknown', 'name': 'Unknown User', 'avatarUrl': null};
    }
  }

  /// Try to read joined date from JWT token if available
  DateTime? _getJoinedDate(String? token) {
    if (token == null || token.isEmpty) return null;
    try {
      final decoded = JwtDecoder.decode(token);
      final raw = decoded['dateCreated'] ?? decoded['createdAt'];
      if (raw == null) return null;

      if (raw is String) {
        // Expecting ISO 8601 string
        return DateTime.tryParse(raw);
      }
      if (raw is int) {
        // Assume seconds since epoch
        return DateTime.fromMillisecondsSinceEpoch(raw * 1000, isUtc: true).toLocal();
      }
    } catch (_) {
      return null;
    }
    return null;
  }

  /// Get initials from email or name
  String _getInitials(String email) {
    if (email == 'Unknown') return 'U';
    final parts = email.split('@');
    if (parts.isNotEmpty) {
      final namePart = parts[0];
      if (namePart.length >= 2) {
        return namePart.substring(0, 2).toUpperCase();
      }
      return namePart[0].toUpperCase();
    }
    return 'U';
  }

  Future<void> _handleLogout(BuildContext context) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDim.radiusMedium),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              'Cancel',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryColor,
              foregroundColor: AppColors.textLight,
            ),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      await authProvider.logout();
      
      // Navigate to login screen
      if (context.mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil(
          '/mobile_login',
          (route) => false,
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
        title: const Text('Profile'),
        backgroundColor: AppColors.primaryColor,
        foregroundColor: AppColors.textLight,
        elevation: 0,
      ),
      body: SafeArea(
        child: Consumer<AuthProvider>(
          builder: (context, authProvider, child) {
            final userInfo = _getUserInfo(authProvider.token);
            final initials = _getInitials(userInfo['email']!);
            final joinedDate = _getJoinedDate(authProvider.token);

            return SingleChildScrollView(
              padding: const EdgeInsets.all(AppDim.paddingLarge),
              child: Column(
                children: [
                  const SizedBox(height: AppDim.paddingLarge),

                  // User Avatar Circle
                  AvatarImage(
                    avatarUrl: userInfo['avatarUrl'],
                    radius: 60,
                    initials: initials,
                    placeholderIcon: Icons.person,
                  ),

                  const SizedBox(height: AppDim.paddingLarge),

                  // User Name
                  Text(
                    userInfo['name']!,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: AppDim.paddingSmall),

                  // Username (from email)
                  Text(
                    '@${userInfo['email']!.split('@')[0]}',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),

                  const SizedBox(height: AppDim.paddingLarge),

                  // Recently Watched Section
                  if (_recentlyWatchedSeries.isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: AppDim.paddingSmall),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Recently Watched',
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          TextButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const MobileStatusScreen(),
                                ),
                              );
                            },
                            child: const Text('See All'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppDim.paddingSmall),
                    SizedBox(
                      height: 180,
                      child: _isLoadingWatchedHistory
                          ? const Center(child: CircularProgressIndicator())
                          : ListView.builder(
                              scrollDirection: Axis.horizontal,
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding: const EdgeInsets.symmetric(horizontal: AppDim.paddingMedium),
                              itemCount: _recentlyWatchedSeries.length,
                              itemBuilder: (context, index) {
                                final series = _recentlyWatchedSeries[index];
                                return _buildWatchedSeriesCard(series, context, theme);
                              },
                            ),
                    ),
                    const SizedBox(height: AppDim.paddingLarge),
                  ],

                  // Menu Items
                  _buildMenuCard(
                    context,
                    theme,
                    icon: Icons.edit,
                    title: 'Edit Profile',
                    onTap: () async {
                      final result = await Navigator.pushNamed(
                        context,
                        '/mobile_edit_profile',
                      );
                      if (result == true && mounted) {
                        setState(() {});
                        // Reload watched history in case user watched something
                        _loadWatchedHistory();
                      }
                    },
                  ),
                  
                  _buildMenuCard(
                    context,
                    theme,
                    icon: Icons.bookmark,
                    title: 'Status',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const MobileStatusScreen(),
                        ),
                      );
                    },
                  ),
                  
                  _buildMenuCard(
                    context,
                    theme,
                    icon: Icons.bar_chart,
                    title: 'Statistics',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const MobileStatisticsScreen(),
                        ),
                      );
                    },
                  ),
                  
                  _buildMenuCard(
                    context,
                    theme,
                    icon: Icons.settings,
                    title: 'Settings',
                    onTap: () {
                      // Show settings dialog
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Settings'),
                          content: Consumer<ThemeProvider>(
                            builder: (context, themeProvider, child) {
                              return Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  ListTile(
                                    leading: Icon(
                                      themeProvider.isDarkMode ? Icons.dark_mode : Icons.light_mode,
                                      color: AppColors.primaryColor,
                                    ),
                                    title: const Text('Dark Mode'),
                                    trailing: Switch(
                                      value: themeProvider.isDarkMode,
                                      onChanged: (value) {
                                        themeProvider.toggleDarkMode();
                                      },
                                      activeColor: AppColors.primaryColor,
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('Close'),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  
                  _buildMenuCard(
                    context,
                    theme,
                    icon: Icons.logout,
                    title: 'Log out',
                    onTap: () => _handleLogout(context),
                    isDestructive: true,
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildMenuCard(
    BuildContext context,
    ThemeData theme, {
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: AppDim.paddingSmall),
      color: AppColors.cardBackground,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDim.radiusMedium),
      ),
      elevation: 2,
      child: ListTile(
        leading: Icon(
          icon,
          color: isDestructive ? AppColors.dangerColor : AppColors.primaryColor,
        ),
        title: Text(
          title,
          style: TextStyle(
            color: isDestructive ? AppColors.dangerColor : AppColors.textPrimary,
          ),
        ),
        trailing: Icon(
          Icons.chevron_right,
          color: AppColors.textSecondary,
        ),
        onTap: onTap,
      ),
    );
  }

  Widget _buildWatchedSeriesCard(Series series, BuildContext context, ThemeData theme) {
    return Container(
      width: 120,
      margin: const EdgeInsets.only(right: AppDim.paddingMedium),
      child: Card(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        elevation: 2,
        child: InkWell(
          onTap: () {
            Navigator.push(
              context,
              MobilePageRoute(
                builder: (context) => MobileSeriesDetailScreen(series: series),
              ),
            );
          },
          borderRadius: BorderRadius.circular(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                child: ImageWithPlaceholder(
                  imageUrl: series.imageUrl,
                  height: 100,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  placeholderIcon: Icons.movie,
                  placeholderIconSize: 40,
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      series.title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.star,
                          size: 12,
                          color: AppColors.primaryColor,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          series.rating.toStringAsFixed(1),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppColors.textSecondary,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
