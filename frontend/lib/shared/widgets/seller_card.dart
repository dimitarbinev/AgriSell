import 'package:flutter/material.dart';
import '../../core/theme.dart';
import 'rating_stars.dart';

class SellerCard extends StatelessWidget {
  final String name;
  final String? photoUrl;
  final double rating;
  final String city;
  final List<String> productChips;
  final VoidCallback? onTap;

  const SellerCard({
    super.key,
    required this.name,
    this.photoUrl,
    required this.rating,
    required this.city,
    this.productChips = const [],
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: glassDecoration(),
        child: Row(
          children: [
            // Avatar
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: AppTheme.primaryGradient,
                image: photoUrl != null
                    ? DecorationImage(
                        image: NetworkImage(photoUrl!),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              child: photoUrl == null
                  ? const Icon(Icons.person, color: Colors.white, size: 28)
                  : null,
            ),
            const SizedBox(width: 14),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      RatingStars(rating: rating, size: 14),
                      const SizedBox(width: 6),
                      Text(
                        rating.toStringAsFixed(1),
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(
                        Icons.location_on_outlined,
                        size: 14,
                        color: AppTheme.accentGreen,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        city,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  if (productChips.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: productChips
                          .take(3)
                          .map(
                            (chip) => Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryGreen.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(
                                  AppTheme.radiusXLarge,
                                ),
                              ),
                              child: Text(
                                chip,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppTheme.accentGreen,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ],
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right,
              color: AppTheme.textTertiary,
            ),
          ],
        ),
      ),
    );
  }
}
