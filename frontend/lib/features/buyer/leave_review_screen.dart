import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme.dart';
import '../../shared/widgets/rating_stars.dart';

class LeaveReviewScreen extends StatefulWidget {
  final String sellerId;
  const LeaveReviewScreen({super.key, required this.sellerId});

  @override
  State<LeaveReviewScreen> createState() => _LeaveReviewScreenState();
}

class _LeaveReviewScreenState extends State<LeaveReviewScreen> {
  double _rating = 0;
  final _commentController = TextEditingController();

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
        title: const Text('Leave Review'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Seller info header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: glassDecoration(),
              child: const Column(
                children: [
                  Icon(Icons.storefront_rounded, size: 48, color: AppTheme.accentGreen),
                  SizedBox(height: 12),
                  Text('How was your experience?',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                  SizedBox(height: 4),
                  Text('Your feedback helps other buyers',
                      style: TextStyle(fontSize: 14, color: AppTheme.textSecondary)),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Rating
            const Center(
              child: Text('Tap to rate', style: TextStyle(fontSize: 14, color: AppTheme.textSecondary)),
            ),
            const SizedBox(height: 12),
            Center(
              child: RatingStars(
                rating: _rating,
                size: 40,
                interactive: true,
                onRatingChanged: (r) => setState(() => _rating = r),
              ),
            ),
            if (_rating > 0) ...[
              const SizedBox(height: 8),
              Center(
                child: Text(
                  _getRatingLabel(_rating),
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppTheme.accentGreen),
                ),
              ),
            ],
            const SizedBox(height: 28),

            // Comment
            TextField(
              controller: _commentController,
              maxLines: 5,
              style: const TextStyle(color: AppTheme.textPrimary),
              decoration: const InputDecoration(
                hintText: 'Share your experience (optional)...',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 28),

            Container(
              height: 52,
              decoration: BoxDecoration(
                gradient: _rating > 0 ? AppTheme.primaryGradient : null,
                color: _rating == 0 ? AppTheme.cardSurfaceLight : null,
                borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
              ),
              child: ElevatedButton(
                onPressed: _rating > 0 ? () {
                  // TODO: Submit to Firestore
                  context.pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('Review submitted! Thank you.'),
                      backgroundColor: AppTheme.primaryGreen,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusMedium)),
                    ),
                  );
                } : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  disabledBackgroundColor: Colors.transparent,
                ),
                child: const Text('Submit Review'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getRatingLabel(double rating) {
    switch (rating.toInt()) {
      case 1: return 'Poor';
      case 2: return 'Fair';
      case 3: return 'Good';
      case 4: return 'Very Good';
      case 5: return 'Excellent!';
      default: return '';
    }
  }
}
