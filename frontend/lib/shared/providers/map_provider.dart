import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../../core/constants.dart';

class MapState {
  final Set<Marker> markers;
  final Set<Polyline> polylines;
  final List<dynamic> routeOptions;
  final bool isLoading;

  MapState({
    this.markers = const {},
    this.polylines = const {},
    this.routeOptions = const [],
    this.isLoading = false,
  });

  MapState copyWith({
    Set<Marker>? markers,
    Set<Polyline>? polylines,
    List<dynamic>? routeOptions,
    bool? isLoading,
  }) {
    return MapState(
      markers: markers ?? this.markers,
      polylines: polylines ?? this.polylines,
      routeOptions: routeOptions ?? this.routeOptions,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

// Day route colors
const _dayColors = [
  Color(0xFFE74C3C), // Day 1 – Red
  Color(0xFF3498DB), // Day 2 – Blue
  Color(0xFFE67E22), // Day 3 – Orange
  Color(0xFF9B59B6), // Day 4 – Purple
  Color(0xFF1ABC9C), // Day 5 – Teal
];

// Constants for day-splitting
const double _adminMinutesPerStop = 30.0; // serving clients at each stop
const double _maxDayMinutes = 360.0; // 6 hours = 360 minutes (stricter limit as requested)
const double _avgSpeedKmh = 60.0; // more balanced average speed
const double _roadFactor = 1.5; // common road curvature factor
const double _maxClusterRadiusKm = 200.0; // max distance between stops (per user request)

class MapNotifier extends Notifier<MapState> {
  @override
  MapState build() => MapState();

  // ─── Haversine distance in km ───
  double _haversineKm(double lat1, double lng1, double lat2, double lng2) {
    const R = 6371.0;
    final dLat = (lat2 - lat1) * pi / 180;
    final dLng = (lng2 - lng1) * pi / 180;
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1 * pi / 180) *
            cos(lat2 * pi / 180) *
            sin(dLng / 2) *
            sin(dLng / 2);
    return 2 * R * asin(sqrt(a));
  }

  // ─── Estimated driving minutes between two cities ───
  double _estimatedDriveMinutes(String cityA, String cityB) {
    final a = AppConstants.cityLocations[cityA];
    final b = AppConstants.cityLocations[cityB];
    if (a == null || b == null) return 0;
    final straightKm = _haversineKm(a.lat, a.lng, b.lat, b.lng);
    final roadKm = straightKm * _roadFactor;
    return (roadKm / _avgSpeedKmh) * 60; // minutes
  }

  // ─── Order cities via nearest-neighbor starting from westernmost ───
  List<String> _nearestNeighborOrder(List<String> cities) {
    if (cities.length <= 2) return List.from(cities);

    final remaining = List<String>.from(cities);

    // Start from the westernmost city (lowest longitude)
    remaining.sort((a, b) {
      final ca = AppConstants.cityLocations[a];
      final cb = AppConstants.cityLocations[b];
      if (ca == null || cb == null) return 0;
      return ca.lng.compareTo(cb.lng);
    });

    final ordered = <String>[remaining.removeAt(0)];

    while (remaining.isNotEmpty) {
      final lastCity = ordered.last;
      final lastCoord = AppConstants.cityLocations[lastCity]!;
      double bestDist = double.infinity;
      int bestIdx = 0;

      for (int i = 0; i < remaining.length; i++) {
        final c = AppConstants.cityLocations[remaining[i]];
        if (c == null) continue;
        final d = _haversineKm(lastCoord.lat, lastCoord.lng, c.lat, c.lng);
        if (d < bestDist) {
          bestDist = d;
          bestIdx = i;
        }
      }
      ordered.add(remaining.removeAt(bestIdx));
    }
    return ordered;
  }

  // ─── Split ordered cities into days by time budget ───
  // Each stop costs: driveTime(from prev) + 30min admin
  // Day total must not exceed 8 hours (480 min)
  List<List<String>> _splitIntoDays(List<String> orderedCities) {
    if (orderedCities.isEmpty) return [];
    if (orderedCities.length == 1) return [orderedCities];

    final days = <List<String>>[];
    var currentDay = <String>[orderedCities.first];
    // First stop of the day: only admin time (you start there)
    double currentDayMinutes = _adminMinutesPerStop;

    for (int i = 1; i < orderedCities.length; i++) {
      final prevCity = orderedCities[i - 1];
      final nextCity = orderedCities[i];
      
      final driveMinutes = _estimatedDriveMinutes(prevCity, nextCity);
      final stopCost = driveMinutes + _adminMinutesPerStop;
      
      // Distance check for clustering
      final pCoords = AppConstants.cityLocations[prevCity]!;
      final nCoords = AppConstants.cityLocations[nextCity]!;
      final distKm = _haversineKm(pCoords.lat, pCoords.lng, nCoords.lat, nCoords.lng);

      if ((currentDayMinutes + stopCost > _maxDayMinutes) || (distKm > _maxClusterRadiusKm)) {
        // CLOSE current day
        days.add(currentDay);
        
        // START new day with nextCity
        currentDay = <String>[nextCity];
        
        // FIX: The driver starts from the previous city in the morning.
        // So the new day's initial time must include the travel to this first stop.
        currentDayMinutes = driveMinutes + _adminMinutesPerStop;
      } else {
        // Fits → add to current day
        currentDay.add(nextCity);
        currentDayMinutes += stopCost;
      }
    }
    // Don't forget the last day
    if (currentDay.isNotEmpty) {
      days.add(currentDay);
    }
    return days;
  }

  // ─── Call Routes API for a list of cities ───
  Future<Map<String, dynamic>?> _callRoutesApi(
      List<String> cities, String apiKey) async {
    if (cities.length < 2) return null;

    final coords = <Map<String, double>>[];
    for (final city in cities) {
      final c = AppConstants.cityLocations[city];
      if (c != null) coords.add({'lat': c.lat, 'lng': c.lng});
    }
    if (coords.length < 2) return null;

    final origin = coords.first;
    final destination = coords.last;
    final intermediates = coords.length > 2
        ? coords.sublist(1, coords.length - 1)
        : <Map<String, double>>[];

    final body = <String, dynamic>{
      'origin': {
        'location': {
          'latLng': {'latitude': origin['lat'], 'longitude': origin['lng']}
        }
      },
      'destination': {
        'location': {
          'latLng': {
            'latitude': destination['lat'],
            'longitude': destination['lng']
          }
        }
      },
      'travelMode': 'DRIVE',
      'polylineEncoding': 'ENCODED_POLYLINE',
      'computeAlternativeRoutes': false,
      'routingPreference': 'TRAFFIC_AWARE',
      'languageCode': 'bg',
      'units': 'METRIC',
    };

    if (intermediates.isNotEmpty) {
      body['intermediates'] = intermediates
          .map((c) => {
                'location': {
                  'latLng': {'latitude': c['lat'], 'longitude': c['lng']}
                }
              })
          .toList();
    }

    final response = await http.post(
      Uri.parse('https://routes.googleapis.com/directions/v2:computeRoutes'),
      headers: {
        'Content-Type': 'application/json',
        'X-Goog-Api-Key': apiKey,
        'X-Goog-FieldMask':
            'routes.duration,routes.distanceMeters,routes.polyline.encodedPolyline',
      },
      body: jsonEncode(body),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final routes = data['routes'] as List?;
      if (routes != null && routes.isNotEmpty) {
        return routes.first as Map<String, dynamic>;
      }
    }
    return null;
  }

  // ═══════════════════════════════════════════════════════════════
  //  MAIN: Multi-day route with time-budget day splitting
  // ═══════════════════════════════════════════════════════════════
  Future<void> fetchMultiDayRoute(List<String> allCities) async {
    if (allCities.length < 2) return;
    state = state.copyWith(isLoading: true);

    final apiKey = dotenv.env['MAPS_KEY'] ?? '';

    try {
      // 1. Order all cities by nearest-neighbor (west → east sweep)
      final ordered = _nearestNeighborOrder(allCities);

      // 2. Split into days by time budget (drive + 30min admin ≤ 8h)
      final days = _splitIntoDays(ordered);

      // 3. For each day, build route with inter-day travel link
      final allMarkers = <Marker>{};
      final allPolylines = <Polyline>{};
      final allRouteOptions = <Map<String, dynamic>>[];

      for (int dayIdx = 0; dayIdx < days.length; dayIdx++) {
        final dayCities = days[dayIdx];
        final dayColor = _dayColors[dayIdx % _dayColors.length];
        final dayNum = dayIdx + 1;
        final numStops = dayCities.length;

        // Build full route cities: if not first day, prepend last city
        // of previous day as the travel start
        List<String> routeCities;
        if (dayIdx > 0) {
          final prevLastCity = days[dayIdx - 1].last;
          routeCities = [prevLastCity, ...dayCities];
        } else {
          routeCities = dayCities;
        }

        final routeResult = await _callRoutesApi(routeCities, apiKey);

        if (routeResult != null) {
          // Parse real driving duration from API
          final durationStr = routeResult['duration'] as String? ?? '0s';
          final driveSecs =
              int.tryParse(durationStr.replaceAll('s', '')) ?? 0;
          final driveMinutes = driveSecs / 60.0;

          // Admin time: 30 min per stop city (not the travel-from city)
          final adminMinutes = numStops * _adminMinutesPerStop;
          final totalMinutes = driveMinutes + adminMinutes;
          final totalH = totalMinutes ~/ 60;
          final totalM = (totalMinutes % 60).round();

          final driveH = driveSecs ~/ 3600;
          final driveM = (driveSecs % 3600) ~/ 60;

          // Distance
          final distMeters =
              (routeResult['distanceMeters'] as num?)?.toDouble() ?? 0;
          final totalKm = (distMeters / 1000).round();

          // Decode polyline
          final encoded = routeResult['polyline']?['encodedPolyline']
                  as String? ??
              '';
          final points = _decodePolyline(encoded);

          // Polyline
          allPolylines.add(Polyline(
            polylineId: PolylineId('day_${dayNum}_route'),
            points: points,
            color: dayColor,
            width: 5,
            jointType: JointType.round,
            startCap: Cap.roundCap,
            endCap: Cap.roundCap,
          ));

          // Markers
          for (final city in routeCities) {
            final coord = AppConstants.cityLocations[city];
            if (coord == null) continue;
            allMarkers.add(Marker(
              markerId: MarkerId(city),
              position: LatLng(coord.lat, coord.lng),
              infoWindow: InfoWindow(title: city, snippet: 'Ден $dayNum'),
              icon: BitmapDescriptor.defaultMarkerWithHue(
                dayIdx == 0
                    ? BitmapDescriptor.hueRed
                    : dayIdx == 1
                        ? BitmapDescriptor.hueAzure
                        : BitmapDescriptor.hueOrange,
              ),
            ));
          }

          // Route option data
          allRouteOptions.add({
            'label': 'Ден $dayNum: ${routeCities.join(' → ')}',
            'day': dayNum,
            'ordered_stops': routeCities,
            'total_distance_km': totalKm,
            'drive_time_readable': '${driveH}ч ${driveM}м',
            'admin_time_minutes': adminMinutes.round(),
            'total_time_readable': '${totalH}ч ${totalM}м',
            'num_stops': numStops,
            'color': dayColor.value,
          });
        }
      }

      state = state.copyWith(
        markers: allMarkers,
        polylines: allPolylines,
        routeOptions: allRouteOptions,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false);
    }
  }

  // ─── Single-day route (kept for simple cases) ───
  Future<void> fetchRoutesApiRoute(List<String> cities) async {
    if (cities.length < 2) return;
    state = state.copyWith(isLoading: true);

    final apiKey = dotenv.env['MAPS_KEY'] ?? '';
    try {
      final routeResult = await _callRoutesApi(cities, apiKey);
      if (routeResult != null) {
        final durationStr = routeResult['duration'] as String? ?? '0s';
        final totalSecs =
            int.tryParse(durationStr.replaceAll('s', '')) ?? 0;
        final h = totalSecs ~/ 3600;
        final m = (totalSecs % 3600) ~/ 60;
        final totalKm =
            ((routeResult['distanceMeters'] as num?)?.toDouble() ?? 0) / 1000;
        final encoded =
            routeResult['polyline']?['encodedPolyline'] as String? ?? '';
        final points = _decodePolyline(encoded);

        final markers = <Marker>{};
        for (int i = 0; i < cities.length; i++) {
          final c = AppConstants.cityLocations[cities[i]];
          if (c != null) {
            markers.add(Marker(
              markerId: MarkerId(cities[i]),
              position: LatLng(c.lat, c.lng),
              infoWindow: InfoWindow(
                  title: cities[i],
                  snippet: i == 0
                      ? 'Start'
                      : i == cities.length - 1
                          ? 'Destination'
                          : 'Stop $i'),
              icon: BitmapDescriptor.defaultMarkerWithHue(
                i == 0
                    ? BitmapDescriptor.hueGreen
                    : i == cities.length - 1
                        ? BitmapDescriptor.hueRed
                        : BitmapDescriptor.hueOrange,
              ),
            ));
          }
        }

        state = state.copyWith(
          markers: markers,
          polylines: {
            Polyline(
              polylineId: const PolylineId('routes_api_route'),
              points: points,
              color: const Color(0xFF2ECC71),
              width: 5,
              jointType: JointType.round,
              startCap: Cap.roundCap,
              endCap: Cap.roundCap,
            )
          },
          routeOptions: [
            {
              'label': cities.join(' → '),
              'ordered_stops': cities,
              'total_distance_km': totalKm.round(),
              'drive_time_readable': '${h}ч ${m}м',
              'total_time_readable': '${h}ч ${m}м',
            }
          ],
          isLoading: false,
        );
        return;
      }
      state = state.copyWith(isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false);
    }
  }

  // ─── AI backend recommended route ───
  Future<void> fetchRecommendedRoute({
    required String sellerId,
    required String listingId,
    required String productId,
    double costPerHour = 15.0,
  }) async {
    state = state.copyWith(isLoading: true);
    try {
      final aiUrl = dotenv.env['AI_URL'] ?? 'http://10.0.2.2:8000';
      final response = await http.post(
        Uri.parse('$aiUrl/recommend-route'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'seller_id': sellerId,
          'listing_id': listingId,
          'product_id': productId,
          'cost_per_hour': costPerHour,
        }),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final options = data['options'] as List;
        if (options.isNotEmpty) _updateMapWithRoute(options.first);
        state = state.copyWith(routeOptions: options, isLoading: false);
      } else {
        state = state.copyWith(isLoading: false);
      }
    } catch (e) {
      state = state.copyWith(isLoading: false);
    }
  }

  // ─── Polyline decoder ───
  List<LatLng> _decodePolyline(String poly) {
    var list = <LatLng>[];
    int index = 0, len = poly.length, lat = 0, lng = 0;
    while (index < len) {
      int b, shift = 0, result = 0;
      do {
        b = poly.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      lat += ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      shift = 0;
      result = 0;
      do {
        b = poly.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      lng += ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      list.add(LatLng(lat / 1E5, lng / 1E5));
    }
    return list;
  }

  // ─── Helper for AI backend responses ───
  void _updateMapWithRoute(dynamic route) {
    final markers = <Marker>{};
    final stops = route['ordered_stops'] as List;
    final encodedPolyline = route['encoded_polyline'] as String? ?? '';

    for (int i = 0; i < stops.length; i++) {
      final cityName = stops[i] as String;
      final coords = AppConstants.cityLocations[cityName];
      if (coords == null) continue;
      markers.add(Marker(
        markerId: MarkerId(cityName),
        position: LatLng(coords.lat, coords.lng),
        infoWindow: InfoWindow(
          title: cityName,
          snippet: i == 0
              ? 'Start'
              : i == stops.length - 1
                  ? 'Destination'
                  : 'Stop $i',
        ),
        icon: BitmapDescriptor.defaultMarkerWithHue(
          i == 0
              ? BitmapDescriptor.hueGreen
              : i == stops.length - 1
                  ? BitmapDescriptor.hueRed
                  : BitmapDescriptor.hueOrange,
        ),
      ));
    }

    List<LatLng> polylinePoints;
    if (encodedPolyline.isNotEmpty) {
      polylinePoints = _decodePolyline(encodedPolyline);
    } else {
      polylinePoints = [];
      for (final cityName in stops) {
        final coords = AppConstants.cityLocations[cityName as String];
        if (coords != null) polylinePoints.add(LatLng(coords.lat, coords.lng));
      }
    }

    state = state.copyWith(
      markers: markers,
      polylines: {
        Polyline(
          polylineId: const PolylineId('recommended_route'),
          points: polylinePoints,
          color: const Color(0xFF2ECC71),
          width: 5,
          jointType: JointType.round,
          startCap: Cap.roundCap,
          endCap: Cap.roundCap,
        )
      },
    );
  }
}

final mapProvider = NotifierProvider<MapNotifier, MapState>(MapNotifier.new);
