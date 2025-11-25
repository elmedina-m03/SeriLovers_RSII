import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dim.dart';
import '../../../models/user.dart';
import '../../../providers/admin_user_provider.dart';

/// Dialog for editing user details
/// 
/// Allows editing of user role and active status.
/// Email field is read-only for security purposes.
class UserFormDialog extends StatefulWidget {
  /// The user to edit
  final ApplicationUser user;

  const UserFormDialog({
    super.key,
    required this.user,
  });

  @override
  State<UserFormDialog> createState() => _UserFormDialogState();
}

class _UserFormDialogState extends State<UserFormDialog> {
  final _formKey = GlobalKey<FormState>();
  
  String? _selectedRole;
  bool _isActive = true;
  bool _isLoading = false;

  // Available roles
  final List<String> _availableRoles = [
    'User',
    'Admin',
  ];

  @override
  void initState() {
    super.initState();
    _initializeForm();
  }

  /// Initialize form with existing user data
  void _initializeForm() {
    final userRole = widget.user.role ?? 'User';
    // Defensive check: ensure selected role is in available roles
    _selectedRole = _availableRoles.contains(userRole) ? userRole : 'User';
    _isActive = widget.user.isActive;
  }

  /// Save the user changes
  Future<void> _saveUser() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final adminUserProvider = Provider.of<AdminUserProvider>(context, listen: false);

      print('🔄 UserFormDialog: Saving user changes...');
      print('User ID: ${widget.user.id}');
      print('New Role: $_selectedRole');
      print('New Active Status: $_isActive');

      // Call updateUser with the changes
      await adminUserProvider.updateUser(
        widget.user.id,
        role: _selectedRole,
        isActive: _isActive,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('User "${widget.user.email}" updated successfully'),
            backgroundColor: AppColors.successColor,
          ),
        );
        Navigator.of(context).pop(true); // Return true to indicate success
      }
    } catch (e) {
      print('❌ UserFormDialog: Error saving user: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating user: $e'),
            backgroundColor: AppColors.dangerColor,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dialog(
      backgroundColor: AppColors.cardBackground,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDim.radiusMedium),
      ),
      child: Container(
        width: 500,
        padding: const EdgeInsets.all(AppDim.paddingLarge),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Icon(
                  Icons.person_outline,
                  color: AppColors.primaryColor,
                  size: 24,
                ),
                const SizedBox(width: AppDim.paddingSmall),
                Text(
                  'Edit User',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                  color: AppColors.textSecondary,
                ),
              ],
            ),
            const SizedBox(height: AppDim.paddingLarge),

            // User info section
            Container(
              padding: const EdgeInsets.all(AppDim.paddingMedium),
              decoration: BoxDecoration(
                color: AppColors.primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(AppDim.radiusSmall),
                border: Border.all(
                  color: AppColors.primaryColor.withOpacity(0.3),
                ),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: AppColors.primaryColor,
                    foregroundColor: AppColors.textLight,
                    child: Text(
                      widget.user.email.isNotEmpty 
                          ? widget.user.email[0].toUpperCase()
                          : 'U',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: AppDim.paddingMedium),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.user.userName ?? 'Unknown User',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'ID: ${widget.user.id}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppDim.paddingLarge),

            // Form
            Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Email field (read-only)
                  TextFormField(
                    initialValue: widget.user.email,
                    decoration: InputDecoration(
                      labelText: 'Email Address',
                      labelStyle: TextStyle(color: AppColors.textSecondary),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppDim.radiusSmall),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppDim.radiusSmall),
                        borderSide: BorderSide(color: AppColors.primaryColor),
                      ),
                      suffixIcon: Icon(
                        Icons.lock_outline,
                        color: AppColors.textSecondary,
                        size: 20,
                      ),
                      helperText: 'Email cannot be changed for security reasons',
                      helperStyle: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                    style: TextStyle(color: AppColors.textSecondary),
                    readOnly: true,
                    enabled: false,
                  ),
                  const SizedBox(height: AppDim.paddingLarge),

                  // Role dropdown
                  Builder(
                    builder: (context) {
                      // Defensive check: ensure value is in available items
                      final validValue = _selectedRole != null && _availableRoles.contains(_selectedRole)
                          ? _selectedRole
                          : _availableRoles.first;
                      return DropdownButtonFormField<String>(
                        value: validValue,
                    decoration: InputDecoration(
                      labelText: 'Role *',
                      labelStyle: TextStyle(color: AppColors.textSecondary),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppDim.radiusSmall),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppDim.radiusSmall),
                        borderSide: BorderSide(color: AppColors.primaryColor),
                      ),
                      prefixIcon: Icon(
                        Icons.admin_panel_settings_outlined,
                        color: AppColors.primaryColor,
                      ),
                    ),
                    style: TextStyle(color: AppColors.textPrimary),
                    dropdownColor: AppColors.cardBackground,
                        items: _availableRoles.map((role) {
                          return DropdownMenuItem(
                            value: role,
                            child: Row(
                              children: [
                                Icon(
                                  role == 'Admin' ? Icons.shield : Icons.person,
                                  color: role == 'Admin' 
                                      ? AppColors.primaryColor 
                                      : AppColors.textSecondary,
                                  size: 20,
                                ),
                                const SizedBox(width: AppDim.paddingSmall),
                                Text(
                                  role,
                                  style: TextStyle(color: AppColors.textPrimary),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedRole = value;
                          });
                        },
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Role is required';
                          }
                          if (!_availableRoles.contains(value)) {
                            return 'Invalid role selected';
                          }
                          return null;
                        },
                      );
                    },
                  ),
                  const SizedBox(height: AppDim.paddingLarge),

                  // Active status switch
                  Container(
                    padding: const EdgeInsets.all(AppDim.paddingMedium),
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.textSecondary.withOpacity(0.3)),
                      borderRadius: BorderRadius.circular(AppDim.radiusSmall),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _isActive ? Icons.check_circle : Icons.cancel,
                          color: _isActive ? AppColors.successColor : AppColors.dangerColor,
                        ),
                        const SizedBox(width: AppDim.paddingMedium),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Account Status',
                                style: TextStyle(
                                  color: AppColors.textPrimary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _isActive 
                                    ? 'User can access the application'
                                    : 'User is blocked from accessing the application',
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Switch(
                          value: _isActive,
                          onChanged: (value) {
                            setState(() {
                              _isActive = value;
                            });
                          },
                          activeColor: AppColors.successColor,
                          inactiveThumbColor: AppColors.dangerColor,
                          inactiveTrackColor: AppColors.dangerColor.withOpacity(0.3),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppDim.paddingLarge),

            // Action buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
                  child: Text(
                    'Cancel',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                ),
                const SizedBox(width: AppDim.paddingMedium),
                ElevatedButton(
                  onPressed: _isLoading ? null : _saveUser,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryColor,
                    foregroundColor: AppColors.textLight,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppDim.paddingLarge,
                      vertical: AppDim.paddingMedium,
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(AppColors.textLight),
                          ),
                        )
                      : const Text('Save Changes'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
