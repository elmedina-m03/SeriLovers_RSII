import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dim.dart';
import '../../models/series.dart';
import '../../providers/series_provider.dart';
import '../../providers/watchlist_provider.dart';
import '../../providers/auth_provider.dart';
import '../providers/mobile_navigation_provider.dart';
import '../widgets/mobile_page_route.dart';
import 'mobile_series_detail_screen.dart';
import 'mobile_search_screen.dart';
import '../../core/widgets/image_with_placeholder.dart';

/// Mobile categories screen with horizontal filter tags and series display
class MobileCategoriesScreen extends StatefulWidget {
  const MobileCategoriesScreen({super.key});

  @override
  State<MobileCategoriesScreen> createState() => _MobileCategoriesScreenState();
}

class _MobileCategoriesScreenState extends State<MobileCategoriesScreen> {
  bool _initialized = false;
  int? _selectedGenreId; // null means "ALL"
  List<Series> _displayedSeries = [];
  bool _isLoadingSeries = false;
  int _currentPage = 1;
  final int _pageSize = 20;
  bool _hasMore = true;
  bool _isLoadingMore = false;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  Timer? _debounceTimer;

  DateTime? _lastLoadTime;
  static const _cacheTimeout = Duration(seconds: 10); // Cache for 10 seconds

  @override
  void initState() {
    super.initState();
    // Search only triggers on button click or Enter key, not on input changes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadGenres();
      _loadAllSeries();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Refresh when returning to this screen
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _initialized) {
        final now = DateTime.now();
        if (_lastLoadTime == null || 
            now.difference(_lastLoadTime!) > _cacheTimeout) {
          _loadAllSeries(forceRefresh: true);
        }
      }
    });
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _performSearch(String query) async {
    if (query.isEmpty) {
      setState(() {
        _searchQuery = '';
      });
      _loadAllSeries();
      return;
    }

    setState(() {
      _isLoadingSeries = true;
      _searchQuery = query;
    });

    final seriesProvider = Provider.of<SeriesProvider>(context, listen: false);
    try {
      // Perform search with the query
      await seriesProvider.searchSeries(query);
      
      // Filter results - search results are already filtered by the provider
      setState(() {
        _displayedSeries = seriesProvider.items;
        _isLoadingSeries = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error searching series: $e'),
            backgroundColor: AppColors.dangerColor,
          ),
        );
        setState(() {
          _isLoadingSeries = false;
        });
      }
    }
  }


  Future<void> _loadGenres() async {
    if (_initialized) return;
    _initialized = true;
    final seriesProvider = Provider.of<SeriesProvider>(context, listen: false);
    try {
      await seriesProvider.fetchGenres();
      // Ensure genres are loaded before filtering
      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading genres: $e'),
            backgroundColor: AppColors.dangerColor,
          ),
        );
      }
    }
  }

  Future<void> _loadAllSeries({bool append = false, bool forceRefresh = false}) async {
    if (!forceRefresh && _initialized && !append) return;
    if (!_initialized && !append) {
      _initialized = true;
    }
    
    if (append) {
      _isLoadingMore = true;
    } else {
      setState(() {
        _isLoadingSeries = true;
        _currentPage = 1;
        _hasMore = true;
      });
    }
    
    final seriesProvider = Provider.of<SeriesProvider>(context, listen: false);
    try {
      await seriesProvider.fetchSeries(
        page: _currentPage,
        pageSize: _pageSize,
        append: append,
      );
      
      if (append) {
        _currentPage++;
        _hasMore = seriesProvider.hasMore;
      } else {
        _currentPage = 1;
        _hasMore = seriesProvider.hasMore;
      }
      
      _filterSeries();
      
      if (mounted && !append) {
        setState(() {
          _lastLoadTime = DateTime.now();
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading series: $e'),
            backgroundColor: AppColors.dangerColor,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingSeries = false;
          _isLoadingMore = false;
        });
      }
    }
  }

  Future<void> _loadMoreSeries() async {
    if (!_hasMore || _isLoadingMore) return;
    await _loadAllSeries(append: true);
  }

  Future<void> _loadSeriesByGenre(int genreId, {bool append = false}) async {
    if (append) {
      _isLoadingMore = true;
    } else {
      setState(() {
        _isLoadingSeries = true;
        _currentPage = 1;
        _hasMore = true;
      });
    }
    
    final seriesProvider = Provider.of<SeriesProvider>(context, listen: false);
    try {
      await seriesProvider.fetchSeries(
        page: _currentPage,
        pageSize: _pageSize,
        genreId: genreId,
        append: append,
      );
      
      if (append) {
        _currentPage++;
        _hasMore = seriesProvider.hasMore;
      } else {
        _currentPage = 1;
        _hasMore = seriesProvider.hasMore;
      }
      
      setState(() {
        _displayedSeries = seriesProvider.items;
        _isLoadingSeries = false;
        _isLoadingMore = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading series: $e'),
            backgroundColor: AppColors.dangerColor,
          ),
        );
        setState(() {
          _isLoadingSeries = false;
          _isLoadingMore = false;
        });
      }
    }
  }

  Future<void> _loadMoreSeriesByGenre(int genreId) async {
    if (!_hasMore || _isLoadingMore) return;
    await _loadSeriesByGenre(genreId, append: true);
  }

  void _filterSeries() {
    final seriesProvider = Provider.of<SeriesProvider>(context, listen: false);
    
    // If searching, use search results directly
    if (_searchQuery.isNotEmpty) {
      setState(() {
        _displayedSeries = seriesProvider.items;
      });
      return;
    }
    
    // Otherwise, filter by genre
    if (_selectedGenreId == null) {
      // Show all series
      setState(() {
        _displayedSeries = seriesProvider.items;
      });
    } else {
      // Filter by genre
      setState(() {
        _displayedSeries = seriesProvider.items.where((series) {
          return series.genres.any((genreName) {
            // Find genre by ID
            final genre = seriesProvider.genres.firstWhere(
              (g) => g.id == _selectedGenreId,
              orElse: () => Genre(id: -1, name: ''),
            );
            return genre.id != -1 && genreName.toLowerCase() == genre.name.toLowerCase();
          });
        }).toList();
      });
    }
  }

  void _onGenreSelected(int? genreId) async {
    setState(() {
      _selectedGenreId = genreId;
      _isLoadingSeries = true;
      _currentPage = 1;
      _hasMore = true;
    });
    
    if (genreId == null) {
      // Show all series
      await _loadAllSeries();
    } else {
      // Load and show only series from selected genre
      await _loadSeriesByGenre(genreId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      appBar: AppBar(
        title: const Text('Categories'),
        backgroundColor: AppColors.primaryColor,
        foregroundColor: AppColors.textLight,
        elevation: 0,
        automaticallyImplyLeading: false, // No back button on categories screen
        // User icon removed - not needed on Categories page
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(AppDim.paddingMedium, 0, AppDim.paddingMedium, AppDim.paddingSmall),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search series by name...',
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
                    ? Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: Icon(Icons.search, color: AppColors.primaryColor),
                            onPressed: () {
                              _performSearch(_searchController.text.trim());
                            },
                            tooltip: 'Search',
                          ),
                          IconButton(
                            icon: Icon(Icons.clear, color: AppColors.textSecondary),
                            tooltip: 'Reset search and filters',
                            onPressed: () {
                              _searchController.clear();
                              _debounceTimer?.cancel();
                              final seriesProvider = Provider.of<SeriesProvider>(context, listen: false);
                              // Reset search query and genre filter to show ALL series
                              seriesProvider.clearSearch().then((_) {
                                if (mounted) {
                                  setState(() {
                                    _searchQuery = '';
                                    _selectedGenreId = null; // Reset genre filter
                                  });
                                  // Force refresh to show all series
                                  _loadAllSeries(forceRefresh: true);
                                }
                              });
                            },
                          ),
                        ],
                      )
                    : IconButton(
                        icon: Icon(Icons.search, color: AppColors.primaryColor),
                        onPressed: () {
                          if (_searchController.text.trim().isNotEmpty) {
                            _performSearch(_searchController.text.trim());
                          }
                        },
                        tooltip: 'Search',
                      ),
              ),
              style: TextStyle(color: AppColors.textPrimary),
              textInputAction: TextInputAction.search,
              onSubmitted: (value) {
                if (value.trim().isNotEmpty) {
                  _performSearch(value.trim());
                } else {
                  _loadAllSeries();
                }
              },
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Consumer<SeriesProvider>(
            builder: (context, seriesProvider, child) {
              final genres = seriesProvider.genres;
              
              return Column(
                children: [
                // Horizontal scrollable filter tags - Show ALL genres (hide when searching)
                if (_searchQuery.isEmpty)
                  SizedBox(
                    height: 50,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                      padding: const EdgeInsets.symmetric(horizontal: AppDim.paddingMedium, vertical: 8),
                      child: Row(
                        children: [
                          // "ALL" option
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: FilterChip(
                              label: const Text('ALL'),
                              selected: _selectedGenreId == null,
                              onSelected: (selected) {
                                _onGenreSelected(null);
                              },
                              selectedColor: AppColors.primaryColor,
                              checkmarkColor: AppColors.textLight,
                              labelStyle: TextStyle(
                                color: _selectedGenreId == null ? AppColors.textLight : AppColors.textPrimary,
                                fontWeight: _selectedGenreId == null ? FontWeight.bold : FontWeight.normal,
                                fontSize: 12,
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            ),
                          ),
                          // Genre chips
                          ...genres.map((genre) {
                            final isSelected = _selectedGenreId == genre.id;
                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: FilterChip(
                                label: Text(genre.name.toUpperCase()),
                                selected: isSelected,
                                onSelected: (selected) {
                                  _onGenreSelected(selected ? genre.id : null);
                                },
                                selectedColor: AppColors.primaryColor,
                                checkmarkColor: AppColors.textLight,
                                labelStyle: TextStyle(
                                  color: isSelected ? AppColors.textLight : AppColors.textPrimary,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                  fontSize: 12,
                                ),
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              ),
                            );
                          }).toList(),
                        ],
                      ),
                    ),
                  ),
                
                // Series list
                _isLoadingSeries
                    ? const SizedBox(
                        height: 400,
                        child: Center(child: CircularProgressIndicator()),
                      )
                    : _displayedSeries.isEmpty
                        ? SizedBox(
                            height: 400,
                            child: Center(
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
                                    'No series found',
                                    style: theme.textTheme.titleMedium?.copyWith(
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : NotificationListener<ScrollNotification>(
                            onNotification: (ScrollNotification scrollInfo) {
                              // Load more when scrolled to bottom
                              if (scrollInfo.metrics.pixels >= 
                                  scrollInfo.metrics.maxScrollExtent - 200) {
                                if (_hasMore && !_isLoadingMore) {
                                  if (_selectedGenreId == null) {
                                    _loadMoreSeries();
                                  } else {
                                    _loadMoreSeriesByGenre(_selectedGenreId!);
                                  }
                                }
                              }
                              return false;
                            },
                            child: ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              padding: const EdgeInsets.symmetric(
                                vertical: AppDim.paddingMedium,
                                horizontal: AppDim.paddingMedium,
                              ),
                              itemCount: _displayedSeries.length + (_hasMore && _isLoadingMore ? 1 : 0),
                              itemBuilder: (context, index) {
                                if (index == _displayedSeries.length) {
                                  return const Center(
                                    child: Padding(
                                      padding: EdgeInsets.all(16.0),
                                      child: CircularProgressIndicator(),
                                    ),
                                  );
                                }
                                final series = _displayedSeries[index];
                                return _buildSeriesCard(series, context, theme);
                              },
                            ),
                          ),
                const SizedBox(height: AppDim.paddingLarge),
              ],
            );
          },
        ),
        ),
      ),
    );
  }

  Widget _buildSeriesCard(Series series, BuildContext context, ThemeData theme) {
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
              // Series Image - Use ImageWithPlaceholder for better handling
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: ImageWithPlaceholder(
                  imageUrl: series.imageUrl,
                  width: 80,
                  height: 120,
                  fit: BoxFit.cover,
                  borderRadius: 8,
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
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.star,
                          size: 14,
                          color: AppColors.primaryColor,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          series.rating.toStringAsFixed(1),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Add to list button
                    Consumer<WatchlistProvider>(
                      builder: (context, watchlistProvider, child) {
                        return SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () => _showAddToListDialog(context, series),
                            icon: const Icon(Icons.add, size: 18),
                            label: const Text('Add to list'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primaryColor,
                              foregroundColor: AppColors.textLight,
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        );
                      },
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

    if (!context.mounted) return;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _WatchlistSelector(seriesId: series.id),
    );
  }

}

class _WatchlistSelector extends StatefulWidget {
  final int seriesId;

  const _WatchlistSelector({required this.seriesId});

  @override
  State<_WatchlistSelector> createState() => _WatchlistSelectorState();
}

class _WatchlistSelectorState extends State<_WatchlistSelector> {
  int? _processingListId;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: Consumer<WatchlistProvider>(
          builder: (context, provider, child) {
            final lists = provider.lists;

            if (provider.loading && lists.isEmpty) {
              return const Center(
                child: CircularProgressIndicator(),
              );
            }

            if (lists.isEmpty) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'You have no lists yet.',
                    style: TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      Navigator.pushNamed(context, '/create_list');
                    },
                    child: const Text('Create a new list'),
                  ),
                ],
              );
            }

            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey[400],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const Text(
                  'Add to list',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: lists.length,
                    itemBuilder: (context, index) {
                      final list = lists[index];
                      final isProcessing = _processingListId == list.id;

                      return ListTile(
                        title: Text(list.name),
                        subtitle: Text('${list.totalSeries} series'),
                        trailing: isProcessing
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : IconButton(
                                icon: const Icon(Icons.add),
                                onPressed: () async {
                                  setState(() {
                                    _processingListId = list.id;
                                  });
                                  try {
                                    await Provider.of<WatchlistProvider>(
                                      context,
                                      listen: false,
                                    ).addSeries(list.id, widget.seriesId);

                                    if (mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('Added to ${list.name}'),
                                          backgroundColor: Colors.green,
                                        ),
                                      );
                                      Navigator.pop(context);
                                    }
                                  } catch (e) {
                                    if (mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('Failed to add: $e'),
                                          backgroundColor: Colors.red,
                                        ),
                                      );
                                    }
                                  } finally {
                                    if (mounted) {
                                      setState(() {
                                        _processingListId = null;
                                      });
                                    }
                                  }
                                },
                              ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                      Navigator.pushNamed(context, '/create_list');
                    },
                    child: const Text('Create a new list'),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
