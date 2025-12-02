import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dim.dart';
import '../../models/series.dart';
import '../../providers/series_provider.dart';
import '../models/series_filter.dart';

/// Filter screen allowing users to pick genre and year range.
class MobileFilterScreen extends StatefulWidget {
  final SeriesFilter? initialFilter;

  const MobileFilterScreen({super.key, this.initialFilter});

  @override
  State<MobileFilterScreen> createState() => _MobileFilterScreenState();
}

class _MobileFilterScreenState extends State<MobileFilterScreen> {
  Genre? _selectedGenre;
  int? _startYear;
  int? _endYear;
  late List<int> _years; // Will be initialized in initState
  bool _requestedGenres = false;

  @override
  void initState() {
    super.initState();
    _selectedGenre = widget.initialFilter?.genre;
    _startYear = widget.initialFilter?.startYear;
    _endYear = widget.initialFilter?.endYear;
    
    // Generate years from 1950 to current year + 5
    final currentYear = DateTime.now().year;
    _years = List.generate(currentYear + 5 - 1950 + 1, (index) => 1950 + index);
    _years = _years.reversed.toList(); // Most recent first
  }

  Future<void> _ensureGenresLoaded(BuildContext context) async {
    if (_requestedGenres) return;
    _requestedGenres = true;
    final provider = Provider.of<SeriesProvider>(context, listen: false);
    if (provider.genres.isEmpty) {
      await provider.fetchGenres();
    }
  }

  void _apply() {
    final filter = SeriesFilter(
      genre: _selectedGenre,
      startYear: _startYear,
      endYear: _endYear,
    );
    Navigator.of(context).pop(filter);
  }

  void _reset() {
    setState(() {
      _selectedGenre = null;
      _startYear = null;
      _endYear = null;
    });
    Navigator.of(context).pop(const SeriesFilter());
  }

  @override
  Widget build(BuildContext context) {
    _ensureGenresLoaded(context);

    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      appBar: AppBar(
        title: const Text('Filters'),
        backgroundColor: AppColors.primaryColor,
        foregroundColor: AppColors.textLight,
      ),
      body: SafeArea(
        child: Consumer<SeriesProvider>(
          builder: (context, seriesProvider, child) {
            final genres = seriesProvider.genres;

            return Padding(
              padding: const EdgeInsets.all(AppDim.paddingLarge),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Genre',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: AppDim.paddingSmall),
                  DropdownButtonFormField<Genre>(
                    value: _selectedGenre != null && genres.any((g) => g.id == _selectedGenre!.id)
                        ? genres.firstWhere((g) => g.id == _selectedGenre!.id)
                        : null,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: AppColors.cardBackground,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    hint: const Text('Select genre'),
                    dropdownColor: AppColors.cardBackground,
                    items: genres.map((genre) {
                      return DropdownMenuItem(
                        value: genre,
                        child: Text(genre.name),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedGenre = value;
                      });
                    },
                  ),
                  const SizedBox(height: AppDim.paddingLarge),

                  Text(
                    'Year range',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: AppDim.paddingSmall),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<int>(
                          value: _startYear,
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: AppColors.cardBackground,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          hint: const Text('From'),
                          dropdownColor: AppColors.cardBackground,
                          items: _years.map((year) {
                            return DropdownMenuItem(
                              value: year,
                              child: Text(year.toString()),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setState(() {
                              _startYear = value;
                              if (_endYear != null && value != null && _endYear! < value) {
                                _endYear = value;
                              }
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: AppDim.paddingMedium),
                      Expanded(
                        child: DropdownButtonFormField<int>(
                          value: _endYear,
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: AppColors.cardBackground,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          hint: const Text('To'),
                          dropdownColor: AppColors.cardBackground,
                          items: _years.map((year) {
                            return DropdownMenuItem(
                              value: year,
                              child: Text(year.toString()),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setState(() {
                              _endYear = value;
                              if (_startYear != null && value != null && value < _startYear!) {
                                _startYear = value;
                              }
                            });
                          },
                        ),
                      ),
                    ],
                  ),

                  const Spacer(),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _apply,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryColor,
                        foregroundColor: AppColors.textLight,
                        padding: const EdgeInsets.symmetric(vertical: AppDim.paddingMedium),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppDim.radiusMedium),
                        ),
                      ),
                      child: const Text(
                        'Apply',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppDim.paddingSmall),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: _reset,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primaryColor,
                        side: const BorderSide(color: AppColors.primaryColor, width: 1.5),
                        padding: const EdgeInsets.symmetric(vertical: AppDim.paddingMedium),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppDim.radiusMedium),
                        ),
                      ),
                      child: const Text(
                        'Reset',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
