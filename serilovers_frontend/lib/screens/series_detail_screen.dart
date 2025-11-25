import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/series.dart';
import '../providers/watchlist_provider.dart';
import '../services/api_service.dart';

/// Screen that displays detailed information about a series
class SeriesDetailScreen extends StatefulWidget {
  final Series series;

  const SeriesDetailScreen({
    super.key,
    required this.series,
  });

  @override
  State<SeriesDetailScreen> createState() => _SeriesDetailScreenState();
}

class _SeriesDetailScreenState extends State<SeriesDetailScreen> {
  @override
  void initState() {
    super.initState();
    // Load watchlist to check if series is already added
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final watchlistProvider = Provider.of<WatchlistProvider>(context, listen: false);
      if (watchlistProvider.items.isEmpty) {
        watchlistProvider.loadWatchlist().catchError((error) {
          // Silently fail - watchlist will be checked when button is pressed
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.series.title),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Placeholder image with rounded corners
            Container(
              width: double.infinity,
              height: 250,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                Icons.movie,
                size: 64,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 24),

            // Rating badge
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                        size: 20,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        widget.series.rating.toStringAsFixed(1),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                // Additional info chips
                if (widget.series.ratingsCount > 0)
                  _InfoChip(
                    icon: Icons.star_outline,
                    label: '${widget.series.ratingsCount} ratings',
                  ),
                const SizedBox(width: 8),
                if (widget.series.watchlistsCount > 0)
                  _InfoChip(
                    icon: Icons.bookmark_outline,
                    label: '${widget.series.watchlistsCount} watchlists',
                  ),
              ],
            ),
            const SizedBox(height: 24),

            // Series description
            if (widget.series.description != null && widget.series.description!.isNotEmpty) ...[
              Text(
                'Description',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                widget.series.description!,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 24),
            ],

            // Genres as Wrap with chips
            if (widget.series.genres.isNotEmpty) ...[
              Text(
                'Genres',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: widget.series.genres.map((genre) {
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
              const SizedBox(height: 24),
            ],

            // Actors section
            if (widget.series.actors.isNotEmpty) ...[
              Text(
                'Actors',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 12),
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: widget.series.actors.length,
                separatorBuilder: (context, index) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final actor = widget.series.actors[index];
                  return Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.grey[200]!,
                      ),
                    ),
                    child: Row(
                      children: [
                        // Actor avatar placeholder
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF7F2FA),
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: const Icon(
                            Icons.person,
                            color: Color(0xFFFF5A5F),
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Actor name
                        Expanded(
                          child: Text(
                            actor.fullName,
                            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                  fontWeight: FontWeight.w500,
                                ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
            const SizedBox(height: 32),
            // Add to Watchlist Button
            Consumer<WatchlistProvider>(
              builder: (context, watchlistProvider, child) {
                final isInWatchlist = watchlistProvider.isInWatchlist(widget.series.id);
                
                return SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: isInWatchlist
                        ? null // Disable button if already in watchlist
                        : () async {
                            try {
                              await watchlistProvider.addToWatchlist(widget.series.id);
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Added to watchlist'),
                                    backgroundColor: Colors.green,
                                    duration: Duration(seconds: 2),
                                  ),
                                );
                              }
                            } catch (e) {
                              if (mounted) {
                                // Extract error message
                                String errorMessage = 'Failed to add to watchlist';
                                if (e is ApiException) {
                                  errorMessage = e.message;
                                } else {
                                  errorMessage = e.toString();
                                }
                                
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(errorMessage),
                                    backgroundColor: Colors.orange,
                                    duration: const Duration(seconds: 3),
                                  ),
                                );
                              }
                            }
                          },
                    icon: Icon(isInWatchlist ? Icons.bookmark : Icons.bookmark_add),
                    label: Text(isInWatchlist ? 'Already in Watchlist' : 'Add to Watchlist'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

/// Helper widget for displaying info chips
class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoChip({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F2FA),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 16,
            color: const Color(0xFFFF5A5F),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFFFF5A5F),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

