import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dim.dart';
import '../../core/widgets/image_with_placeholder.dart';
import '../../core/widgets/admin_data_table_config.dart';
import '../../models/series.dart';
import '../providers/admin_series_provider.dart';
import 'series/series_form_dialog.dart';

/// Admin series management screen with DataTable
class AdminSeriesScreen extends StatefulWidget {
  const AdminSeriesScreen({super.key});

  @override
  State<AdminSeriesScreen> createState() => _AdminSeriesScreenState();
}

class _AdminSeriesScreenState extends State<AdminSeriesScreen> {
  final _searchController = TextEditingController();
  final _horizontalScrollController = ScrollController();
  final _verticalScrollController = ScrollController();
  String _searchQuery = '';
  String? _selectedGenre;
  int? _selectedYear;
  String _sortBy = 'title';
  bool _sortAscending = true;
  int _pageSize = 10;

  // Get unique genres from series data
  List<String> get _availableGenres {
    final adminSeriesProvider = Provider.of<AdminSeriesProvider>(context, listen: false);
    final allGenres = <String>{};
    
    // Collect all genres from all series
    for (var series in adminSeriesProvider.items) {
      if (series.genres != null) {
        for (var genre in series.genres) {
          if (genre != null && genre.isNotEmpty) {
            allGenres.add(genre);
          }
        }
      }
    }
    
    // Convert to sorted list (ensures uniqueness via Set)
    final uniqueGenres = allGenres.toList()..sort();
    
    // If selected genre is not in the list, add it (for edit mode)
    if (_selectedGenre != null && !uniqueGenres.contains(_selectedGenre)) {
      uniqueGenres.add(_selectedGenre!);
    }
    
    return uniqueGenres;
  }
  
  // Get validated selected genre (null if not in available genres)
  String? get _validatedSelectedGenre {
    final availableGenres = _availableGenres;
    return _selectedGenre != null && availableGenres.contains(_selectedGenre) 
        ? _selectedGenre 
        : null;
  }

  // Generate years list (1990 to current year + 1)
  List<int?> get _availableYears {
    final currentYear = DateTime.now().year;
    final years = <int?>[null]; // null for "All Years"
    for (int year = currentYear + 1; year >= 1990; year--) {
      years.add(year);
    }
    return years;
  }

  @override
  void initState() {
    super.initState();
    // Fetch series when screen loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadSeries();
    });
  }

  @override
  @override
  void dispose() {
    _searchController.dispose();
    _horizontalScrollController.dispose();
    _verticalScrollController.dispose();
    super.dispose();
  }

  /// Load series data with current filters
  Future<void> _loadSeries({int? page}) async {
    try {
      final adminSeriesProvider = Provider.of<AdminSeriesProvider>(context, listen: false);
      await adminSeriesProvider.fetchFiltered(
        search: _searchQuery.isEmpty ? null : _searchQuery,
        genre: _selectedGenre,
        year: _selectedYear,
        sortBy: _sortBy,
        sortOrder: _sortAscending ? 'asc' : 'desc',
        page: page,
        pageSize: _pageSize,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading series: $e'),
            backgroundColor: AppColors.dangerColor,
          ),
        );
      }
    }
  }

  /// Go to previous page
  void _goToPreviousPage() {
    final adminSeriesProvider = Provider.of<AdminSeriesProvider>(context, listen: false);
    if (adminSeriesProvider.currentPage > 1) {
      _loadSeries(page: adminSeriesProvider.currentPage - 1);
    }
  }

  /// Go to next page
  void _goToNextPage() {
    final adminSeriesProvider = Provider.of<AdminSeriesProvider>(context, listen: false);
    if (adminSeriesProvider.currentPage < adminSeriesProvider.totalPages) {
      _loadSeries(page: adminSeriesProvider.currentPage + 1);
    }
  }

  /// Handle adding a new series
  Future<void> _handleAddSeries() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => const SeriesFormDialog(),
    );

    // Reload data if series was created successfully
    if (result == true) {
      await _loadSeries();
    }
  }

  /// Handle editing an existing series
  Future<void> _handleEditSeries(Series series) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => SeriesFormDialog(series: series),
    );

    // Reload data if series was updated successfully
    if (result == true) {
      await _loadSeries();
    }
  }

  /// Handle deleting a series with confirmation
  Future<void> _handleDeleteSeries(Series series) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.cardBackground,
        title: Text(
          'Delete Series',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: Text(
          'Are you sure you want to delete "${series.title}"?\n\nThis action cannot be undone.',
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
        final adminSeriesProvider = Provider.of<AdminSeriesProvider>(context, listen: false);
        await adminSeriesProvider.deleteSeries(series.id);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('"${series.title}" deleted successfully'),
              backgroundColor: AppColors.successColor,
            ),
          );
        }
        
        // Reload the series list
        await _loadSeries();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error deleting series: $e'),
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
    
    return Container(
      color: AppColors.backgroundColor,
      child: Padding(
        padding: const EdgeInsets.all(AppDim.paddingLarge),
        child: Consumer<AdminSeriesProvider>(
          builder: (context, adminSeriesProvider, child) {
            if (adminSeriesProvider.isLoading) {
              return const Center(
                child: CircularProgressIndicator(),
              );
            }

            if (adminSeriesProvider.items.isEmpty) {
              final hasActiveFilters = _searchQuery.isNotEmpty || _selectedGenre != null || _selectedYear != null;
              
              return Center(
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
                      hasActiveFilters
                          ? 'No series match your search or filters'
                          : 'No series found',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: AppColors.textPrimary,
                      ),
                    ),
                    if (hasActiveFilters) ...[
                      const SizedBox(height: AppDim.paddingSmall),
                      Text(
                        'Try clearing your search or filters to see all series',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: AppDim.paddingLarge),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          ElevatedButton.icon(
                            onPressed: () {
                              setState(() {
                                _searchQuery = '';
                                _selectedGenre = null;
                                _selectedYear = null;
                                _searchController.clear();
                              });
                              _loadSeries(page: 1);
                            },
                            icon: const Icon(Icons.clear_all),
                            label: const Text('Clear All Filters'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primaryColor,
                              foregroundColor: AppColors.textLight,
                            ),
                          ),
                          const SizedBox(width: AppDim.paddingMedium),
                          OutlinedButton.icon(
                            onPressed: _loadSeries,
                            icon: const Icon(Icons.refresh),
                            label: const Text('Refresh'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.primaryColor,
                              side: BorderSide(color: AppColors.primaryColor),
                            ),
                          ),
                        ],
                      ),
                    ] else ...[
                      const SizedBox(height: AppDim.paddingLarge),
                      ElevatedButton.icon(
                        onPressed: _loadSeries,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Refresh'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryColor,
                          foregroundColor: AppColors.textLight,
                        ),
                      ),
                    ],
                  ],
                ),
              );
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Add button at top-right
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    ElevatedButton.icon(
                      onPressed: _handleAddSeries,
                      icon: const Icon(Icons.add, size: 20),
                      label: const Text('Add new series'),
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
                // Search and Filter Controls
                Card(
                  color: AppColors.cardBackground,
                  child: Padding(
                    padding: const EdgeInsets.all(AppDim.paddingSmall),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            // Search TextField
                            Expanded(
                              flex: 2,
                              child: TextField(
                                controller: _searchController,
                                decoration: InputDecoration(
                                  labelText: 'Search by name or actor...',
                                  labelStyle: TextStyle(color: AppColors.textSecondary),
                                  prefixIcon: Icon(Icons.search, color: AppColors.textSecondary),
                                  suffixIcon: _searchQuery.isNotEmpty
                                      ? IconButton(
                                          icon: Icon(Icons.clear, color: AppColors.textSecondary),
                                          onPressed: () {
                                            _searchController.clear();
                                            setState(() {
                                              _searchQuery = '';
                                            });
                                          },
                                        )
                                      : null,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(AppDim.radiusSmall),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(AppDim.radiusSmall),
                                    borderSide: BorderSide(color: AppColors.primaryColor),
                                  ),
                                ),
                                style: TextStyle(color: AppColors.textPrimary),
                                onChanged: (value) {
                                  setState(() {
                                    _searchQuery = value;
                                  });
                                  // Don't trigger search automatically - wait for Search button
                                },
                                onSubmitted: (value) {
                                  // Don't trigger search on Enter - wait for Search button
                                },
                              ),
                            ),
                            const SizedBox(width: AppDim.paddingMedium),
                            
                            // Genre Filter Dropdown
                            Expanded(
                              flex: 1,
                              child: Builder(
                                builder: (context) {
                                  final availableGenres = _availableGenres;
                                  final validValue = _validatedSelectedGenre;
                                  return DropdownButtonFormField<String>(
                                    value: validValue,
                                decoration: InputDecoration(
                                  labelText: 'Filter by Genre',
                                  labelStyle: TextStyle(color: AppColors.textSecondary),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(AppDim.radiusSmall),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(AppDim.radiusSmall),
                                    borderSide: BorderSide(color: AppColors.primaryColor),
                                  ),
                                ),
                                style: TextStyle(color: AppColors.textPrimary),
                                dropdownColor: AppColors.cardBackground,
                                    items: [
                                      const DropdownMenuItem<String>(
                                        value: null,
                                        child: Text('All Genres'),
                                      ),
                                      ...availableGenres.map((genre) {
                                        return DropdownMenuItem<String>(
                                          value: genre,
                                          child: Text(genre),
                                        );
                                      }),
                                    ],
                                onChanged: (value) {
                                  setState(() {
                                    _selectedGenre = value;
                                  });
                                  // Don't trigger search automatically - wait for Search button
                                },
                                  );
                                },
                              ),
                            ),
                            const SizedBox(width: AppDim.paddingMedium),
                            
                            // Year Filter Dropdown
                            Expanded(
                              flex: 1,
                              child: DropdownButtonFormField<int?>(
                                value: _selectedYear,
                                decoration: InputDecoration(
                                  labelText: 'Filter by Year',
                                  labelStyle: TextStyle(color: AppColors.textSecondary),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(AppDim.radiusSmall),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(AppDim.radiusSmall),
                                    borderSide: BorderSide(color: AppColors.primaryColor),
                                  ),
                                ),
                                style: TextStyle(color: AppColors.textPrimary),
                                dropdownColor: AppColors.cardBackground,
                                items: _availableYears.map((year) {
                                  return DropdownMenuItem<int?>(
                                    value: year,
                                    child: Text(
                                      year == null ? 'All Years' : year.toString(),
                                      style: TextStyle(color: AppColors.textPrimary),
                                    ),
                                  );
                                }).toList(),
                                onChanged: (value) {
                                  setState(() {
                                    _selectedYear = value;
                                  });
                                  // Don't trigger search automatically - wait for Search button
                                },
                              ),
                            ),
                            const SizedBox(width: AppDim.paddingMedium),
                            
                            // Search Button
                            ElevatedButton.icon(
                              onPressed: () => _loadSeries(page: 1), // Reset to first page on search
                              icon: const Icon(Icons.search),
                              label: const Text('Search'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primaryColor,
                                foregroundColor: AppColors.textLight,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppDim.paddingSmall),
                
                // Data Table with proper height constraints and scrolling
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      return Scrollbar(
                        controller: _horizontalScrollController,
                        thumbVisibility: true,
                        child: SingleChildScrollView(
                          controller: _horizontalScrollController,
                          scrollDirection: Axis.horizontal,
                          child: Scrollbar(
                            controller: _verticalScrollController,
                            thumbVisibility: true,
                            child: SingleChildScrollView(
                              controller: _verticalScrollController,
                              scrollDirection: Axis.vertical,
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
                columns: [
                  DataColumn(
                    label: AdminDataTableConfig.getColumnLabel('ID'),
                    numeric: true,
                  ),
                  DataColumn(
                    label: AdminDataTableConfig.getColumnLabel('Image'),
                  ),
                  DataColumn(
                    label: AdminDataTableConfig.getColumnLabel('Title'),
                    onSort: (columnIndex, ascending) {
                      setState(() {
                        _sortBy = 'title';
                        _sortAscending = ascending;
                      });
                      _loadSeries(page: 1); // Reset to first page on sort
                    },
                  ),
                  DataColumn(
                    label: AdminDataTableConfig.getColumnLabel('Episodes'),
                    numeric: true,
                  ),
                  DataColumn(
                    label: AdminDataTableConfig.getColumnLabel('Year'),
                    numeric: true,
                    onSort: (columnIndex, ascending) {
                      setState(() {
                        _sortBy = 'year';
                        _sortAscending = ascending;
                      });
                      _loadSeries();
                    },
                  ),
                  DataColumn(
                    label: AdminDataTableConfig.getColumnLabel('Genre'),
                  ),
                  DataColumn(
                    label: AdminDataTableConfig.getColumnLabel('Main Actor'),
                  ),
                  DataColumn(
                    label: AdminDataTableConfig.getColumnLabel('Actions'),
                  ),
                ],
                sortColumnIndex: _sortBy == 'title' ? 2 : _sortBy == 'year' ? 4 : null,
                sortAscending: _sortAscending,
                rows: adminSeriesProvider.items.map((series) {
                  // Calculate total episodes from seasons using the series model's getter
                  final totalEpisodes = series.totalEpisodes;
                  
                  // Get main actor (first actor or empty)
                  final mainActor = series.actors.isNotEmpty 
                      ? series.actors.first.fullName 
                      : 'N/A';
                  
                  // Get first genre or empty
                  final firstGenre = series.genres.isNotEmpty 
                      ? series.genres.first 
                      : 'N/A';
                  
                  return DataRow(
                    cells: [
                      DataCell(
                        Text(
                          series.id.toString(),
                          style: AdminDataTableConfig.getCellTextStyle(theme.textTheme),
                        ),
                      ),
                      DataCell(
                        Builder(
                          builder: (context) {
                            return ImageWithPlaceholder(
                              imageUrl: series.imageUrl,
                              width: 40,
                              height: 40,
                              fit: BoxFit.cover,
                              borderRadius: 6,
                              placeholderIcon: Icons.movie,
                              placeholderIconSize: 20,
                            );
                          },
                        ),
                      ),
                      DataCell(
                        Text(
                          series.title,
                          style: AdminDataTableConfig.getCellTextStyle(theme.textTheme),
                        ),
                      ),
                      DataCell(
                        Text(
                          totalEpisodes > 0 ? totalEpisodes.toString() : 'N/A',
                          style: AdminDataTableConfig.getCellTextStyle(theme.textTheme),
                        ),
                      ),
                      DataCell(
                        Text(
                          series.releaseDate.year.toString(),
                          style: AdminDataTableConfig.getCellTextStyle(theme.textTheme),
                        ),
                      ),
                      DataCell(
                        Text(
                          firstGenre,
                          style: AdminDataTableConfig.getCellTextStyle(theme.textTheme),
                        ),
                      ),
                      DataCell(
                        Text(
                          mainActor,
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
                                onPressed: () => _handleEditSeries(series),
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
                                onPressed: () => _handleDeleteSeries(series),
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
                ),
              ),
                const SizedBox(height: AppDim.paddingSmall),
                
                // Pagination Controls
                Consumer<AdminSeriesProvider>(
                  builder: (context, adminSeriesProvider, child) {
                    return Card(
                      color: AppColors.cardBackground,
                      child: Padding(
                        padding: const EdgeInsets.all(AppDim.paddingSmall),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            // Page size selector
                            Row(
                              children: [
                                Text(
                                  'Items per page:',
                                  style: TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(width: AppDim.paddingSmall),
                                DropdownButton<int>(
                                  value: _pageSize,
                                  items: [5, 10, 20, 50, 100].map((size) {
                                    return DropdownMenuItem<int>(
                                      value: size,
                                      child: Text(size.toString()),
                                    );
                                  }).toList(),
                                  onChanged: (value) {
                                    if (value != null) {
                                      setState(() {
                                        _pageSize = value;
                                      });
                                      _loadSeries(page: 1); // Reset to first page
                                    }
                                  },
                                  style: TextStyle(color: AppColors.textPrimary),
                                  dropdownColor: AppColors.cardBackground,
                                ),
                              ],
                            ),
                            
                            // Page info and navigation
                            Row(
                              children: [
                                Text(
                                  'Page ${adminSeriesProvider.currentPage} of ${adminSeriesProvider.totalPages} (${adminSeriesProvider.totalItems} total)',
                                  style: TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(width: AppDim.paddingMedium),
                                IconButton(
                                  icon: const Icon(Icons.chevron_left),
                                  onPressed: adminSeriesProvider.currentPage > 1
                                      ? _goToPreviousPage
                                      : null,
                                  color: AppColors.primaryColor,
                                  tooltip: 'Previous page',
                                ),
                                IconButton(
                                  icon: const Icon(Icons.chevron_right),
                                  onPressed: adminSeriesProvider.currentPage < adminSeriesProvider.totalPages
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
                    );
                  },
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

