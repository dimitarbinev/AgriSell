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
import '../../shared/widgets/nature_scaffold.dart';

class BuyerListingDetailScreen extends ConsumerStatefulWidget {
  final String listingId;
  const BuyerListingDetailScreen({super.key, required this.listingId});

  @override
  ConsumerState<BuyerListingDetailScreen> createState() => _BuyerListingDetailScreenState();
}

class _BuyerListingDetailScreenState extends ConsumerState<BuyerListingDetailScreen> {
  final _quantityController = TextEditingController();
  final _depositController = TextEditingController();

  @override
  void dispose() {
    _quantityController.dispose();
    _depositController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final listingsAsync = ref.watch(activeListingsProvider);
    final reservationsAsync = ref.watch(listingReservationsProvider(widget.listingId));

    return listingsAsync.when(
      data: (listings) {
        final listing = listings.cast<Listing?>().firstWhere(
          (l) => l?.id == widget.listingId,
          orElse: () => null,
        );

        if (listing == null) {
          return NatureScaffold(
            appBar: AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                onPressed: () => context.go('/buyer/home'),
              ),
              title: const Text('Детайли за обявата'),
            ),
            body: const Center(child: Text('Обявата не е намерена', style: TextStyle(color: Colors.white))),
          );
        }

        return NatureScaffold(
          body: CustomScrollView(
            slivers: [
              // Product Image Header
              SliverAppBar(
                expandedHeight: 240,
                pinned: true,
                backgroundColor: Colors.transparent,
                elevation: 0,
                leading: IconButton(
                  icon: Container(
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
                              Colors.black.withValues(alpha: 0.4),
                              Colors.transparent,
                            ],
                          ),
                        ),
                        child: Icon(Icons.eco, size: 80, color: AppTheme.accentGreen.withValues(alpha: 0.5)),
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
                                Text('${DateFormat('MMM d').format(listing.startDate)} - ${DateFormat('MMM d').format(listing.endDate)}',
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
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle, 
                                  gradient: AppTheme.primaryGradient,
                                  border: Border.all(color: Colors.white.withValues(alpha: 0.2), width: 1.5),
                                ),
                                child: const Icon(Icons.person, color: Colors.white, size: 22),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(listing.sellerName ?? 'Seller',
                                        style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.white)),
                                    Row(children: [
                                      RatingStars(rating: listing.sellerRating ?? 0, size: 14),
                                      const SizedBox(width: 6),
                                      const Icon(Icons.location_on_outlined, size: 13, color: AppTheme.accentGreen),
                                      const SizedBox(width: 2),
                                      Text(listing.city, style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.6))),
                                    ]),
                                  ],
                                ),
                              ),
                              Icon(Icons.chevron_right, color: Colors.white.withValues(alpha: 0.3)),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Price
                      Text('${listing.pricePerKg.toStringAsFixed(2)} лв/кг',
                          style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: AppTheme.accentGreen)),
                      const SizedBox(height: 16),

                      // Scaled Info Section
                      _InfoTile(label: 'Произход', value: listing.city, isFullWidth: true),
                      const SizedBox(height: 10),
                      _InfoTile(label: 'Категория', value: listing.productCategory, isFullWidth: true),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(child: _InfoTile(label: 'Остатък', value: '${(listing.availableQuantity - listing.requestedQuantity).toStringAsFixed(0)} кг')),
                          const SizedBox(width: 10),
                          Expanded(child: _InfoTile(label: 'Цел', value: '${listing.minThreshold.toStringAsFixed(0)} кг')),
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
                            Text('${DateFormat('EEEE, MMM d').format(listing.startDate)} - ${DateFormat('MMM d').format(listing.endDate)}',
                                style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.white)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Quantity Progress
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: glassDecoration(),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Прогрес на груповата покупка',
                                style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white)),
                            const SizedBox(height: 12),
                            QuantityProgressBar(
                              current: listing.requestedQuantity,
                              target: listing.minThreshold,
                              height: 12,
                              label: '${listing.requestedQuantity.toStringAsFixed(0)} / ${listing.minThreshold.toStringAsFixed(0)} кг цел',
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Reservations Section
                      reservationsAsync.when(
                        data: (reservations) {
                          if (reservations.isEmpty) return const SizedBox.shrink();
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Участници в групата',
                                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white)),
                              const SizedBox(height: 14),
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: glassDecoration(),
                                child: Column(
                                  children: reservations
                                      .where((r) => r.status != 'cancelled')
                                      .take(5)
                                      .map((r) => Padding(
                                    padding: const EdgeInsets.only(bottom: 12),
                                    child: Row(
                                      children: [
                                        CircleAvatar(
                                          radius: 16,
                                          backgroundColor: Colors.white.withValues(alpha: 0.1),
                                          child: const Icon(Icons.person, size: 18, color: Colors.white),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(r.buyerName ?? 'Участник',
                                                  style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.white)),
                                              Text('${r.quantity.toStringAsFixed(0)} кг резервирани',
                                                  style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.5))),
                                            ],
                                          ),
                                        ),
                                        const Icon(Icons.check_circle, size: 16, color: AppTheme.accentGreen),
                                      ],
                                    ),
                                  )).toList(),
                                ),
                              ),
                              const SizedBox(height: 20),
                            ],
                          );
                        },
                        loading: () => const SizedBox.shrink(),
                        error: (_, _) => const SizedBox.shrink(),
                      ),

                      // Reserve Form
                      if (listing.status == 'cancelled')
                        Container(
                          padding: const EdgeInsets.all(20),
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: Colors.red.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
                            border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                          ),
                          child: const Column(
                            children: [
                              Icon(Icons.cancel_outlined, color: Colors.red, size: 32),
                              SizedBox(height: 12),
                              Text(
                                'Тази обява е отменена. Резервации не се приемат повече.',
                                style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        )
                      else ...[
                        const Text('Присъедини се към групата',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white)),
                        const SizedBox(height: 14),
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: glassDecoration(),
                          child: Column(
                            children: [
                              TextField(
                                controller: _quantityController,
                                keyboardType: TextInputType.number,
                                style: const TextStyle(color: Colors.white),
                                decoration: InputDecoration(
                                  labelText: 'Количество (кг)',
                                  labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.6)),
                                  prefixIcon: Icon(Icons.scale, size: 20, color: Colors.white.withValues(alpha: 0.6)),
                                  enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.2))),
                                ),
                              ),
                              const SizedBox(height: 14),
                              TextField(
                                controller: _depositController,
                                keyboardType: TextInputType.number,
                                style: const TextStyle(color: Colors.white),
                                decoration: InputDecoration(
                                  labelText: 'Депозит (лв)',
                                  labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.6)),
                                  prefixIcon: Icon(Icons.payments_outlined, size: 20, color: Colors.white.withValues(alpha: 0.6)),
                                  enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.2))),
                                ),
                              ),
                              const SizedBox(height: 20),
                              SizedBox(
                                width: double.infinity, height: 52,
                                child: Container(
                                  decoration: BoxDecoration(
                                    gradient: AppTheme.primaryGradient,
                                    borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppTheme.accentGreen.withValues(alpha: 0.3),
                                        blurRadius: 12,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: ElevatedButton.icon(
                                    onPressed: () async {
                                      if (_quantityController.text.isEmpty || _depositController.text.isEmpty) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(content: Text('Моля, попълнете всички полета')),
                                        );
                                        return;
                                      }

                                      try {
                                        final quantity = double.parse(_quantityController.text);
                                        final deposit = double.parse(_depositController.text);

                                        if (quantity <= 0 || deposit < 0) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(content: Text('Количеството трябва да е по-голямо от 0')),
                                          );
                                          return;
                                        }

                                        await ref.read(productServiceProvider).placeOrder(
                                          listingId: listing.id,
                                          sellerId: listing.sellerId,
                                          productId: listing.productId,
                                          quantity: quantity,
                                          deposit: deposit,
                                        );
                                        
                                        invalidateProductListingCaches(
                                          ref,
                                          listingSellerId: listing.sellerId,
                                        );

                                        if (mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(content: Text('Резервацията е подадена успешно!')),
                                          );
                                          _quantityController.clear();
                                          _depositController.clear();
                                          FocusScope.of(context).unfocus();
                                        }
                                      } catch (e) {
                                        if (mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(content: Text('Error: $e')),
                                          );
                                        }
                                      }
                                    },
                                    icon: const Icon(Icons.check_circle_outline),
                                    label: const Text('Подай резервация'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.transparent,
                                      shadowColor: Colors.transparent,
                                      foregroundColor: Colors.white,
                                      elevation: 0,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),

                      // AI Insight
                      AIInsightCard(
                         icon: Icons.lightbulb_outline,
                       title: "Съвет за групова покупка",
                         body: "Груповото купуване за тази обява напредва бързо! Присъединете се сега.",
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
      loading: () => const NatureScaffold(body: Center(child: CircularProgressIndicator())),
      error: (err, _) => NatureScaffold(body: Center(child: Text('Error: $err', style: const TextStyle(color: Colors.white)))),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final String label, value;
  final bool isFullWidth;
  const _InfoTile({required this.label, required this.value, this.isFullWidth = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isFullWidth ? 16 : 12),
      decoration: glassDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(label, style: TextStyle(fontSize: isFullWidth ? 13 : 11, color: Colors.white.withValues(alpha: 0.5))),
          const SizedBox(height: 4),
          Text(
            value, 
            style: TextStyle(
              fontSize: isFullWidth ? 18 : 15, 
              fontWeight: FontWeight.w700, 
              color: Colors.white
            ),
            softWrap: true,
          ),
        ],
      ),
    );
  }
}