import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class RatingWidget extends StatelessWidget {
  final double rating;
  final int totalRatings;
  final double size;
  final bool showText;
  final Color? color;

  const RatingWidget({
    super.key,
    required this.rating,
    this.totalRatings = 0,
    this.size = 20,
    this.showText = true,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final starColor = color ?? AppColors.accentColor;
    
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ...List.generate(5, (index) {
          if (index < rating.floor()) {
            return Icon(
              Icons.star,
              size: size,
              color: starColor,
            );
          } else if (index < rating) {
            return Icon(
              Icons.star_half,
              size: size,
              color: starColor,
            );
          } else {
            return Icon(
              Icons.star_border,
              size: size,
              color: starColor.withOpacity(0.3),
            );
          }
        }),
        if (showText) ...[
          const SizedBox(width: 8),
          Text(
            rating.toStringAsFixed(1),
            style: TextStyle(
              fontSize: size * 0.7,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          if (totalRatings > 0) ...[
            const SizedBox(width: 4),
            Text(
              '($totalRatings)',
              style: TextStyle(
                fontSize: size * 0.6,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ],
      ],
    );
  }
}

class InteractiveRatingWidget extends StatefulWidget {
  final double initialRating;
  final Function(double) onRatingChanged;
  final double size;
  final Color? color;
  final bool allowHalfRating;

  const InteractiveRatingWidget({
    super.key,
    this.initialRating = 0,
    required this.onRatingChanged,
    this.size = 32,
    this.color,
    this.allowHalfRating = false,
  });

  @override
  State<InteractiveRatingWidget> createState() => _InteractiveRatingWidgetState();
}

class _InteractiveRatingWidgetState extends State<InteractiveRatingWidget> {
  late double _rating;

  @override
  void initState() {
    super.initState();
    _rating = widget.initialRating;
  }

  void _updateRating(double localPosition, double starWidth) {
    double newRating;
    
    if (widget.allowHalfRating) {
      final starIndex = (localPosition / starWidth).floor();
      final fraction = (localPosition % starWidth) / starWidth;
      
      if (fraction < 0.5) {
        newRating = starIndex + 0.5;
      } else {
        newRating = starIndex + 1.0;
      }
    } else {
      newRating = (localPosition / starWidth).ceil().toDouble();
    }
    
    newRating = newRating.clamp(0.0, 5.0);
    
    if (newRating != _rating) {
      setState(() {
        _rating = newRating;
      });
      widget.onRatingChanged(newRating);
    }
  }

  @override
  Widget build(BuildContext context) {
    final starColor = widget.color ?? AppColors.accentColor;
    final starWidth = widget.size + 4; // Include padding
    
    return GestureDetector(
      onTapDown: (details) {
        _updateRating(details.localPosition.dx, starWidth);
      },
      onHorizontalDragUpdate: (details) {
        _updateRating(details.localPosition.dx, starWidth);
      },
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(5, (index) {
          Widget star;
          
          if (index < _rating.floor()) {
            star = Icon(
              Icons.star,
              size: widget.size,
              color: starColor,
            );
          } else if (index < _rating && widget.allowHalfRating) {
            star = Icon(
              Icons.star_half,
              size: widget.size,
              color: starColor,
            );
          } else {
            star = Icon(
              Icons.star_border,
              size: widget.size,
              color: starColor.withOpacity(0.3),
            );
          }
          
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: star,
          );
        }),
      ),
    );
  }
}

class RatingBarIndicator extends StatelessWidget {
  final double rating;
  final int totalRatings;
  final Map<int, int> ratingDistribution;

  const RatingBarIndicator({
    super.key,
    required this.rating,
    required this.totalRatings,
    required this.ratingDistribution,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              rating.toStringAsFixed(1),
              style: const TextStyle(
                fontSize: 48,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RatingWidget(
                  rating: rating,
                  showText: false,
                  size: 24,
                ),
                const SizedBox(height: 4),
                Text(
                  '$totalRatings reviews',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 24),
        ...List.generate(5, (index) {
          final starCount = 5 - index;
          final count = ratingDistribution[starCount] ?? 0;
          final percentage = totalRatings > 0 ? count / totalRatings : 0.0;
          
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Text(
                  '$starCount',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(
                  Icons.star,
                  size: 16,
                  color: AppColors.accentColor,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Container(
                    height: 8,
                    decoration: BoxDecoration(
                      color: AppColors.borderColor,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: percentage,
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppColors.accentColor,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 30,
                  child: Text(
                    count.toString(),
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                    textAlign: TextAlign.right,
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}