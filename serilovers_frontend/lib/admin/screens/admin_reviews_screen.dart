import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dim.dart';
import '../../core/widgets/image_with_placeholder.dart';
import '../../core/widgets/admin_data_table_config.dart';
import '../../models/rating.dart';
import '../../services/rating_service.dart';
import '../../providers/auth_provider.dart';

/// Unified review item for display (series reviews only)
class UnifiedReview {
  final int id;
  final String? userName;
  final String? userEmail;
  final String? userAvatarUrl;
  final String? seriesTitle;
  final String? seriesImageUrl;
  final int rating;
  final String? reviewText;
  final DateTime createdAt;
  
  UnifiedReview({
    required this.id,
    this.userName,
    this.userEmail,
    this.userAvatarUrl,
    this.seriesTitle,
    this.seriesImageUrl,
    required this.rating,
    this.reviewText,
    required this.createdAt,
  });
}

/// Admin reviews management screen with DataTable
/// Shows series-level reviews (Ratings) only
class AdminReviewsScreen extends StatefulWidget {
  const AdminReviewsScreen({super.key});

  @override
  State<AdminReviewsScreen> createState() => _AdminReviewsScreenState();
}

class _AdminReviewsScreenState extends State<AdminReviewsScreen> {
  final _searchController = TextEditingController();
  final _horizontalScrollController = ScrollController();
  final _verticalScrollController = ScrollController();
  String _searchQuery = '';
  List<UnifiedReview> _allReviews = []; // Cache all series reviews
  List<UnifiedReview> _filteredReviews = []; // Filtered reviews after search/sort
  List<UnifiedReview> _displayedReviews = []; // Paginated reviews to display
  bool _isLoading = false;
  String? _sortColumn;
  bool _sortAscending = true;
  int _currentPage = 1;
  int _pageSize = 10;
  int get _totalPages => (_filteredReviews.length / _pageSize).ceil();
  int get _totalItems => _filteredReviews.length;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadReviews();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _horizontalScrollController.dispose();
    _verticalScrollController.dispose();
    super.dispose();
  }

  /// Load all series reviews from API (admin only)
  Future<void> _loadReviews() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final token = authProvider.token;
      
      if (token == null || token.isEmpty) {
        throw Exception('Authentication required');
      }

      // Load all ratings (including those with and without comments)
      final ratingService = RatingService();
      final ratings = await ratingService.getAllRatings(token: token);
      
      // Convert all ratings to UnifiedReview (show all ratings, not just those with comments)
      final seriesReviews = ratings
          .map((r) => UnifiedReview(
                id: r.id,
                userName: r.userName,
                userEmail: r.userEmail,
                userAvatarUrl: r.userAvatarUrl,
                seriesTitle: r.seriesTitle,
                seriesImageUrl: r.seriesImageUrl,
                rating: r.score,
                reviewText: r.comment, // Can be null or empty for ratings without comments
                createdAt: r.createdAt,
              ))
          .toList();
      
      // Sort by creation date (newest first)
      seriesReviews.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      
      setState(() {
        _allReviews = seriesReviews;
        _isLoading = false;
      });
      
      // Apply filters and sorting after loading
      _applyFilters();
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading reviews: $e'),
            backgroundColor: AppColors.dangerColor,
          ),
        );
      }
    }
  }

  /// Apply search filter and sorting to cached reviews
  void _applyFilters() {
    var reviews = List<UnifiedReview>.from(_allReviews);
    
    // Apply search filter
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase().trim();
      reviews = reviews.where((review) {
        return (review.userName?.toLowerCase().contains(query) ?? false) ||
               (review.userEmail?.toLowerCase().contains(query) ?? false) ||
               (review.reviewText?.toLowerCase().contains(query) ?? false) ||
               (review.seriesTitle?.toLowerCase().contains(query) ?? false);
      }).toList();
    }

    // Apply sorting
    if (_sortColumn != null) {
      reviews.sort((a, b) {
        int comparison = 0;
        switch (_sortColumn) {
          case 'userName':
            comparison = (a.userName ?? '').compareTo(b.userName ?? '');
            break;
          case 'seriesTitle':
            comparison = (a.seriesTitle ?? '').compareTo(b.seriesTitle ?? '');
            break;
          case 'rating':
            comparison = a.rating.compareTo(b.rating);
            break;
          case 'createdAt':
            comparison = a.createdAt.compareTo(b.createdAt);
            break;
          default:
            comparison = 0;
        }
        return _sortAscending ? comparison : -comparison;
      });
    }
    
    setState(() {
      _filteredReviews = reviews;
      _currentPage = 1; // Reset to first page when filters change
      _updateDisplayedRatings();
    });
  }

  /// Update displayed reviews based on current page
  void _updateDisplayedRatings() {
    if (_filteredReviews.isEmpty) {
      setState(() {
        _displayedReviews = [];
      });
      return;
    }
    
    final startIndex = (_currentPage - 1) * _pageSize;
    final endIndex = startIndex + _pageSize;
    setState(() {
      _displayedReviews = _filteredReviews.sublist(
        startIndex.clamp(0, _filteredReviews.length),
        endIndex.clamp(0, _filteredReviews.length),
      );
    });
  }

  /// Go to previous page
  void _goToPreviousPage() {
    if (_currentPage > 1) {
      setState(() {
        _currentPage--;
      });
      _updateDisplayedRatings();
    }
  }

  /// Go to next page
  void _goToNextPage() {
    if (_currentPage < _totalPages) {
      setState(() {
        _currentPage++;
      });
      _updateDisplayedRatings();
    }
  }

  /// Handle deleting a review
  Future<void> _handleDeleteReview(UnifiedReview review) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.cardBackground,
        title: Text(
          'Delete Review',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: Text(
          'Are you sure you want to delete this review?\n\nThis action cannot be undone.',
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
        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        final token = authProvider.token;
        
        if (token == null || token.isEmpty) {
          throw Exception('Authentication required');
        }

        final ratingService = RatingService();
        await ratingService.deleteRating(review.id, token: token);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Review deleted successfully'),
              backgroundColor: AppColors.successColor,
            ),
          );
        }
        
        await _loadReviews();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error deleting review: $e'),
              backgroundColor: AppColors.dangerColor,
            ),
          );
        }
      }
    }
  }

  void _onSort(String column) {
    setState(() {
      if (_sortColumn == column) {
        _sortAscending = !_sortAscending;
      } else {
        _sortColumn = column;
        _sortAscending = true;
      }
    });
    _applyFilters(); // Apply sorting to cached reviews, no need to reload from API
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Container(
      color: AppColors.backgroundColor,
      child: Padding(
        padding: const EdgeInsets.all(AppDim.paddingMedium),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Search bar
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search by user, series, or review text...',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppDim.borderRadius),
                      ),
                      filled: true,
                      fillColor: AppColors.cardBackground,
                    ),
                    onChanged: (value) {
                      setState(() {
                        _searchQuery = value;
                      });
                    },
                    onSubmitted: (value) {
                      setState(() {
                        _searchQuery = value;
                      });
                      _applyFilters();
                    },
                  ),
                ),
                const SizedBox(width: AppDim.paddingMedium),
                ElevatedButton.icon(
                  onPressed: () {
                    setState(() {
                      _searchQuery = _searchController.text;
                    });
                    _applyFilters();
                  },
                  icon: const Icon(Icons.search),
                  label: const Text('Search'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryColor,
                    foregroundColor: AppColors.textLight,
                  ),
                ),
                const SizedBox(width: AppDim.paddingSmall),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: _loadReviews,
                  tooltip: 'Refresh',
                ),
              ],
            ),
            const SizedBox(height: AppDim.paddingSmall),
            
            // DataTable with proper scrolling
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _displayedReviews.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.search_off,
                                size: 64,
                                color: AppColors.textSecondary.withOpacity(0.5),
                              ),
                              const SizedBox(height: AppDim.paddingMedium),
                              Text(
                                _searchQuery.isNotEmpty
                                    ? 'No reviews match your search'
                                    : 'No reviews found',
                                style: theme.textTheme.bodyLarge?.copyWith(
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              if (_searchQuery.isNotEmpty) ...[
                                const SizedBox(height: AppDim.paddingSmall),
                                Text(
                                  'Try clearing your search to see all reviews',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: AppColors.textSecondary,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: AppDim.paddingLarge),
                                ElevatedButton.icon(
                                  onPressed: () {
                                    setState(() {
                                      _searchQuery = '';
                                      _searchController.clear();
                                    });
                                    _applyFilters();
                                  },
                                  icon: const Icon(Icons.clear),
                                  label: const Text('Clear Search'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.primaryColor,
                                    foregroundColor: AppColors.textLight,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        )
                      : LayoutBuilder(
                          builder: (context, constraints) {
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
                                        minWidth: constraints.maxWidth,
                                      ),
                                      child: DataTable(
                              headingRowColor: AdminDataTableConfig.getTableProperties()['headingRowColor'] as MaterialStateProperty<Color>,
                              dataRowColor: AdminDataTableConfig.getTableProperties()['dataRowColor'] as MaterialStateProperty<Color>,
                              headingRowHeight: AdminDataTableConfig.headingRowHeight,
                              dataRowMinHeight: AdminDataTableConfig.dataRowMinHeight,
                              dataRowMaxHeight: AdminDataTableConfig.dataRowMaxHeight,
                              sortColumnIndex: _sortColumn == 'userName'
                                  ? 0
                                  : _sortColumn == 'seriesTitle'
                                      ? 1
                                      : _sortColumn == 'rating'
                                          ? 2
                                          : _sortColumn == 'createdAt'
                                              ? 3
                                              : null,
                              sortAscending: _sortAscending,
                              columns: [
                                DataColumn(
                                  label: AdminDataTableConfig.getColumnLabel('User'),
                                  onSort: (columnIndex, ascending) =>
                                      _onSort('userName'),
                                ),
                                DataColumn(
                                  label: AdminDataTableConfig.getColumnLabel('Series'),
                                  onSort: (columnIndex, ascending) =>
                                      _onSort('seriesTitle'),
                                ),
                                DataColumn(
                                  label: AdminDataTableConfig.getColumnLabel('Rating'),
                                  numeric: true,
                                  onSort: (columnIndex, ascending) =>
                                      _onSort('rating'),
                                ),
                                DataColumn(
                                  label: AdminDataTableConfig.getColumnLabel('Review'),
                                ),
                                DataColumn(
                                  label: AdminDataTableConfig.getColumnLabel('Created At'),
                                  onSort: (columnIndex, ascending) =>
                                      _onSort('createdAt'),
                                ),
                                DataColumn(
                                  label: AdminDataTableConfig.getColumnLabel('Actions'),
                                ),
                              ],
                              rows: _displayedReviews.map((review) {
                                return DataRow(
                                  cells: [
                                    DataCell(
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          // Use ImageWithPlaceholder for consistent avatar display
                                          ImageWithPlaceholder(
                                            imageUrl: (review.userAvatarUrl != null && review.userAvatarUrl!.isNotEmpty)
                                                ? review.userAvatarUrl
                                                : null,
                                            width: 20,
                                            height: 20,
                                            fit: BoxFit.cover,
                                            borderRadius: 10, // Makes it circular
                                            placeholderIcon: Icons.person,
                                            placeholderIconSize: 12,
                                            isCircular: true,
                                          ),
                                          const SizedBox(width: 6),
                                          Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(
                                                review.userName ?? 'Unknown',
                                                style: AdminDataTableConfig.getCellTextStyle(theme.textTheme),
                                              ),
                                              if (review.userEmail != null)
                                                Text(
                                                  review.userEmail!,
                                                  style: AdminDataTableConfig.getCellSmallTextStyle(theme.textTheme).copyWith(
                                                    color: AppColors.textSecondary,
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    DataCell(
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          if (review.seriesImageUrl != null)
                                            ImageWithPlaceholder(
                                              imageUrl: review.seriesImageUrl!,
                                              width: 32,
                                              height: 32,
                                              fit: BoxFit.cover,
                                              borderRadius: 4,
                                            )
                                          else
                                            const SizedBox(width: 32, height: 32),
                                          const SizedBox(width: 6),
                                          Flexible(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Text(
                                                  review.seriesTitle ?? 'N/A',
                                                  style: AdminDataTableConfig.getCellTextStyle(theme.textTheme),
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    DataCell(
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.star,
                                            size: AdminDataTableConfig.actionIconSize,
                                            color: AppColors.primaryColor,
                                          ),
                                          const SizedBox(width: 3),
                                          Text(
                                            '${review.rating}/10',
                                            style: AdminDataTableConfig.getCellTextStyle(theme.textTheme),
                                          ),
                                        ],
                                      ),
                                    ),
                                    DataCell(
                                      ConstrainedBox(
                                        constraints: const BoxConstraints(
                                          minWidth: 200,
                                          maxWidth: 400,
                                        ),
                                        child: Text(
                                          review.reviewText ?? 'No review text',
                                          style: AdminDataTableConfig.getCellSmallTextStyle(theme.textTheme),
                                          softWrap: true,
                                          overflow: TextOverflow.visible,
                                          maxLines: null,
                                        ),
                                      ),
                                    ),
                                    DataCell(
                                      Text(
                                        '${review.createdAt.day}/${review.createdAt.month}/${review.createdAt.year}',
                                        style: AdminDataTableConfig.getCellSmallTextStyle(theme.textTheme),
                                      ),
                                    ),
                                    DataCell(
                                      SizedBox(
                                        width: AdminDataTableConfig.actionButtonSize,
                                        child: IconButton(
                                          icon: const Icon(Icons.delete, size: AdminDataTableConfig.actionIconSize),
                                          color: AppColors.dangerColor,
                                          onPressed: () => _handleDeleteReview(review),
                                          tooltip: 'Delete',
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(
                                            minWidth: AdminDataTableConfig.actionButtonSize,
                                            minHeight: AdminDataTableConfig.actionButtonSize,
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
                        ),
            ),
            
            // Pagination Controls
            if (!_isLoading && _filteredReviews.isNotEmpty)
              Card(
                color: AppColors.cardBackground,
                child: Padding(
                  padding: const EdgeInsets.all(AppDim.paddingSmall),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Page $_currentPage of $_totalPages ($_totalItems total)',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 14,
                        ),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.chevron_left),
                            onPressed: _currentPage > 1
                                ? _goToPreviousPage
                                : null,
                            color: AppColors.primaryColor,
                            tooltip: 'Previous page',
                          ),
                          IconButton(
                            icon: const Icon(Icons.chevron_right),
                            onPressed: _currentPage < _totalPages
                                ? _goToNextPage
                                : null,
                            color: AppColors.primaryColor,
                            tooltip: 'Next page',
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
