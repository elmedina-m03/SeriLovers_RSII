import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/episode_review.dart';
import '../providers/episode_review_provider.dart';
import '../core/theme/app_colors.dart';
import '../services/api_service.dart';
import 'add_episode_review_screen.dart';

class EpisodeReviewsScreen extends StatefulWidget {
  final int episodeId;
  final String? episodeTitle;
  final int episodeNumber;
  final int seasonNumber;
  final String? seriesTitle;

  const EpisodeReviewsScreen({
    super.key,
    required this.episodeId,
    this.episodeTitle,
    required this.episodeNumber,
    required this.seasonNumber,
    this.seriesTitle,
  });

  @override
  State<EpisodeReviewsScreen> createState() => _EpisodeReviewsScreenState();
}

class _EpisodeReviewsScreenState extends State<EpisodeReviewsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadReviews();
    });
  }

  Future<void> _loadReviews() async {
    final provider = Provider.of<EpisodeReviewProvider>(context, listen: false);
    await provider.loadEpisodeReviews(widget.episodeId);
    await provider.loadMyReview(widget.episodeId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Reviews',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Consumer<EpisodeReviewProvider>(
        builder: (context, provider, child) {
          if (provider.loading) {
            return const Center(child: CircularProgressIndicator());
          }

          final reviews = provider.getEpisodeReviews(widget.episodeId);
          final myReview = provider.getMyReview(widget.episodeId);

          return Column(
            children: [
              Expanded(
                child: reviews.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.reviews,
                              size: 64,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No reviews yet',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Be the first to review this episode!',
                              style: TextStyle(
                                color: Colors.grey[500],
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: reviews.length,
                        itemBuilder: (context, index) {
                          final review = reviews[index];
                          return _ReviewCard(review: review);
                        },
                      ),
              ),
              // Add review button
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => AddEpisodeReviewScreen(
                            episodeId: widget.episodeId,
                            episodeTitle: widget.episodeTitle,
                            episodeNumber: widget.episodeNumber,
                            seasonNumber: widget.seasonNumber,
                            seriesTitle: widget.seriesTitle,
                            existingReview: myReview,
                          ),
                        ),
                      );
                      if (result == true) {
                        _loadReviews();
                      }
                    },
                    icon: Icon(
                      myReview != null ? Icons.edit : Icons.add,
                      color: AppColors.textLight,
                    ),
                    label: Text(
                      myReview != null ? 'Edit your review' : 'Add your review',
                      style: const TextStyle(
                        color: AppColors.textLight,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryColor,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ReviewCard extends StatelessWidget {
  final EpisodeReview review;

  const _ReviewCard({required this.review});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Avatar
                CircleAvatar(
                  radius: 20,
                  backgroundColor: AppColors.primaryColor.withOpacity(0.2),
                  backgroundImage: review.userAvatarUrl != null &&
                          review.userAvatarUrl!.isNotEmpty
                      ? NetworkImage(
                          ApiService.convertToHttpUrl(review.userAvatarUrl!) ?? review.userAvatarUrl!,
                        )
                      : null,
                  child: review.userAvatarUrl == null ||
                          review.userAvatarUrl!.isEmpty
                      ? Text(
                          (review.userName ?? 'U')[0].toUpperCase(),
                          style: const TextStyle(
                            color: AppColors.primaryColor,
                            fontWeight: FontWeight.bold,
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        review.userName ?? 'Anonymous',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        _formatDate(review.createdAt),
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                // Star rating
                Row(
                  children: List.generate(5, (index) {
                    return Icon(
                      index < review.rating ? Icons.star : Icons.star_border,
                      color: Colors.amber,
                      size: 20,
                    );
                  }),
                ),
              ],
            ),
            if (review.reviewText != null &&
                review.reviewText!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                review.reviewText!,
                style: const TextStyle(fontSize: 14, height: 1.5),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December'
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }
}

