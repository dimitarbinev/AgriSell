import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme.dart';
import '../../core/constants.dart';
import '../../shared/models/models.dart';
import '../../shared/widgets/listing_card.dart';

class BuyerHomeScreen extends StatefulWidget {
  const BuyerHomeScreen({super.key});

  @override
  State<BuyerHomeScreen> createState() => _BuyerHomeScreenState();
}

class _BuyerHomeScreenState extends State<BuyerHomeScreen> {
  String? _selectedCategory;
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _selectedCategory == null
        ? _listings
        : _listings.where((l) => l.productCategory == _selectedCategory).toList();

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
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Good Morning', style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
                        Text('Explore Fresh Produce',
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
              child: Text('Available Listings (${filtered.length})',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: filtered.length,
                itemBuilder: (ctx, i) => ListingCard(
                  listing: filtered[i],
                  onTap: () => context.go('/buyer/listing/${filtered[i].id}'),
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

final _listings = [
  Listing(id: '1', sellerId: 's1', productId: 'p1', productName: 'Fresh Tomatoes', productCategory: 'Vegetables', city: 'Sofia',
    date: DateTime.now().add(const Duration(days: 2)), startTime: '08:00', endTime: '14:00',
    pricePerKg: 3.50, availableQuantity: 200, minThreshold: 100, requestedQuantity: 75, status: 'active',
    sellerName: 'Ivan Petrov', sellerRating: 4.7),
  Listing(id: '2', sellerId: 's2', productId: 'p2', productName: 'Organic Apples', productCategory: 'Fruits', city: 'Plovdiv',
    date: DateTime.now().add(const Duration(days: 3)), startTime: '09:00', endTime: '15:00',
    pricePerKg: 2.80, availableQuantity: 150, minThreshold: 80, requestedQuantity: 85, status: 'threshold_reached',
    sellerName: 'Maria Georgieva', sellerRating: 4.5),
  Listing(id: '3', sellerId: 's3', productId: 'p3', productName: 'Sunflower Honey', productCategory: 'Honey', city: 'Varna',
    date: DateTime.now().add(const Duration(days: 5)), startTime: '10:00', endTime: '16:00',
    pricePerKg: 12.00, availableQuantity: 50, minThreshold: 30, requestedQuantity: 10, status: 'active',
    sellerName: 'Todor Stoyanov', sellerRating: 4.9),
  Listing(id: '4', sellerId: 's4', productId: 'p4', productName: 'Fresh Carrots', productCategory: 'Vegetables', city: 'Burgas',
    date: DateTime.now().add(const Duration(days: 1)), startTime: '07:00', endTime: '12:00',
    pricePerKg: 2.20, availableQuantity: 120, minThreshold: 60, requestedQuantity: 45, status: 'active',
    sellerName: 'Elena Nikolova', sellerRating: 4.3),
  Listing(id: '5', sellerId: 's5', productId: 'p5', productName: 'White Cheese', productCategory: 'Dairy', city: 'Sofia',
    date: DateTime.now().add(const Duration(days: 4)), startTime: '09:00', endTime: '13:00',
    pricePerKg: 8.50, availableQuantity: 80, minThreshold: 40, requestedQuantity: 38, status: 'active',
    sellerName: 'Dimitar Kolev', sellerRating: 4.6),
];
