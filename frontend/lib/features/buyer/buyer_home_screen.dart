import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme.dart';
import '../../core/constants.dart';
import '../../shared/models/models.dart';
import '../../shared/providers/providers.dart';
import '../../shared/widgets/listing_card.dart';

class BuyerHomeScreen extends ConsumerStatefulWidget {
  const BuyerHomeScreen({super.key});

  @override
  ConsumerState<BuyerHomeScreen> createState() => _BuyerHomeScreenState();
}

class _BuyerHomeScreenState extends ConsumerState<BuyerHomeScreen> {
  String? _selectedCategory;
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ref.watch(currentBuyerProvider).when(
                          data: (buyer) => Text(
                            'Good Morning, ${buyer?.name ?? "Friend"}',
                            style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                          ),
                          loading: () => const Text(
                            'Good Morning',
                            style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                          ),
                          error: (_, __) => const Text(
                            'Good Morning',
                            style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                          ),
                        ),
                        const Text('Explore Fresh Produce',
                            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () => context.go('/notifications'),
                    child: Container(
                      width: 44, height: 44,
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
                            top: 10, right: 10,
                            child: Container(width: 8, height: 8,
                              decoration: const BoxDecoration(shape: BoxShape.circle, color: AppTheme.statusCancelled)),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Search
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: TextField(
                controller: _searchController,
                style: const TextStyle(color: AppTheme.textPrimary),
                decoration: InputDecoration(
                  hintText: 'Search products, sellers, cities...',
                  prefixIcon: const Icon(Icons.search, size: 22),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.tune, size: 20, color: AppTheme.accentGreen),
                    onPressed: () {},
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Category Chips
            SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: [
                  _CategoryChip(label: 'All', isSelected: _selectedCategory == null,
                      onTap: () => setState(() => _selectedCategory = null)),
                  ...AppConstants.productCategories.take(5).map((c) => _CategoryChip(
                    label: c,
                    isSelected: _selectedCategory == c,
                    onTap: () => setState(() => _selectedCategory = c),
                  )),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Listings
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: const Text('Available Listings',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ref.watch(activeListingsProvider).when(
                data: (listings) {
                  final filtered = listings.where((l) {
                    final matchesCategory = _selectedCategory == null || l.productCategory == _selectedCategory;
                    final matchesSearch = _searchController.text.isEmpty ||
                        l.productName.toLowerCase().contains(_searchController.text.toLowerCase()) ||
                        l.city.toLowerCase().contains(_searchController.text.toLowerCase());
                    return matchesCategory && matchesSearch;
                  }).toList();

                  if (filtered.isEmpty) {
                    return const Center(child: Text('No listings found', style: TextStyle(color: AppTheme.textSecondary)));
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: filtered.length,
                    itemBuilder: (ctx, i) => ListingCard(
                      listing: filtered[i],
                      onTap: () => context.go('/buyer/listing/${filtered[i].id}'),
                    ),
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, stack) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Text(
                      'Error: $err\n\nNote: If this is an index error, please click the link in the debug console to create it.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppTheme.statusCancelled),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _CategoryChip({required this.label, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryGreen : AppTheme.cardSurface,
          borderRadius: BorderRadius.circular(AppTheme.radiusXLarge),
          border: Border.all(color: isSelected ? AppTheme.primaryGreen : Colors.white.withValues(alpha: 0.08)),
        ),
        child: Text(label, style: TextStyle(
          fontSize: 13, fontWeight: FontWeight.w600,
          color: isSelected ? Colors.white : AppTheme.textSecondary,
        )),
      ),
    );
  }
}

