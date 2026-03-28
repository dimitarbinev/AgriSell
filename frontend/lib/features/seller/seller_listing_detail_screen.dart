import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/theme.dart';
import '../../shared/models/models.dart';
import '../../shared/widgets/quantity_progress_bar.dart';
import '../../shared/widgets/status_chip.dart';
import '../../shared/widgets/go_decision_bar.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../shared/providers/providers.dart';
import '../../shared/widgets/nature_scaffold.dart';


class SellerListingDetailScreen extends ConsumerWidget {
  final String listingId;
  const SellerListingDetailScreen({super.key, required this.listingId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authStateProvider).value;
    if (user == null) {
      return const NatureScaffold(body: Center(child: Text('Моля, влезте в профила си', style: TextStyle(color: Colors.white))));
    }

    final listingsAsync = ref.watch(sellerListingsProvider(user.uid));
    final reservationsAsync = ref.watch(listingReservationsProvider(listingId));

    return listingsAsync.when(
      data: (listings) {
        final listing = listings.cast<Listing?>().firstWhere(
              (l) => l?.id == listingId,
              orElse: () => null,
            );

        if (listing == null) {
          return NatureScaffold(
            appBar: AppBar(
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                onPressed: () => context.go('/seller/dashboard'),
              ),
              title: const Text('Детайли на обявата', style: TextStyle(color: Colors.white)),
              backgroundColor: Colors.transparent,
              elevation: 0,
            ),
            body: const Center(child: Text('Обявата не е намерена', style: TextStyle(color: Colors.white))),
          );
        }

        final showGoCancel =
            listing.status == 'active' || listing.status == 'threshold_reached';

        return NatureScaffold(
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
              onPressed: () => context.go('/seller/dashboard'),
            ),
            title: const Text('Детайли', style: TextStyle(color: Colors.white)),
            actions: [
              StatusChip(status: listing.status),
              const SizedBox(width: 16),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
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
                          image: listing.productImageUrl != null
                              ? DecorationImage(
                                  image: NetworkImage(listing.productImageUrl!),
                                  fit: BoxFit.cover,
                                )
                              : null,
                        ),
                        child: listing.productImageUrl == null
                            ? const Icon(Icons.eco,
                                color: AppTheme.accentGreen, size: 32)
                            : null,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(listing.productName,
                                style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w800,
                                    color: AppTheme.textPrimary)),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const Icon(Icons.location_on_outlined, size: 14, color: AppTheme.accentGreen),
                                const SizedBox(width: 4),
                                Text(listing.city,
                                    style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
                                const SizedBox(width: 12),
                                const Icon(Icons.calendar_today, size: 12, color: AppTheme.textSecondary),
                                const SizedBox(width: 4),
                                Text('${DateFormat('MMM d').format(listing.startDate)} - ${DateFormat('MMM d').format(listing.endDate)}',
                                    style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text('${listing.pricePerKg.toStringAsFixed(2)} лв/кг',
                                style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w800,
                                    color: AppTheme.accentGreen)),
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
                      const Text('Прогрес на търсенето',
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textPrimary)),
                      const SizedBox(height: 14),
                      QuantityProgressBar(
                        current: listing.requestedQuantity,
                        target: listing.minThreshold,
                        height: 12,
                        label:
                            '${listing.requestedQuantity.toStringAsFixed(0)} / ${listing.minThreshold.toStringAsFixed(0)} кг заявено',
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                              'Депозити: ${listing.depositsTotal.toStringAsFixed(2)} лв',
                              style: const TextStyle(
                                  fontSize: 13, color: AppTheme.textSecondary)),

                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 15),
                // Product Info Tiles (Now Full Width)
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: glassDecoration(),
                  child: Row(
                    children: [
                      const Icon(Icons.category_outlined,
                          size: 20, color: AppTheme.accentGreen),
                      const SizedBox(width: 12),
                      const Text('Категория',
                          style: TextStyle(
                              fontSize: 14, color: AppTheme.textSecondary)),
                      const Spacer(),
                      Text(listing.productCategory,
                          style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.textPrimary)),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: glassDecoration(),
                  child: Row(
                    children: [
                      const Icon(Icons.scale_outlined,
                          size: 20, color: AppTheme.accentGreen),
                      const SizedBox(width: 12),
                      const Text('Мин. праг',
                          style: TextStyle(
                              fontSize: 14, color: AppTheme.textSecondary)),
                      const Spacer(),
                      Text('${listing.minThreshold.toStringAsFixed(0)} кг',
                          style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.textPrimary)),
                    ],
                  ),
                ),
                const SizedBox(height: 15),

                // Reservations (Using real data)
                reservationsAsync.when(
                  data: (reservations) {
                    final visibleReservations = reservations
                        .where((r) => r.status == 'active' || r.status == 'confirmed')
                        .toList();

                    return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                    decoration: glassDecoration(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Резервации (${visibleReservations.length})',
                            style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: AppTheme.textPrimary)),
                        const SizedBox(height: 18),
                        if (visibleReservations.isEmpty)
                          const Text('Все още няма резервации',
                              style: TextStyle(color: AppTheme.textTertiary)),
                        ...visibleReservations.map((r) => Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: Row(
                                children: [
                                  Container(
                                    width: 48,
                                    height: 48,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: AppTheme.primaryGreen
                                          .withValues(alpha: 0.15),
                                    ),
                                    child: const Icon(Icons.person,
                                        size: 24, color: AppTheme.accentGreen),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(r.buyerName ?? 'Купувач',
                                            style: const TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w700,
                                                color: AppTheme.textPrimary)),
                                        const SizedBox(height: 2),
                                        Text(
                                            '${r.quantity.toStringAsFixed(0)} кг · ${r.deposit.toStringAsFixed(2)} лв депозит',
                                            style: const TextStyle(
                                                fontSize: 14,
                                                color: AppTheme.textSecondary)),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.close_rounded, color: AppTheme.statusCancelled, size: 20),
                                    splashRadius: 18,
                                    tooltip: 'Откажи резервация',
                                    onPressed: () async {
                                      final shouldCancel = await showDialog<bool>(
                                        context: context,
                                        builder: (ctx) => AlertDialog(
                                          backgroundColor: AppTheme.cardSurface.withValues(alpha: 0.95),
                                          title: const Text(
                                            'Отмяна на резервация',
                                            style: TextStyle(color: Colors.white),
                                          ),
                                          content: Text(
                                            'Сигурни ли сте, че искате да премахнете тази резервация?',
                                            style: TextStyle(color: Colors.white.withValues(alpha: 0.8)),
                                          ),
                                          actions: [
                                            TextButton(
                                              onPressed: () => Navigator.pop(ctx, false),
                                              child: Text(
                                                'Не',
                                                style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
                                              ),
                                            ),
                                            TextButton(
                                              onPressed: () => Navigator.pop(ctx, true),
                                              child: const Text(
                                                'Да, премахни',
                                                style: TextStyle(color: AppTheme.statusCancelled),
                                              ),
                                            ),
                                          ],
                                        ),
                                      );

                                      if (shouldCancel != true) return;

                                      try {
                                        await ref.read(productServiceProvider).cancelReservation(r.id);

                                        invalidateProductListingCaches(ref);
                                        ref.invalidate(listingReservationsProvider(listingId));
                                        ref.invalidate(myReservationsProvider);

                                        if (context.mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(content: Text('Резервацията е отменена успешно')),
                                          );
                                        }
                                      } catch (e) {
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(content: Text('Грешка: $e')),
                                          );
                                        }
                                      }
                                    },
                                  ),
                                ],
                              ),
                            )),
                      ],
                    ),
                  );
                  },
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Text('Грешка при зареждане: $e'),
                ),
                const SizedBox(height: 16),

                
              ],
            ),
          ),
          bottomNavigationBar: showGoCancel
              ? GoDecisionBar(
                  onGo: () async {
                    try {
                      await ref.read(productServiceProvider).updateListingStatus(
                        productId: listing.productId,
                        listingId: listing.id,
                        status: 2, // Confirmed GO!
                      );
                      invalidateProductListingCaches(ref);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Обявата е потвърдена! Старт!')),
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Error: $e')),
                        );
                      }
                    }
                  },
                  onCancel: () async {
                    try {
                      await ref.read(productServiceProvider).updateListingStatus(
                        productId: listing.productId,
                        listingId: listing.id,
                        status: 3, // Cancelled
                      );
                      invalidateProductListingCaches(ref);
                      if (context.mounted) {
                        context.go('/seller/dashboard');
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Обявата е отменена.')),
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Error: $e')),
                        );
                      }
                    }
                  },
                )
              : null,
        );
      },
      loading: () => const NatureScaffold(body: Center(child: CircularProgressIndicator())),
      error: (err, _) => NatureScaffold(body: Center(child: Text('Error: $err', style: const TextStyle(color: Colors.white)))),
    );
  }
}
