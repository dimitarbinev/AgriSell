import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme.dart';
import '../../shared/widgets/listing_card.dart';
import '../../shared/widgets/rating_stars.dart';
import '../../shared/providers/providers.dart';
import '../../shared/widgets/nature_scaffold.dart';

class SellerDashboardScreen extends ConsumerWidget {
  const SellerDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authStateProvider).value;
    if (user == null) return const NatureScaffold(body: Center(child: CircularProgressIndicator()));
    final userId = user.uid;
    final reviewStatsAsync = ref.watch(sellerReviewStatsProvider);

    return NatureScaffold(
      blur: 8.0,
      overlayOpacity: 0.42,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddMenu(context),
        backgroundColor: AppTheme.primaryGreen.withValues(alpha: 0.9),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Нова сесия', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: SingleChildScrollView(
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
                    border: Border.all(color: Colors.white.withValues(alpha: 0.2), width: 2),
                  ),
                  child: const Icon(Icons.person, color: Colors.white, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Добро утро',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.white.withValues(alpha: 0.8),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      ref.watch(reactiveSellerProvider).when(
                        data: (seller) => Text(
                          seller?.name ?? 'Продавач',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                        loading: () => const Text('...', style: TextStyle(fontSize: 20, color: Colors.white)),
                        error: (err, stack) => const Text('Продавач', style: TextStyle(fontSize: 20, color: Colors.white)),
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

                return Column(
                  children: [
                    GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 1.1, // ✅ Променено от 1.5 на 1.1 за повече място
                      children: [
                        _MetricCard(
                          icon: Icons.storefront_rounded,
                          iconColor: AppTheme.statusActive,
                          label: 'Активни обяви',
                          value: '$activeCount',
                        ),
                        _MetricCard(
                          icon: Icons.inventory_2_rounded,
                          iconColor: AppTheme.accentGreen,
                          label: 'Заявено кол.',
                          value: '${totalRequested.toStringAsFixed(0)} кг',
                        ),
                        _MetricCard(
                          icon: Icons.rate_review_rounded,
                          iconColor: AppTheme.statusThresholdReached,
                          label: 'Общо отзиви',
                          value: reviewStatsAsync.maybeWhen(
                            data: (stats) => '${stats.totalReviews}',
                            orElse: () => '0',
                          ),
                        ),
                        _MetricCard(
                          icon: Icons.star_rounded,
                          iconColor: AppTheme.accentGreen,
                          label: 'Ср. оценка',
                          value: reviewStatsAsync.maybeWhen(
                            data: (stats) => stats.rating.toStringAsFixed(1),
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
                            label: 'Добави продукт',
                            onTap: () => context.go('/seller/add-product'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _QuickAction(
                            icon: Icons.post_add_rounded,
                            label: 'Нова обява',
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
                        'Предстояща активност',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white),
                      ),
                    ),
                    const SizedBox(height: 14),
                    () {
                      final today = DateTime.now();
                      final startOfToday = DateTime(today.year, today.month, today.day);
                      final sortedListings = listings
                          .where((l) => l.endDate.isAfter(startOfToday.subtract(const Duration(seconds: 1))))
                          .toList();
                      sortedListings.sort((a, b) => a.startDate.compareTo(b.startDate));
                      
                      if (sortedListings.isEmpty) {
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 20),
                            child: Text('Няма предстояща активност', style: TextStyle(color: Colors.white.withValues(alpha: 0.6))),
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
                    const SizedBox(height: 28),

                    // Recent Reviews
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Последни отзиви',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white),
                      ),
                    ),
                    const SizedBox(height: 14),
                    ref.watch(myReviewsProvider).when(
                      data: (reviews) {
                        if (reviews.isEmpty) {
                          return Center(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 20),
                              child: Text('Все още няма отзиви', style: TextStyle(color: Colors.white.withValues(alpha: 0.6))),
                            ),
                          );
                        }
                        return Column(
                          children: reviews.take(5).map((r) => Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(16),
                            decoration: glassDecoration(),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(r.buyerName ?? 'Анонимен', style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.white)),
                                    const Spacer(),
                                    RatingStars(rating: r.rating, size: 14),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(r.comment, style: const TextStyle(fontSize: 13, color: Colors.white, height: 1.4)),
                              ],
                            ),
                          )).toList(),
                        );
                      },
                      loading: () => const Center(child: CircularProgressIndicator()),
                      error: (err, _) => Center(child: Text('Error: $err', style: const TextStyle(color: Colors.white))),
                    ),
                    const SizedBox(height: 40),
                  ],
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) => Center(child: Text('Error: $err')),
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
      padding: const EdgeInsets.all(12),
      decoration: glassDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
            ),
            child: Icon(icon, size: 18, color: iconColor),
          ),
          const Spacer(),
          // ✅ FittedBox за защита на големи числа
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: AppTheme.textPrimary,
              ),
            ),
          ),
          const SizedBox(height: 2),
          // ✅ Текстът е защитен с maxLines
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 11,
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

// Помощни уиджети (остават същите като логика, но подредени)
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
                decoration: const BoxDecoration(shape: BoxShape.circle, color: AppTheme.statusCancelled),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _QuickAction({required this.icon, required this.label, required this.onTap});

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
            Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14)),
          ],
        ),
      ),
    );
  }
}

void _showAddMenu(BuildContext context) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (context) => Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.cardSurface.withValues(alpha: 0.95),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Създай ново',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white),
          ),
          const SizedBox(height: 24),
          _AddMenuOption(
            icon: Icons.add_circle_outline,
            title: 'Добави нов продукт',
            subtitle: 'Регистрирай нов артикул в инвентара',
            onTap: () {
              Navigator.pop(context);
              context.go('/seller/add-product');
            },
          ),
          const SizedBox(height: 12),
          _AddMenuOption(
            icon: Icons.post_add_rounded,
            title: 'Създай нова обява',
            subtitle: 'Стартирай нова групова покупка',
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

  const _AddMenuOption({required this.icon, required this.title, required this.subtitle, required this.onTap});

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
                  Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
                  Text(subtitle, style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.7))),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.white.withValues(alpha: 0.3)),
          ],
        ),
      ),
    );
  }
}