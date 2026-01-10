import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/language_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dim.dart';

/// Mobile settings screen with Password change functionality
class MobileSettingsScreen extends StatefulWidget {
  const MobileSettingsScreen({super.key});

  @override
  State<MobileSettingsScreen> createState() => _MobileSettingsScreenState();
}

class _MobileSettingsScreenState extends State<MobileSettingsScreen> {
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _obscureCurrentPassword = true;
  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;
  bool _isChangingPassword = false;

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  String? _validatePassword(String? value, {required bool isRequired, required LanguageProvider languageProvider}) {
    if (isRequired && (value == null || value.isEmpty)) {
      return languageProvider.translate('passwordRequired');
    }
    if (value != null && value.isNotEmpty && value.length < 8) {
      return languageProvider.translate('passwordMinLength');
    }
    return null;
  }

  String? _validateConfirmPassword(String? value, LanguageProvider languageProvider) {
    if (_newPasswordController.text.isNotEmpty) {
      if (value == null || value.isEmpty) {
        return languageProvider.translate('confirmPasswordRequired');
      }
      if (value != _newPasswordController.text) {
        return languageProvider.translate('passwordsDoNotMatch');
      }
    }
    return null;
  }

  Future<void> _handlePasswordChange() async {
    // Obtain LanguageProvider here so we can use translations in snackbars
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_newPasswordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(languageProvider.translate('newPasswordMissing')),
          backgroundColor: AppColors.dangerColor,
        ),
      );
      return;
    }

    if (_currentPasswordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(languageProvider.translate('currentPasswordMissing')),
          backgroundColor: AppColors.dangerColor,
        ),
      );
      return;
    }

    setState(() {
      _isChangingPassword = true;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      
      final updateData = <String, dynamic>{
        'currentPassword': _currentPasswordController.text,
        'newPassword': _newPasswordController.text,
      };

      final success = await authProvider.updateUser(updateData);

      if (!mounted) return;

      if (success) {
        // Clear password fields
        _currentPasswordController.clear();
        _newPasswordController.clear();
        _confirmPasswordController.clear();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(languageProvider.translate('passwordChangedSuccess')),
            backgroundColor: AppColors.successColor,
            duration: const Duration(seconds: 2),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(languageProvider.translate('passwordChangedFailed')),
            backgroundColor: AppColors.dangerColor,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${languageProvider.translate('passwordChangedError')}: $e'),
          backgroundColor: AppColors.dangerColor,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isChangingPassword = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final languageProvider = Provider.of<LanguageProvider>(context);

    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      appBar: AppBar(
        title: Text(languageProvider.translate('settings')),
        backgroundColor: AppColors.primaryColor,
        foregroundColor: AppColors.textLight,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppDim.paddingLarge),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [

              // Password Change Section
              _buildSectionHeader(theme, languageProvider.translate('passwordChange')),
              const SizedBox(height: AppDim.paddingSmall),
              Card(
                color: AppColors.cardBackground,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppDim.radiusMedium),
                ),
                child: Form(
                  key: _formKey,
                  child: Padding(
                    padding: const EdgeInsets.all(AppDim.paddingMedium),
                    child: Column(
                      children: [
                        // Current Password
                        TextFormField(
                          controller: _currentPasswordController,
                          decoration: InputDecoration(
                            labelText: languageProvider.translate('currentPassword'),
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
                            fillColor: AppColors.backgroundColor,
                          ),
                          style: TextStyle(color: AppColors.textPrimary),
                          obscureText: _obscureCurrentPassword,
                          validator: (value) => _validatePassword(
                            value,
                            isRequired: _newPasswordController.text.isNotEmpty,
                            languageProvider: languageProvider,
                          ),
                        ),

                        const SizedBox(height: AppDim.paddingMedium),

                        // New Password
                        TextFormField(
                          controller: _newPasswordController,
                          decoration: InputDecoration(
                            labelText: languageProvider.translate('newPassword'),
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
                            fillColor: AppColors.backgroundColor,
                          ),
                          style: TextStyle(color: AppColors.textPrimary),
                          obscureText: _obscureNewPassword,
                          validator: (value) => _validatePassword(
                            value,
                            isRequired: false,
                            languageProvider: languageProvider,
                          ),
                        ),

                        const SizedBox(height: AppDim.paddingMedium),

                        // Confirm Password
                        TextFormField(
                          controller: _confirmPasswordController,
                          decoration: InputDecoration(
                            labelText: languageProvider.translate('confirmPassword'),
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
                            fillColor: AppColors.backgroundColor,
                          ),
                          style: TextStyle(color: AppColors.textPrimary),
                          obscureText: _obscureConfirmPassword,
                          validator: (value) => _validateConfirmPassword(
                            value,
                            languageProvider,
                          ),
                        ),

                        const SizedBox(height: AppDim.paddingMedium),

                        // Change Password Button
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _isChangingPassword ? null : _handlePasswordChange,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primaryColor,
                              foregroundColor: AppColors.textLight,
                              padding: const EdgeInsets.symmetric(
                                vertical: AppDim.paddingMedium,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(AppDim.radiusMedium),
                              ),
                            ),
                            child: _isChangingPassword
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(AppColors.textLight),
                                    ),
                                  )
                                : Text(
                                    languageProvider.translate('changePassword'),
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(ThemeData theme, String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppDim.paddingSmall),
      child: Text(
        title,
        style: theme.textTheme.titleLarge?.copyWith(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

