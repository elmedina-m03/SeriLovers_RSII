import 'package:flutter/material.dart';
import '../models/series.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_dim.dart';

/// Full Description screen showing complete series description
class SeriesFullDescriptionScreen extends StatelessWidget {
  final Series series;

  const SeriesFullDescriptionScreen({
    super.key,
    required this.series,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Series image (same as detail screen)
            Container(
              width: double.infinity,
              height: 350,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                image: series.imageUrl != null && series.imageUrl!.isNotEmpty
                    ? DecorationImage(
                        image: NetworkImage(series.imageUrl!),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              child: series.imageUrl == null || series.imageUrl!.isEmpty
                  ? Center(
                      child: Icon(
                        Icons.movie,
                        size: 64,
                        color: Colors.grey[600],
                      ),
                    )
                  : null,
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title with heart icon (same as detail screen)
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          series.title,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Year, seasons, episodes (same as detail screen)
                  Row(
                    children: [
                      Text(
                        '${series.releaseDate.year}',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      if (series.seasons.isNotEmpty) ...[
                        Text(
                          ' • ${series.totalSeasons} season${series.totalSeasons > 1 ? 's' : ''}',
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        Text(
                          ' • ${series.totalEpisodes} episodes',
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Rating (same as detail screen)
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.successColor,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.star,
                              color: Colors.white,
                              size: 18,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              series.rating.toStringAsFixed(1),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            if (series.ratingsCount > 0) ...[
                              const SizedBox(width: 4),
                              Text(
                                '(${series.ratingsCount})',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  // Full Description
                  Text(
                    'Description',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    series.description ?? 'No description available.',
                    style: theme.textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 24),
                  // Genres (same as detail screen)
                  if (series.genres.isNotEmpty) ...[
                    Text(
                      'Genres',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: series.genres.map((genre) {
                        return Chip(
                          label: Text(
                            genre,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          backgroundColor: const Color(0xFFF7F2FA),
                          labelStyle: const TextStyle(
                            color: Color(0xFFFF5A5F),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

