import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme.dart';
import '../../shared/models/models.dart';
import '../../shared/widgets/rating_stars.dart';
import '../../shared/widgets/listing_card.dart';
import '../../shared/providers/providers.dart';

class BuyerSellerProfileScreen extends ConsumerWidget {
  final String sellerId;
  const BuyerSellerProfileScreen({super.key, required this.sellerId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(sellerProfileProvider(sellerId));

    return profileAsync.when(
      data: (data) {
        final profile = data['profile'];
        final List<dynamic> listingsData = data['listings'];
        final listings = listingsData.map((l) => Listing.fromJson(l, l['id'] ?? '')).toList();
        final List<dynamic> reviewsData = data['reviews'] ?? [];
        final reviews = reviewsData.map((r) => Review.fromJson(r, r['id'] ?? '')).toList();

        return Scaffold(
          appBar: AppBar(
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_rounded),
              onPressed: () => context.go('/buyer/home'),
            ),
            title: const Text('Seller Profile'),
            actions: [
              Consumer(
                builder: (context, ref, child) {
                  final savedSellersAsync = ref.watch(savedSellersProvider);
                  return savedSellersAsync.when(
                    data: (ids) {
                      final isSaved = ids.contains(sellerId);
                      return IconButton(
                        icon: Icon(
                          isSaved ? Icons.favorite : Icons.favorite_border,
                          color: isSaved ? AppTheme.statusCancelled : null,
                        ),
                        onPressed: () async {
                          try {
                            await ref.read(productServiceProvider).toggleSaveSeller(sellerId);
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Error: $e')),
                              );
                            }
                          }
                        },
                      );
                    },
                    loading: () => const SizedBox.shrink(),
                    error: (_, __) => const SizedBox.shrink(),
                  );
                },
              ),
              const SizedBox(width: 8),
            ],
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
                Text(profile['name'] ?? 'Seller', 
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    RatingStars(rating: (profile['rating'] as num?)?.toDouble() ?? 0.0, size: 18),
                    const SizedBox(width: 8),
                    Text(profile['rating']?.toStringAsFixed(1) ?? '0.0', 
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                    const SizedBox(width: 4),
                    Text('(${profile['reviewCount'] ?? 0} reviews)', 
                        style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.location_on_outlined, size: 14, color: AppTheme.accentGreen),
                    const SizedBox(width: 4),
                    Text(profile['mainCity'] ?? 'Unknown', 
                        style: const TextStyle(fontSize: 14, color: AppTheme.textSecondary)),
                  ],
                ),
                const SizedBox(height: 24),

                // Active Listings
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Active Listings', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                ),
                const SizedBox(height: 12),
                if (listings.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Text('No active listings found', style: TextStyle(color: AppTheme.textTertiary)),
                  )
                else
                  ...listings.map((l) => ListingCard(
                    listing: l,
                    showSellerInfo: false,
                    onTap: () => context.go('/buyer/listing/${l.id}'),
                  )),
                const SizedBox(height: 24),

                // Reviews
                if (reviews.isNotEmpty) ...[
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Reviews', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                  ),
                  const SizedBox(height: 12),
                  ...reviews.map((r) => Container(
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
              ],
            ),
          ),
        );
      },
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (err, _) => Scaffold(body: Center(child: Text('Error: $err'))),
    );
  }
}
