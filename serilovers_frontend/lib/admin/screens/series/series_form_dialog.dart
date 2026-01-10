import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dim.dart';
import '../../../models/series.dart';
import '../../../models/season.dart';
import '../../../providers/actor_provider.dart';
import '../../../services/api_service.dart';
import '../../../providers/auth_provider.dart';
import '../../../utils/file_picker_helper.dart';
import '../../providers/admin_series_provider.dart';
import '../../../core/widgets/image_with_placeholder.dart';

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
  String? _uploadedImageUrl; // Store uploaded image URL
  bool _isUploadingImage = false;

  DateTime? _selectedDate;
  List<int> _selectedGenreIds = []; // Changed to use genre IDs
  List<Actor> _selectedActors = [];
  List<Actor> _availableActors = [];
  List<Genre> _availableGenres = []; // Changed to Genre objects
  bool _isLoading = false;
  bool _isLoadingGenres = false;
  
  // Seasons and Episodes management
  List<_SeasonData> _seasons = []; // List of seasons with their episodes

  @override
  void initState() {
    super.initState();
    _loadActors();
    _loadGenres();
    _initializeForm();
    // If editing, fetch fresh seasons data from API
    if (widget.series != null) {
      _loadSeasonsFromAPI();
    }
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
      _uploadedImageUrl = series.imageUrl;
      
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
      
      // Load seasons and episodes
      if (series.seasons.isNotEmpty) {
        _seasons = series.seasons.map((season) {
          final seasonData = _SeasonData(
            id: season.id,
            seasonNumber: season.seasonNumber,
            titleController: TextEditingController(text: season.title),
            descriptionController: TextEditingController(text: season.description ?? ''),
            releaseDate: season.releaseDate,
            releaseDateController: TextEditingController(
              text: season.releaseDate != null ? _formatDate(season.releaseDate!) : '',
            ),
            episodes: season.episodes.map((episode) {
              return _EpisodeData(
                id: episode.id,
                episodeNumber: episode.episodeNumber,
                titleController: TextEditingController(text: episode.title),
                descriptionController: TextEditingController(text: episode.description ?? ''),
                airDate: episode.airDate,
                airDateController: TextEditingController(
                  text: episode.airDate != null ? _formatDate(episode.airDate!) : '',
                ),
                durationMinutes: episode.durationMinutes,
                durationController: TextEditingController(
                  text: episode.durationMinutes?.toString() ?? '',
                ),
                rating: episode.rating,
                ratingController: TextEditingController(
                  text: episode.rating?.toString() ?? '',
                ),
              );
            }).toList(),
          );
          return seasonData;
        }).toList();
      }
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

  /// Load seasons from API for the series being edited
  Future<void> _loadSeasonsFromAPI() async {
    if (widget.series == null) return;
    
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final apiService = ApiService();
      final token = authProvider.token;

      if (token == null || token.isEmpty) {
        throw Exception('Authentication required');
      }

      final response = await apiService.get('/Season/series/${widget.series!.id}', token: token);
      
      if (response is List) {
        final seasons = response
            .map((item) => Season.fromJson(item as Map<String, dynamic>))
            .toList();
        
        // Update _seasons with fresh data from API
        setState(() {
          _seasons = seasons.map((season) {
            // Check if this season already exists in _seasons (by ID)
            final existingSeasonIndex = _seasons.indexWhere((s) => s.id == season.id);
            if (existingSeasonIndex >= 0) {
              // Update existing season data but keep controllers
              final existing = _seasons[existingSeasonIndex];
              return _SeasonData(
                id: season.id,
                seasonNumber: season.seasonNumber,
                titleController: existing.titleController,
                descriptionController: existing.descriptionController,
                releaseDate: season.releaseDate,
                releaseDateController: existing.releaseDateController,
                episodes: season.episodes.map((episode) {
                  final existingEpisodeIndex = existing.episodes.indexWhere((e) => e.id == episode.id);
                  if (existingEpisodeIndex >= 0) {
                    final existingEpisode = existing.episodes[existingEpisodeIndex];
                    return _EpisodeData(
                      id: episode.id,
                      episodeNumber: episode.episodeNumber,
                      titleController: existingEpisode.titleController,
                      descriptionController: existingEpisode.descriptionController,
                      airDate: episode.airDate,
                      airDateController: existingEpisode.airDateController,
                      durationMinutes: episode.durationMinutes,
                      durationController: existingEpisode.durationController,
                      rating: episode.rating,
                      ratingController: existingEpisode.ratingController,
                    );
                  } else {
                    // New episode from API
                    return _EpisodeData(
                      id: episode.id,
                      episodeNumber: episode.episodeNumber,
                      titleController: TextEditingController(text: episode.title),
                      descriptionController: TextEditingController(text: episode.description ?? ''),
                      airDate: episode.airDate,
                      airDateController: TextEditingController(
                        text: episode.airDate != null ? _formatDate(episode.airDate!) : '',
                      ),
                      durationMinutes: episode.durationMinutes,
                      durationController: TextEditingController(
                        text: episode.durationMinutes?.toString() ?? '',
                      ),
                      rating: episode.rating,
                      ratingController: TextEditingController(
                        text: episode.rating?.toString() ?? '',
                      ),
                    );
                  }
                }).toList(),
              );
            } else {
              // New season from API
              return _SeasonData(
                id: season.id,
                seasonNumber: season.seasonNumber,
                titleController: TextEditingController(text: season.title),
                descriptionController: TextEditingController(text: season.description ?? ''),
                releaseDate: season.releaseDate,
                releaseDateController: TextEditingController(
                  text: season.releaseDate != null ? _formatDate(season.releaseDate!) : '',
                ),
                episodes: season.episodes.map((episode) {
                  return _EpisodeData(
                    id: episode.id,
                    episodeNumber: episode.episodeNumber,
                    titleController: TextEditingController(text: episode.title),
                    descriptionController: TextEditingController(text: episode.description ?? ''),
                    airDate: episode.airDate,
                    airDateController: TextEditingController(
                      text: episode.airDate != null ? _formatDate(episode.airDate!) : '',
                    ),
                    durationMinutes: episode.durationMinutes,
                    durationController: TextEditingController(
                      text: episode.durationMinutes?.toString() ?? '',
                    ),
                    rating: episode.rating,
                    ratingController: TextEditingController(
                      text: episode.rating?.toString() ?? '',
                    ),
                  );
                }).toList(),
              );
            }
          }).toList();
        });
      }
    } catch (e) {
      print('Error loading seasons from API: $e');
      // Don't show error to user - fall back to seasons from series object
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
        selectedActors: List.from(_selectedActors),
      ),
    );

    if (result != null) {
      setState(() {
        _selectedActors = result;
      });
    }
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
          folder: 'series',
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
          folder: 'series',
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
      // Use uploaded image URL if available, otherwise keep existing image URL
      // If editing and no new image uploaded, keep the existing image URL
      // If editing and image was removed (deleted), set to null
      final imageUrlToSave = _uploadedImageUrl ?? widget.series?.imageUrl;
      
      final seriesData = <String, dynamic>{
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim(),
        'rating': double.parse(_ratingController.text),
        'releaseDate': _selectedDate!.toIso8601String(),
        'genreIds': _selectedGenreIds,
        'actorIds': _selectedActors.map((actor) => actor.id).toList(),
      };
      
      // Always include imageUrl, even if null (to allow removing images)
      if (imageUrlToSave != null && imageUrlToSave.isNotEmpty) {
        seriesData['imageUrl'] = imageUrlToSave;
      } else if (widget.series != null && widget.series!.imageUrl != null) {
        // Keep existing image if no new one uploaded and not explicitly removed
        seriesData['imageUrl'] = widget.series!.imageUrl;
      } else {
        // No image (new series or image was removed)
        seriesData['imageUrl'] = null;
      }
      
      print('💾 Saving series with imageUrl: ${seriesData['imageUrl']}');
      print('💾 Full series data: $seriesData');

      int? seriesId;
      if (widget.series == null) {
        // Create new series
        final createdSeries = await adminSeriesProvider.createSeries(seriesData);
        seriesId = createdSeries.id;
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
        seriesId = widget.series!.id;
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

      // Save seasons and episodes if series was created/updated successfully
      if (seriesId != null && _seasons.isNotEmpty) {
        await _saveSeasonsAndEpisodes(seriesId);
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

  /// Save seasons and episodes for a series
  Future<void> _saveSeasonsAndEpisodes(int seriesId) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final apiService = ApiService();
    final token = authProvider.token;

    if (token == null || token.isEmpty) {
      throw Exception('Authentication required');
    }

    try {
      for (var seasonData in _seasons) {
        int? seasonId = seasonData.id;
        
        // Create or update season
        final seasonPayload = {
          'seriesId': seriesId,
          'seasonNumber': seasonData.seasonNumber,
          'title': seasonData.titleController.text.trim(),
          'description': seasonData.descriptionController.text.trim().isEmpty 
              ? null 
              : seasonData.descriptionController.text.trim(),
          'releaseDate': seasonData.releaseDate?.toIso8601String(),
        };

        if (seasonId == null) {
          // Create new season
          final response = await apiService.post('/Season', seasonPayload, token: token);
          if (response is Map<String, dynamic>) {
            seasonId = response['id'] as int?;
          }
        } else {
          // Update existing season
          await apiService.put('/Season/$seasonId', seasonPayload, token: token);
        }

        if (seasonId == null) continue;

        // Save episodes for this season
        // First, get all existing episodes for this season to check for duplicates
        final existingEpisodesResponse = await apiService.get('/Episode/season/$seasonId', token: token);
        final existingEpisodes = existingEpisodesResponse is List
            ? (existingEpisodesResponse as List).map((e) => {
                'id': (e as Map<String, dynamic>)['id'],
                'episodeNumber': (e as Map<String, dynamic>)['episodeNumber'],
              }).toList()
            : <Map<String, dynamic>>[];
        
        for (var episodeData in seasonData.episodes) {
          final episodePayload = {
            'seasonId': seasonId,
            'episodeNumber': episodeData.episodeNumber,
            'title': episodeData.titleController.text.trim(),
            'description': episodeData.descriptionController.text.trim().isEmpty 
                ? null 
                : episodeData.descriptionController.text.trim(),
            'airDate': episodeData.airDate?.toIso8601String(),
            'durationMinutes': episodeData.durationMinutes,
            'rating': episodeData.rating,
          };

          if (episodeData.id == null) {
            // Check if an episode with this number already exists
            final existingEpisode = existingEpisodes.firstWhere(
              (e) => e['episodeNumber'] == episodeData.episodeNumber,
              orElse: () => {},
            );
            
            if (existingEpisode.isNotEmpty && existingEpisode['id'] != null) {
              // Episode already exists, update it instead of creating
              await apiService.put('/Episode/${existingEpisode['id']}', episodePayload, token: token);
            } else {
              // Create new episode
              await apiService.post('/Episode', episodePayload, token: token);
            }
          } else {
            // Update existing episode
            await apiService.put('/Episode/${episodeData.id}', episodePayload, token: token);
          }
        }
      }
    } catch (e) {
      print('Error saving seasons/episodes: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Series saved, but error saving seasons/episodes: $e'),
            backgroundColor: AppColors.dangerColor,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  /// Add a new season
  void _addSeason() {
    setState(() {
      // Calculate next season number based on existing seasons
      // Use the highest season number + 1, or 1 if no seasons exist
      final nextSeasonNumber = _seasons.isEmpty 
          ? 1 
          : (_seasons.map((s) => s.seasonNumber).reduce((a, b) => a > b ? a : b)) + 1;
      
      _seasons.add(_SeasonData(
        seasonNumber: nextSeasonNumber,
        titleController: TextEditingController(text: 'Season $nextSeasonNumber'),
        descriptionController: TextEditingController(),
        releaseDateController: TextEditingController(),
        episodes: [],
      ));
    });
  }

  /// Remove a season
  void _removeSeason(int index) {
    setState(() {
      final season = _seasons[index];
      // Dispose controllers
      season.titleController.dispose();
      season.descriptionController.dispose();
      season.releaseDateController.dispose();
      for (var episode in season.episodes) {
        episode.titleController.dispose();
        episode.descriptionController.dispose();
        episode.airDateController.dispose();
        episode.durationController.dispose();
        episode.ratingController.dispose();
      }
      _seasons.removeAt(index);
      // Renumber remaining seasons
      for (int i = 0; i < _seasons.length; i++) {
        _seasons[i].seasonNumber = i + 1;
      }
    });
  }

  /// Add an episode to a season
  void _addEpisode(int seasonIndex) {
    setState(() {
      final season = _seasons[seasonIndex];
      final nextEpisodeNumber = season.episodes.isEmpty 
          ? 1 
          : season.episodes.map((e) => e.episodeNumber).reduce((a, b) => a > b ? a : b) + 1;
      season.episodes.add(_EpisodeData(
        episodeNumber: nextEpisodeNumber,
        titleController: TextEditingController(text: 'Episode $nextEpisodeNumber'),
        descriptionController: TextEditingController(),
        airDateController: TextEditingController(),
        durationController: TextEditingController(),
        ratingController: TextEditingController(),
      ));
    });
  }

  /// Remove an episode from a season
  void _removeEpisode(int seasonIndex, int episodeIndex) {
    setState(() {
      final season = _seasons[seasonIndex];
      final episode = season.episodes[episodeIndex];
      // Dispose controllers
      episode.titleController.dispose();
      episode.descriptionController.dispose();
      episode.airDateController.dispose();
      episode.durationController.dispose();
      episode.ratingController.dispose();
      season.episodes.removeAt(episodeIndex);
      // Renumber remaining episodes
      for (int i = 0; i < season.episodes.length; i++) {
        season.episodes[i].episodeNumber = i + 1;
      }
    });
  }

  /// Select release date for a season
  Future<void> _selectSeasonDate(int seasonIndex) async {
    final season = _seasons[seasonIndex];
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: season.releaseDate ?? DateTime.now(),
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

    if (picked != null) {
      setState(() {
        season.releaseDate = picked;
        season.releaseDateController.text = _formatDate(picked);
      });
    }
  }

  /// Select air date for an episode
  Future<void> _selectEpisodeDate(int seasonIndex, int episodeIndex) async {
    final episode = _seasons[seasonIndex].episodes[episodeIndex];
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: episode.airDate ?? DateTime.now(),
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

    if (picked != null) {
      setState(() {
        episode.airDate = picked;
        episode.airDateController.text = _formatDate(picked);
      });
    }
  }

  /// Build the seasons and episodes management section
  Widget _buildSeasonsAndEpisodesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Seasons & Episodes',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            ElevatedButton.icon(
              onPressed: _addSeason,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add Season'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryColor,
                foregroundColor: AppColors.textLight,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDim.paddingMedium,
                  vertical: AppDim.paddingSmall,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppDim.paddingMedium),
        if (_seasons.isEmpty)
          Container(
            padding: const EdgeInsets.all(AppDim.paddingLarge),
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.textSecondary.withOpacity(0.3)),
              borderRadius: BorderRadius.circular(AppDim.radiusSmall),
            ),
            child: Center(
              child: Text(
                'No seasons added. Click "Add Season" to get started.',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          )
        else
          ...List.generate(_seasons.length, (seasonIndex) {
            return _buildSeasonCard(seasonIndex);
          }),
      ],
    );
  }

  /// Build a card for a single season with its episodes
  Widget _buildSeasonCard(int seasonIndex) {
    final season = _seasons[seasonIndex];
    return Card(
      margin: const EdgeInsets.only(bottom: AppDim.paddingMedium),
      child: ExpansionTile(
        initiallyExpanded: false,
        title: Text(
          'Season ${season.seasonNumber}',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          '${season.episodes.length} episode${season.episodes.length != 1 ? 's' : ''}',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        leading: Icon(Icons.tv, color: AppColors.primaryColor),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.delete, color: AppColors.dangerColor),
              onPressed: () => _removeSeason(seasonIndex),
              tooltip: 'Remove Season',
            ),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(AppDim.paddingMedium),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Season Title
                TextFormField(
                  controller: season.titleController,
                  decoration: InputDecoration(
                    labelText: 'Season Title *',
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
                ),
                const SizedBox(height: AppDim.paddingMedium),
                // Season Description
                TextFormField(
                  controller: season.descriptionController,
                  decoration: InputDecoration(
                    labelText: 'Season Description',
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
                  maxLines: 2,
                ),
                const SizedBox(height: AppDim.paddingMedium),
                // Season Release Date
                TextFormField(
                  controller: season.releaseDateController,
                  decoration: InputDecoration(
                    labelText: 'Season Release Date',
                    labelStyle: TextStyle(color: AppColors.textSecondary),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppDim.radiusSmall),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppDim.radiusSmall),
                      borderSide: BorderSide(color: AppColors.primaryColor),
                    ),
                    suffixIcon: Icon(Icons.calendar_today, color: AppColors.primaryColor),
                  ),
                  style: TextStyle(color: AppColors.textPrimary),
                  readOnly: true,
                  onTap: () => _selectSeasonDate(seasonIndex),
                ),
                const SizedBox(height: AppDim.paddingLarge),
                // Episodes section
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Episodes',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: () => _addEpisode(seasonIndex),
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('Add Episode'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryColor,
                        foregroundColor: AppColors.textLight,
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppDim.paddingSmall,
                          vertical: 8,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppDim.paddingSmall),
                if (season.episodes.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(AppDim.paddingMedium),
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.textSecondary.withOpacity(0.2)),
                      borderRadius: BorderRadius.circular(AppDim.radiusSmall),
                    ),
                    child: Center(
                      child: Text(
                        'No episodes. Click "Add Episode" to add one.',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontStyle: FontStyle.italic,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  )
                else
                  ...List.generate(season.episodes.length, (episodeIndex) {
                    return _buildEpisodeCard(seasonIndex, episodeIndex);
                  }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Build a card for a single episode
  Widget _buildEpisodeCard(int seasonIndex, int episodeIndex) {
    final episode = _seasons[seasonIndex].episodes[episodeIndex];
    return Card(
      margin: const EdgeInsets.only(bottom: AppDim.paddingSmall),
      color: AppColors.cardBackground.withOpacity(0.5),
      child: Padding(
        padding: const EdgeInsets.all(AppDim.paddingMedium),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Episode ${episode.episodeNumber}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete, size: 18, color: AppColors.dangerColor),
                  onPressed: () => _removeEpisode(seasonIndex, episodeIndex),
                  tooltip: 'Remove Episode',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const SizedBox(height: AppDim.paddingSmall),
            // Episode Title
            TextFormField(
              controller: episode.titleController,
              decoration: InputDecoration(
                labelText: 'Episode Title *',
                labelStyle: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppDim.radiusSmall),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppDim.radiusSmall),
                  borderSide: BorderSide(color: AppColors.primaryColor),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
              ),
              style: TextStyle(color: AppColors.textPrimary, fontSize: 14),
            ),
            const SizedBox(height: AppDim.paddingSmall),
            // Episode Description
            TextFormField(
              controller: episode.descriptionController,
              decoration: InputDecoration(
                labelText: 'Description',
                labelStyle: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppDim.radiusSmall),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppDim.radiusSmall),
                  borderSide: BorderSide(color: AppColors.primaryColor),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
              ),
              style: TextStyle(color: AppColors.textPrimary, fontSize: 14),
              maxLines: 2,
            ),
            const SizedBox(height: AppDim.paddingSmall),
            // Episode details row - Duration only (Air Date and Rating removed)
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: episode.durationController,
                    decoration: InputDecoration(
                      labelText: 'Duration (min)',
                      labelStyle: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppDim.radiusSmall),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppDim.radiusSmall),
                        borderSide: BorderSide(color: AppColors.primaryColor),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                    ),
                    style: TextStyle(color: AppColors.textPrimary, fontSize: 14),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    onChanged: (value) {
                      episode.durationMinutes = int.tryParse(value);
                    },
                  ),
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
    _titleController.dispose();
    _descriptionController.dispose();
    _ratingController.dispose();
    _releaseDateController.dispose();
    for (var season in _seasons) {
      season.titleController.dispose();
      season.descriptionController.dispose();
      season.releaseDateController.dispose();
      for (var episode in season.episodes) {
        episode.titleController.dispose();
        episode.descriptionController.dispose();
        episode.airDateController.dispose();
        episode.durationController.dispose();
        episode.ratingController.dispose();
      }
    }
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

                      // Seasons and Episodes Management
                      _buildSeasonsAndEpisodesSection(),
                      const SizedBox(height: AppDim.paddingMedium),

                      // Image upload field
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Series Image',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: AppDim.paddingSmall),
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: _isUploadingImage ? null : _pickAndUploadImage,
                                  icon: _isUploadingImage
                                      ? const SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            valueColor: AlwaysStoppedAnimation<Color>(AppColors.textLight),
                                          ),
                                        )
                                      : const Icon(Icons.image, size: 20),
                                  label: Text(_isUploadingImage ? 'Uploading...' : 'Choose Image'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.primaryColor,
                                    foregroundColor: AppColors.textLight,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: AppDim.paddingMedium,
                                      vertical: AppDim.paddingMedium,
                                    ),
                                  ),
                                ),
                              ),
                              if ((_uploadedImageUrl != null && _uploadedImageUrl!.isNotEmpty) || 
                                  (widget.series?.imageUrl != null && widget.series!.imageUrl!.isNotEmpty)) ...[
                                const SizedBox(width: AppDim.paddingSmall),
                                IconButton(
                                  onPressed: () {
                                    setState(() {
                                      _uploadedImageUrl = null;
                                    });
                                  },
                                  icon: const Icon(Icons.delete_outline),
                                  color: AppColors.dangerColor,
                                  tooltip: 'Remove image',
                                ),
                              ],
                            ],
                          ),
                          // Always show image preview if there's an image (existing or newly uploaded)
                          Builder(
                            builder: (context) {
                              final currentImageUrl = _uploadedImageUrl ?? widget.series?.imageUrl;
                              if (currentImageUrl != null && currentImageUrl.isNotEmpty) {
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const SizedBox(height: AppDim.paddingSmall),
                                    Container(
                                      height: 150,
                                      width: double.infinity,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(AppDim.radiusSmall),
                                        border: Border.all(color: AppColors.textSecondary.withOpacity(0.3)),
                                      ),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(AppDim.radiusSmall),
                                        child: ImageWithPlaceholder(
                                          imageUrl: currentImageUrl,
                                          height: 150,
                                          width: double.infinity,
                                          fit: BoxFit.cover,
                                          borderRadius: AppDim.radiusSmall,
                                          placeholderIcon: Icons.movie,
                                        ),
                                      ),
                                    ),
                                    if (widget.series?.imageUrl != null && 
                                        widget.series!.imageUrl!.isNotEmpty && 
                                        _uploadedImageUrl == null) ...[
                                      const SizedBox(height: AppDim.paddingSmall),
                                      Text(
                                        'Current image (click "Choose Image" to change)',
                                        style: TextStyle(
                                          color: AppColors.textSecondary,
                                          fontSize: 12,
                                          fontStyle: FontStyle.italic,
                                        ),
                                      ),
                                    ] else if (_uploadedImageUrl != null && _uploadedImageUrl!.isNotEmpty) ...[
                                      const SizedBox(height: AppDim.paddingSmall),
                                      Text(
                                        'New image selected (click "Update" to save)',
                                        style: TextStyle(
                                          color: AppColors.successColor,
                                          fontSize: 12,
                                          fontStyle: FontStyle.italic,
                                        ),
                                      ),
                                    ],
                                  ],
                                );
                              }
                              return const SizedBox.shrink();
                            },
                          ),
                        ],
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
  final _searchController = TextEditingController();
  late List<Actor> _filteredActors;
  late List<Actor> _selectedActors;

  @override
  void initState() {
    super.initState();
    _selectedActors = List.from(widget.selectedActors);
    _filteredActors = List.from(widget.availableActors);
    _searchController.addListener(_filterActors);
  }

  void _filterActors() {
    final query = _searchController.text;
    setState(() {
      if (query.isEmpty) {
        _filteredActors = List.from(widget.availableActors);
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
                  final isSelected = _selectedActors.any((a) => a.id == actor.id);

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
                          _selectedActors.removeWhere((a) => a.id == actor.id);
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

/// Helper class to hold season data with episodes
class _SeasonData {
  int? id; // null for new seasons
  int seasonNumber;
  TextEditingController titleController;
  TextEditingController descriptionController;
  DateTime? releaseDate;
  TextEditingController releaseDateController;
  List<_EpisodeData> episodes;

  _SeasonData({
    this.id,
    required this.seasonNumber,
    required this.titleController,
    required this.descriptionController,
    this.releaseDate,
    required this.releaseDateController,
    required this.episodes,
  });
}

/// Helper class to hold episode data
class _EpisodeData {
  int? id; // null for new episodes
  int episodeNumber;
  TextEditingController titleController;
  TextEditingController descriptionController;
  DateTime? airDate;
  TextEditingController airDateController;
  int? durationMinutes;
  TextEditingController durationController;
  double? rating;
  TextEditingController ratingController;

  _EpisodeData({
    this.id,
    required this.episodeNumber,
    required this.titleController,
    required this.descriptionController,
    this.airDate,
    required this.airDateController,
    this.durationMinutes,
    required this.durationController,
    this.rating,
    required this.ratingController,
  });
}
