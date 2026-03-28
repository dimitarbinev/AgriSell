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
                  // Product image - фиксиран размер, за да не "играе" интерфейсът
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
                  
                  // Основна информация - Expanded заема останалото място
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                              child: Text(
                                listing.productName,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            // StatusChip е малък, но го пазим да не прелее
                            StatusChip(status: listing.status, small: true),
                          ],
                        ),
                        const SizedBox(height: 6),
                        
                        // Секция Продавач
                        if (showSellerInfo && listing.sellerName != null) ...[
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  listing.sellerName!,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.white.withValues(alpha: 0.7),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (listing.sellerRating != null) ...[
                                const SizedBox(width: 6),
                                RatingStars(
                                  rating: listing.sellerRating!,
                                  size: 10,
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 6),
                        ],

                        // Локация и Дати
                        Row(
                          children: [
                            const Icon(
                              Icons.location_on_outlined,
                              size: 14,
                              color: AppTheme.accentGreen,
                            ),
                            const SizedBox(width: 3),
                            Flexible(
                              child: Text(
                                listing.city,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.accentGreen,
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            // Датите в малък контейнер с FittedBox за защита
                            Flexible(
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppTheme.primaryGreen.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    '${DateFormat('dd.MM').format(listing.startDate)} - ${DateFormat('dd.MM').format(listing.endDate)}',
                                    style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: AppTheme.accentGreen,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        
                        // Цена
                        Text(
                          '${listing.pricePerKg.toStringAsFixed(2)} лв/кг',
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
            
            // Progress bar - подсигурен с Padding
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
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
      case 'зеленчуци':
      case 'vegetables':
        return Icons.eco;
      case 'плодове':
      case 'fruits':
        return Icons.apple;
      case 'зърнени':
      case 'grains':
        return Icons.grain;
      case 'млечни':
      case 'dairy':
        return Icons.water_drop;
      case 'билки':
      case 'herbs':
        return Icons.local_florist;
      case 'месо':
      case 'meat':
        return Icons.restaurant;
      case 'яйца':
      case 'eggs':
        return Icons.egg;
      default:
        return Icons.shopping_basket;
    }
  }
}