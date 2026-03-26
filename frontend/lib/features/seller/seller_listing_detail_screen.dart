import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/theme.dart';
import '../../shared/models/models.dart';
import '../../shared/widgets/quantity_progress_bar.dart';
import '../../shared/widgets/status_chip.dart';
import '../../shared/widgets/ai_insight_card.dart';
import '../../shared/widgets/go_decision_bar.dart';

class SellerListingDetailScreen extends StatelessWidget {
  final String listingId;
  const SellerListingDetailScreen({super.key, required this.listingId});

  @override
  Widget build(BuildContext context) {
    // TODO: Fetch from Firestore with riverpod
    final listing = _demoListing;
    final reservations = _demoReservations;
    final showGoCancel = listing.status == 'active' || listing.status == 'threshold_reached';

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
        title: const Text('Listing Details'),
        actions: [
          StatusChip(status: listing.status),
          const SizedBox(width: 16),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Product Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: glassDecoration(),
              child: Row(
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                      color: AppTheme.cardSurfaceLight,
                    ),
                    child: const Icon(Icons.eco, color: AppTheme.accentGreen, size: 32),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(listing.productName,
                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
                        const SizedBox(height: 4),
                        Row(children: [
                          const Icon(Icons.location_on_outlined, size: 14, color: AppTheme.accentGreen),
                          const SizedBox(width: 4),
                          Text(listing.city, style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
                          const SizedBox(width: 12),
                          Text(DateFormat('MMM d, y').format(listing.date),
                              style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
                        ]),
                        const SizedBox(height: 4),
                        Text('${listing.pricePerKg.toStringAsFixed(2)} лв/kg',
                            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppTheme.accentGreen)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Progress
            Container(
              padding: const EdgeInsets.all(20),
              decoration: glassDecoration(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Demand Progress', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                  const SizedBox(height: 14),
                  QuantityProgressBar(
                    current: listing.requestedQuantity,
                    target: listing.minThreshold,
                    height: 12,
                    label: '${listing.requestedQuantity.toStringAsFixed(0)} / ${listing.minThreshold.toStringAsFixed(0)} kg requested',
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Deposits: ${listing.depositsTotal.toStringAsFixed(2)} лв',
                          style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
                      Text('${listing.startTime} - ${listing.endTime}',
                          style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Reservations
            Container(
              padding: const EdgeInsets.all(20),
              decoration: glassDecoration(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Reservations (${reservations.length})',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                  const SizedBox(height: 14),
                  ...reservations.map((r) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      children: [
                        Container(
                          width: 40, height: 40,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppTheme.primaryGreen.withValues(alpha: 0.15),
                          ),
                          child: const Icon(Icons.person, size: 20, color: AppTheme.accentGreen),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(r.buyerName ?? 'Buyer', style: const TextStyle(fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                              Text('${r.quantity.toStringAsFixed(0)} kg · ${r.deposit.toStringAsFixed(2)} лв deposit',
                                  style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                            ],
                          ),
                        ),
                        StatusChip(status: r.status, small: true),
                      ],
                    ),
                  )),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // AI Price Suggestion
            AIInsightCard(
              icon: Icons.trending_up,
              title: 'Price Insight',
              body: 'Based on 12 similar listings in Sofia for Tomatoes over the last 30 days:\n\n'
                  '• Recommended: 3.20 - 3.80 лв/kg\n'
                  '• Market Average: 3.45 лв/kg\n'
                  '• Range: 2.80 - 4.20 лв/kg\n\n'
                  'Your price of ${listing.pricePerKg.toStringAsFixed(2)} лв/kg is within range.',
              confidenceLabel: 'High Confidence',
              confidenceValue: 0.85,
            ),
            const SizedBox(height: 12),

            // AI Route Suggestion
            AIInsightCard(
              icon: Icons.route,
              title: 'Route Suggestion',
              body: 'Optimized stops ranked by demand/distance:\n\n'
                  '1. Sofia — 75 kg requested (32 km)\n'
                  '2. Plovdiv — 85 kg requested (145 km)\n'
                  '3. Stara Zagora — 40 kg requested (230 km)\n\n'
                  'Expected revenue: ~680 лв\n'
                  'Estimated fuel: ~85 лв',
              confidenceLabel: 'Medium',
              confidenceValue: 0.6,
            ),
            const SizedBox(height: 100),
          ],
        ),
      ),
      bottomNavigationBar: showGoCancel
          ? GoDecisionBar(
              onGo: () {/* TODO: update Firestore */},
              onCancel: () {/* TODO: update Firestore */},
            )
          : null,
    );
  }
}

final _demoListing = Listing(
  id: '1', sellerId: 's1', productId: 'p1',
  productName: 'Fresh Tomatoes', productCategory: 'Vegetables',
  city: 'Sofia',
  date: DateTime.now().add(const Duration(days: 2)),
  startTime: '08:00', endTime: '14:00',
  pricePerKg: 3.50, availableQuantity: 200, minThreshold: 100,
  requestedQuantity: 75, depositsTotal: 187.50, status: 'active',
);

final _demoReservations = [
  Reservation(id: 'r1', buyerId: 'b1', listingId: '1', quantity: 30, deposit: 75, attendanceDate: DateTime.now(), buyerName: 'Maria Ivanova', status: 'confirmed'),
  Reservation(id: 'r2', buyerId: 'b2', listingId: '1', quantity: 25, deposit: 62.50, attendanceDate: DateTime.now(), buyerName: 'Georgi Dimitrov', status: 'pending'),
  Reservation(id: 'r3', buyerId: 'b3', listingId: '1', quantity: 20, deposit: 50, attendanceDate: DateTime.now(), buyerName: 'Elena Todorova', status: 'confirmed'),
];
