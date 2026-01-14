import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dim.dart';
import '../../../models/challenge.dart';
import '../../providers/admin_challenge_provider.dart';

/// Dialog for creating or editing a challenge
/// 
/// Supports two modes:
/// - Create: No initial data provided
/// - Edit: Initial challenge data provided for editing
class ChallengeFormDialog extends StatefulWidget {
  /// The challenge to edit (null for create mode)
  final Challenge? challenge;

  const ChallengeFormDialog({
    super.key,
    this.challenge,
  });

  @override
  State<ChallengeFormDialog> createState() => _ChallengeFormDialogState();
}

class _ChallengeFormDialogState extends State<ChallengeFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _targetCountController = TextEditingController();

  String _selectedDifficulty = 'Easy';
  bool _isLoading = false;

  final List<String> _difficulties = ['Easy', 'Medium', 'Hard', 'Expert'];

  @override
  void initState() {
    super.initState();
    _initializeForm();
  }

  /// Initialize form with existing data if in edit mode
  void _initializeForm() {
    if (widget.challenge != null) {
      final challenge = widget.challenge!;
      _nameController.text = challenge.name;
      _descriptionController.text = challenge.description ?? '';
      _targetCountController.text = challenge.targetCount.toString();
      // Defensive check: ensure difficulty is in available difficulties
      final challengeDifficulty = challenge.difficulty;
      _selectedDifficulty = _difficulties.contains(challengeDifficulty) 
          ? challengeDifficulty 
          : _difficulties.first;
    } else {
      // Set default target count for new challenges
      _targetCountController.text = '10';
    }
  }

  /// Save the challenge (create or update)
  Future<void> _saveChallenge() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final adminChallengeProvider = Provider.of<AdminChallengeProvider>(context, listen: false);

      // Prepare challenge data
      // Backend enum: Easy=1, Medium=2, Hard=3, Expert=4
      // Send as integer enum value
      int difficultyValue;
      switch (_selectedDifficulty) {
        case 'Easy':
          difficultyValue = 1;
          break;
        case 'Medium':
          difficultyValue = 2;
          break;
        case 'Hard':
          difficultyValue = 3;
          break;
        case 'Expert':
          difficultyValue = 4;
          break;
        default:
          difficultyValue = 1; // Default to Easy
      }

      final challengeData = {
        'name': _nameController.text.trim(),
        'description': _descriptionController.text.trim().isEmpty 
            ? null 
            : _descriptionController.text.trim(),
        'difficulty': difficultyValue, // Send as integer (1-4)
        'targetCount': int.parse(_targetCountController.text),
      };

      if (widget.challenge == null) {
        // Create new challenge
        await adminChallengeProvider.createChallenge(challengeData);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Challenge created successfully'),
              backgroundColor: AppColors.successColor,
            ),
          );
        }
      } else {
        // Update existing challenge
        final challengeId = widget.challenge!.id;
        await adminChallengeProvider.updateChallenge(challengeId, challengeData);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Challenge updated successfully'),
              backgroundColor: AppColors.successColor,
            ),
          );
        }
      }

      if (mounted) {
        Navigator.of(context).pop(true); // Return true to indicate success
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving challenge: $e'),
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
    _nameController.dispose();
    _descriptionController.dispose();
    _targetCountController.dispose();
    super.dispose();
  }

  Color _getDifficultyColor(String difficulty) {
    switch (difficulty.toLowerCase()) {
      case 'easy':
        return AppColors.successColor;
      case 'medium':
        return Colors.orange;
      case 'hard':
        return AppColors.dangerColor;
      case 'expert':
        return Colors.purple;
      default:
        return AppColors.textPrimary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isEditMode = widget.challenge != null;

    return Dialog(
      backgroundColor: AppColors.cardBackground,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDim.radiusMedium),
      ),
      child: Container(
        width: 500,
        constraints: const BoxConstraints(maxHeight: 600),
        padding: const EdgeInsets.all(AppDim.paddingLarge),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Icon(
                  isEditMode ? Icons.edit : Icons.add,
                  color: AppColors.primaryColor,
                  size: 24,
                ),
                const SizedBox(width: AppDim.paddingSmall),
                Text(
                  isEditMode ? 'Edit Challenge' : 'Create New Challenge',
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
                      // Name field
                      TextFormField(
                        controller: _nameController,
                        decoration: InputDecoration(
                          labelText: 'Name *',
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
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Name is required';
                          }
                          if (value.trim().length > 100) {
                            return 'Name cannot exceed 100 characters';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: AppDim.paddingMedium),

                      // Description field
                      TextFormField(
                        controller: _descriptionController,
                        decoration: InputDecoration(
                          labelText: 'Description',
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
                        maxLines: 3,
                        validator: (value) {
                          if (value != null && value.length > 1000) {
                            return 'Description cannot exceed 1000 characters';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: AppDim.paddingMedium),

                      // Difficulty dropdown
                      Builder(
                        builder: (context) {
                          // Defensive check: ensure value is in available items
                          final validValue = _selectedDifficulty != null && _difficulties.contains(_selectedDifficulty)
                              ? _selectedDifficulty
                              : _difficulties.first;
                          return DropdownButtonFormField<String>(
                            value: validValue,
                        decoration: InputDecoration(
                          labelText: 'Difficulty *',
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
                            items: _difficulties.map((difficulty) {
                              return DropdownMenuItem<String>(
                                value: difficulty,
                                child: Row(
                                  children: [
                                    Container(
                                      width: 12,
                                      height: 12,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: _getDifficultyColor(difficulty),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(difficulty),
                                  ],
                                ),
                              );
                            }).toList(),
                            onChanged: (value) {
                              if (value != null && _difficulties.contains(value)) {
                                setState(() {
                                  _selectedDifficulty = value;
                                });
                              }
                            },
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Difficulty is required';
                              }
                              if (!_difficulties.contains(value)) {
                                return 'Invalid difficulty selected';
                              }
                              return null;
                            },
                          );
                        },
                      ),
                      const SizedBox(height: AppDim.paddingMedium),

                      // Target Count field with default value
                      TextFormField(
                        controller: _targetCountController,
                        decoration: InputDecoration(
                          labelText: 'Target Count *',
                          hintText: '10', // Default suggestion
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
                        keyboardType: TextInputType.number,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Target count is required';
                          }
                          final count = int.tryParse(value);
                          if (count == null) {
                            return 'Please enter a valid number';
                          }
                          if (count < 1) {
                            return 'Target count must be at least 1';
                          }
                          return null;
                        },
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
                  onPressed: _isLoading ? null : _saveChallenge,
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

