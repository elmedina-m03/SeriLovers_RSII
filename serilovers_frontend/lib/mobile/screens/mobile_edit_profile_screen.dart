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
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isLoading = false;
  bool _obscureCurrentPassword = true;
  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;
  String? _uploadedAvatarUrl; // Store uploaded avatar URL
  bool _isUploadingAvatar = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  void _loadUserData() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final userInfo = _getUserInfo(authProvider.token);
    
    _nameController.text = userInfo['name'] ?? '';
    _emailController.text = userInfo['email'] ?? '';
  }

  Map<String, String> _getUserInfo(String? token) {
    if (token == null || token.isEmpty) {
      return {'email': '', 'name': ''};
    }

    try {
      final decodedToken = JwtDecoder.decode(token);
      final email = decodedToken['email'] as String? ?? 
                   decodedToken['sub'] as String? ?? 
                   '';
      
      String name = '';
      if (email.isNotEmpty) {
        final parts = email.split('@');
        if (parts.isNotEmpty) {
          final namePart = parts[0];
          name = namePart[0].toUpperCase() + namePart.substring(1);
        }
      }
      
      return {'email': email, 'name': name};
    } catch (e) {
      return {'email': '', 'name': ''};
    }
  }

  /// Constructs the full image URL, removing /api from base URL for static files
  String _getImageUrl(String imageUrl) {
    if (imageUrl.startsWith('http://') || imageUrl.startsWith('https://')) {
      return imageUrl;
    }
    
    var baseUrl = ApiService().baseUrl;
    if (baseUrl.isNotEmpty) {
      // Remove /api from the end of base URL if present (static files are at root, not /api)
      if (baseUrl.endsWith('/api')) {
        baseUrl = baseUrl.substring(0, baseUrl.length - 4);
      } else if (baseUrl.endsWith('/api/')) {
        baseUrl = baseUrl.substring(0, baseUrl.length - 5);
      }
      return '$baseUrl$imageUrl';
    }
    return imageUrl;
  }

  Future<void> _pickAvatar() async {
    try {
      final result = await FilePickerHelper.pickImage();
      if (result == null) return; // User cancelled

      setState(() {
        _isUploadingAvatar = true;
      });

      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final apiService = ApiService();
      final token = authProvider.token;

      if (token == null || token.isEmpty) {
        throw Exception('Authentication required');
      }

      dynamic uploadResponse;

      if (FilePickerHelper.isWeb) {
        // Web: use bytes
        final bytes = FilePickerHelper.getBytes(result);
        final fileName = FilePickerHelper.getFileName(result);
        if (bytes == null || fileName == null) {
          throw Exception('Failed to read file');
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
          throw Exception('Failed to read file');
        }
        uploadResponse = await apiService.uploadFile(
          '/ImageUpload/upload',
          file,
          folder: 'avatars',
          token: token,
        );
      }

      if (uploadResponse != null && uploadResponse['imageUrl'] != null) {
        setState(() {
          _uploadedAvatarUrl = uploadResponse['imageUrl'] as String;
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
        throw Exception('Invalid response from server');
      }
    } catch (e) {
      print('Error uploading avatar: $e');
      if (mounted) {
        setState(() {
          _isUploadingAvatar = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error picking image: $e'),
            backgroundColor: AppColors.dangerColor,
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

  String? _validatePassword(String? value, {required bool isRequired}) {
    if (isRequired && (value == null || value.isEmpty)) {
      return 'Password is required';
    }
    if (value != null && value.isNotEmpty && value.length < 8) {
      return 'Password must be at least 8 characters';
    }
    return null;
  }

  String? _validateConfirmPassword(String? value) {
    if (_newPasswordController.text.isNotEmpty) {
      if (value == null || value.isEmpty) {
        return 'Please confirm your new password';
      }
      if (value != _newPasswordController.text) {
        return 'Passwords do not match';
      }
    }
    return null;
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Validate password change if new password is provided
    if (_newPasswordController.text.isNotEmpty) {
      if (_currentPasswordController.text.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Current password is required to change password'),
            backgroundColor: AppColors.dangerColor,
          ),
        );
        return;
      }
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

      // Add password change if provided
      if (_newPasswordController.text.isNotEmpty) {
        updateData['currentPassword'] = _currentPasswordController.text;
        updateData['newPassword'] = _newPasswordController.text;
      }

      // Add avatar URL if uploaded
      if (_uploadedAvatarUrl != null) {
        updateData['avatarUrl'] = _uploadedAvatarUrl;
      }

      await authProvider.updateUser(updateData);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile updated successfully'),
          backgroundColor: AppColors.successColor,
        ),
      );

      // Navigate back
      Navigator.of(context).pop(true);
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
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
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
              children: [
                const SizedBox(height: AppDim.paddingMedium),

                // Avatar Section
                Center(
                  child: Column(
                    children: [
                      Stack(
                        children: [
                          CircleAvatar(
                            radius: 60,
                            backgroundColor: AppColors.primaryColor,
                            backgroundImage: _uploadedAvatarUrl != null
                                ? NetworkImage(_getImageUrl(_uploadedAvatarUrl!))
                                : null,
                            child: _uploadedAvatarUrl == null
                                ? Text(
                                    _nameController.text.isNotEmpty
                                        ? _nameController.text[0].toUpperCase()
                                        : 'U',
                                    style: const TextStyle(
                                      color: AppColors.textLight,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 36,
                                    ),
                                  )
                                : null,
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

                const SizedBox(height: AppDim.paddingLarge * 2),

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

                // Password Change Section
                Text(
                  'Change Password (Optional)',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: AppDim.paddingMedium),

                // Current Password Field
                TextFormField(
                  controller: _currentPasswordController,
                  decoration: InputDecoration(
                    labelText: 'Current Password',
                    labelStyle: TextStyle(color: AppColors.textSecondary),
                    prefixIcon: Icon(Icons.lock, color: AppColors.textSecondary),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureCurrentPassword ? Icons.visibility : Icons.visibility_off,
                        color: AppColors.textSecondary,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscureCurrentPassword = !_obscureCurrentPassword;
                        });
                      },
                    ),
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
                  obscureText: _obscureCurrentPassword,
                  validator: (value) => _validatePassword(
                    value,
                    isRequired: _newPasswordController.text.isNotEmpty,
                  ),
                ),

                const SizedBox(height: AppDim.paddingMedium),

                // New Password Field
                TextFormField(
                  controller: _newPasswordController,
                  decoration: InputDecoration(
                    labelText: 'New Password',
                    labelStyle: TextStyle(color: AppColors.textSecondary),
                    prefixIcon: Icon(Icons.lock_outline, color: AppColors.textSecondary),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureNewPassword ? Icons.visibility : Icons.visibility_off,
                        color: AppColors.textSecondary,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscureNewPassword = !_obscureNewPassword;
                        });
                      },
                    ),
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
                  obscureText: _obscureNewPassword,
                  validator: (value) => _validatePassword(value, isRequired: false),
                ),

                const SizedBox(height: AppDim.paddingMedium),

                // Confirm Password Field
                TextFormField(
                  controller: _confirmPasswordController,
                  decoration: InputDecoration(
                    labelText: 'Confirm New Password',
                    labelStyle: TextStyle(color: AppColors.textSecondary),
                    prefixIcon: Icon(Icons.lock_outline, color: AppColors.textSecondary),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureConfirmPassword ? Icons.visibility : Icons.visibility_off,
                        color: AppColors.textSecondary,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscureConfirmPassword = !_obscureConfirmPassword;
                        });
                      },
                    ),
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
                  obscureText: _obscureConfirmPassword,
                  validator: _validateConfirmPassword,
                ),

                const SizedBox(height: AppDim.paddingLarge * 2),

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

                const SizedBox(height: AppDim.paddingLarge),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

