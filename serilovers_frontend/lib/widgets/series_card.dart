import 'package:flutter/material.dart';
import '../models/series.dart';
import '../core/widgets/image_with_placeholder.dart';
import '../core/theme/app_colors.dart';

/// Widget that displays a series card with title, rating, and genres
/// 
/// Styled to match the app theme with rounded corners and theme colors.
class SeriesCard extends StatelessWidget {
  final Series series;

  const SeriesCard({
    super.key,
    required this.series,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      elevation: 2,
      color: Colors.white,
      child: InkWell(
        onTap: () {
          Navigator.pushNamed(
            context,
            '/series_detail',
            arguments: series,
          );
        },
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Series Image
              if (series.imageUrl != null && series.imageUrl!.isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: ImageWithPlaceholder(
                    imageUrl: series.imageUrl,
                    height: 180,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    borderRadius: 12,
                    placeholderIcon: Icons.movie,
                    placeholderIconSize: 60,
                  ),
                ),
              if (series.imageUrl != null && series.imageUrl!.isNotEmpty)
                const SizedBox(height: 12),
              // Title and Rating Row
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title (expanded to take available space)
                  Expanded(
                    child: Text(
                      series.title,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF2D2D2D),
                          ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Rating Badge (green background, white text)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.green,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.star,
                          color: Colors.white,
                          size: 16,
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
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Genres as Wrap with small Chips
              if (series.genres.isNotEmpty)
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: series.genres.map((genre) {
                    return Chip(
                      label: Text(
                        genre,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
                      backgroundColor: const Color(0xFFF7F2FA),
                      labelStyle: const TextStyle(
                        color: Color(0xFFFF5A5F),
                      ),
                    );
                  }).toList(),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
