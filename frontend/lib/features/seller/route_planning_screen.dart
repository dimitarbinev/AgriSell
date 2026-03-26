import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../shared/providers/map_provider.dart';
import '../../core/theme.dart';

class RoutePlanningScreen extends ConsumerWidget {
  const RoutePlanningScreen({super.key});

  static const LatLng _initialCenter = LatLng(42.6977, 23.3219); // Sofia

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mapState = ref.watch(mapProvider);

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Text('Route Planning',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
            ),
            const SizedBox(height: 16),
            // Map Placeholder
            Expanded(
              flex: 3,
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
                  color: AppTheme.cardSurface,
                  border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
                ),
                clipBehavior: Clip.antiAlias,
                child: GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: _initialCenter,
                    zoom: 7,
                  ),
                  markers: mapState.markers,
                  polylines: mapState.polylines,
                  myLocationEnabled: true,
                  zoomControlsEnabled: false,
                  mapType: MapType.normal,
                  onMapCreated: (controller) {
                    if (mapState.routeOptions.isEmpty) {
                      ref.read(mapProvider.notifier).fetchRecommendedRoute(
                        sellerLat: 42.6977,
                        sellerLng: 23.3219,
                        pricePerKg: 3.5,
                        availableQty: 500,
                        cities: _sampleCityData,
                      );
                    }
                  },
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Ranked stops
            Expanded(
              flex: 2,
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: [
                  const Text('Ranked Stops',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                  const SizedBox(height: 12),
                  if (mapState.isLoading)
                    const Center(child: CircularProgressIndicator(color: AppTheme.primaryGreen))
                  else if (mapState.routeOptions.isEmpty)
                    const Center(child: Text('No routes found', style: TextStyle(color: AppTheme.textSecondary)))
                  else
                    ...mapState.routeOptions.first['ordered_stops'].asMap().entries.map((e) {
                      final cityName = e.value;
                      final cityData = _sampleCityData.firstWhere((c) => c['name'] == cityName);
                      final routeInfo = mapState.routeOptions.first;
                      
                      return _StopCard(
                        rank: e.key + 1,
                        city: cityName,
                        demand: (cityData['requested_qty'] as num).toInt(),
                        distance: (routeInfo['total_distance_km'] as num).toInt(),
                        profit: (routeInfo['estimated_profit_bgn'] as num).toDouble() / routeInfo['ordered_stops'].length,
                      );
                    }),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StopCard extends StatelessWidget {
  final int rank;
  final String city;
  final int demand;
  final int distance;
  final double profit;

  const _StopCard({
    required this.rank,
    required this.city,
    required this.demand,
    required this.distance,
    required this.profit,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: glassDecoration(),
      child: Row(
        children: [
          Container(
            width: 32, height: 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: AppTheme.primaryGradient,
            ),
            child: Center(child: Text('$rank', style: const TextStyle(fontWeight: FontWeight.w800, color: Colors.white, fontSize: 14))),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(city, style: const TextStyle(fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                Text('$demand kg demand · $distance km',
                    style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
              ],
            ),
          ),
          Text('~${profit.toStringAsFixed(0)} лв',
              style: const TextStyle(fontWeight: FontWeight.w700, color: AppTheme.accentGreen)),
        ],
      ),
    );
  }
}

const _sampleCityData = [
  {'name': 'Plovdiv', 'lat': 42.1354, 'lng': 24.7453, 'requested_qty': 85},
  {'name': 'Sofia', 'lat': 42.6977, 'lng': 23.3219, 'requested_qty': 75},
  {'name': 'Stara Zagora', 'lat': 42.4258, 'lng': 25.6345, 'requested_qty': 40},
  {'name': 'Burgas', 'lat': 42.5048, 'lng': 27.4626, 'requested_qty': 20},
];
