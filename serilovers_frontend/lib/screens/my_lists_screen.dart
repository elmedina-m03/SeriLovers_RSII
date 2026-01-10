import 'package:flutter/material.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import 'package:provider/provider.dart';

import '../models/watchlist.dart';
import '../providers/auth_provider.dart';
import '../providers/watchlist_provider.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_dim.dart';

class MyListsScreen extends StatefulWidget {
  const MyListsScreen({super.key});

  @override
  State<MyListsScreen> createState() => _MyListsScreenState();
}

class _MyListsScreenState extends State<MyListsScreen> {
  int? _currentUserId;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase();
      });
    });
    // Load only once on init
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_isLoading) {
        _isLoading = true;
        _loadWatchlists();
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Refresh when returning to this screen (e.g., after creating a list)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_isLoading && _currentUserId != null) {
        _loadWatchlists();
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  int? _extractUserId(String? token) {
    if (token == null || token.isEmpty) return null;
    try {
      final decoded = JwtDecoder.decode(token);
      final dynamic rawId =
          decoded['userId'] ?? decoded['id'] ?? decoded['nameid'] ?? decoded['sub'];
      if (rawId is int) return rawId;
      if (rawId is String) {
        return int.tryParse(rawId);
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<void> _loadWatchlists() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final watchlists = Provider.of<WatchlistProvider>(context, listen: false);

    final userId = _extractUserId(auth.token);
    if (userId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not determine current user ID from token.'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    _currentUserId = userId;
    await watchlists.loadUserWatchlists(userId);
  }

  Future<void> _onRefresh() async {
    if (_currentUserId == null) {
      await _loadWatchlists();
    } else {
      final watchlists = Provider.of<WatchlistProvider>(context, listen: false);
      await watchlists.loadUserWatchlists(_currentUserId!);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      appBar: AppBar(
        title: const Text('My Lists'),
        backgroundColor: AppColors.primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: Consumer<WatchlistProvider>(
          builder: (context, provider, child) {
            if (provider.loading) {
              return const Center(
                child: CircularProgressIndicator(),
              );
            }

            if (provider.error != null) {
              return Center(
                child: Container(
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.red.shade100,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error, color: Colors.red),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          provider.error!,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            return RefreshIndicator(
              onRefresh: _onRefresh,
              child: CustomScrollView(
                slivers: [
                  // Search bar - Modern design matching other screens
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(AppDim.paddingMedium, AppDim.paddingSmall, AppDim.paddingMedium, AppDim.paddingSmall),
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: 'Search lists...',
                          hintStyle: TextStyle(color: AppColors.textSecondary.withOpacity(0.7)),
                          prefixIcon: Icon(Icons.search, color: AppColors.primaryColor),
                          filled: true,
                          fillColor: AppColors.cardBackground,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: AppColors.textSecondary.withOpacity(0.2)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: AppColors.textSecondary.withOpacity(0.2)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: AppColors.primaryColor, width: 2),
                          ),
                          suffixIcon: _searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: Icon(Icons.clear, color: AppColors.textSecondary),
                                  onPressed: () {
                                    _searchController.clear();
                                  },
                                )
                              : null,
                        ),
                        style: TextStyle(color: AppColors.textPrimary),
                        textInputAction: TextInputAction.search,
                      ),
                    ),
                  ),
                  // Title and subtitle
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'My Lists',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Organize your favorite series your way',
                            style: TextStyle(
                              fontSize: 14,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Watchlist cards grid
                  Builder(
                    builder: (context) {
                      // Filter lists by search query
                      final filteredLists = _searchQuery.isEmpty
                          ? provider.lists
                          : provider.lists.where((list) =>
                              list.name.toLowerCase().contains(_searchQuery)).toList();
                      
                      if (provider.lists.isEmpty) {
                        return SliverFillRemaining(
                          hasScrollBody: false,
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.list_alt,
                                  size: 64,
                                  color: Colors.grey[400],
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'You have no lists yet.',
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: 24),
                                // Show create button even when empty
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16),
                                  child: SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton(
                                      onPressed: () {
                                        Navigator.pushNamed(context, '/create_list');
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppColors.primaryColor,
                                        foregroundColor: AppColors.textLight,
                                        padding: const EdgeInsets.symmetric(vertical: 16),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        elevation: 2,
                                      ),
                                      child: const Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.add, size: 20),
                                          SizedBox(width: 8),
                                          Text(
                                            'Create a new list',
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }
                      
                      if (filteredLists.isEmpty && _searchQuery.isNotEmpty) {
                        return SliverFillRemaining(
                          hasScrollBody: false,
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.search_off,
                                  size: 64,
                                  color: Colors.grey[400],
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'No lists found matching "$_searchQuery"',
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 16,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        );
                      }
                      
                      // If we have lists, show the grid
                      return SliverPadding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        sliver: SliverGrid(
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                            childAspectRatio: 0.85,
                          ),
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              final Watchlist list = filteredLists[index];
                              final isFavorites = list.name.toLowerCase() == 'favorites' || list.name.toLowerCase() == 'favourite';
                            
                            return GestureDetector(
                              onTap: () {
                                Navigator.pushNamed(
                                  context,
                                  '/list_view',
                                  arguments: list.id,
                                );
                              },
                              onLongPress: isFavorites
                                  ? null
                                  : () => _showDeleteDialog(context, list, provider),
                              child: Card(
                                elevation: 2,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(16),
                                  child: Stack(
                                    fit: StackFit.expand,
                                    children: [
                                      // Cover image or placeholder
                                      if (list.coverUrl.isNotEmpty && !isFavorites)
                                        Image.network(
                                          list.coverUrl,
                                          fit: BoxFit.cover,
                                          errorBuilder: (context, error, stackTrace) {
                                            return _buildPlaceholderCover(list.name);
                                          },
                                        )
                                      else
                                        _buildPlaceholderCover(list.name),
                                      // Gradient overlay for text readability
                                      Container(
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            begin: Alignment.topCenter,
                                            end: Alignment.bottomCenter,
                                            colors: [
                                              Colors.transparent,
                                              Colors.black.withOpacity(0.7),
                                            ],
                                          ),
                                        ),
                                      ),
                                      // Heart icon for Favorites (top-right) or Delete button for other lists
                                      Positioned(
                                        top: 8,
                                        right: 8,
                                        child: isFavorites
                                            ? Container(
                                                padding: const EdgeInsets.all(6),
                                                decoration: BoxDecoration(
                                                  color: Colors.white.withOpacity(0.9),
                                                  shape: BoxShape.circle,
                                                ),
                                                child: const Icon(
                                                  Icons.favorite,
                                                  color: Colors.red,
                                                  size: 24,
                                                ),
                                              )
                                            : IconButton(
                                                icon: const Icon(
                                                  Icons.delete_outline,
                                                  color: Colors.white,
                                                  size: 24,
                                                ),
                                                onPressed: () => _showDeleteDialog(context, list, provider),
                                                style: IconButton.styleFrom(
                                                  backgroundColor: Colors.black.withOpacity(0.5),
                                                  padding: const EdgeInsets.all(6),
                                                ),
                                                tooltip: 'Delete list',
                                              ),
                                      ),
                                      // Content
                                      Padding(
                                        padding: const EdgeInsets.all(12),
                                        child: Column(
                                          mainAxisAlignment: MainAxisAlignment.end,
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                if (isFavorites) ...[
                                                  const Icon(
                                                    Icons.favorite,
                                                    color: Colors.white,
                                                    size: 18,
                                                  ),
                                                  const SizedBox(width: 4),
                                                ],
                                                Expanded(
                                                  child: Text(
                                                    list.name,
                                                    style: const TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 16,
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                    maxLines: 2,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              '${list.totalSeries} series',
                                              style: TextStyle(
                                                color: Colors.white.withOpacity(0.9),
                                                fontSize: 12,
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
                              },
                              childCount: filteredLists.length,
                            ),
                          ),
                        );
                      },
                    ),
                  // Create button
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                      child: SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.pushNamed(context, '/create_list');
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryColor,
                            foregroundColor: AppColors.textLight,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 2,
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.add, size: 20),
                              SizedBox(width: 8),
                              Text(
                                'Create a new list',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _showDeleteDialog(BuildContext context, Watchlist list, WatchlistProvider provider) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete List'),
        content: Text('Are you sure you want to delete "${list.name}"? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        await provider.deleteList(list.id);
        
        // Reload watchlists to refresh the UI
        if (_currentUserId != null) {
          await provider.loadUserWatchlists(_currentUserId!);
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('List deleted successfully'),
              backgroundColor: AppColors.successColor,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error deleting list: $e'),
              backgroundColor: AppColors.dangerColor,
            ),
          );
        }
      }
    }
  }

  Widget _buildPlaceholderCover(String listName) {
    final isFavorites = listName.toLowerCase() == 'favorites';
    
    if (isFavorites) {
      return Container(
        color: Colors.red[400],
        child: const Center(
          child: Icon(
            Icons.favorite,
            color: Colors.white,
            size: 48,
          ),
        ),
      );
    }
    
    // Generate a color based on list name
    final colors = [
      Colors.blue[300],
      Colors.green[300],
      Colors.orange[300],
      Colors.purple[300],
      Colors.pink[300],
      Colors.teal[300],
    ];
    final colorIndex = listName.hashCode.abs() % colors.length;
    
    return Container(
      color: colors[colorIndex],
      child: Center(
        child: Icon(
          Icons.movie,
          color: Colors.white.withOpacity(0.8),
          size: 48,
        ),
      ),
    );
  }
}


