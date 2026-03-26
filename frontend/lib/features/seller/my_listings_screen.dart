import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme.dart';
import '../../shared/models/models.dart';
import '../../shared/widgets/listing_card.dart';

class MyListingsScreen extends StatefulWidget {
  const MyListingsScreen({super.key});

  @override
  State<MyListingsScreen> createState() => _MyListingsScreenState();
}

class _MyListingsScreenState extends State<MyListingsScreen> {
  String? _filterStatus;

  @override
  Widget build(BuildContext context) {
    final filtered = _filterStatus == null
        ? _allListings
        : _allListings.where((l) => l.status == _filterStatus).toList();

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Row(
                children: [
                  const Expanded(
                    child: Text('My Listings',
                        style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
                  ),
                  IconButton(
                    onPressed: () => context.go('/seller/create-listing'),
                    icon: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        gradient: AppTheme.primaryGradient,
                        borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                      ),
                      child: const Icon(Icons.add, color: Colors.white, size: 20),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            // Filter Chips
            SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: [
                  _FilterChip(label: 'All', isSelected: _filterStatus == null, onTap: () => setState(() => _filterStatus = null)),
                  _FilterChip(label: 'Active', isSelected: _filterStatus == 'active', onTap: () => setState(() => _filterStatus = 'active')),
                  _FilterChip(label: 'Threshold', isSelected: _filterStatus == 'threshold_reached', onTap: () => setState(() => _filterStatus = 'threshold_reached')),
                  _FilterChip(label: 'GO', isSelected: _filterStatus == 'go_confirmed', onTap: () => setState(() => _filterStatus = 'go_confirmed')),
                  _FilterChip(label: 'Cancelled', isSelected: _filterStatus == 'cancelled', onTap: () => setState(() => _filterStatus = 'cancelled')),
                  _FilterChip(label: 'Completed', isSelected: _filterStatus == 'completed', onTap: () => setState(() => _filterStatus = 'completed')),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: filtered.length,
                itemBuilder: (ctx, i) => ListingCard(
                  listing: filtered[i],
                  showSellerInfo: false,
                  onTap: () => context.go('/seller/listing/${filtered[i].id}'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterChip({required this.label, required this.isSelected, required this.onTap});

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

final _allListings = [
  Listing(id: '1', sellerId: 's1', productId: 'p1', productName: 'Fresh Tomatoes', productCategory: 'Vegetables', city: 'Sofia', date: DateTime.now().add(const Duration(days: 2)), startTime: '08:00', endTime: '14:00', pricePerKg: 3.50, availableQuantity: 200, minThreshold: 100, requestedQuantity: 75, status: 'active'),
  Listing(id: '2', sellerId: 's1', productId: 'p2', productName: 'Organic Apples', productCategory: 'Fruits', city: 'Plovdiv', date: DateTime.now().add(const Duration(days: 3)), startTime: '09:00', endTime: '15:00', pricePerKg: 2.80, availableQuantity: 150, minThreshold: 80, requestedQuantity: 85, status: 'threshold_reached'),
  Listing(id: '3', sellerId: 's1', productId: 'p3', productName: 'Sunflower Honey', productCategory: 'Honey', city: 'Varna', date: DateTime.now().add(const Duration(days: 5)), startTime: '10:00', endTime: '16:00', pricePerKg: 12.00, availableQuantity: 50, minThreshold: 30, requestedQuantity: 10, status: 'draft'),
  Listing(id: '4', sellerId: 's1', productId: 'p1', productName: 'Fresh Tomatoes', productCategory: 'Vegetables', city: 'Burgas', date: DateTime.now().subtract(const Duration(days: 5)), startTime: '08:00', endTime: '13:00', pricePerKg: 3.20, availableQuantity: 180, minThreshold: 90, requestedQuantity: 120, status: 'completed'),
  Listing(id: '5', sellerId: 's1', productId: 'p2', productName: 'Organic Apples', productCategory: 'Fruits', city: 'Ruse', date: DateTime.now().subtract(const Duration(days: 2)), startTime: '09:00', endTime: '14:00', pricePerKg: 3.00, availableQuantity: 100, minThreshold: 60, requestedQuantity: 25, status: 'cancelled'),
];
