import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dim.dart';
import '../../../models/series.dart';
import '../../../providers/actor_provider.dart';
import '../../../services/api_service.dart';
import '../../../providers/auth_provider.dart';
import '../../providers/admin_series_provider.dart';

/// Dialog for creating or editing a series
/// 
/// Supports two modes:
/// - Create: No initial data provided
/// - Edit: Initial series data provided for editing
class SeriesFormDialog extends StatefulWidget {
  /// The series to edit (null for create mode)
  final Series? series;

  const SeriesFormDialog({
    super.key,
    this.series,
  });

  @override
  State<SeriesFormDialog> createState() => _SeriesFormDialogState();
}

class _SeriesFormDialogState extends State<SeriesFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _ratingController = TextEditingController();
  final _releaseDateController = TextEditingController();

  DateTime? _selectedDate;
  List<int> _selectedGenreIds = []; // Changed to use genre IDs
  List<Actor> _selectedActors = [];
  List<Actor> _availableActors = [];
  List<Genre> _availableGenres = []; // Changed to Genre objects
  bool _isLoading = false;
  bool _isLoadingGenres = false;

  @override
  void initState() {
    super.initState();
    _loadActors();
    _loadGenres();
    _initializeForm();
  }

  /// Initialize form with existing data if in edit mode
  void _initializeForm() {
    if (widget.series != null) {
      final series = widget.series!;
      _titleController.text = series.title;
      _descriptionController.text = series.description ?? '';
      _ratingController.text = series.rating.toString();
      _selectedDate = series.releaseDate;
      _releaseDateController.text = _formatDate(_selectedDate!);
      
      // Set genre IDs from series genres
      // Note: series.genres is List<String>, we need to find matching Genre IDs
      if (series.genres.isNotEmpty && _availableGenres.isNotEmpty) {
        _selectedGenreIds = _availableGenres
            .where((genre) => series.genres.contains(genre.name))
            .map((genre) => genre.id)
            .toList();
      }
      
      // Set selected actors
      _selectedActors = List.from(series.actors);
    }
  }

  /// Load available genres from API
  Future<void> _loadGenres() async {
    setState(() {
      _isLoadingGenres = true;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final apiService = ApiService();
      final token = authProvider.token;

      if (token == null || token.isEmpty) {
        throw Exception('Authentication required');
      }

      final response = await apiService.get('/Genre', token: token);
      
      if (response is List) {
        setState(() {
          _availableGenres = response
              .map((item) => Genre.fromJson(item as Map<String, dynamic>))
              .toList();
        });
        
        // Re-initialize form if editing to set genre IDs
        if (widget.series != null) {
          _initializeForm();
        }
      } else {
        throw Exception('Invalid response format from genre API');
      }
    } catch (e) {
      print('Error loading genres: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading genres: $e'),
            backgroundColor: AppColors.dangerColor,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingGenres = false;
        });
      }
    }
  }

  /// Load available actors from the provider
  Future<void> _loadActors() async {
    try {
      final actorProvider = Provider.of<ActorProvider>(context, listen: false);
      await actorProvider.fetchActors();
      setState(() {
        _availableActors = actorProvider.items;
      });
    } catch (e) {
      print('Error loading actors: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading actors: $e'),
            backgroundColor: AppColors.dangerColor,
          ),
        );
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
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(1900),
      lastDate: DateTime.now().add(const Duration(days: 365 * 10)),
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
        _releaseDateController.text = _formatDate(picked);
      });
    }
  }

  /// Show actor multiselect dialog
  Future<void> _selectActors() async {
    final List<Actor>? result = await showDialog<List<Actor>>(
      context: context,
      builder: (context) => _ActorMultiSelectDialog(
        availableActors: _availableActors,
        selectedActors: _selectedActors,
      ),
    );

    if (result != null) {
      setState(() {
        _selectedActors = result;
      });
    }
  }

  /// Save the series (create or update)
  Future<void> _saveSeries() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a release date'),
          backgroundColor: AppColors.dangerColor,
        ),
      );
      return;
    }

    if (_selectedGenreIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one genre'),
          backgroundColor: AppColors.dangerColor,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final adminSeriesProvider = Provider.of<AdminSeriesProvider>(context, listen: false);

      // Prepare series data with expected property names
      final seriesData = {
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim(),
        'rating': double.parse(_ratingController.text),
        'releaseDate': _selectedDate!.toIso8601String(),
        'genreIds': _selectedGenreIds, // Changed to genreIds
        'actorIds': _selectedActors.map((actor) => actor.id).toList(),
      };

      if (widget.series == null) {
        // Create new series
        await adminSeriesProvider.createSeries(seriesData);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Series created successfully'),
              backgroundColor: AppColors.successColor,
            ),
          );
        }
      } else {
        // Update existing series - ensure correct ID is passed
        final seriesId = widget.series!.id;
        await adminSeriesProvider.updateSeries(seriesId, seriesData);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Series updated successfully'),
              backgroundColor: AppColors.successColor,
            ),
          );
        }
      }

      if (mounted) {
        Navigator.of(context).pop(true); // Return true to indicate success
      }
    } catch (e) {
      print('Error saving series: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving series: $e'),
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
    _titleController.dispose();
    _descriptionController.dispose();
    _ratingController.dispose();
    _releaseDateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isEditMode = widget.series != null;

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
                  isEditMode ? Icons.edit : Icons.add,
                  color: AppColors.primaryColor,
                  size: 24,
                ),
                const SizedBox(width: AppDim.paddingSmall),
                Text(
                  isEditMode ? 'Edit Series' : 'Create New Series',
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
                      // Title field
                      TextFormField(
                        controller: _titleController,
                        decoration: InputDecoration(
                          labelText: 'Title *',
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
                            return 'Title is required';
                          }
                          if (value.trim().length > 200) {
                            return 'Title cannot exceed 200 characters';
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
                          if (value != null && value.length > 2000) {
                            return 'Description cannot exceed 2000 characters';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: AppDim.paddingMedium),

                      // Rating field
                      TextFormField(
                        controller: _ratingController,
                        decoration: InputDecoration(
                          labelText: 'Rating (0-10) *',
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
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                        ],
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Rating is required';
                          }
                          final rating = double.tryParse(value);
                          if (rating == null) {
                            return 'Please enter a valid number';
                          }
                          if (rating < 0 || rating > 10) {
                            return 'Rating must be between 0 and 10';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: AppDim.paddingMedium),

                      // Release date field
                      TextFormField(
                        controller: _releaseDateController,
                        decoration: InputDecoration(
                          labelText: 'Release Date *',
                          labelStyle: TextStyle(color: AppColors.textSecondary),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AppDim.radiusSmall),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AppDim.radiusSmall),
                            borderSide: BorderSide(color: AppColors.primaryColor),
                          ),
                          suffixIcon: Icon(
                            Icons.calendar_today,
                            color: AppColors.primaryColor,
                          ),
                        ),
                        style: TextStyle(color: AppColors.textPrimary),
                        readOnly: true,
                        onTap: _selectDate,
                        validator: (value) {
                          if (_selectedDate == null) {
                            return 'Release date is required';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: AppDim.paddingMedium),

                      // Genre selection with ChoiceChips
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Genres *',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: AppDim.paddingSmall),
                          if (_isLoadingGenres)
                            const Padding(
                              padding: EdgeInsets.all(AppDim.paddingMedium),
                              child: Center(child: CircularProgressIndicator()),
                            )
                          else
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(AppDim.paddingMedium),
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: AppColors.textSecondary.withOpacity(0.3),
                                ),
                                borderRadius: BorderRadius.circular(AppDim.radiusSmall),
                              ),
                              child: Wrap(
                                spacing: 8.0,
                                runSpacing: 4.0,
                                children: _availableGenres.map((genre) {
                                  final isSelected = _selectedGenreIds.contains(genre.id);
                                  return ChoiceChip(
                                    label: Text(
                                      genre.name,
                                      style: TextStyle(
                                        color: isSelected 
                                            ? AppColors.textLight 
                                            : AppColors.textPrimary,
                                        fontSize: 14,
                                      ),
                                    ),
                                    selected: isSelected,
                                    onSelected: (selected) {
                                      setState(() {
                                        if (selected) {
                                          _selectedGenreIds.add(genre.id);
                                        } else {
                                          _selectedGenreIds.remove(genre.id);
                                        }
                                      });
                                    },
                                    selectedColor: AppColors.primaryColor,
                                    backgroundColor: AppColors.cardBackground,
                                    side: BorderSide(
                                      color: isSelected 
                                          ? AppColors.primaryColor 
                                          : AppColors.textSecondary.withOpacity(0.3),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                          if (_selectedGenreIds.isEmpty && !_isLoadingGenres)
                            Padding(
                              padding: const EdgeInsets.only(top: AppDim.paddingSmall),
                              child: Text(
                                'Please select at least one genre',
                                style: TextStyle(
                                  color: AppColors.dangerColor,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: AppDim.paddingMedium),

                      // Actors multiselect
                      InkWell(
                        onTap: _selectActors,
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(AppDim.paddingMedium),
                          decoration: BoxDecoration(
                            border: Border.all(color: AppColors.textSecondary),
                            borderRadius: BorderRadius.circular(AppDim.radiusSmall),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    'Actors',
                                    style: TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 16,
                                    ),
                                  ),
                                  const Spacer(),
                                  Icon(
                                    Icons.arrow_drop_down,
                                    color: AppColors.textSecondary,
                                  ),
                                ],
                              ),
                              const SizedBox(height: AppDim.paddingSmall),
                              if (_selectedActors.isEmpty)
                                Text(
                                  'No actors selected',
                                  style: TextStyle(
                                    color: AppColors.textSecondary,
                                    fontStyle: FontStyle.italic,
                                  ),
                                )
                              else
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 4,
                                  children: _selectedActors.map((actor) {
                                    return Chip(
                                      label: Text(
                                        actor.fullName,
                                        style: TextStyle(
                                          color: AppColors.textPrimary,
                                          fontSize: 12,
                                        ),
                                      ),
                                      backgroundColor: AppColors.primaryColor.withOpacity(0.1),
                                      side: BorderSide(
                                        color: AppColors.primaryColor.withOpacity(0.3),
                                      ),
                                    );
                                  }).toList(),
                                ),
                            ],
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
                  onPressed: _isLoading ? null : _saveSeries,
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

/// Dialog for selecting multiple actors
class _ActorMultiSelectDialog extends StatefulWidget {
  final List<Actor> availableActors;
  final List<Actor> selectedActors;

  const _ActorMultiSelectDialog({
    required this.availableActors,
    required this.selectedActors,
  });

  @override
  State<_ActorMultiSelectDialog> createState() => _ActorMultiSelectDialogState();
}

class _ActorMultiSelectDialogState extends State<_ActorMultiSelectDialog> {
  late List<Actor> _selectedActors;
  final _searchController = TextEditingController();
  List<Actor> _filteredActors = [];

  @override
  void initState() {
    super.initState();
    _selectedActors = List.from(widget.selectedActors);
    _filteredActors = widget.availableActors;
  }

  void _filterActors(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredActors = widget.availableActors;
      } else {
        _filteredActors = widget.availableActors
            .where((actor) =>
                actor.fullName.toLowerCase().contains(query.toLowerCase()))
            .toList();
      }
    });
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
        height: 600,
        padding: const EdgeInsets.all(AppDim.paddingLarge),
        child: Column(
          children: [
            // Header
            Row(
              children: [
                Icon(
                  Icons.people,
                  color: AppColors.primaryColor,
                ),
                const SizedBox(width: AppDim.paddingSmall),
                Text(
                  'Select Actors',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: AppColors.textPrimary,
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
            const SizedBox(height: AppDim.paddingMedium),

            // Search field
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search actors...',
                hintStyle: TextStyle(color: AppColors.textSecondary),
                prefixIcon: Icon(
                  Icons.search,
                  color: AppColors.textSecondary,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppDim.radiusSmall),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppDim.radiusSmall),
                  borderSide: BorderSide(color: AppColors.primaryColor),
                ),
              ),
              style: TextStyle(color: AppColors.textPrimary),
              onChanged: _filterActors,
            ),
            const SizedBox(height: AppDim.paddingMedium),

            // Selected count
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '${_selectedActors.length} actors selected',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 14,
                ),
              ),
            ),
            const SizedBox(height: AppDim.paddingSmall),

            // Actor list
            Expanded(
              child: ListView.builder(
                itemCount: _filteredActors.length,
                itemBuilder: (context, index) {
                  final actor = _filteredActors[index];
                  final isSelected = _selectedActors.contains(actor);

                  return CheckboxListTile(
                    title: Text(
                      actor.fullName,
                      style: TextStyle(color: AppColors.textPrimary),
                    ),
                    subtitle: Text(
                      '${actor.seriesCount} series',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                    value: isSelected,
                    activeColor: AppColors.primaryColor,
                    onChanged: (bool? value) {
                      setState(() {
                        if (value == true) {
                          _selectedActors.add(actor);
                        } else {
                          _selectedActors.remove(actor);
                        }
                      });
                    },
                  );
                },
              ),
            ),

            const SizedBox(height: AppDim.paddingMedium),

            // Action buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(
                    'Cancel',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                ),
                const SizedBox(width: AppDim.paddingMedium),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(_selectedActors),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryColor,
                    foregroundColor: AppColors.textLight,
                  ),
                  child: const Text('Done'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}
