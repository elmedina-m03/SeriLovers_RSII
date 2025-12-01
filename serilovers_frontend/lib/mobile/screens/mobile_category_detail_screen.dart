import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dim.dart';
import '../../models/series.dart';
import '../../providers/series_provider.dart';
import '../widgets/series_card_mobile.dart';
import '../models/series_filter.dart';
import 'mobile_filter_screen.dart';

/// Mobile category detail screen showing series for a specific genre
class MobileCategoryDetailScreen extends StatefulWidget {
  final Genre genre;

  const MobileCategoryDetailScreen({
    super.key,
    required this.genre,
  });

  @override
  State<MobileCategoryDetailScreen> createState() => _MobileCategoryDetailScreenState();
}

class _MobileCategoryDetailScreenState extends State<MobileCategoryDetailScreen> {
  bool _isLoading = true;
  List<Series> _series = [];
  SeriesFilter? _activeFilter;
  late Genre _currentGenre;

  @override
  void initState() {
    super.initState();
    _currentGenre = widget.genre;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadSeries();
    });
  }

  Future<void> _loadSeries() async {
    final provider = Provider.of<SeriesProvider>(context, listen: false);
    setState(() {
      _isLoading = true;
    });
    try {
      final result = await provider.fetchSeriesByGenre(_currentGenre.id);
      final filtered = _applyYearFilter(result);
      setState(() {
        _series = filtered;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading series: $e'),
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

  List<Series> _applyYearFilter(List<Series> items) {
    if (_activeFilter == null || _activeFilter!.isEmpty) {
      return items;
    }
    final start = _activeFilter!.startYear;
    final end = _activeFilter!.endYear;
    return items.where((series) {
      final year = series.releaseDate.year;
      final matchesStart = start == null || year >= start;
      final matchesEnd = end == null || year <= end;
      return matchesStart && matchesEnd;
    }).toList();
  }

  Future<void> _openFilter() async {
    final initialFilter = SeriesFilter(
      genre: _currentGenre,
      startYear: _activeFilter?.startYear,
      endYear: _activeFilter?.endYear,
    );
    final result = await Navigator.push<SeriesFilter?>(
      context,
      MaterialPageRoute(
        builder: (context) => MobileFilterScreen(initialFilter: initialFilter),
      ),
    );

    if (!mounted || result == null) return;

    setState(() {
      if (result.genre != null) {
        _currentGenre = result.genre!;
      }
      final yearFilter = SeriesFilter(
        startYear: result.startYear,
        endYear: result.endYear,
      );
      _activeFilter = yearFilter.isEmpty ? null : yearFilter;
    });

    await _loadSeries();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      appBar: AppBar(
        title: Text(_currentGenre.name),
        backgroundColor: AppColors.primaryColor,
        foregroundColor: AppColors.textLight,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _openFilter,
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadSeries,
          color: AppColors.primaryColor,
          child: _isLoading
              ? ListView.builder(
                  padding: const EdgeInsets.all(AppDim.paddingMedium),
                  itemCount: 4,
                  itemBuilder: (context, index) {
                    return _buildShimmerCard();
                  },
                )
              : (_series.isEmpty
                  ? ListView(
                      padding: const EdgeInsets.all(AppDim.paddingLarge),
                      children: [
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.movie_outlined,
                              size: 64,
                              color: AppColors.textSecondary.withOpacity(0.5),
                            ),
                            const SizedBox(height: AppDim.paddingMedium),
                            Text(
                              'No series found in ${_currentGenre.name}',
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: AppColors.textSecondary,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ],
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(
                        vertical: AppDim.paddingMedium,
                      ),
                      itemCount: _series.length,
                      itemBuilder: (context, index) {
                        final series = _series[index];
                        return SeriesCardMobile(series: series);
                      },
                    )),
        ),
      ),
    );
  }

  /// Simple shimmer-like placeholder for series card
  Widget _buildShimmerCard() {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Container(
                    height: 16,
                    decoration: BoxDecoration(
                      color: AppColors.primaryColor.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  width: 40,
                  height: 16,
                  decoration: BoxDecoration(
                    color: AppColors.primaryColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Container(
                  width: 60,
                  height: 18,
                  decoration: BoxDecoration(
                    color: AppColors.primaryColor.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  width: 50,
                  height: 18,
                  decoration: BoxDecoration(
                    color: AppColors.primaryColor.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
