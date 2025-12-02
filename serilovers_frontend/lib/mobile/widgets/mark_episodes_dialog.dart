import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dim.dart';

/// Dialog for marking episodes as watched
class MarkEpisodesDialog extends StatefulWidget {
  final int totalEpisodes;
  final int currentEpisode;
  final String seriesTitle;

  const MarkEpisodesDialog({
    super.key,
    required this.totalEpisodes,
    required this.currentEpisode,
    required this.seriesTitle,
  });

  @override
  State<MarkEpisodesDialog> createState() => _MarkEpisodesDialogState();
}

class _MarkEpisodesDialogState extends State<MarkEpisodesDialog> {
  late TextEditingController _episodeController;
  int _selectedEpisode = 1;

  @override
  void initState() {
    super.initState();
    // Ensure selectedEpisode is valid (between 1 and totalEpisodes)
    final nextEpisode = widget.currentEpisode + 1;
    _selectedEpisode = nextEpisode.clamp(1, widget.totalEpisodes > 0 ? widget.totalEpisodes : 1);
    _episodeController = TextEditingController(text: _selectedEpisode.toString());
  }

  @override
  void dispose() {
    _episodeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.backgroundColor,
      title: Text(
        'Mark Episodes Watched',
        style: TextStyle(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.bold,
        ),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.seriesTitle,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: AppDim.paddingMedium),
            Text(
              'Current: Episode ${widget.currentEpisode} of ${widget.totalEpisodes}',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: AppDim.paddingLarge),
            Text(
              'Mark up to episode:',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: AppDim.paddingSmall),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _episodeController,
                    keyboardType: TextInputType.number,
                    style: TextStyle(color: AppColors.textPrimary),
                    decoration: InputDecoration(
                      hintText: 'Episode number',
                      hintStyle: TextStyle(color: AppColors.textSecondary),
                      filled: true,
                      fillColor: AppColors.primaryColor.withOpacity(0.1),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppDim.radiusSmall),
                        borderSide: BorderSide(color: AppColors.primaryColor),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppDim.radiusSmall),
                        borderSide: BorderSide(color: AppColors.primaryColor),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppDim.radiusSmall),
                        borderSide: BorderSide(color: AppColors.primaryColor, width: 2),
                      ),
                    ),
                    onChanged: (value) {
                      final episode = int.tryParse(value);
                      if (episode != null) {
                        setState(() {
                          _selectedEpisode = episode.clamp(1, widget.totalEpisodes);
                        });
                      }
                    },
                  ),
                ),
                const SizedBox(width: AppDim.paddingSmall),
                Text(
                  '/ ${widget.totalEpisodes}',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppDim.paddingSmall),
            // Slider for easier selection (only show if totalEpisodes > 0)
            if (widget.totalEpisodes > 0)
              Slider(
                value: _selectedEpisode.toDouble().clamp(1.0, widget.totalEpisodes.toDouble()),
                min: 1.0,
                max: widget.totalEpisodes.toDouble(),
                divisions: widget.totalEpisodes > 1 ? widget.totalEpisodes - 1 : null,
                label: 'Episode $_selectedEpisode',
                activeColor: AppColors.primaryColor,
                onChanged: (value) {
                  setState(() {
                    _selectedEpisode = value.round().clamp(1, widget.totalEpisodes);
                    _episodeController.text = _selectedEpisode.toString();
                  });
                },
              )
            else
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppDim.paddingSmall),
                child: Text(
                  'No episodes available',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 14,
                  ),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(
            'Cancel',
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ),
        ElevatedButton(
          onPressed: () {
            final episode = int.tryParse(_episodeController.text);
            if (episode != null && episode >= 1 && episode <= widget.totalEpisodes) {
              Navigator.of(context).pop(episode);
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Please enter a valid episode number (1-${widget.totalEpisodes})'),
                  backgroundColor: AppColors.dangerColor,
                ),
              );
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primaryColor,
            foregroundColor: Colors.white,
          ),
          child: const Text('Mark as Watched'),
        ),
      ],
    );
  }
}

