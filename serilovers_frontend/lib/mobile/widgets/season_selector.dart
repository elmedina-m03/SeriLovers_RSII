import 'package:flutter/material.dart';
import '../../models/season.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dim.dart';

/// Widget for selecting a season from a series
class SeasonSelector extends StatelessWidget {
  final List<Season> seasons;
  final int? selectedSeasonNumber;
  final Function(int) onSeasonSelected;

  const SeasonSelector({
    super.key,
    required this.seasons,
    this.selectedSeasonNumber,
    required this.onSeasonSelected,
  });

  @override
  Widget build(BuildContext context) {
    if (seasons.isEmpty) {
      return const SizedBox.shrink();
    }

    // Sort seasons by season number
    final sortedSeasons = List<Season>.from(seasons)
      ..sort((a, b) => a.seasonNumber.compareTo(b.seasonNumber));

    return SizedBox(
      height: 50,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
        padding: const EdgeInsets.symmetric(horizontal: AppDim.paddingMedium, vertical: 8),
        child: Row(
          children: sortedSeasons.map((season) {
            final isSelected = selectedSeasonNumber == season.seasonNumber;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                label: Text('Season ${season.seasonNumber}'),
                selected: isSelected,
                onSelected: (selected) {
                  if (selected) {
                    onSeasonSelected(season.seasonNumber);
                  }
                },
                selectedColor: AppColors.primaryColor,
                checkmarkColor: AppColors.textLight,
                labelStyle: TextStyle(
                  color: isSelected ? AppColors.textLight : AppColors.textPrimary,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  fontSize: 14,
                ),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

