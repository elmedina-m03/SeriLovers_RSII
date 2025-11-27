import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dim.dart';
import '../../providers/series_provider.dart';
import '../../widgets/series_card.dart';

/// Mobile search screen for finding series
class MobileSearchScreen extends StatefulWidget {
  const MobileSearchScreen({super.key});

  @override
  State<MobileSearchScreen> createState() => _MobileSearchScreenState();
}

class _MobileSearchScreenState extends State<MobileSearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _onSearchChanged(String value) async {
    final query = value.trim();
    setState(() {
      _query = query;
    });

    if (query.isEmpty) {
      // Do not search on empty query; keep current items or show hint
      return;
    }

    final seriesProvider = Provider.of<SeriesProvider>(context, listen: false);
    await seriesProvider.searchSeries(query);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      appBar: AppBar(
        title: const Text('Search'),
        backgroundColor: AppColors.primaryColor,
        foregroundColor: AppColors.textLight,
        elevation: 0,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Search Bar
            Padding(
              padding: const EdgeInsets.all(AppDim.paddingMedium),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search series...',
                  hintStyle: TextStyle(color: AppColors.textSecondary.withOpacity(0.7)),
                  prefixIcon: Icon(Icons.search, color: AppColors.primaryColor),
                  filled: true,
                  fillColor: AppColors.cardBackground,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppColors.textSecondary.withOpacity(0.2)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppColors.textSecondary.withOpacity(0.2)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.primaryColor, width: 2),
                  ),
                  suffixIcon: _query.isNotEmpty
                      ? IconButton(
                          icon: Icon(Icons.clear, color: AppColors.textSecondary),
                          onPressed: () {
                            _searchController.clear();
                            _onSearchChanged('');
                          },
                        )
                      : null,
                ),
                style: TextStyle(color: AppColors.textPrimary),
                textInputAction: TextInputAction.search,
                onChanged: _onSearchChanged,
                onSubmitted: _onSearchChanged,
              ),
            ),

            // Results
            Expanded(
              child: Consumer<SeriesProvider>(
                builder: (context, seriesProvider, child) {
                  if (_query.isEmpty) {
                    return Center(
                      child: Text(
                        'Type to search series…',
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    );
                  }

                  if (seriesProvider.isLoading) {
                    return const Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryColor),
                      ),
                    );
                  }

                  if (seriesProvider.items.isEmpty) {
                    return Center(
                      child: Text(
                        'No series found.',
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    );
                  }

                  return ListView.builder(
                    itemCount: seriesProvider.items.length,
                    itemBuilder: (context, index) {
                      final series = seriesProvider.items[index];
                      return SeriesCard(series: series);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}


