import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dim.dart';
import '../../core/widgets/image_with_placeholder.dart';
import '../../core/widgets/admin_data_table_config.dart';
import '../../providers/admin_user_provider.dart';
import '../../models/user.dart';
import '../../providers/auth_provider.dart';

/// Admin users management screen with DataTable
class AdminUsersScreen extends StatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  final _searchController = TextEditingController();
  final _horizontalScrollController = ScrollController();
  final _verticalScrollController = ScrollController();
  String _searchQuery = '';
  String? _selectedStatus;
  String _sortBy = 'name';
  bool _sortAscending = true; // Alphabetical by default
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
    _horizontalScrollController.dispose();
    _verticalScrollController.dispose();
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
                // Refresh the users list to reflect the status change
                await _loadUsers();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        user.isActive
                            ? 'User disabled successfully. The user will not be able to log in.'
                            : 'User enabled successfully. The user can now log in.',
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
              final hasActiveFilters = _searchQuery.isNotEmpty || _selectedStatus != null;
              
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
                          ? 'No users match your search or filters'
                          : 'No users found',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: AppColors.textPrimary,
                      ),
                    ),
                    if (hasActiveFilters) ...[
                      const SizedBox(height: AppDim.paddingSmall),
                      Text(
                        'Try clearing your search or filters to see all users',
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
                                _selectedStatus = null;
                                _searchController.clear();
                              });
                              _loadUsers(page: 1);
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
                            onPressed: _loadUsers,
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
                        onPressed: _loadUsers,
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
                // Users Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
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
                    label: AdminDataTableConfig.getColumnLabel('Avatar'),
                  ),
                  DataColumn(
                    label: AdminDataTableConfig.getColumnLabel('ID'),
                  ),
                  DataColumn(
                    label: AdminDataTableConfig.getColumnLabel('Name'),
                    onSort: (columnIndex, ascending) {
                      setState(() {
                        _sortBy = 'name';
                        _sortAscending = ascending;
                      });
                      _loadUsers(page: 1); // Reset to first page on sort
                    },
                  ),
                  DataColumn(
                    label: AdminDataTableConfig.getColumnLabel('Phone'),
                  ),
                  DataColumn(
                    label: AdminDataTableConfig.getColumnLabel('Email'),
                  ),
                  DataColumn(
                    label: AdminDataTableConfig.getColumnLabel('Country'),
                  ),
                  DataColumn(
                    label: AdminDataTableConfig.getColumnLabel('Status'),
                  ),
                  DataColumn(
                    label: AdminDataTableConfig.getColumnLabel('Actions'),
                  ),
                ],
                sortColumnIndex: _sortBy == 'name' ? 2 : null,
                sortAscending: _sortAscending,
                rows: userProvider.users.map((user) {
                  return DataRow(
                    cells: [
                      DataCell(
                        ImageWithPlaceholder(
                          imageUrl: user.avatarUrl,
                          width: 40,
                          height: 40,
                          fit: BoxFit.cover,
                          borderRadius: 6,
                          placeholderIcon: Icons.person,
                          placeholderIconSize: 20,
                        ),
                      ),
                      DataCell(
                        Text(
                          user.id.toString(),
                          style: AdminDataTableConfig.getCellTextStyle(theme.textTheme),
                        ),
                      ),
                      DataCell(
                        Text(
                          user.displayName,
                          style: AdminDataTableConfig.getCellTextStyle(theme.textTheme),
                        ),
                      ),
                      DataCell(
                        Text(
                          user.phoneNumber ?? 'N/A',
                          style: AdminDataTableConfig.getCellTextStyle(theme.textTheme).copyWith(
                            color: user.phoneNumber == null ? AppColors.textSecondary : AppColors.textPrimary,
                          ),
                        ),
                      ),
                      DataCell(
                        Text(
                          user.email,
                          style: AdminDataTableConfig.getCellTextStyle(theme.textTheme),
                        ),
                      ),
                      DataCell(
                        Text(
                          user.country ?? 'N/A',
                          style: AdminDataTableConfig.getCellTextStyle(theme.textTheme).copyWith(
                            color: user.country == null ? AppColors.textSecondary : AppColors.textPrimary,
                          ),
                        ),
                      ),
                      DataCell(
                        Container(
                          padding: AdminDataTableConfig.cellPadding,
                          decoration: BoxDecoration(
                            color: user.isActive
                                ? AppColors.successColor.withOpacity(0.1)
                                : AppColors.dangerColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(AppDim.borderRadius),
                          ),
                          child: Text(
                            user.status,
                            style: AdminDataTableConfig.getCellSmallTextStyle(theme.textTheme).copyWith(
                              color: user.isActive
                                  ? AppColors.successColor
                                  : AppColors.dangerColor,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                      DataCell(
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: AdminDataTableConfig.actionButtonSize,
                              child: IconButton(
                                icon: Icon(
                                  user.isActive ? Icons.block : Icons.check_circle,
                                  size: AdminDataTableConfig.actionIconSize,
                                ),
                                color: user.isActive
                                    ? AppColors.dangerColor
                                    : AppColors.successColor,
                                onPressed: () => _handleToggleUserStatus(user),
                                tooltip: user.isActive ? 'Disable' : 'Enable',
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
                                onPressed: () => _handleDeleteUser(user),
                                tooltip: 'Delete User',
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
                Consumer<AdminUserProvider>(
                  builder: (context, userProvider, child) {
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
              ],
            );
          },
        ),
      ),
    );
  }
}

