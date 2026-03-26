import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/theme.dart';
import '../../shared/models/models.dart';
import 'quantity_progress_bar.dart';
import 'rating_stars.dart';
import 'status_chip.dart';

class ListingCard extends StatelessWidget {
  final Listing listing;
  final VoidCallback? onTap;
  final bool showSellerInfo;

  const ListingCard({
    super.key,
    required this.listing,
    this.onTap,
    this.showSellerInfo = true,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: glassDecoration(),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Product image
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                      color: AppTheme.cardSurfaceLight,
                      image: listing.productImageUrl != null
                          ? DecorationImage(
                              image: NetworkImage(listing.productImageUrl!),
                              fit: BoxFit.cover,
                            )
                          : null,
                    ),
                    child: listing.productImageUrl == null
                        ? Icon(
                            _getCategoryIcon(listing.productCategory),
                            color: AppTheme.accentGreen,
                            size: 32,
                          )
                        : null,
                  ),
                  const SizedBox(width: 14),
                  // Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                listing.productName,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.textPrimary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            StatusChip(status: listing.status, small: true),
                          ],
                        ),
                        const SizedBox(height: 4),
                        if (showSellerInfo && listing.sellerName != null) ...[
                          Row(
                            children: [
                              Text(
                                listing.sellerName!,
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                              if (listing.sellerRating != null) ...[
                                const SizedBox(width: 8),
                                RatingStars(
                                  rating: listing.sellerRating!,
                                  size: 12,
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 4),
                        ],
                        Row(
                          children: [
                            const Icon(
                              Icons.location_on_outlined,
                              size: 14,
                              color: AppTheme.accentGreen,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              listing.city,
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryGreen.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                DateFormat('MMM d').format(listing.date),
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.accentGreen,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${listing.pricePerKg.toStringAsFixed(2)} лв/kg',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.accentGreen,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Progress bar
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              child: QuantityProgressBar(
                current: listing.requestedQuantity,
                target: listing.minThreshold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'vegetables':
        return Icons.eco;
      case 'fruits':
        return Icons.apple;
      case 'grains':
        return Icons.grain;
      case 'dairy':
        return Icons.water_drop;
      case 'herbs':
        return Icons.local_florist;
      case 'meat':
        return Icons.restaurant;
      case 'eggs':
        return Icons.egg;
      default:
        return Icons.shopping_basket;
    }
  }
}
