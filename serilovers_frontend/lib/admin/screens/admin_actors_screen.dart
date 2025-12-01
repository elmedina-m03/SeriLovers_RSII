import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dim.dart';
import '../../core/widgets/image_with_placeholder.dart';
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
              return Center(
                child: Text(
                  'No actors found',
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
                    padding: const EdgeInsets.all(AppDim.paddingMedium),
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
                            },
                            onSubmitted: (value) {
                              _loadActors(page: 1); // Reset to first page on search
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
                                    _loadActors(page: 1); // Reset to first page on filter change
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
                  const DataColumn(
                    label: Text('Photo'),
                  ),
                  const DataColumn(
                    label: Text('First Name'),
                  ),
                  DataColumn(
                    label: const Text('Last Name'),
                    onSort: (columnIndex, ascending) {
                      setState(() {
                        _sortBy = 'lastName';
                        _sortAscending = ascending;
                      });
                      _loadActors(page: 1); // Reset to first page on sort
                    },
                  ),
                  const DataColumn(
                    label: Text('Date of Birth'),
                  ),
                  DataColumn(
                    label: const Text('Age'),
                    numeric: true,
                    onSort: (columnIndex, ascending) {
                      setState(() {
                        _sortBy = 'age';
                        _sortAscending = ascending;
                      });
                      _loadActors(page: 1); // Reset to first page on sort
                    },
                  ),
                  const DataColumn(
                    label: Text('Total Series'),
                    numeric: true,
                  ),
                  const DataColumn(
                    label: Text('Actions'),
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
                            // Debug: log image URL for troubleshooting
                            if (actor.imageUrl != null && actor.imageUrl!.isNotEmpty) {
                              print('📸 Actor "${actor.fullName}" has imageUrl: ${actor.imageUrl}');
                            }
                            return ImageWithPlaceholder(
                              imageUrl: actor.imageUrl,
                              width: 50,
                              height: 50,
                              fit: BoxFit.cover,
                              borderRadius: 8,
                              placeholderIcon: Icons.person,
                              placeholderIconSize: 24,
                            );
                          },
                        ),
                      ),
                      DataCell(
                        Text(
                          actor.firstName,
                          style: theme.textTheme.bodyMedium,
                        ),
                      ),
                      DataCell(
                        Text(
                          actor.lastName,
                          style: theme.textTheme.bodyMedium,
                        ),
                      ),
                      DataCell(
                        Text(
                          _formatDate(actor.dateOfBirth),
                          style: theme.textTheme.bodyMedium,
                        ),
                      ),
                      DataCell(
                        Text(
                          (actor.age ?? actor.calculatedAge)?.toString() ?? 'N/A',
                          style: theme.textTheme.bodyMedium,
                        ),
                      ),
                      DataCell(
                        Text(
                          actor.seriesCount.toString(),
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
                              onPressed: () => _handleEditActor(actor),
                              tooltip: 'Edit',
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete),
                              color: AppColors.dangerColor,
                              onPressed: () => _handleDeleteActor(actor),
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
                Consumer<AdminActorProvider>(
                  builder: (context, adminActorProvider, child) {
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

