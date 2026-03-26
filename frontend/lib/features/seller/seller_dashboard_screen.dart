import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme.dart';
import '../../shared/widgets/listing_card.dart';
import '../../shared/models/models.dart';
import '../../shared/providers/providers.dart';

class SellerDashboardScreen extends ConsumerWidget {
  const SellerDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authStateProvider).value;
    if (user == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final userId = user.uid;

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddMenu(context),
        backgroundColor: AppTheme.primaryGreen,
        icon: const Icon(Icons.add),
        label: const Text('New Session'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: AppTheme.primaryGradient,
                    ),
                    child: const Icon(Icons.person, color: Colors.white, size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Good Morning',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                        ref.watch(reactiveSellerProvider).when(
                          data: (seller) => Text(
                            seller?.name ?? 'Seller',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          loading: () => const Text(
                            '...',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          error: (_, __) => const Text(
                            'Seller',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  _NotifBell(onTap: () => context.go('/notifications')),
                ],
              ),
              const SizedBox(height: 28),

              // Summary Cards
              ref.watch(sellerListingsProvider(userId)).when(
                data: (listings) {
                  final activeCount = listings.where((l) => l.status == 'active' || l.status == 'confirmed').length;
                  final totalRequested = listings.fold<double>(0, (sum, l) => sum + l.requestedQuantity);
                  final pendingDecisions = listings.where((l) => (l.status == 'threshold_reached' || l.status == 'active') && l.requestedQuantity >= l.minThreshold).length;

                  return Column(
                    children: [
                      GridView.count(
                        crossAxisCount: 2,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        childAspectRatio: 1.5,
                        children: [
                          _MetricCard(
                            icon: Icons.storefront_rounded,
                            iconColor: AppTheme.statusActive,
                            label: 'Active Listings',
                            value: '$activeCount',
                          ),
                          _MetricCard(
                            icon: Icons.inventory_2_rounded,
                            iconColor: AppTheme.accentGreen,
                            label: 'Requested Qty',
                            value: '${totalRequested.toStringAsFixed(0)} kg',
                          ),
                          _MetricCard(
                            icon: Icons.pending_actions_rounded,
                            iconColor: AppTheme.statusThresholdReached,
                            label: 'Pending Decisions',
                            value: '$pendingDecisions',
                          ),
                          _MetricCard(
                            icon: Icons.star_rounded,
                            iconColor: AppTheme.statusThresholdReached,
                            label: 'Avg Rating',
                            value: ref.watch(reactiveSellerProvider).maybeWhen(
                              data: (s) => (s?.rating ?? 0.0).toStringAsFixed(1),
                              orElse: () => '0.0',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 28),

                      // Quick Actions
                      Row(
                        children: [
                          Expanded(
                            child: _QuickAction(
                              icon: Icons.add_circle_outline,
                              label: 'Add Product',
                              onTap: () => context.go('/seller/add-product'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _QuickAction(
                              icon: Icons.post_add_rounded,
                              label: 'New Listing',
                              onTap: () => context.go('/seller/create-listing'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 28),

                      // Recent Activity
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Upcoming Activity',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      () {
                        final today = DateTime.now();
                        final startOfToday = DateTime(today.year, today.month, today.day);
                        
                        final sortedListings = listings
                            .where((l) => l.date.isAfter(startOfToday.subtract(const Duration(seconds: 1))))
                            .toList();
                            
                        sortedListings.sort((a, b) => a.date.compareTo(b.date));
                        
                        if (sortedListings.isEmpty) {
                          return const Center(
                            child: Padding(
                              padding: EdgeInsets.symmetric(vertical: 20),
                              child: Text('No upcoming activity', style: TextStyle(color: AppTheme.textSecondary)),
                            ),
                          );
                        }
                        
                        return Column(
                          children: sortedListings.take(3).map(
                            (listing) => ListingCard(
                              listing: listing,
                              showSellerInfo: false,
                              onTap: () => context.go('/seller/listing/${listing.id}'),
                            ),
                          ).toList(),
                        );
                      }(),
                    ],
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, stack) => Center(child: Text('Error: $err')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NotifBell extends StatelessWidget {
  final VoidCallback onTap;
  const _NotifBell({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: AppTheme.cardSurface,
          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
          border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            const Icon(Icons.notifications_outlined, color: AppTheme.textPrimary, size: 22),
            Positioned(
              top: 10,
              right: 10,
              child: Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.statusCancelled,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;

  const _MetricCard({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: glassDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
            ),
            child: Icon(icon, size: 18, color: iconColor),
          ),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _QuickAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
          gradient: AppTheme.primaryGradient,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Demo data
final _sampleListings = [
  Listing(
    id: '1',
    sellerId: 's1',
    productId: 'p1',
    productName: 'Fresh Tomatoes',
    productCategory: 'Vegetables',
    city: 'Sofia',
    date: DateTime.now().add(const Duration(days: 2)),
    startTime: '08:00',
    endTime: '14:00',
    pricePerKg: 3.50,
    availableQuantity: 200,
    minThreshold: 100,
    requestedQuantity: 75,
    status: 'active',
  ),
  Listing(
    id: '2',
    sellerId: 's1',
    productId: 'p2',
    productName: 'Organic Apples',
    productCategory: 'Fruits',
    city: 'Plovdiv',
    date: DateTime.now().add(const Duration(days: 3)),
    startTime: '09:00',
    endTime: '15:00',
    pricePerKg: 2.80,
    availableQuantity: 150,
    minThreshold: 80,
    requestedQuantity: 85,
    status: 'threshold_reached',
  ),
  Listing(
    id: '3',
    sellerId: 's1',
    productId: 'p3',
    productName: 'Sunflower Honey',
    productCategory: 'Honey',
    city: 'Varna',
    date: DateTime.now().add(const Duration(days: 5)),
    startTime: '10:00',
    endTime: '16:00',
    pricePerKg: 12.00,
    availableQuantity: 50,
    minThreshold: 30,
    requestedQuantity: 10,
    status: 'draft',
  ),
];

void _showAddMenu(BuildContext context) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (context) => Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: AppTheme.cardSurface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Create New',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 24),
          _AddMenuOption(
            icon: Icons.add_circle_outline,
            title: 'Add New Product',
            subtitle: 'Register a new item to your inventory',
            onTap: () {
              Navigator.pop(context);
              context.go('/seller/add-product');
            },
          ),
          const SizedBox(height: 12),
          _AddMenuOption(
            icon: Icons.post_add_rounded,
            title: 'Create New Listing',
            subtitle: 'Start a new group buying session',
            onTap: () {
              Navigator.pop(context);
              context.go('/seller/create-listing');
            },
          ),
          const SizedBox(height: 24),
        ],
      ),
    ),
  );
}

class _AddMenuOption extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _AddMenuOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
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
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.accentGreen.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: AppTheme.accentGreen, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppTheme.textTertiary),
          ],
        ),
      ),
    );
  }
}
