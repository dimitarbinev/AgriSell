import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme.dart';
import '../../shared/widgets/seller_card.dart';

class BuyerMapScreen extends StatelessWidget {
  const BuyerMapScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Map placeholder (replace with GoogleMap widget)
          Container(
            color: const Color(0xFF1A2E2E),
            child: const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.map_rounded, size: 64, color: AppTheme.textTertiary),
                  SizedBox(height: 12),
                  Text('Google Maps', style: TextStyle(color: AppTheme.textTertiary, fontSize: 16)),
                  SizedBox(height: 4),
                  Text('Configure API key in AndroidManifest.xml',
                      style: TextStyle(color: AppTheme.textTertiary, fontSize: 12)),
                ],
              ),
            ),
          ),

          // Simulated markers
          ..._markers.map((m) => Positioned(
            left: m.x,
            top: m.y,
            child: GestureDetector(
              onTap: () => _showSellerSheet(context, m),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.primaryGreen,
                  border: Border.all(color: AppTheme.accentGreen, width: 2),
                  boxShadow: [BoxShadow(color: AppTheme.primaryGreen.withValues(alpha: 0.4), blurRadius: 12)],
                ),
                child: const Icon(Icons.storefront, size: 18, color: Colors.white),
              ),
            ),
          )),

          // Top search bar
          Positioned(
            top: MediaQuery.of(context).padding.top + 12,
            left: 20, right: 20,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              decoration: glassDecoration(),
              child: const TextField(
                style: TextStyle(color: AppTheme.textPrimary),
                decoration: InputDecoration(
                  hintText: 'Search sellers nearby...',
                  prefixIcon: Icon(Icons.search, size: 22),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                ),
              ),
            ),
          ),

          // Filter chips
          Positioned(
            top: MediaQuery.of(context).padding.top + 72,
            left: 20,
            child: Row(
              children: ['All', 'Vegetables', 'Fruits', 'Dairy']
                  .map((c) => Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: c == 'All'
                          ? AppTheme.primaryGreen
                          : AppTheme.cardSurface.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(AppTheme.radiusXLarge),
                    ),
                    child: Text(c, style: TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w600,
                      color: c == 'All' ? Colors.white : AppTheme.textSecondary,
                    )),
                  ))
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }

  void _showSellerSheet(BuildContext context, _MapMarker marker) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppTheme.cardSurface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: AppTheme.textTertiary,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            SellerCard(
              name: marker.sellerName,
              rating: marker.rating,
              city: marker.city,
              productChips: marker.products,
              onTap: () {
                Navigator.pop(ctx);
                context.go('/buyer/seller/${marker.sellerId}');
              },
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  context.go('/buyer/seller/${marker.sellerId}');
                },
                child: const Text('View Listings'),
              ),
            ),
            SizedBox(height: MediaQuery.of(ctx).padding.bottom),
          ],
        ),
      ),
    );
  }
}

class _MapMarker {
  final double x, y;
  final String sellerId, sellerName, city;
  final double rating;
  final List<String> products;

  const _MapMarker({
    required this.x, required this.y,
    required this.sellerId, required this.sellerName,
    required this.city, required this.rating,
    required this.products,
  });
}

const _markers = [
  _MapMarker(x: 100, y: 250, sellerId: 's1', sellerName: 'Ivan Petrov', city: 'Sofia', rating: 4.7, products: ['Tomatoes', 'Peppers']),
  _MapMarker(x: 230, y: 380, sellerId: 's2', sellerName: 'Maria Georgieva', city: 'Plovdiv', rating: 4.5, products: ['Apples', 'Pears']),
  _MapMarker(x: 300, y: 200, sellerId: 's3', sellerName: 'Todor Stoyanov', city: 'Varna', rating: 4.9, products: ['Honey']),
  _MapMarker(x: 60, y: 450, sellerId: 's4', sellerName: 'Elena Nikolova', city: 'Burgas', rating: 4.3, products: ['Carrots', 'Potatoes']),
];
