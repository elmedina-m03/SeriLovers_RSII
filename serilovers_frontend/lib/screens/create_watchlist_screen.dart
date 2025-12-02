import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/scheduler.dart';

import '../providers/watchlist_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/series_provider.dart';
import '../core/theme/app_colors.dart';
import '../utils/file_picker_helper.dart';
import '../services/api_service.dart';

class CreateWatchlistScreen extends StatefulWidget {
  const CreateWatchlistScreen({super.key});

  @override
  State<CreateWatchlistScreen> createState() => _CreateWatchlistScreenState();
}

class _CreateWatchlistScreenState extends State<CreateWatchlistScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _coverUrlController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  bool _submitting = false;
  bool _isUploadingImage = false;
  String? _selectedCategory;
  String? _selectedStatus;
  String? _uploadedImageUrl;
  List<String> _selectedGenres = [];

  @override
  void initState() {
    super.initState();
    // Load genres when screen opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final seriesProvider = Provider.of<SeriesProvider>(context, listen: false);
      if (seriesProvider.genres.isEmpty) {
        seriesProvider.fetchGenres();
      }
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _coverUrlController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _submitting = true;
    });

    final provider = Provider.of<WatchlistProvider>(context, listen: false);
    final name = _nameController.text.trim();
    // Use uploaded image URL if available, otherwise use URL from text field
    final coverUrl = _uploadedImageUrl ?? 
        (_coverUrlController.text.trim().isEmpty ? null : _coverUrlController.text.trim());
    final description = _notesController.text.trim().isEmpty 
        ? null 
        : _notesController.text.trim();
    final category = _selectedCategory;
    final status = _selectedStatus;

    try {
      await provider.createList(
        name,
        coverUrl: coverUrl,
        description: description,
        category: category,
        status: status,
      );

      if (!mounted) return;

      // Refresh the lists in MyListsScreen
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final token = auth.token;
      if (token != null && token.isNotEmpty) {
        try {
          final decoded = JwtDecoder.decode(token);
          final rawId = decoded['userId'] ?? decoded['id'] ?? decoded['nameid'] ?? decoded['sub'];
          int? userId;
          if (rawId is int) {
            userId = rawId;
          } else if (rawId is String) {
            userId = int.tryParse(rawId);
          }
          if (userId != null) {
            await provider.loadUserWatchlists(userId);
          }
        } catch (_) {
          // Silently fail - list was created anyway
        }
      }

      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('List "${name}" created successfully!'),
          backgroundColor: AppColors.successColor,
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to create list: ${e.toString()}'),
          backgroundColor: AppColors.dangerColor,
          duration: const Duration(seconds: 3),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _submitting = false;
        });
      }
    }
  }

  /// Pick and upload image file
  Future<void> _pickAndUploadImage() async {
    try {
      final result = await FilePickerHelper.pickImage();
      if (result == null) return; // User cancelled

      setState(() {
        _isUploadingImage = true;
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
          folder: 'watchlists',
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
          folder: 'watchlists',
          token: token,
        );
      }

      if (uploadResponse != null && uploadResponse['imageUrl'] != null) {
        setState(() {
          _uploadedImageUrl = uploadResponse['imageUrl'] as String;
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
        throw Exception('Invalid response from server');
      }
    } catch (e) {
      setState(() {
        _isUploadingImage = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to upload image: ${e.toString()}'),
            backgroundColor: AppColors.dangerColor,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Create a new list',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Cover photo section
              Text(
                'Cover photo',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              // Cover image preview/upload
              GestureDetector(
                onTap: _isUploadingImage ? null : _pickAndUploadImage,
                child: Container(
                  width: double.infinity,
                  height: 120,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.grey[300]!,
                      width: 2,
                      style: BorderStyle.solid,
                    ),
                    color: Colors.grey[100],
                  ),
                  child: _isUploadingImage
                      ? const Center(
                          child: CircularProgressIndicator(),
                        )
                      : (_uploadedImageUrl != null || _coverUrlController.text.isNotEmpty)
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.network(
                                _uploadedImageUrl ?? _coverUrlController.text,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return Container(
                                    color: Colors.grey[200],
                                    child: const Center(
                                      child: Icon(Icons.broken_image, size: 48, color: Colors.grey),
                                    ),
                                  );
                                },
                              ),
                            )
                          : Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.image_outlined,
                                  size: 48,
                                  color: Colors.grey[600],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Tap to upload cover photo',
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                ),
              ),
              const SizedBox(height: 8),
              // Or enter URL option
              TextFormField(
                controller: _coverUrlController,
                decoration: InputDecoration(
                  labelText: 'Or enter image URL (optional)',
                  hintText: 'Enter image URL',
                  prefixIcon: const Icon(Icons.link),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: AppColors.primaryColor,
                      width: 2,
                    ),
                  ),
                ),
                onChanged: (value) {
                  setState(() {}); // Refresh to show/hide preview
                },
                keyboardType: TextInputType.url,
              ),
              const SizedBox(height: 24),
              // List Name
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'List Name',
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: AppColors.primaryColor,
                      width: 2,
                    ),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Name is required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              // Genres section (multiple selection)
              Text(
                'Genres (select multiple)',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Consumer<SeriesProvider>(
                builder: (context, seriesProvider, child) {
                  if (seriesProvider.isGenresLoading) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(16.0),
                        child: CircularProgressIndicator(),
                      ),
                    );
                  }

                  final genres = seriesProvider.genres;
                  if (genres.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text(
                        'No genres available',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 14,
                        ),
                      ),
                    );
                  }

                  return Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: genres.map((genre) {
                      final isSelected = _selectedGenres.contains(genre.name.toUpperCase());
                      return FilterChip(
                        label: Text(genre.name.toUpperCase()),
                        selected: isSelected,
                        onSelected: (selected) {
                          setState(() {
                            if (selected) {
                              _selectedGenres.add(genre.name.toUpperCase());
                            } else {
                              _selectedGenres.remove(genre.name.toUpperCase());
                            }
                          });
                        },
                        selectedColor: AppColors.primaryColor,
                        checkmarkColor: AppColors.textLight,
                        labelStyle: TextStyle(
                          color: isSelected ? AppColors.textLight : AppColors.textPrimary,
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                        ),
                      );
                    }).toList(),
                  );
                },
              ),
              // Keep old Category field for backward compatibility (optional)
              const SizedBox(height: 24),
              Text(
                'Category (optional)',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: ['ROMANCE', 'DRAMA', 'ACTION', 'COMEDY', 'CRIME', 'HISTORICAL', 'FANTASY']
                    .map((category) {
                  final isSelected = _selectedCategory == category;
                  return FilterChip(
                    label: Text(category),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() {
                        _selectedCategory = selected ? category : null;
                      });
                    },
                    selectedColor: AppColors.primaryColor,
                    checkmarkColor: AppColors.textLight,
                    labelStyle: TextStyle(
                      color: isSelected ? AppColors.textLight : AppColors.textPrimary,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),
              // Status section
              Text(
                'Status',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: ['TO WATCH', 'IN PROGRESS', 'FINISHED'].map((status) {
                  final isSelected = _selectedStatus == status;
                  return FilterChip(
                    label: Text(status),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() {
                        _selectedStatus = selected ? status : null;
                      });
                    },
                    selectedColor: AppColors.primaryColor,
                    checkmarkColor: AppColors.textLight,
                    labelStyle: TextStyle(
                      color: isSelected ? AppColors.textLight : AppColors.textPrimary,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),
              // Notes section
              Text(
                'Notes',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _notesController,
                maxLines: 4,
                decoration: InputDecoration(
                  hintText: 'Add a short description',
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: AppColors.primaryColor,
                      width: 2,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 32),
              // Submit button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _submitting ? null : _handleSubmit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryColor,
                    foregroundColor: AppColors.textLight,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 2,
                  ),
                  child: _submitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              AppColors.textLight,
                            ),
                          ),
                        )
                      : const Text(
                          'Apply filters',
                          style: TextStyle(
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
    );
  }
}


