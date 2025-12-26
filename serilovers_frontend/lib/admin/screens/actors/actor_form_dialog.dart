import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dim.dart';
import '../../../models/series.dart';
import '../../../services/api_service.dart';
import '../../../providers/auth_provider.dart';
import '../../../utils/file_picker_helper.dart';
import '../../providers/admin_actor_provider.dart';
import '../../../core/widgets/image_with_placeholder.dart';

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

  String? _uploadedImageUrl; // Store uploaded image URL
  bool _isUploadingImage = false;
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
      _uploadedImageUrl = actor.imageUrl;
    }
  }

  /// Format date for display
  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  /// Pick and upload image file
  Future<void> _pickAndUploadImage() async {
    try {
      print('📸 Starting image pick...');
      final result = await FilePickerHelper.pickImage();
      if (result == null) {
        print('❌ User cancelled file picker');
        return; // User cancelled
      }

      print('✅ File picked successfully');
      setState(() {
        _isUploadingImage = true;
      });

      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final apiService = ApiService();
      final token = authProvider.token;

      if (token == null || token.isEmpty) {
        throw Exception('Authentication required. Please log in again.');
      }

      print('🔐 Token available, starting upload...');
      dynamic uploadResponse;

      if (FilePickerHelper.isWeb) {
        // Web: use bytes
        final bytes = FilePickerHelper.getBytes(result);
        final fileName = FilePickerHelper.getFileName(result);
        print('🌐 Web platform - bytes: ${bytes?.length ?? 0}, fileName: $fileName');
        if (bytes == null || fileName == null) {
          throw Exception('Failed to read file. Please try again.');
        }
        uploadResponse = await apiService.uploadFileFromBytes(
          '/ImageUpload/upload',
          bytes,
          fileName,
          folder: 'actors',
          token: token,
        );
      } else {
        // Desktop/Mobile: use File
        final file = FilePickerHelper.getFile(result);
        print('💻 Desktop/Mobile platform - file: ${file?.path ?? "null"}');
        if (file == null) {
          throw Exception('Failed to read file. Please try selecting the file again.');
        }
        
        // Check if file exists and is readable
        if (!await file.exists()) {
          throw Exception('Selected file does not exist. Please try again.');
        }
        
        final fileSize = await file.length();
        print('📁 File size: $fileSize bytes');
        
        uploadResponse = await apiService.uploadFile(
          '/ImageUpload/upload',
          file,
          folder: 'actors',
          token: token,
        );
      }

      print('📥 Upload response: $uploadResponse');
      
      if (uploadResponse != null && uploadResponse['imageUrl'] != null) {
        final imageUrl = uploadResponse['imageUrl'] as String;
        print('✅ Image uploaded successfully: $imageUrl');
        setState(() {
          _uploadedImageUrl = imageUrl;
          _isUploadingImage = false;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Image uploaded successfully'),
              backgroundColor: AppColors.successColor,
            ),
          );
        }
      } else {
        print('❌ Invalid response: $uploadResponse');
        throw Exception('Invalid response from server. Response: ${uploadResponse?.toString() ?? "null"}');
      }
    } catch (e) {
      print('❌ Error uploading image: $e');
      print('   Error type: ${e.runtimeType}');
      if (e is Exception) {
        print('   Exception message: ${e.toString()}');
      }
      if (mounted) {
        setState(() {
          _isUploadingImage = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error uploading image: ${e.toString()}'),
            backgroundColor: AppColors.dangerColor,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
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
        'imageUrl': _uploadedImageUrl,
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
                      const SizedBox(height: AppDim.paddingMedium),

                      // Image upload field
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.photo_camera,
                                color: AppColors.primaryColor,
                                size: 20,
                              ),
                              const SizedBox(width: AppDim.paddingSmall),
                              Text(
                                'Actor Photo',
                                style: TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppDim.paddingMedium),
                          // Image preview or placeholder
                          if (_uploadedImageUrl != null || widget.actor?.imageUrl != null) ...[
                            Container(
                              height: 150,
                              width: double.infinity,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(AppDim.radiusSmall),
                                border: Border.all(
                                  color: AppColors.primaryColor.withOpacity(0.3),
                                  width: 2,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.primaryColor.withOpacity(0.1),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(AppDim.radiusSmall),
                                child: Stack(
                                  children: [
                                    ImageWithPlaceholder(
                                      imageUrl: _uploadedImageUrl ?? widget.actor?.imageUrl,
                                      height: 150,
                                      width: double.infinity,
                                      fit: BoxFit.cover,
                                      borderRadius: AppDim.radiusSmall,
                                      placeholderIcon: Icons.person,
                                    ),
                                    // Remove button overlay
                                    Positioned(
                                      top: 8,
                                      right: 8,
                                      child: Material(
                                        color: Colors.black.withOpacity(0.5),
                                        borderRadius: BorderRadius.circular(20),
                                        child: IconButton(
                                          onPressed: () {
                                            setState(() {
                                              _uploadedImageUrl = null;
                                            });
                                          },
                                          icon: const Icon(
                                            Icons.close,
                                            color: Colors.white,
                                            size: 20,
                                          ),
                                          tooltip: 'Remove image',
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(
                                            minWidth: 32,
                                            minHeight: 32,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: AppDim.paddingSmall),
                            if (widget.actor?.imageUrl != null && _uploadedImageUrl == null) ...[
                              Text(
                                'Current photo (click "Upload New Photo" to change)',
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 12,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ] else if (_uploadedImageUrl != null) ...[
                              Row(
                                children: [
                                  Icon(
                                    Icons.check_circle,
                                    color: AppColors.successColor,
                                    size: 16,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'New photo uploaded (click "Update" to save)',
                                    style: TextStyle(
                                      color: AppColors.successColor,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                            const SizedBox(height: AppDim.paddingMedium),
                          ] else ...[
                            // No image - show upload prompt
                            Container(
                              height: 150,
                              width: double.infinity,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(AppDim.radiusSmall),
                                border: Border.all(
                                  color: AppColors.textSecondary.withOpacity(0.3),
                                  width: 2,
                                  style: BorderStyle.solid,
                                ),
                                color: AppColors.cardBackground,
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.add_photo_alternate,
                                    size: 48,
                                    color: AppColors.textSecondary.withOpacity(0.5),
                                  ),
                                  const SizedBox(height: AppDim.paddingSmall),
                                  Text(
                                    'No photo uploaded',
                                    style: TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: AppDim.paddingMedium),
                          ],
                          // Upload button
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _isUploadingImage ? null : _pickAndUploadImage,
                              icon: _isUploadingImage
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                      ),
                                    )
                                  : const Icon(Icons.cloud_upload, size: 22),
                              label: Text(
                                _isUploadingImage 
                                    ? 'Uploading Photo...' 
                                    : (_uploadedImageUrl != null || widget.actor?.imageUrl != null)
                                        ? 'Upload New Photo'
                                        : 'Upload Photo',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primaryColor,
                                foregroundColor: AppColors.textLight,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: AppDim.paddingLarge,
                                  vertical: AppDim.paddingMedium,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(AppDim.radiusSmall),
                                ),
                                elevation: 2,
                              ),
                            ),
                          ),
                          if (_uploadedImageUrl != null || widget.actor?.imageUrl != null) ...[
                            const SizedBox(height: AppDim.paddingSmall),
                            Container(
                              height: 100,
                              width: double.infinity,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(AppDim.radiusSmall),
                                border: Border.all(color: AppColors.textSecondary.withOpacity(0.3)),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(AppDim.radiusSmall),
                                child: ImageWithPlaceholder(
                                  imageUrl: _uploadedImageUrl ?? widget.actor?.imageUrl,
                                  height: 100,
                                  width: double.infinity,
                                  fit: BoxFit.cover,
                                  borderRadius: AppDim.radiusSmall,
                                  placeholderIcon: Icons.person,
                                ),
                              ),
                            ),
                            if (widget.actor?.imageUrl != null && _uploadedImageUrl == null) ...[
                              const SizedBox(height: AppDim.paddingSmall),
                              Text(
                                'Current image (click "Choose Image" to change)',
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 12,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ] else if (_uploadedImageUrl != null) ...[
                              const SizedBox(height: AppDim.paddingSmall),
                              Text(
                                'New image uploaded (click "Update" to save)',
                                style: TextStyle(
                                  color: AppColors.successColor,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ],
                        ],
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

