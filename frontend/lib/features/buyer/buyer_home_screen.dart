import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme.dart';
import '../../core/constants.dart';
import '../../shared/providers/providers.dart';
import '../../shared/widgets/listing_card.dart';
import '../../shared/widgets/nature_scaffold.dart';

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
    final currentUserId = ref.watch(authStateProvider).value?.uid;

    return NatureScaffold(
      body: Column(
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
                          'Добро утро, ${buyer?.name ?? "Приятел"}',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.white.withValues(alpha: 0.8),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        loading: () => Text(
                          'Добро утро',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.white.withValues(alpha: 0.8),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        error: (_, _) => Text(
                          'Добро утро',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.white.withValues(alpha: 0.8),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const Text(
                        'Разгледай пресни продукти',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () => context.go('/notifications'),
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
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Search
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              decoration: glassDecoration(radius: AppTheme.radiusLarge),
              child: TextField(
                controller: _searchController,
                style: const TextStyle(color: AppTheme.textPrimary),
                onChanged: (val) => setState(() {}),
                decoration: InputDecoration(
                  hintText: 'Търси продукти, продавачи, градове...',
                  hintStyle: const TextStyle(color: AppTheme.textSecondary),
                  prefixIcon: const Icon(Icons.search, size: 22, color: AppTheme.textSecondary),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.close, size: 20, color: AppTheme.textSecondary),
                          onPressed: () {
                            _searchController.clear();
                            setState(() {});
                          },
                        )
                      : IconButton(
                          icon: const Icon(Icons.tune, size: 20, color: AppTheme.accentGreen),
                          onPressed: () {},
                        ),
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
                _CategoryChip(
                  label: 'Всички',
                  isSelected: _selectedCategory == null,
                  onTap: () => setState(() => _selectedCategory = null),
                ),
                ...AppConstants.productCategories.take(10).map(
                      (c) => _CategoryChip(
                        label: c,
                        isSelected: _selectedCategory == c,
                        onTap: () => setState(() => _selectedCategory = c),
                      ),
                    ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Listings
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              'Налични обяви',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(activeListingsProvider);
              },
              color: AppTheme.primaryGreen,
              child: ref.watch(activeListingsProvider).when(
                    data: (listings) {
                      final filtered = listings.where((l) {
                        final isOwnListing = currentUserId != null && l.sellerId == currentUserId;
                        final query = _searchController.text.toLowerCase();
                        final matchesCategory = _selectedCategory == null || l.productCategory == _selectedCategory;
                        final matchesSearch = query.isEmpty ||
                            l.productName.toLowerCase().contains(query) ||
                            (l.sellerName?.toLowerCase().contains(query) ?? false) ||
                            l.city.toLowerCase().contains(query);
                        return !isOwnListing && matchesCategory && matchesSearch;
                      }).toList();

                      if (filtered.isEmpty) {
                        return ListView(
                          children: [
                            const SizedBox(height: 100),
                            Center(
                              child: Text(
                                'Няма намерени обяви',
                                style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
                              ),
                            ),
                            Center(
                              child: Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Text(
                                  'Издърпай за обновяване',
                                  style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 12),
                                ),
                              ),
                            ),
                          ],
                        );
                      }

                      return ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                        itemCount: filtered.length,
                        itemBuilder: (ctx, i) => ListingCard(
                          listing: filtered[i],
                          onTap: () => context.go('/buyer/listing/${filtered[i].id}'),
                        ),
                      );
                    },
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (err, stack) => ListView(
                      children: [
                        const SizedBox(height: 80),
                        Center(
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Container(
                              decoration: glassDecoration(),
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                children: [
                                  const Icon(Icons.cloud_off, size: 48, color: AppTheme.textTertiary),
                                  const SizedBox(height: 12),
                                  Text(
                                    'Неуспешно зареждане.\nПроверете дали сървърът работи.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    '$err',
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(color: AppTheme.statusCancelled, fontSize: 11),
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    'Издърпай за повторен опит',
                                    style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
            ),
          ),
        ],
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
          color: isSelected ? AppTheme.primaryGreen.withValues(alpha: 0.85) : AppTheme.cardSurface.withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(AppTheme.radiusXLarge),
          border: Border.all(color: isSelected ? AppTheme.primaryGreen : Colors.white.withValues(alpha: 0.12)),
        ),
        child: Center(
          child: Text(label, style: TextStyle(
            fontSize: 13, fontWeight: FontWeight.w600,
            color: isSelected ? Colors.white : AppTheme.textPrimary.withValues(alpha: 0.9),
          )),
        ),
      ),
    );
  }
}

