import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme.dart';
import '../../shared/models/models.dart';
import '../../shared/widgets/rating_stars.dart';
import '../../shared/providers/providers.dart';
import '../../shared/widgets/nature_scaffold.dart';

class SellerProfileScreen extends ConsumerWidget {
  const SellerProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reviewStatsAsync = ref.watch(sellerReviewStatsProvider);
    final productsAsync = ref.watch(sellerProductsProvider);

    return NatureScaffold(
      appBar: AppBar(
        title: const Text('Профил на продавач', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const SizedBox(height: 20),
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: AppTheme.primaryGradient,
                border: Border.all(color: AppTheme.accentGreen.withValues(alpha: 0.4), width: 3),
              ),
              child: const Icon(Icons.person, color: Colors.white, size: 48),
            ),
            const SizedBox(height: 16),
            ref.watch(reactiveSellerProvider).when(
                  data: (seller) {
                    final liveRating = reviewStatsAsync.maybeWhen(
                      data: (stats) => stats.rating,
                      orElse: () => 0.0,
                    );
                    final liveReviews = reviewStatsAsync.maybeWhen(
                      data: (stats) => stats.totalReviews,
                      orElse: () => 0,
                    );
                    final displayRating = liveReviews > 0 ? liveRating : (seller?.rating ?? 0.0);
                    final displayReviews = liveReviews > 0 ? liveReviews : (seller?.totalReviews ?? 0);
                    final productCount = productsAsync.maybeWhen(
                      data: (p) => p.length,
                      orElse: () => 0,
                    );

                    return Column(
                      children: [
                        Text(
                          seller?.name ?? 'Продавач',
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.location_on_outlined, size: 14, color: AppTheme.accentGreen),
                            const SizedBox(width: 4),
                            Text(
                              seller?.mainCity ?? 'Неизвестен',
                              style: const TextStyle(fontSize: 14, color: AppTheme.textSecondary),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            RatingStars(rating: displayRating, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              displayRating.toStringAsFixed(1),
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '($displayReviews отзива)',
                              style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                            ),
                          ],
                        ),
                        const SizedBox(height: 28),
                        Row(
                          children: [
                            Expanded(
                              child: _StatCard(
                                label: 'Завършени',
                                value: '${seller?.completedOrders ?? 0}',
                                icon: Icons.check_circle_outline,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _StatCard(
                                label: '% отказ',
                                value: '${((seller?.cancelRate ?? 0.0) * 100).toStringAsFixed(0)}%',
                                icon: Icons.cancel_outlined,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _StatCard(
                                label: 'Продукти',
                                value: '$productCount',
                                icon: Icons.eco,
                              ),
                            ),
                          ],
                        ),
                      ],
                    );
                  },
                  loading: () => const CircularProgressIndicator(),
                  error: (_, _) => const Text('Грешка при зареждане'),
                ),
            const SizedBox(height: 28),

            

            _ProfileMenuTile(
              icon: Icons.inventory_2_outlined,
              label: 'Моите продукти',
              onTap: () => context.go('/seller/products'),
            ),
            _ProfileMenuTile(
              icon: Icons.settings_outlined,
              label: 'Настройки',
              onTap: () => context.push('/seller/settings'),
            ),
            _ProfileMenuTile(
              icon: Icons.shopping_bag_outlined,
              label: 'Превключи към купувач',
              onTap: () async {
                try {
                  await ref.read(authServiceProvider).switchRole('buyer');
                  if (context.mounted) context.go('/buyer/home');
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Неуспешна смяна на ролята: $e')),
                    );
                  }
                }
              },
            ),
            _ProfileMenuTile(
              icon: Icons.logout,
              label: 'Изход',
              isDanger: true,
              onTap: () async {
                await ref.read(authServiceProvider).signOut();
                if (context.mounted) context.go('/login');
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _SellerProductRow extends StatelessWidget {
  final Product product;

  const _SellerProductRow({required this.product});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        color: Colors.black.withValues(alpha: 0.28),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          Icon(Icons.eco_outlined, color: AppTheme.accentGreen.withValues(alpha: 0.9), size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: AppTheme.textPrimary,
                  ),
                ),
                Text(
                  product.category,
                  style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                ),
              ],
            ),
          ),
          Text(
            '${product.pricePerKg.toStringAsFixed(2)} лв/кг',
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              color: AppTheme.accentGreen,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label, value;
  final IconData icon;
  const _StatCard({required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: glassDecoration(),
      child: Column(
        children: [
          Icon(icon, color: AppTheme.accentGreen, size: 22),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
          ),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
        ],
      ),
    );
  }
}

class _ProfileMenuTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isDanger;

  const _ProfileMenuTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isDanger = false,
  });

  @override
  Widget build(BuildContext context) {
    final accent = isDanger ? AppTheme.statusCancelled : AppTheme.accentGreen;
    final textColor = isDanger ? AppTheme.statusCancelled : AppTheme.textPrimary;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppTheme.radiusXLarge),
          onTap: onTap,
          child: Ink(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppTheme.radiusXLarge),
              color: Colors.black.withValues(alpha: 0.32),
              border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.25),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Icon(icon, size: 22, color: accent),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: textColor,
                    ),
                  ),
                ),
                Icon(Icons.chevron_right, size: 22, color: Colors.white.withValues(alpha: 0.35)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
