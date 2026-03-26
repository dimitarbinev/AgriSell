import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../core/theme.dart';
import '../../shared/widgets/seller_card.dart';

class BuyerMapScreen extends StatefulWidget {
  const BuyerMapScreen({super.key});

  @override
  State<BuyerMapScreen> createState() => _BuyerMapScreenState();
}

class _BuyerMapScreenState extends State<BuyerMapScreen> {
  static const LatLng _center = LatLng(42.6977, 23.3219); // Sofia

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: const CameraPosition(
              target: _center,
              zoom: 6.5,
            ),
            markers: _markers.map((m) {
              return Marker(
                markerId: MarkerId(m.sellerId),
                position: m.position,
                infoWindow: InfoWindow(
                  title: m.sellerName,
                  snippet: '${m.city} · ★ ${m.rating}',
                  onTap: () => _showSellerSheet(context, m),
                ),
                icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
              );
            }).toSet(),
            myLocationEnabled: true,
            zoomControlsEnabled: false,
          ),

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
  final LatLng position;
  final String sellerId, sellerName, city;
  final double rating;
  final List<String> products;

  const _MapMarker({
    required this.position,
    required this.sellerId, required this.sellerName,
    required this.city, required this.rating,
    required this.products,
  });
}

const _markers = [
  _MapMarker(position: LatLng(42.6977, 23.3219), sellerId: 's1', sellerName: 'Ivan Petrov', city: 'Sofia', rating: 4.7, products: ['Tomatoes', 'Peppers']),
  _MapMarker(position: LatLng(42.1354, 24.7453), sellerId: 's2', sellerName: 'Maria Georgieva', city: 'Plovdiv', rating: 4.5, products: ['Apples', 'Pears']),
  _MapMarker(position: LatLng(43.2141, 27.9147), sellerId: 's3', sellerName: 'Todor Stoyanov', city: 'Varna', rating: 4.9, products: ['Honey']),
  _MapMarker(position: LatLng(42.5048, 27.4626), sellerId: 's4', sellerName: 'Elena Nikolova', city: 'Burgas', rating: 4.3, products: ['Carrots', 'Potatoes']),
];
