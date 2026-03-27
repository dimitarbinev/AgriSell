import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../shared/providers/map_provider.dart';
import '../../shared/providers/providers.dart';
import '../../core/theme.dart';
import '../../core/constants.dart';

class RoutePlanningScreen extends ConsumerWidget {
  const RoutePlanningScreen({super.key});

  static const LatLng _initialCenter = LatLng(42.6977, 23.3219); // Sofia

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authStateProvider).value;
    if (user == null) return const Scaffold(body: Center(child: Text('Please log in')));

    final listingsAsync = ref.watch(sellerListingsProvider(user.uid));
    final mapState = ref.watch(mapProvider);

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
                    child: Text('Route Planning',
                        style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
                  ),
                  if (mapState.isLoading)
                    const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primaryGreen)),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Map
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
                child: listingsAsync.when(
                  data: (listings) {
                    final activeListings = listings.where((l) => l.status == AppConstants.statusActive).toList();
                    
                    return GoogleMap(
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
                          ref.read(mapProvider.notifier).fetchHardcodedRoute();
                        }
                      },
                    );
                  },
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (err, _) => Center(child: Text('Error loading listings')),
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
                   Text(
                    mapState.routeOptions.isNotEmpty 
                      ? 'Best Route: ${mapState.routeOptions.first['label']}' 
                      : 'Recommended Stops',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)
                  ),
                  const SizedBox(height: 12),
                  if (mapState.isLoading)
                    const Center(child: Padding(
                      padding: EdgeInsets.only(top: 40),
                      child: CircularProgressIndicator(color: AppTheme.primaryGreen),
                    ))
                  else if (mapState.routeOptions.isEmpty)
                    const Center(child: Padding(
                      padding: EdgeInsets.only(top: 40),
                      child: Text('No routes found for active listings', style: TextStyle(color: AppTheme.textSecondary)),
                    ))
                  else
                    ...(() {
                      final routeInfo = mapState.routeOptions.first;
                      final stops = routeInfo['ordered_stops'] as List;
                      final totalProfit = (routeInfo['estimated_profit_bgn'] as num).toDouble();
                      final totalDistance = (routeInfo['total_distance_km'] as num).toDouble();
                      
                      return stops.asMap().entries.map((e) {
                        return _StopCard(
                          rank: e.key + 1,
                          city: e.value,
                          isLast: e.key == stops.length - 1,
                          totalProfit: totalProfit,
                          totalDistance: totalDistance,
                          time: routeInfo['travel_time_readable'],
                        );
                      });
                    }()),
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
  final bool isLast;
  final double totalProfit;
  final double totalDistance;
  final String time;

  const _StopCard({
    required this.rank,
    required this.city,
    required this.isLast,
    required this.totalProfit,
    required this.totalDistance,
    required this.time,
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
                if (isLast)
                   Text('Total: ${totalDistance.toStringAsFixed(0)} km · $time',
                      style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary))
                else
                   const Text('Recommended Stop',
                      style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
              ],
            ),
          ),
          if (isLast)
            Text('${totalProfit.toStringAsFixed(0)} лв',
                style: const TextStyle(fontWeight: FontWeight.w700, color: AppTheme.accentGreen)),
        ],
      ),
    );
  }
}

// Sample data removed as we now use real Firestore data
