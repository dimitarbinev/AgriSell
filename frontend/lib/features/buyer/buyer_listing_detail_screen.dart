import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/theme.dart';
import '../../shared/models/models.dart';
import '../../shared/widgets/quantity_progress_bar.dart';
import '../../shared/widgets/ai_insight_card.dart';
import '../../shared/widgets/rating_stars.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../shared/providers/providers.dart';

class BuyerListingDetailScreen extends ConsumerStatefulWidget {
  final String listingId;
  const BuyerListingDetailScreen({super.key, required this.listingId});

  @override
  ConsumerState<BuyerListingDetailScreen> createState() => _BuyerListingDetailScreenState();
}

class _BuyerListingDetailScreenState extends ConsumerState<BuyerListingDetailScreen> {
  final _quantityController = TextEditingController();
  final _depositController = TextEditingController();
  DateTime? _attendanceDate;

  @override
  void dispose() {
    _quantityController.dispose();
    _depositController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final listingsAsync = ref.watch(activeListingsProvider);

    return listingsAsync.when(
      data: (listings) {
        final listing = listings.cast<Listing?>().firstWhere(
          (l) => l?.id == widget.listingId,
          orElse: () => null,
        );

        if (listing == null) {
          return const Scaffold(body: Center(child: Text('Listing not found')));
        }

        return Scaffold(
          body: CustomScrollView(
            slivers: [
              // Product Image Header
              SliverAppBar(
                expandedHeight: 240,
                pinned: true,
                backgroundColor: AppTheme.darkBackground,
                leading: IconButton(
                  icon:     Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.4),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                  ),
                  onPressed: () => context.go('/buyer/home'),
                ),
                flexibleSpace: FlexibleSpaceBar(
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              AppTheme.primaryGreen.withValues(alpha: 0.3),
                              AppTheme.darkBackground,
                            ],
                          ),
                        ),
                        child: const Icon(Icons.eco, size: 80, color: AppTheme.accentGreen),
                      ),
                      Positioned(
                        bottom: 20, left: 20, right: 20,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryGreen.withValues(alpha: 0.8),
                                borderRadius: BorderRadius.circular(AppTheme.radiusXLarge),
                              ),
                              child: Text(listing.productCategory,
                                  style: const TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.w600)),
                            ),
                            const SizedBox(height: 8),
                            Text(listing.productName,
                                style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: Colors.white)),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                const Icon(Icons.location_on_outlined, size: 14, color: AppTheme.accentGreen),
                                const SizedBox(width: 4),
                                Text(listing.city,
                                    style: const TextStyle(fontSize: 13, color: Colors.white70)),
                                const SizedBox(width: 12),
                                const Icon(Icons.calendar_today, size: 12, color: Colors.white70),
                                const SizedBox(width: 4),
                                Text(DateFormat('MMM d, y').format(listing.date),
                                    style: const TextStyle(fontSize: 13, color: Colors.white70)),
                                const SizedBox(width: 12),
                                const Icon(Icons.access_time, size: 12, color: Colors.white70),
                                const SizedBox(width: 4),
                                Text('${listing.startTime} - ${listing.endTime}',
                                    style: const TextStyle(fontSize: 13, color: Colors.white70)),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Seller Info Row
                      GestureDetector(
                        onTap: () => context.go('/buyer/seller/${listing.sellerId}'),
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: glassDecoration(),
                          child: Row(
                            children: [
                              Container(
                                width: 44, height: 44,
                                decoration: BoxDecoration(shape: BoxShape.circle, gradient: AppTheme.primaryGradient),
                                child: const Icon(Icons.person, color: Colors.white, size: 22),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(listing.sellerName ?? 'Seller',
                                        style: const TextStyle(fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                                    Row(children: [
                                      RatingStars(rating: listing.sellerRating ?? 0, size: 14),
                                      const SizedBox(width: 6),
                                      const Icon(Icons.location_on_outlined, size: 13, color: AppTheme.accentGreen),
                                      const SizedBox(width: 2),
                                      Text(listing.city, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                                    ]),
                                  ],
                                ),
                              ),
                              const Icon(Icons.chevron_right, color: AppTheme.textTertiary),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Price
                      Text('${listing.pricePerKg.toStringAsFixed(2)} лв/kg',
                          style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: AppTheme.accentGreen)),
                      const SizedBox(height: 16),

                      // Info Grid
                      GridView.count(
                        crossAxisCount: 2,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        mainAxisSpacing: 10, crossAxisSpacing: 10,
                        childAspectRatio: 2.2,
                        children: [
                          _InfoTile(label: 'Origin', value: listing.city),
                          _InfoTile(label: 'Category', value: listing.productCategory),
                          _InfoTile(label: 'Remaining', value: '${(listing.availableQuantity - listing.requestedQuantity).toStringAsFixed(0)} kg'),
                          _InfoTile(label: 'Goal', value: '${listing.minThreshold.toStringAsFixed(0)} kg'),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Date/Time
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: glassDecoration(),
                        child: Row(
                          children: [
                            const Icon(Icons.calendar_today, size: 18, color: AppTheme.accentGreen),
                            const SizedBox(width: 10),
                            Text(DateFormat('EEEE, MMM d').format(listing.date),
                                style: const TextStyle(fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                            const Spacer(),
                            Text('${listing.startTime} - ${listing.endTime}',
                                style: const TextStyle(color: AppTheme.textSecondary)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Quantity Progress
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: glassDecoration(),
                        child: QuantityProgressBar(
                          current: listing.requestedQuantity,
                          target: listing.minThreshold,
                          height: 12,
                          label: '${listing.requestedQuantity.toStringAsFixed(0)} / ${listing.minThreshold.toStringAsFixed(0)} kg target',
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Reserve Form
                      const Text('Make a Reservation',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: glassDecoration(),
                        child: Column(
                          children: [
                            TextField(
                              controller: _quantityController,
                              keyboardType: TextInputType.number,
                              style: const TextStyle(color: AppTheme.textPrimary),
                              decoration: const InputDecoration(
                                labelText: 'Quantity (kg)',
                                prefixIcon: Icon(Icons.scale, size: 20),
                              ),
                            ),
                            const SizedBox(height: 14),
                            TextField(
                              controller: _depositController,
                              keyboardType: TextInputType.number,
                              style: const TextStyle(color: AppTheme.textPrimary),
                              decoration: const InputDecoration(
                                labelText: 'Deposit Amount (лв)',
                                prefixIcon: Icon(Icons.payments_outlined, size: 20),
                              ),
                            ),
                            const SizedBox(height: 14),
                            GestureDetector(
                              onTap: () async {
                                final d = await showDatePicker(
                                  context: context,
                                  initialDate: listing.date,
                                  firstDate: DateTime.now(),
                                  lastDate: listing.date,
                                );
                                if (d != null) setState(() => _attendanceDate = d);
                              },
                              child: InputDecorator(
                                decoration: const InputDecoration(
                                  labelText: 'Attendance Date',
                                  prefixIcon: Icon(Icons.event, size: 20),
                                ),
                                child: Text(
                                  _attendanceDate != null ? DateFormat('MMM d, y').format(_attendanceDate!) : 'Select date',
                                  style: TextStyle(
                                    color: _attendanceDate != null ? AppTheme.textPrimary : AppTheme.textTertiary,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),
                            SizedBox(
                              width: double.infinity, height: 52,
                              child:     Container(
                                decoration: BoxDecoration(
                                  gradient: AppTheme.primaryGradient,
                                  borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                                ),
                                child: ElevatedButton.icon(
                                  onPressed: () {/* TODO: submit */},
                                  icon: const Icon(Icons.check_circle_outline),
                                  label: const Text('Submit Reservation'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.transparent,
                                    shadowColor: Colors.transparent,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // AI Insight
                      AIInsightCard(
                        icon: Icons.trending_up,
                        title: 'Price Insight',
                        body: 'This price of ${listing.pricePerKg.toStringAsFixed(2)} лв/kg is competitive for ${listing.city}.',
                        confidenceLabel: 'High',
                        confidenceValue: 0.82,
                      ),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (err, _) => Scaffold(body: Center(child: Text('Error: $err'))),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final String label, value;
  const _InfoTile({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: glassDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(label, style: const TextStyle(fontSize: 11, color: AppTheme.textTertiary)),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
        ],
      ),
    );
  }
}
