import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme.dart';
import '../../shared/models/models.dart';
import '../../shared/widgets/rating_stars.dart';
import '../../shared/widgets/listing_card.dart';

class BuyerSellerProfileScreen extends StatelessWidget {
  final String sellerId;
  const BuyerSellerProfileScreen({super.key, required this.sellerId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
        title: const Text('Seller Profile'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Avatar & info
            Container(
              width: 80, height: 80,
              decoration: BoxDecoration(shape: BoxShape.circle, gradient: AppTheme.primaryGradient),
              child: const Icon(Icons.person, color: Colors.white, size: 40),
            ),
            const SizedBox(height: 14),
            const Text('Ivan Petrov', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const RatingStars(rating: 4.7, size: 18),
                const SizedBox(width: 8),
                const Text('4.7', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                const SizedBox(width: 4),
                const Text('(23 reviews)', style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
              ],
            ),
            const SizedBox(height: 6),
            const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.location_on_outlined, size: 14, color: AppTheme.accentGreen),
                SizedBox(width: 4),
                Text('Sofia', style: TextStyle(fontSize: 14, color: AppTheme.textSecondary)),
              ],
            ),
            const SizedBox(height: 24),

            // Active Listings
            const Align(
              alignment: Alignment.centerLeft,
              child: Text('Active Listings', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
            ),
            const SizedBox(height: 12),
            ..._sellerListings.map((l) => ListingCard(
              listing: l,
              showSellerInfo: false,
              onTap: () => context.go('/buyer/listing/${l.id}'),
            )),
            const SizedBox(height: 24),

            // Reviews
            const Align(
              alignment: Alignment.centerLeft,
              child: Text('Reviews', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
            ),
            const SizedBox(height: 12),
            ..._reviews.map((r) => Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: glassDecoration(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(r.buyerName ?? 'Anonymous', style: const TextStyle(fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                      const Spacer(),
                      RatingStars(rating: r.rating, size: 14),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(r.comment, style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary, height: 1.4)),
                ],
              ),
            )),
          ],
        ),
      ),
    );
  }
}

final _sellerListings = [
  Listing(id: '1', sellerId: 's1', productId: 'p1', productName: 'Fresh Tomatoes', productCategory: 'Vegetables', city: 'Sofia',
    date: DateTime.now().add(const Duration(days: 2)), startTime: '08:00', endTime: '14:00',
    pricePerKg: 3.50, availableQuantity: 200, minThreshold: 100, requestedQuantity: 75, status: 'active'),
  Listing(id: '2', sellerId: 's1', productId: 'p2', productName: 'Organic Apples', productCategory: 'Fruits', city: 'Plovdiv',
    date: DateTime.now().add(const Duration(days: 3)), startTime: '09:00', endTime: '15:00',
    pricePerKg: 2.80, availableQuantity: 150, minThreshold: 80, requestedQuantity: 85, status: 'threshold_reached'),
];

final _reviews = [
  Review(id: 'r1', buyerId: 'b1', sellerId: 's1', rating: 5, comment: 'Excellent quality tomatoes! Very fresh and the seller was on time.', createdAt: DateTime.now().subtract(const Duration(days: 3)), buyerName: 'Maria Ivanova'),
  Review(id: 'r2', buyerId: 'b2', sellerId: 's1', rating: 4, comment: 'Good products, reasonable prices. Would buy again.', createdAt: DateTime.now().subtract(const Duration(days: 7)), buyerName: 'Georgi Dimitrov'),
  Review(id: 'r3', buyerId: 'b3', sellerId: 's1', rating: 5, comment: 'Best honey in the region! Highly recommended.', createdAt: DateTime.now().subtract(const Duration(days: 14)), buyerName: 'Elena Todorova'),
];
