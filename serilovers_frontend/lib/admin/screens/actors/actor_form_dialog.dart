import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dim.dart';
import '../../../models/series.dart';
import '../../providers/admin_actor_provider.dart';

/// Dialog for creating or editing an actor
/// 
/// Supports two modes:
/// - Create: No initial data provided
/// - Edit: Initial actor data provided for editing
class ActorFormDialog extends StatefulWidget {
  /// The actor to edit (null for create mode)
  final Actor? actor;

  const ActorFormDialog({
    super.key,
    this.actor,
  });

  @override
  State<ActorFormDialog> createState() => _ActorFormDialogState();
}

class _ActorFormDialogState extends State<ActorFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _biographyController = TextEditingController();
  final _dateOfBirthController = TextEditingController();

  DateTime? _selectedDate;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _initializeForm();
    _setupBiographyListener();
  }

  /// Setup biography character count listener
  void _setupBiographyListener() {
    _biographyController.addListener(() {
      setState(() {
        // This will trigger a rebuild to update the character count
      });
    });
  }

  /// Initialize form with existing data if in edit mode
  void _initializeForm() {
    if (widget.actor != null) {
      final actor = widget.actor!;
      _firstNameController.text = actor.firstName;
      _lastNameController.text = actor.lastName;
      _biographyController.text = ''; // Biography not in current Actor model
      _selectedDate = actor.dateOfBirth;
      if (_selectedDate != null) {
        _dateOfBirthController.text = _formatDate(_selectedDate!);
      }
    }
  }

  /// Format date for display
  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  /// Show date picker
  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime(1980),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
              primary: AppColors.primaryColor,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
        _dateOfBirthController.text = _formatDate(picked);
      });
    }
  }

  /// Save the actor (create or update)
  Future<void> _saveActor() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final adminActorProvider = Provider.of<AdminActorProvider>(context, listen: false);

      // Prepare actor data
      final actorData = {
        'firstName': _firstNameController.text.trim(),
        'lastName': _lastNameController.text.trim(),
        'biography': _biographyController.text.trim(),
        'dateOfBirth': _selectedDate?.toIso8601String(),
      };

      if (widget.actor == null) {
        // Create new actor
        await adminActorProvider.createActor(actorData);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Actor created successfully'),
              backgroundColor: AppColors.successColor,
            ),
          );
        }
      } else {
        // Update existing actor
        await adminActorProvider.updateActor(widget.actor!.id, actorData);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Actor updated successfully'),
              backgroundColor: AppColors.successColor,
            ),
          );
        }
      }

      if (mounted) {
        Navigator.of(context).pop(true); // Return true to indicate success
      }
    } catch (e) {
      print('Error saving actor: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving actor: $e'),
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
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _biographyController.dispose();
    _dateOfBirthController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isEditMode = widget.actor != null;

    return Dialog(
      backgroundColor: AppColors.cardBackground,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDim.radiusMedium),
      ),
      child: Container(
        width: 600,
        constraints: const BoxConstraints(maxHeight: 700),
        padding: const EdgeInsets.all(AppDim.paddingLarge),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Icon(
                  isEditMode ? Icons.edit : Icons.person_add,
                  color: AppColors.primaryColor,
                  size: 24,
                ),
                const SizedBox(width: AppDim.paddingSmall),
                Text(
                  isEditMode ? 'Edit Actor' : 'Create New Actor',
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

            // Form
            Expanded(
              child: Form(
                key: _formKey,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // First Name field
                      TextFormField(
                        controller: _firstNameController,
                        decoration: InputDecoration(
                          labelText: 'First Name *',
                          labelStyle: TextStyle(color: AppColors.textSecondary),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AppDim.radiusSmall),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AppDim.radiusSmall),
                            borderSide: BorderSide(color: AppColors.primaryColor),
                          ),
                          prefixIcon: Icon(
                            Icons.person,
                            color: AppColors.primaryColor,
                          ),
                        ),
                        style: TextStyle(color: AppColors.textPrimary),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'First name is required';
                          }
                          if (value.trim().length > 100) {
                            return 'First name cannot exceed 100 characters';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: AppDim.paddingMedium),

                      // Last Name field
                      TextFormField(
                        controller: _lastNameController,
                        decoration: InputDecoration(
                          labelText: 'Last Name *',
                          labelStyle: TextStyle(color: AppColors.textSecondary),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AppDim.radiusSmall),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AppDim.radiusSmall),
                            borderSide: BorderSide(color: AppColors.primaryColor),
                          ),
                          prefixIcon: Icon(
                            Icons.person_outline,
                            color: AppColors.primaryColor,
                          ),
                        ),
                        style: TextStyle(color: AppColors.textPrimary),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Last name is required';
                          }
                          if (value.trim().length > 100) {
                            return 'Last name cannot exceed 100 characters';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: AppDim.paddingMedium),

                      // Date of Birth field
                      TextFormField(
                        controller: _dateOfBirthController,
                        decoration: InputDecoration(
                          labelText: 'Date of Birth',
                          labelStyle: TextStyle(color: AppColors.textSecondary),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AppDim.radiusSmall),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AppDim.radiusSmall),
                            borderSide: BorderSide(color: AppColors.primaryColor),
                          ),
                          prefixIcon: Icon(
                            Icons.cake,
                            color: AppColors.primaryColor,
                          ),
                          suffixIcon: Icon(
                            Icons.calendar_today,
                            color: AppColors.primaryColor,
                          ),
                        ),
                        style: TextStyle(color: AppColors.textPrimary),
                        readOnly: true,
                        onTap: _selectDate,
                      ),
                      const SizedBox(height: AppDim.paddingMedium),

                      // Biography field
                      TextFormField(
                        controller: _biographyController,
                        decoration: InputDecoration(
                          labelText: 'Biography',
                          labelStyle: TextStyle(color: AppColors.textSecondary),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AppDim.radiusSmall),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AppDim.radiusSmall),
                            borderSide: BorderSide(color: AppColors.primaryColor),
                          ),
                          prefixIcon: Icon(
                            Icons.description,
                            color: AppColors.primaryColor,
                          ),
                          alignLabelWithHint: true,
                        ),
                        style: TextStyle(color: AppColors.textPrimary),
                        maxLines: 4,
                        validator: (value) {
                          if (value != null && value.length > 1000) {
                            return 'Biography cannot exceed 1000 characters';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: AppDim.paddingSmall),

                      // Character count for biography
                      Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          '${_biographyController.text.length}/1000',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
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
                  onPressed: _isLoading ? null : _saveActor,
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
                      : Text(isEditMode ? 'Update' : 'Create'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

