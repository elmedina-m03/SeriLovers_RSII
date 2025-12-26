import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dim.dart';
import '../../core/widgets/image_with_placeholder.dart';
import '../../core/widgets/admin_data_table_config.dart';
import '../../models/series.dart';
import '../providers/admin_actor_provider.dart';
import 'actors/actor_form_dialog.dart';

/// Admin actors management screen with DataTable
class AdminActorsScreen extends StatefulWidget {
  const AdminActorsScreen({super.key});

  @override
  State<AdminActorsScreen> createState() => _AdminActorsScreenState();
}

class _AdminActorsScreenState extends State<AdminActorsScreen> {
  final _nameSearchController = TextEditingController();
  final _horizontalScrollController = ScrollController();
  final _verticalScrollController = ScrollController();
  String _nameSearchQuery = '';
  int? _selectedAge;
  String _sortBy = 'lastName';
  bool _sortAscending = true;
  int _pageSize = 10;

  // Age filter options
  final List<int?> _ageOptions = [
    null, // All ages
    18, 20, 25, 30, 35, 40, 45, 50, 55, 60, 65, 70, 75, 80,
  ];

  @override
  void initState() {
    super.initState();
    // Fetch actors when screen loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadActors();
    });
  }

  @override
  void dispose() {
    _nameSearchController.dispose();
    _horizontalScrollController.dispose();
    _verticalScrollController.dispose();
    super.dispose();
  }

  /// Load actors data with current filters
  Future<void> _loadActors({int? page}) async {
    try {
      final adminActorProvider = Provider.of<AdminActorProvider>(context, listen: false);
      await adminActorProvider.fetchFiltered(
        search: _nameSearchQuery.isEmpty ? null : _nameSearchQuery,
        age: _selectedAge,
        sortBy: _sortBy,
        sortOrder: _sortAscending ? 'asc' : 'desc',
        page: page,
        pageSize: _pageSize,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading actors: $e'),
            backgroundColor: AppColors.dangerColor,
          ),
        );
      }
    }
  }

  /// Go to previous page
  void _goToPreviousPage() {
    final adminActorProvider = Provider.of<AdminActorProvider>(context, listen: false);
    if (adminActorProvider.currentPage > 1) {
      _loadActors(page: adminActorProvider.currentPage - 1);
    }
  }

  /// Go to next page
  void _goToNextPage() {
    final adminActorProvider = Provider.of<AdminActorProvider>(context, listen: false);
    if (adminActorProvider.currentPage < adminActorProvider.totalPages) {
      _loadActors(page: adminActorProvider.currentPage + 1);
    }
  }

  /// Handle adding a new actor
  Future<void> _handleAddActor() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => const ActorFormDialog(),
    );

    // Reload data if actor was created successfully
    if (result == true) {
      await _loadActors();
    }
  }

  /// Handle editing an existing actor
  Future<void> _handleEditActor(Actor actor) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => ActorFormDialog(actor: actor),
    );

    // Reload data if actor was updated successfully
    if (result == true) {
      await _loadActors();
    }
  }

  /// Handle deleting an actor with confirmation
  Future<void> _handleDeleteActor(Actor actor) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.cardBackground,
        title: Text(
          'Delete Actor',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: Text(
          'Are you sure you want to delete "${actor.fullName}"?\n\nThis action cannot be undone and will remove the actor from all associated series.',
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
        final adminActorProvider = Provider.of<AdminActorProvider>(context, listen: false);
        await adminActorProvider.deleteActor(actor.id);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('"${actor.fullName}" deleted successfully'),
              backgroundColor: AppColors.successColor,
            ),
          );
        }
        
        // Reload the actors list
        await _loadActors();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error deleting actor: $e'),
              backgroundColor: AppColors.dangerColor,
            ),
          );
        }
      }
    }
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'N/A';
    return '${date.day}/${date.month}/${date.year}';
  }

  /// Calculate age from date of birth
  int _calculateAge(DateTime dateOfBirth) {
    final now = DateTime.now();
    int age = now.year - dateOfBirth.year;
    if (now.month < dateOfBirth.month || 
        (now.month == dateOfBirth.month && now.day < dateOfBirth.day)) {
      age--;
    }
    return age;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Container(
      color: AppColors.backgroundColor,
      child: Padding(
        padding: const EdgeInsets.all(AppDim.paddingLarge),
        child: Consumer<AdminActorProvider>(
          builder: (context, adminActorProvider, child) {
            if (adminActorProvider.isLoading) {
              return const Center(
                child: CircularProgressIndicator(),
              );
            }

            if (adminActorProvider.items.isEmpty) {
              final hasActiveFilters = _nameSearchQuery.isNotEmpty || _selectedAge != null;
              
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
                          ? 'No actors match your search or filters'
                          : 'No actors found',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: AppColors.textPrimary,
                      ),
                    ),
                    if (hasActiveFilters) ...[
                      const SizedBox(height: AppDim.paddingSmall),
                      Text(
                        'Try clearing your search or filters to see all actors',
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
                                _nameSearchQuery = '';
                                _selectedAge = null;
                                _nameSearchController.clear();
                              });
                              _loadActors(page: 1);
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
                            onPressed: _loadActors,
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
                        onPressed: _loadActors,
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
                      onPressed: _handleAddActor,
                      icon: const Icon(Icons.add, size: 20),
                      label: const Text('Add Actor'),
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
                // Search Controls
                Card(
                  color: AppColors.cardBackground,
                  child: Padding(
                    padding: const EdgeInsets.all(AppDim.paddingSmall),
                    child: Row(
                      children: [
                        // Name Search TextField
                        Expanded(
                          flex: 2,
                          child: TextField(
                            controller: _nameSearchController,
                            decoration: InputDecoration(
                              labelText: 'Search by name...',
                              labelStyle: TextStyle(color: AppColors.textSecondary),
                              prefixIcon: Icon(Icons.person_search, color: AppColors.textSecondary),
                              suffixIcon: _nameSearchQuery.isNotEmpty
                                  ? IconButton(
                                      icon: Icon(Icons.clear, color: AppColors.textSecondary),
                                      onPressed: () {
                                        _nameSearchController.clear();
                                        setState(() {
                                          _nameSearchQuery = '';
                                        });
                                        _loadActors(page: 1); // Reset to first page on clear
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
                                _nameSearchQuery = value;
                              });
                              // Don't trigger search automatically - wait for Search button
                            },
                            onSubmitted: (value) {
                              // Don't trigger search on Enter - wait for Search button
                            },
                          ),
                        ),
                        const SizedBox(width: AppDim.paddingMedium),
                        
                        // Age Filter Dropdown
                        Expanded(
                          flex: 1,
                          child: Builder(
                            builder: (context) {
                              // Defensive check: ensure value is in available items
                              final validValue = _selectedAge != null && _ageOptions.contains(_selectedAge)
                                  ? _selectedAge
                                  : null;
                              return DropdownButtonFormField<int?>(
                                value: validValue,
                            decoration: InputDecoration(
                              labelText: 'Filter by Age',
                              labelStyle: TextStyle(color: AppColors.textSecondary),
                              prefixIcon: Icon(Icons.calendar_today, color: AppColors.textSecondary),
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
                                items: _ageOptions.map((age) {
                                  return DropdownMenuItem<int?>(
                                    value: age,
                                    child: Text(
                                      age == null ? 'All Ages' : '$age years',
                                      style: TextStyle(color: AppColors.textPrimary),
                                    ),
                                  );
                                }).toList(),
                                onChanged: (value) {
                                  // Defensive check: only set if value is in available options
                                  if (value == null || _ageOptions.contains(value)) {
                                    setState(() {
                                      _selectedAge = value;
                                    });
                                    // Don't trigger search automatically - wait for Search button
                                  }
                                },
                              );
                            },
                          ),
                        ),
                        const SizedBox(width: AppDim.paddingMedium),
                        
                        // Search Button
                        ElevatedButton.icon(
                          onPressed: () => _loadActors(page: 1), // Reset to first page on search
                          icon: const Icon(Icons.search),
                          label: const Text('Search'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryColor,
                            foregroundColor: AppColors.textLight,
                          ),
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
                    label: AdminDataTableConfig.getColumnLabel('Photo'),
                  ),
                  DataColumn(
                    label: AdminDataTableConfig.getColumnLabel('First Name'),
                  ),
                  DataColumn(
                    label: AdminDataTableConfig.getColumnLabel('Last Name'),
                    onSort: (columnIndex, ascending) {
                      setState(() {
                        _sortBy = 'lastName';
                        _sortAscending = ascending;
                      });
                      _loadActors(page: 1); // Reset to first page on sort
                    },
                  ),
                  DataColumn(
                    label: AdminDataTableConfig.getColumnLabel('Date of Birth'),
                  ),
                  DataColumn(
                    label: AdminDataTableConfig.getColumnLabel('Age'),
                    numeric: true,
                    onSort: (columnIndex, ascending) {
                      setState(() {
                        _sortBy = 'age';
                        _sortAscending = ascending;
                      });
                      _loadActors(page: 1); // Reset to first page on sort
                    },
                  ),
                  DataColumn(
                    label: AdminDataTableConfig.getColumnLabel('Total Series'),
                    numeric: true,
                  ),
                  DataColumn(
                    label: AdminDataTableConfig.getColumnLabel('Actions'),
                  ),
                ],
                sortColumnIndex: _sortBy == 'lastName' ? 2 : (_sortBy == 'age' ? 4 : null),
                sortAscending: _sortAscending,
                rows: adminActorProvider.items.map((actor) {
                  return DataRow(
                    cells: [
                      DataCell(
                        Builder(
                          builder: (context) {
                            return ImageWithPlaceholder(
                              imageUrl: actor.imageUrl,
                              width: 40,
                              height: 40,
                              fit: BoxFit.cover,
                              borderRadius: 6,
                              placeholderIcon: Icons.person,
                              placeholderIconSize: 20,
                            );
                          },
                        ),
                      ),
                      DataCell(
                        Text(
                          actor.firstName,
                          style: AdminDataTableConfig.getCellTextStyle(theme.textTheme),
                        ),
                      ),
                      DataCell(
                        Text(
                          actor.lastName,
                          style: AdminDataTableConfig.getCellTextStyle(theme.textTheme),
                        ),
                      ),
                      DataCell(
                        Text(
                          _formatDate(actor.dateOfBirth),
                          style: AdminDataTableConfig.getCellTextStyle(theme.textTheme),
                        ),
                      ),
                      DataCell(
                        Text(
                          (actor.age ?? actor.calculatedAge)?.toString() ?? 'N/A',
                          style: AdminDataTableConfig.getCellTextStyle(theme.textTheme),
                        ),
                      ),
                      DataCell(
                        Text(
                          actor.seriesCount.toString(),
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
                                onPressed: () => _handleEditActor(actor),
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
                                onPressed: () => _handleDeleteActor(actor),
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
                Consumer<AdminActorProvider>(
                  builder: (context, adminActorProvider, child) {
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
                                      _loadActors(page: 1); // Reset to first page
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
                                  'Page ${adminActorProvider.currentPage} of ${adminActorProvider.totalPages} (${adminActorProvider.totalItems} total)',
                                  style: TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(width: AppDim.paddingMedium),
                                IconButton(
                                  icon: const Icon(Icons.chevron_left),
                                  onPressed: adminActorProvider.currentPage > 1
                                      ? _goToPreviousPage
                                      : null,
                                  color: AppColors.primaryColor,
                                  tooltip: 'Previous page',
                                ),
                                IconButton(
                                  icon: const Icon(Icons.chevron_right),
                                  onPressed: adminActorProvider.currentPage < adminActorProvider.totalPages
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

