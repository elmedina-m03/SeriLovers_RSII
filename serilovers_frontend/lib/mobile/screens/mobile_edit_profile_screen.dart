import 'dart:typed_data';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import '../../providers/auth_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dim.dart';
import '../../services/api_service.dart';
import '../../utils/file_picker_helper.dart';

/// Mobile edit profile screen with name, email, password, and avatar upload
class MobileEditProfileScreen extends StatefulWidget {
  const MobileEditProfileScreen({super.key});

  @override
  State<MobileEditProfileScreen> createState() => _MobileEditProfileScreenState();
}

class _MobileEditProfileScreenState extends State<MobileEditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();

  bool _isLoading = false;
  String? _uploadedAvatarUrl; // Store uploaded avatar URL
  bool _isUploadingAvatar = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  void _loadUserData() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    
    // Prefer currentUser (fresh from backend), fallback to token
    Map<String, String?> userInfo;
    final current = authProvider.currentUser;
    if (current != null) {
      userInfo = {
        'email': current['email'] as String? ?? '',
        'name': current['name'] as String? ?? '',
        'avatarUrl': current['avatarUrl'] as String?,
      };
    } else {
      userInfo = _getUserInfo(authProvider.token);
    }
    
    _nameController.text = userInfo['name'] ?? '';
    _emailController.text = userInfo['email'] ?? '';
    
    // Load existing avatar URL if available
    final avatarUrl = userInfo['avatarUrl'];
    if (avatarUrl != null && avatarUrl.isNotEmpty) {
      _uploadedAvatarUrl = avatarUrl;
    }
  }

  Map<String, String?> _getUserInfo(String? token) {
    if (token == null || token.isEmpty) {
      return {'email': '', 'name': '', 'avatarUrl': null};
    }

    try {
      final decodedToken = JwtDecoder.decode(token);
      final email = decodedToken['email'] as String? ?? 
                   decodedToken['sub'] as String? ?? 
                   '';
      
      // Try to get name from token claim, otherwise extract from email
      String name = decodedToken['name'] as String? ?? '';
      if (name.isEmpty && email.isNotEmpty) {
        final parts = email.split('@');
        if (parts.isNotEmpty) {
          final namePart = parts[0];
          name = namePart[0].toUpperCase() + namePart.substring(1);
        }
      }
      
      final avatarUrl = decodedToken['avatarUrl'] as String?;
      
      return {'email': email, 'name': name, 'avatarUrl': avatarUrl};
    } catch (e) {
      return {'email': '', 'name': '', 'avatarUrl': null};
    }
  }

  /// Constructs the full image URL, removing /api from base URL for static files
  String _getImageUrl(String imageUrl) {
    // Use ApiService helper to convert file:// URLs and relative paths to HTTP URLs
    return ApiService.convertToHttpUrl(imageUrl) ?? imageUrl;
  }

  Future<void> _pickAvatar() async {
    try {
      final result = await FilePickerHelper.pickImage();
      if (result == null) {
        return; // User cancelled
      }
      setState(() {
        _isUploadingAvatar = true;
      });

      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final apiService = ApiService();
      final token = authProvider.token;

      if (token == null || token.isEmpty) {
        throw Exception('Authentication required. Please log in again.');
      }

      dynamic uploadResponse;

      if (FilePickerHelper.isWeb) {
        // Web: use bytes
        final bytes = FilePickerHelper.getBytes(result);
        final fileName = FilePickerHelper.getFileName(result);
        if (bytes == null || fileName == null) {
          throw Exception('Failed to read file. Please try again.');
        }
        uploadResponse = await apiService.uploadFileFromBytes(
          '/ImageUpload/upload',
          bytes,
          fileName,
          folder: 'avatars',
          token: token,
        );
      } else {
        // Desktop/Mobile: use File
        final file = FilePickerHelper.getFile(result);
        if (file == null) {
          throw Exception('Failed to read file. Please try selecting the file again.');
        }
        
        // Check if file exists and is readable
        if (!await file.exists()) {
          throw Exception('Selected file does not exist. Please try again.');
        }
        
        uploadResponse = await apiService.uploadFile(
          '/ImageUpload/upload',
          file,
          folder: 'avatars',
          token: token,
        );
      }

      if (uploadResponse != null && uploadResponse['imageUrl'] != null) {
        final imageUrl = uploadResponse['imageUrl'] as String;
        
        // Immediately update user profile with new avatar URL
        try {
          final updateSuccess = await authProvider.updateUser({
            'avatarUrl': imageUrl,
          });
          
          if (updateSuccess) {
            // Update local state - updateUser already updates token and notifies listeners
            setState(() {
              _uploadedAvatarUrl = imageUrl;
              _isUploadingAvatar = false;
            });
            
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Avatar uploaded successfully'),
                  backgroundColor: AppColors.successColor,
                ),
              );
            }
          } else {
            throw Exception('Failed to update user profile with new avatar');
          }
        } catch (e) {
          setState(() {
            _isUploadingAvatar = false;
          });
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Avatar uploaded but failed to update profile: $e'),
                backgroundColor: AppColors.dangerColor,
              ),
            );
          }
        }
      } else {
        throw Exception('Invalid response from server. Response: ${uploadResponse?.toString() ?? "null"}');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isUploadingAvatar = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error uploading avatar: ${e.toString()}'),
            backgroundColor: AppColors.dangerColor,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  String? _validateName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Name is required';
    }
    if (value.trim().length < 2) {
      return 'Name must be at least 2 characters';
    }
    return null;
  }

  String? _validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Email is required';
    }
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(value.trim())) {
      return 'Please enter a valid email address';
    }
    return null;
  }


  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }


    setState(() {
      _isLoading = true;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      
      // Prepare update data
      final updateData = <String, dynamic>{
        'name': _nameController.text.trim(),
        'email': _emailController.text.trim(),
      };

      // Add avatar URL if uploaded
      if (_uploadedAvatarUrl != null) {
        updateData['avatarUrl'] = _uploadedAvatarUrl;
      }

      final success = await authProvider.updateUser(updateData);

      if (!mounted) return;

      if (success) {
        // updateUser already updates token and notifies listeners
        // Reload user data from AuthProvider to show updated values
        _loadUserData();
        
        // Force UI update
        setState(() {});
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile updated successfully'),
            backgroundColor: AppColors.successColor,
            duration: Duration(seconds: 2),
          ),
        );

        // Navigate back and refresh profile screen
        Navigator.of(context).pop(true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to update profile'),
            backgroundColor: AppColors.dangerColor,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating profile: $e'),
          backgroundColor: AppColors.dangerColor,
        ),
      );
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
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      appBar: AppBar(
        title: const Text('Edit Profile'),
        backgroundColor: AppColors.primaryColor,
        foregroundColor: AppColors.textLight,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppDim.paddingLarge),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [

                // Avatar Section
                Center(
                  child: Column(
                    children: [
                      Stack(
                        children: [
                          _uploadedAvatarUrl != null
                              ? CircleAvatar(
                                  key: ValueKey(_uploadedAvatarUrl), // Force rebuild on URL change
                                  radius: 60,
                                  backgroundColor: AppColors.primaryColor,
                                  backgroundImage: NetworkImage(
                                    '${_getImageUrl(_uploadedAvatarUrl!)}?v=${_uploadedAvatarUrl.hashCode}',
                                  ), // Cache-busting parameter based on URL hash
                                  onBackgroundImageError: (exception, stackTrace) {
                                    // Handle image load error - show placeholder
                                    setState(() {
                                      _uploadedAvatarUrl = null;
                                    });
                                  },
                                )
                              : CircleAvatar(
                                  radius: 60,
                                  backgroundColor: AppColors.primaryColor,
                                  child: Text(
                                    _nameController.text.isNotEmpty
                                        ? _nameController.text[0].toUpperCase()
                                        : 'U',
                                    style: const TextStyle(
                                      color: AppColors.textLight,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 36,
                                    ),
                                  ),
                                ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: CircleAvatar(
                              radius: 18,
                              backgroundColor: AppColors.primaryColor,
                              child: IconButton(
                                icon: _isUploadingAvatar
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor: AlwaysStoppedAnimation<Color>(AppColors.textLight),
                                        ),
                                      )
                                    : const Icon(
                                        Icons.camera_alt,
                                        size: 18,
                                        color: AppColors.textLight,
                                      ),
                                onPressed: _isUploadingAvatar ? null : _pickAvatar,
                                padding: EdgeInsets.zero,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppDim.paddingSmall),
                      TextButton(
                        onPressed: _isUploadingAvatar ? null : _pickAvatar,
                        child: Text(
                          _isUploadingAvatar
                              ? 'Uploading...'
                              : _uploadedAvatarUrl != null
                                  ? 'Change Avatar'
                                  : 'Upload Avatar',
                          style: TextStyle(color: AppColors.primaryColor),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: AppDim.paddingLarge),

                // Name Field
                TextFormField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    labelText: 'Name',
                    labelStyle: TextStyle(color: AppColors.textSecondary),
                    prefixIcon: Icon(Icons.person, color: AppColors.textSecondary),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppDim.radiusMedium),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppDim.radiusMedium),
                      borderSide: BorderSide(color: AppColors.primaryColor, width: 2),
                    ),
                    filled: true,
                    fillColor: AppColors.cardBackground,
                  ),
                  style: TextStyle(color: AppColors.textPrimary),
                  validator: _validateName,
                ),

                const SizedBox(height: AppDim.paddingMedium),

                // Email Field
                TextFormField(
                  controller: _emailController,
                  decoration: InputDecoration(
                    labelText: 'Email',
                    labelStyle: TextStyle(color: AppColors.textSecondary),
                    prefixIcon: Icon(Icons.email, color: AppColors.textSecondary),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppDim.radiusMedium),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppDim.radiusMedium),
                      borderSide: BorderSide(color: AppColors.primaryColor, width: 2),
                    ),
                    filled: true,
                    fillColor: AppColors.cardBackground,
                  ),
                  style: TextStyle(color: AppColors.textPrimary),
                  keyboardType: TextInputType.emailAddress,
                  validator: _validateEmail,
                ),

                const SizedBox(height: AppDim.paddingLarge),

                // Save Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _handleSave,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryColor,
                      foregroundColor: AppColors.textLight,
                      padding: const EdgeInsets.symmetric(
                        vertical: AppDim.paddingMedium,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppDim.radiusMedium),
                      ),
                      elevation: 4,
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(AppColors.textLight),
                            ),
                          )
                        : const Text(
                            'Save Changes',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),

                const SizedBox(height: AppDim.paddingMedium),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

