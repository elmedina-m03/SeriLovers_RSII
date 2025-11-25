import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dim.dart';
import '../../providers/admin_user_provider.dart';
import '../../models/user.dart';
import 'users/user_form_dialog.dart';

/// Admin users management screen with DataTable
class AdminUsersScreen extends StatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  String? _selectedStatus;
  String _sortBy = 'dateCreated';
  bool _sortAscending = false; // Newest first by default
  int _pageSize = 10;

  final List<String> _availableStatuses = [
    'Active',
    'Inactive',
  ];

  @override
  void initState() {
    super.initState();
    // Fetch users when screen loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadUsers();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Load users data with current filters
  Future<void> _loadUsers({int? page}) async {
    try {
      final userProvider = Provider.of<AdminUserProvider>(context, listen: false);
      await userProvider.fetchFiltered(
        search: _searchQuery.isEmpty ? null : _searchQuery,
        status: _selectedStatus,
        sortBy: _sortBy,
        sortOrder: _sortAscending ? 'asc' : 'desc',
        page: page,
        pageSize: _pageSize,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading users: $e'),
            backgroundColor: AppColors.dangerColor,
          ),
        );
      }
    }
  }

  /// Go to previous page
  void _goToPreviousPage() {
    final userProvider = Provider.of<AdminUserProvider>(context, listen: false);
    if (userProvider.currentPage > 1) {
      _loadUsers(page: userProvider.currentPage - 1);
    }
  }

  /// Go to next page
  void _goToNextPage() {
    final userProvider = Provider.of<AdminUserProvider>(context, listen: false);
    if (userProvider.currentPage < userProvider.totalPages) {
      _loadUsers(page: userProvider.currentPage + 1);
    }
  }

  /// Handle editing a user
  Future<void> _handleEditUser(ApplicationUser user) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => UserFormDialog(user: user),
    );

    // Reload data if user was updated successfully
    if (result == true) {
      await _loadUsers();
    }
  }

  /// Handle deleting a user with confirmation
  Future<void> _handleDeleteUser(ApplicationUser user) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.cardBackground,
        title: Text(
          'Delete User',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: Text(
          'Are you sure you want to delete user "${user.email}"?\n\nThis action cannot be undone and will permanently remove the user from the system.',
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
        final userProvider = Provider.of<AdminUserProvider>(context, listen: false);
        await userProvider.deleteUser(user.id);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('User "${user.email}" deleted successfully'),
              backgroundColor: AppColors.successColor,
            ),
          );
        }
        
        // Reload the users list
        await _loadUsers();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error deleting user: $e'),
              backgroundColor: AppColors.dangerColor,
            ),
          );
        }
      }
    }
  }

  /// Handle toggling user status (enable/disable)
  Future<void> _handleToggleUserStatus(ApplicationUser user) async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(user.isActive ? 'Disable User' : 'Enable User'),
        content: Text(
          user.isActive
              ? 'Are you sure you want to disable "${user.email}"?'
              : 'Are you sure you want to enable "${user.email}"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                final userProvider = Provider.of<AdminUserProvider>(context, listen: false);
                await userProvider.toggleUserStatus(user);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        user.isActive
                            ? 'User disabled successfully'
                            : 'User enabled successfully',
                      ),
                      backgroundColor: AppColors.successColor,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error: ${e.toString()}'),
                      backgroundColor: AppColors.dangerColor,
                    ),
                  );
                }
              }
            },
            style: TextButton.styleFrom(
              foregroundColor: user.isActive ? AppColors.dangerColor : AppColors.successColor,
            ),
            child: Text(user.isActive ? 'Disable' : 'Enable'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Container(
      color: AppColors.backgroundColor,
      child: Padding(
        padding: const EdgeInsets.all(AppDim.paddingLarge),
        child: Consumer<AdminUserProvider>(
          builder: (context, userProvider, child) {
            if (userProvider.isLoading) {
              return const Center(
                child: CircularProgressIndicator(),
              );
            }

            if (userProvider.users.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'No users found',
                      style: theme.textTheme.bodyLarge,
                    ),
                    const SizedBox(height: AppDim.padding),
                    ElevatedButton(
                      onPressed: _loadUsers,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryColor,
                        foregroundColor: AppColors.textLight,
                      ),
                      child: const Text('Refresh'),
                    ),
                  ],
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
                                  labelText: 'Search users...',
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
                                            _loadUsers(page: 1); // Reset to first page on clear
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
                                  _loadUsers(page: 1); // Reset to first page on search
                                },
                              ),
                            ),
                            const SizedBox(width: AppDim.paddingMedium),
                            
                            // Status Filter Dropdown
                            Expanded(
                              flex: 1,
                              child: DropdownButtonFormField<String>(
                                value: _selectedStatus,
                                decoration: InputDecoration(
                                  labelText: 'Filter by Status',
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
                                    child: Text('All Statuses'),
                                  ),
                                  ..._availableStatuses.map((status) {
                                    return DropdownMenuItem<String>(
                                      value: status,
                                      child: Text(status),
                                    );
                                  }),
                                ],
                                onChanged: (value) {
                                  setState(() {
                                    _selectedStatus = value;
                                  });
                                  _loadUsers(page: 1); // Reset to first page on filter change
                                },
                              ),
                            ),
                            const SizedBox(width: AppDim.paddingMedium),
                            
                            // Search Button
                            ElevatedButton.icon(
                              onPressed: () => _loadUsers(page: 1), // Reset to first page on search
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
                  const DataColumn(
                    label: Text('ID'),
                  ),
                  DataColumn(
                    label: const Text('Name'),
                    onSort: (columnIndex, ascending) {
                      setState(() {
                        _sortBy = 'name';
                        _sortAscending = ascending;
                      });
                      _loadUsers(page: 1); // Reset to first page on sort
                    },
                  ),
                  const DataColumn(
                    label: Text('Phone'),
                  ),
                  const DataColumn(
                    label: Text('Email'),
                  ),
                  const DataColumn(
                    label: Text('Country'),
                  ),
                  const DataColumn(
                    label: Text('Status'),
                  ),
                  DataColumn(
                    label: const Text('Date Added'),
                    onSort: (columnIndex, ascending) {
                      setState(() {
                        _sortBy = 'dateCreated';
                        _sortAscending = ascending;
                      });
                      _loadUsers(page: 1); // Reset to first page on sort
                    },
                  ),
                  const DataColumn(
                    label: Text('Actions'),
                  ),
                ],
                sortColumnIndex: _sortBy == 'name' ? 1 : _sortBy == 'dateCreated' ? 6 : null,
                sortAscending: _sortAscending,
                rows: userProvider.users.map((user) {
                  return DataRow(
                    cells: [
                      DataCell(
                        Text(
                          user.id.toString(),
                          style: theme.textTheme.bodyMedium,
                        ),
                      ),
                      DataCell(
                        Text(
                          user.displayName,
                          style: theme.textTheme.bodyMedium,
                        ),
                      ),
                      DataCell(
                        Text(
                          user.phoneNumber ?? 'N/A',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: user.phoneNumber == null ? AppColors.textSecondary : AppColors.textPrimary,
                          ),
                        ),
                      ),
                      DataCell(
                        Text(
                          user.email,
                          style: theme.textTheme.bodyMedium,
                        ),
                      ),
                      DataCell(
                        Text(
                          user.country ?? 'N/A',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: user.country == null ? AppColors.textSecondary : AppColors.textPrimary,
                          ),
                        ),
                      ),
                      DataCell(
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: user.isActive
                                ? AppColors.successColor.withOpacity(0.1)
                                : AppColors.dangerColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(AppDim.borderRadius),
                          ),
                          child: Text(
                            user.status,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: user.isActive
                                  ? AppColors.successColor
                                  : AppColors.dangerColor,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                      DataCell(
                        Text(
                          user.dateCreated != null 
                              ? '${user.dateCreated!.day}/${user.dateCreated!.month}/${user.dateCreated!.year}'
                              : 'N/A',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: user.dateCreated == null ? AppColors.textSecondary : AppColors.textPrimary,
                          ),
                        ),
                      ),
                      DataCell(
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit),
                              color: AppColors.primaryColor,
                              onPressed: () => _handleEditUser(user),
                              tooltip: 'Edit',
                            ),
                            IconButton(
                              icon: Icon(
                                user.isActive ? Icons.block : Icons.check_circle,
                              ),
                              color: user.isActive
                                  ? AppColors.dangerColor
                                  : AppColors.successColor,
                              onPressed: () => _handleToggleUserStatus(user),
                              tooltip: user.isActive ? 'Disable' : 'Enable',
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete),
                              color: AppColors.dangerColor,
                              onPressed: () => _handleDeleteUser(user),
                              tooltip: 'Delete User',
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
                Consumer<AdminUserProvider>(
                  builder: (context, userProvider, child) {
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
                                      _loadUsers(page: 1); // Reset to first page on page size change
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
                                  'Page ${userProvider.currentPage} of ${userProvider.totalPages} (${userProvider.totalItems} total)',
                                  style: TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(width: AppDim.paddingMedium),
                                IconButton(
                                  icon: const Icon(Icons.chevron_left),
                                  onPressed: userProvider.currentPage > 1
                                      ? _goToPreviousPage
                                      : null,
                                  color: AppColors.primaryColor,
                                  tooltip: 'Previous page',
                                ),
                                IconButton(
                                  icon: const Icon(Icons.chevron_right),
                                  onPressed: userProvider.currentPage < userProvider.totalPages
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

