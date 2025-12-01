import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dim.dart';
import '../../models/series.dart';
import '../../providers/watchlist_provider.dart';
import '../../providers/auth_provider.dart';
import '../../core/widgets/image_with_placeholder.dart';
import '../widgets/mobile_page_route.dart';
import 'mobile_series_detail_screen.dart';

// Import AvatarImage from image_with_placeholder
// AvatarImage is already available via image_with_placeholder.dart

/// Status screen showing series organized by To Do, In Progress, Finished
class MobileStatusScreen extends StatefulWidget {
  const MobileStatusScreen({super.key});

  @override
  State<MobileStatusScreen> createState() => _MobileStatusScreenState();
}

class _MobileStatusScreenState extends State<MobileStatusScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int? _currentUserId;
  List<Series> _toDoSeries = [];
  List<Series> _inProgressSeries = [];
  List<Series> _finishedSeries = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadUserData();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  int? _extractUserId(String? token) {
    if (token == null || token.isEmpty) return null;
    try {
      final decoded = JwtDecoder.decode(token);
      final dynamic rawId = decoded['userId'] ?? decoded['id'] ?? decoded['nameid'] ?? decoded['sub'];
      if (rawId is int) return rawId;
      if (rawId is String) return int.tryParse(rawId);
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<void> _loadUserData() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final watchlistProvider = Provider.of<WatchlistProvider>(context, listen: false);
    
    final userId = _extractUserId(auth.token);
    if (userId == null) return;
    
    _currentUserId = userId;
    setState(() {
      _isLoading = true;
    });

    try {
      // Load watchlist items
      await watchlistProvider.loadWatchlist();
      
      // For now, we'll categorize based on watchlist items
      // In a real implementation, you'd check episode progress to determine status
      final allItems = watchlistProvider.items;
      
      // This is a simplified categorization - in reality you'd check episode progress
      setState(() {
        _toDoSeries = allItems.take(allItems.length ~/ 3).toList();
        _inProgressSeries = allItems.skip(allItems.length ~/ 3).take(allItems.length ~/ 3).toList();
        _finishedSeries = allItems.skip(2 * (allItems.length ~/ 3)).toList();
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Map<String, String?> _getUserInfo(String? token) {
    if (token == null || token.isEmpty) {
      return {'email': 'Unknown', 'name': 'Unknown User', 'avatarUrl': null};
    }

    try {
      final decodedToken = JwtDecoder.decode(token);
      final email = decodedToken['email'] as String? ?? 
                   decodedToken['sub'] as String? ?? 
                   'Unknown';
      
      String name = 'User';
      if (email != 'Unknown') {
        final parts = email.split('@');
        if (parts.isNotEmpty) {
          final namePart = parts[0];
          name = namePart[0].toUpperCase() + namePart.substring(1);
        }
      }
      
      final avatarUrl = decodedToken['avatarUrl'] as String?;
      return {'email': email, 'name': name, 'avatarUrl': avatarUrl};
    } catch (e) {
      return {'email': 'Unknown', 'name': 'Unknown User', 'avatarUrl': null};
    }
  }

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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final auth = Provider.of<AuthProvider>(context);
    final userInfo = _getUserInfo(auth.token);
    final initials = _getInitials(userInfo['email']!);

    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textLight),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Status'),
        backgroundColor: AppColors.primaryColor,
        foregroundColor: AppColors.textLight,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.textLight,
          labelColor: AppColors.textLight,
          unselectedLabelColor: AppColors.textLight.withOpacity(0.7),
          tabs: const [
            Tab(text: 'To do'),
            Tab(text: 'In progress'),
            Tab(text: 'Finished'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildSeriesList(_toDoSeries, theme),
                _buildSeriesList(_inProgressSeries, theme),
                _buildSeriesList(_finishedSeries, theme, showFullProgress: true),
              ],
            ),
    );
  }

  Widget _buildSeriesList(List<Series> series, ThemeData theme, {bool showFullProgress = false}) {
    if (series.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.movie_outlined,
              size: 64,
              color: AppColors.textSecondary.withOpacity(0.5),
            ),
            const SizedBox(height: AppDim.paddingMedium),
            Text(
              'No series in this category',
              style: theme.textTheme.titleMedium?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(AppDim.paddingMedium),
      itemCount: series.length,
      itemBuilder: (context, index) {
        final seriesItem = series[index];
        return _buildSeriesCard(seriesItem, theme, showFullProgress);
      },
    );
  }

  Widget _buildSeriesCard(Series series, ThemeData theme, bool showFullProgress) {
    // Calculate progress (simplified - in reality you'd get this from episode progress)
    final progress = showFullProgress ? 1.0 : 0.5; // 50% for in progress, 100% for finished
    final totalEpisodes = 12; // This should come from series data
    final currentEpisode = (totalEpisodes * progress).round();

    return Card(
      margin: const EdgeInsets.only(bottom: AppDim.paddingMedium),
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
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Series Image
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: ImageWithPlaceholder(
                  imageUrl: series.imageUrl,
                  width: 80,
                  height: 120,
                  fit: BoxFit.cover,
                  placeholderIcon: Icons.movie,
                  placeholderIconSize: 40,
                ),
              ),
              const SizedBox(width: 12),
              // Series Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      series.title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Episode $currentEpisode of $totalEpisodes',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Progress Bar
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: progress,
                        backgroundColor: AppColors.primaryColor.withOpacity(0.2),
                        valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryColor),
                        minHeight: 6,
                      ),
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

