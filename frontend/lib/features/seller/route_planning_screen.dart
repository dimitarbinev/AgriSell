import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../shared/providers/map_provider.dart';
import '../../shared/providers/providers.dart';
import '../../shared/models/route_stop.dart';
import '../../core/theme.dart';
import '../../shared/widgets/nature_scaffold.dart';

bool _sameStopsList(List<SellerRouteStop>? a, List<SellerRouteStop> b) {
  if (a == null || a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i].id != b[i].id || a[i].city != b[i].city) return false;
  }
  return true;
}

class RoutePlanningScreen extends ConsumerWidget {
  const RoutePlanningScreen({super.key});

  static const LatLng _initialCenter = LatLng(42.6977, 23.3219);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authStateProvider).value;
    if (user == null) {
      return const Scaffold(body: Center(child: Text('Please log in')));
    }

    final listingsAsync = ref.watch(sellerListingsProvider(user.uid));
    final mapState = ref.watch(mapProvider);
    final citiesAsync = ref.watch(sellerReservationCitiesProvider(user.uid));

    // Firestore stream: refetch route when stop list changes.
    ref.listen(sellerReservationCitiesProvider(user.uid), (prev, next) {
      next.whenData((info) {
        final stops = info.stops;
        final notifier = ref.read(mapProvider.notifier);
        if (stops.isEmpty) {
          notifier.clearRoute();
          return;
        }
        final prevStops = switch (prev) {
          AsyncData(:final value) => value.stops,
          _ => null,
        };
        if (_sameStopsList(prevStops, stops)) return;
        notifier.fetchMultiDayRoute(stops);
      });
    });

    return NatureScaffold(
      appBar: AppBar(
        title: const Text('Маршрут за доставка',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          if (citiesAsync.hasValue && citiesAsync.value!.stops.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.refresh, color: Colors.white),
              onPressed: () {
                ref.read(mapProvider.notifier).fetchMultiDayRoute(citiesAsync.value!.stops);
              },
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Map Container ──
            Expanded(
              flex: 3,
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
                  color: AppTheme.cardSurface,
                  boxShadow: AppTheme.cardShadow,
                  border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                ),
                clipBehavior: Clip.antiAlias,
                child: listingsAsync.when(
                  data: (listings) {
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
                    );
                  },
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (err, _) => const Center(child: Text('Error loading map')),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // ── Day Legend ──
            if (mapState.routeOptions.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (final opt in mapState.routeOptions) ...[
                        _LegendItem(
                          label: 'Ден ${opt['day']}',
                          color: Color((opt as Map)['color'] as int? ?? 0xFF2E7D32),
                        ),
                        const SizedBox(width: 12),
                      ],
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 12),

            // ── Route Details List ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                children: [
                  const Text(
                    'Вашият план за седмицата',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const Spacer(),
                  citiesAsync.when(
                    data: (info) => Text(
                      '${info.totalReservations} клиента',
                      style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                    ),
                    loading: () => const SizedBox.shrink(),
                    error: (_, __) => const SizedBox.shrink(),
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 2,
              child: mapState.isLoading
                  ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryGreen))
                  : citiesAsync.when(
                      data: (info) {
                        if (info.totalReservations == 0) {
                          return const Center(
                            child: Padding(
                              padding: EdgeInsets.all(24),
                              child: Text(
                                'Нямате нови резервации за доставка.\nМаршрутът ще се обнови автоматично при нови заявки.',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: AppTheme.textSecondary),
                              ),
                            ),
                          );
                        }
                        return mapState.routeOptions.isEmpty
                            ? Center(
                                child: Text(
                                  mapState.isLoading 
                                    ? 'Изчисляване на най-добрия маршрут...'
                                    : 'Грешка: Не може да се генерира маршрут.\nУверете се, че градовете са валидни.',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(color: AppTheme.textSecondary)
                                ))
                            : ListView.builder(
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                itemCount: mapState.routeOptions.length,
                                itemBuilder: (context, index) {
                                  return _DayRouteCard(
                                    routeInfo: mapState.routeOptions[index] as Map<String, dynamic>,
                                  );
                                },
                              );
                      },
                      loading: () => const Center(child: CircularProgressIndicator()),
                      error: (err, _) => const Center(child: Text('Грешка при зареждане на градове')),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  final String label;
  final Color color;

  const _LegendItem({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(shape: BoxShape.circle, color: color),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppTheme.textSecondary,
          ),
        ),
      ],
    );
  }
}

class _DayRouteCard extends StatelessWidget {
  final Map<String, dynamic> routeInfo;

  const _DayRouteCard({required this.routeInfo});

  @override
  Widget build(BuildContext context) {
    final dayNum = routeInfo['day'] ?? '?';
    final stops = routeInfo['ordered_stops'] as List? ?? [];
    final distKm = routeInfo['total_distance_km'] ?? 0;
    final totalTime = routeInfo['total_time_readable'] ?? '';
    final driveTime = routeInfo['drive_time_readable'] ?? '';
    final color = Color(routeInfo['color'] as int? ?? 0xFF2E7D32);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: glassDecoration(radius: AppTheme.radiusMedium),
      child: ExpansionTile(
        initiallyExpanded: true,
        shape: const RoundedRectangleBorder(side: BorderSide.none),
        collapsedShape: const RoundedRectangleBorder(side: BorderSide.none),
        leading: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(shape: BoxShape.circle, color: color.withValues(alpha: 0.2)),
          child: Center(
              child: Text('$dayNum',
                  style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 16))),
        ),
        title: Text(
          'Ден $dayNum: ${stops.length} спирки',
          style: const TextStyle(fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
        ),
        subtitle: Text(
          '$distKm км · Общо $totalTime ($driveTime път)',
          style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              children: [
                const Divider(height: 1, thickness: 0.5),
                const SizedBox(height: 8),
                for (int i = 0; i < stops.length; i++)
                  _StopTile(
                    label: stops[i] as String,
                    isFirst: i == 0,
                    isLast: i == stops.length - 1,
                    color: color,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StopTile extends StatelessWidget {
  final String label;
  final bool isFirst;
  final bool isLast;
  final Color color;

  const _StopTile({
    required this.label,
    required this.isFirst,
    required this.isLast,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Column(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color,
                ),
              ),
              if (!isLast)
                Container(
                  width: 2,
                  height: 20,
                  color: color.withValues(alpha: 0.3),
                ),
            ],
          ),
          const SizedBox(width: 12),
          Text(
            label,
            style: const TextStyle(fontSize: 14, color: AppTheme.textPrimary),
          ),
          const Spacer(),
          if (isFirst)
             const Icon(Icons.departure_board, size: 14, color: AppTheme.textTertiary)
          else if (isLast)
             const Icon(Icons.flag, size: 14, color: AppTheme.textTertiary)
          else
             const Icon(Icons.store, size: 14, color: AppTheme.textTertiary),
        ],
      ),
    );
  }
}
