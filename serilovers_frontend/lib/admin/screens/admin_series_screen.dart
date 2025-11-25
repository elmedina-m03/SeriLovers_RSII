import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dim.dart';
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
  void dispose() {
    _searchController.dispose();
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
              return Center(
                child: Text(
                  'No series found',
                  style: theme.textTheme.bodyLarge,
                ),
              );
            }

            return LayoutBuilder(
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
                      onPressed: _handleAddSeries,
                      icon: const Icon(Icons.add, size: 20),
                      label: const Text('Add Series'),
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
                    padding: const EdgeInsets.all(AppDim.paddingMedium),
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
                                            _loadSeries();
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
                                },
                                onSubmitted: (value) {
                                  _loadSeries(page: 1); // Reset to first page on search
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
                                      _loadSeries(page: 1); // Reset to first page on filter change
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
                                  _loadSeries(page: 1); // Reset to first page on filter change
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
                const SizedBox(height: AppDim.paddingMedium),
                
                // Data Table
                SizedBox(
                  height: 400, // Fixed height for table with vertical scroll
                  child: SingleChildScrollView(
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
                columns: [
                  DataColumn(
                    label: const Text('Title'),
                    onSort: (columnIndex, ascending) {
                      setState(() {
                        _sortBy = 'title';
                        _sortAscending = ascending;
                      });
                      _loadSeries(page: 1); // Reset to first page on sort
                    },
                  ),
                  DataColumn(
                    label: const Text('Year'),
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
                    label: const Text('Rating'),
                    numeric: true,
                    onSort: (columnIndex, ascending) {
                      setState(() {
                        _sortBy = 'rating';
                        _sortAscending = ascending;
                      });
                      _loadSeries();
                    },
                  ),
                  const DataColumn(
                    label: Text('Genres'),
                  ),
                  const DataColumn(
                    label: Text('Actions'),
                  ),
                ],
                sortColumnIndex: _sortBy == 'title' ? 0 : _sortBy == 'year' ? 1 : _sortBy == 'rating' ? 2 : null,
                sortAscending: _sortAscending,
                rows: adminSeriesProvider.items.map((series) {
                  return DataRow(
                    cells: [
                      DataCell(
                        Text(
                          series.title,
                          style: theme.textTheme.bodyMedium,
                        ),
                      ),
                      DataCell(
                        Text(
                          series.releaseDate.year.toString(),
                          style: theme.textTheme.bodyMedium,
                        ),
                      ),
                      DataCell(
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.star,
                              size: 16,
                              color: AppColors.primaryColor,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              series.rating.toStringAsFixed(1),
                              style: theme.textTheme.bodyMedium,
                            ),
                          ],
                        ),
                      ),
                      DataCell(
                        Wrap(
                          spacing: 4,
                          runSpacing: 4,
                          children: series.genres.take(3).map((genre) {
                            return Chip(
                              label: Text(
                                genre,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              backgroundColor: AppColors.cardBackground,
                              side: BorderSide(
                                color: AppColors.primaryColor.withOpacity(0.3),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                      DataCell(
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit),
                              color: AppColors.primaryColor,
                              onPressed: () => _handleEditSeries(series),
                              tooltip: 'Edit',
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete),
                              color: AppColors.dangerColor,
                              onPressed: () => _handleDeleteSeries(series),
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
                  ),
                ),
                const SizedBox(height: AppDim.paddingMedium),
                
                // Pagination Controls
                Consumer<AdminSeriesProvider>(
                  builder: (context, adminSeriesProvider, child) {
                    return Card(
                      color: AppColors.cardBackground,
                      child: Padding(
                        padding: const EdgeInsets.all(AppDim.paddingMedium),
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
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

