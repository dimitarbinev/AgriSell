import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../../core/constants.dart';
import '../models/route_stop.dart';

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

  /// Clears map overlays when there is nothing to route (e.g. fewer than 2 stops).
  void clearRoute() {
    state = MapState();
  }

  LatLng _markerPositionForStop(
      SellerRouteStop stop, List<SellerRouteStop> segment, int index) {
    final base = AppConstants.cityLocations[stop.city]!;
    final baseLatLng = LatLng(base.lat, base.lng);
    final sameIdx = <int>[];
    for (var j = 0; j < segment.length; j++) {
      if (segment[j].city == stop.city) sameIdx.add(j);
    }
    if (sameIdx.length <= 1) return baseLatLng;
    final k = sameIdx.indexOf(index);
    final n = sameIdx.length;
    final angle = 2 * pi * k / n;
    const offsetDeg = 0.004;
    return LatLng(
      baseLatLng.latitude + offsetDeg * cos(angle),
      baseLatLng.longitude + offsetDeg * sin(angle),
    );
  }

  void _buildSingleStopRoute(SellerRouteStop stop) {
    final coord = AppConstants.cityLocations[stop.city];
    if (coord == null) {
      clearRoute();
      return;
    }

    final marker = Marker(
      markerId: MarkerId(stop.id),
      position: LatLng(coord.lat, coord.lng),
      infoWindow: InfoWindow(title: stop.label, snippet: 'Ден 1'),
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
    );

    state = state.copyWith(
      markers: {marker},
      polylines: const {},
      routeOptions: [
        {
          'label': 'Ден 1: ${stop.label}',
          'day': 1,
          'ordered_stops': [stop.label],
          'total_distance_km': 0,
          'drive_time_readable': '0ч 0м',
          'admin_time_minutes': _adminMinutesPerStop.round(),
          'total_time_readable': '0ч 30м',
          'num_stops': 1,
          'color': _dayColors.first.value,
        }
      ],
      isLoading: false,
    );
  }

  void _buildSameCityMultiStopRoute(List<SellerRouteStop> stops) {
    if (stops.isEmpty) {
      clearRoute();
      return;
    }
    final markers = <Marker>{};
    for (var i = 0; i < stops.length; i++) {
      final s = stops[i];
      final coord = AppConstants.cityLocations[s.city];
      if (coord == null) continue;
      final pos = _markerPositionForStop(s, stops, i);
      markers.add(Marker(
        markerId: MarkerId(s.id),
        position: pos,
        infoWindow: InfoWindow(title: s.label, snippet: 'Ден 1'),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
      ));
    }
    final labels = stops.map((s) => s.label).toList();
    final adminMinutes = stops.length * _adminMinutesPerStop;
    final totalH = adminMinutes ~/ 60;
    final totalM = (adminMinutes % 60).round();
    state = state.copyWith(
      markers: markers,
      polylines: const {},
      routeOptions: [
        {
          'label': 'Ден 1: ${labels.join(' → ')}',
          'day': 1,
          'ordered_stops': labels,
          'total_distance_km': 0,
          'drive_time_readable': '0ч 0м',
          'admin_time_minutes': adminMinutes.round(),
          'total_time_readable': '${totalH}ч ${totalM}м',
          'num_stops': stops.length,
          'color': _dayColors.first.value,
        }
      ],
      isLoading: false,
    );
  }

  List<SellerRouteStop> _nearestNeighborOrderStops(List<SellerRouteStop> stops) {
    if (stops.length <= 2) return List.from(stops);

    final remaining = List<SellerRouteStop>.from(stops);
    remaining.sort((a, b) {
      final ca = AppConstants.cityLocations[a.city];
      final cb = AppConstants.cityLocations[b.city];
      if (ca == null || cb == null) return 0;
      return ca.lng.compareTo(cb.lng);
    });

    final ordered = <SellerRouteStop>[remaining.removeAt(0)];

    while (remaining.isNotEmpty) {
      final lastCity = ordered.last.city;
      final lastCoord = AppConstants.cityLocations[lastCity]!;
      double bestDist = double.infinity;
      var bestIdx = 0;

      for (int i = 0; i < remaining.length; i++) {
        final c = AppConstants.cityLocations[remaining[i].city];
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

  List<List<SellerRouteStop>> _splitIntoDaysStops(
      List<SellerRouteStop> ordered) {
    if (ordered.isEmpty) return [];
    if (ordered.length == 1) return [ordered];

    final days = <List<SellerRouteStop>>[];
    var currentDay = <SellerRouteStop>[ordered.first];
    double currentDayMinutes = _adminMinutesPerStop;

    for (int i = 1; i < ordered.length; i++) {
      final prevCity = ordered[i - 1].city;
      final nextCity = ordered[i].city;

      final driveMinutes = _estimatedDriveMinutes(prevCity, nextCity);
      final stopCost = driveMinutes + _adminMinutesPerStop;

      final pCoords = AppConstants.cityLocations[prevCity]!;
      final nCoords = AppConstants.cityLocations[nextCity]!;
      final distKm = _haversineKm(pCoords.lat, pCoords.lng, nCoords.lat, nCoords.lng);

      if ((currentDayMinutes + stopCost > _maxDayMinutes) ||
          (distKm > _maxClusterRadiusKm)) {
        days.add(currentDay);
        currentDay = <SellerRouteStop>[ordered[i]];
        currentDayMinutes = driveMinutes + _adminMinutesPerStop;
      } else {
        currentDay.add(ordered[i]);
        currentDayMinutes += stopCost;
      }
    }
    if (currentDay.isNotEmpty) {
      days.add(currentDay);
    }
    return days;
  }

  /// Road polyline + stats for a stop sequence (handles duplicate cities).
  Future<({List<LatLng> points, double km, double driveMin})?>
      _polylineForStopSegment(
          List<SellerRouteStop> segment, String apiKey) async {
    if (segment.length < 2) return null;

    final allPoints = <LatLng>[];
    double totalKm = 0;
    double totalDriveMin = 0;

    for (int i = 0; i < segment.length - 1; i++) {
      final a = segment[i].city;
      final b = segment[i + 1].city;

      if (a == b) {
        final c = AppConstants.cityLocations[a]!;
        if (allPoints.isEmpty) allPoints.add(LatLng(c.lat, c.lng));
        allPoints.add(LatLng(c.lat, c.lng));
        continue;
      }

      final routeResult = await _callRoutesApi([a, b], apiKey);
      if (routeResult != null) {
        final durationStr = routeResult['duration'] as String? ?? '0s';
        final driveSecs =
            int.tryParse(durationStr.replaceAll('s', '')) ?? 0;
        totalDriveMin += driveSecs / 60.0;
        final distMeters =
            (routeResult['distanceMeters'] as num?)?.toDouble() ?? 0;
        totalKm += distMeters / 1000.0;
        final encoded = routeResult['polyline']?['encodedPolyline']
                as String? ??
            '';
        final pts = _decodePolyline(encoded);
        if (pts.isNotEmpty) {
          if (allPoints.isNotEmpty) {
            final last = allPoints.last;
            final first = pts.first;
            if ((last.latitude - first.latitude).abs() < 1e-5 &&
                (last.longitude - first.longitude).abs() < 1e-5) {
              allPoints.addAll(pts.skip(1));
            } else {
              allPoints.addAll(pts);
            }
          } else {
            allPoints.addAll(pts);
          }
        }
      } else {
        totalDriveMin += _estimatedDriveMinutes(a, b);
        final ca = AppConstants.cityLocations[a]!;
        final cb = AppConstants.cityLocations[b]!;
        totalKm +=
            _haversineKm(ca.lat, ca.lng, cb.lat, cb.lng) * _roadFactor;
        if (allPoints.isEmpty) allPoints.add(LatLng(ca.lat, ca.lng));
        allPoints.add(LatLng(cb.lat, cb.lng));
      }
    }

    if (allPoints.isEmpty) return null;
    return (points: allPoints, km: totalKm, driveMin: totalDriveMin);
  }

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
  //  MAIN: Multi-day route with time-budget day splitting (per reservation)
  // ═══════════════════════════════════════════════════════════════
  Future<void> fetchMultiDayRoute(List<SellerRouteStop> allStops) async {
    if (allStops.isEmpty) {
      clearRoute();
      return;
    }
    if (allStops.length == 1) {
      _buildSingleStopRoute(allStops.first);
      return;
    }
    final uniqueCities = allStops.map((s) => s.city).toSet();
    if (uniqueCities.length == 1) {
      _buildSameCityMultiStopRoute(allStops);
      return;
    }

    state = state.copyWith(isLoading: true);

    final apiKey = dotenv.env['MAPS_KEY'] ?? '';

    try {
      final ordered = _nearestNeighborOrderStops(allStops);
      final days = _splitIntoDaysStops(ordered);

      final allMarkers = <Marker>{};
      final allPolylines = <Polyline>{};
      final allRouteOptions = <Map<String, dynamic>>[];

      for (int dayIdx = 0; dayIdx < days.length; dayIdx++) {
        final dayStops = days[dayIdx];
        final dayColor = _dayColors[dayIdx % _dayColors.length];
        final dayNum = dayIdx + 1;
        final numStops = dayStops.length;

        final List<SellerRouteStop> routeSegment;
        if (dayIdx > 0) {
          routeSegment = [days[dayIdx - 1].last, ...dayStops];
        } else {
          routeSegment = dayStops;
        }

        final seg = routeSegment.length >= 2
            ? await _polylineForStopSegment(routeSegment, apiKey)
            : null;

        final points = seg?.points ?? <LatLng>[];
        final totalKm = seg?.km ?? 0.0;
        final driveMinutes = seg?.driveMin ?? 0.0;

        if (points.length > 1) {
          allPolylines.add(Polyline(
            polylineId: PolylineId('day_${dayNum}_route'),
            points: points,
            color: dayColor,
            width: 5,
            jointType: JointType.round,
            startCap: Cap.roundCap,
            endCap: Cap.roundCap,
          ));
        }

        for (var i = 0; i < dayStops.length; i++) {
          final s = dayStops[i];
          final coord = AppConstants.cityLocations[s.city];
          if (coord == null) continue;
          final pos = _markerPositionForStop(s, dayStops, i);
          allMarkers.add(Marker(
            markerId: MarkerId('${s.id}_d$dayNum'),
            position: pos,
            infoWindow: InfoWindow(title: s.label, snippet: 'Ден $dayNum'),
            icon: BitmapDescriptor.defaultMarkerWithHue(
              dayIdx == 0
                  ? BitmapDescriptor.hueRed
                  : dayIdx == 1
                      ? BitmapDescriptor.hueAzure
                      : BitmapDescriptor.hueOrange,
            ),
          ));
        }

        final adminMinutes = numStops * _adminMinutesPerStop;
        final totalMinutes = driveMinutes + adminMinutes;
        final totalH = totalMinutes ~/ 60;
        final totalM = (totalMinutes % 60).round();

        final driveSecs = (driveMinutes * 60).round();
        final driveH = driveSecs ~/ 3600;
        final driveM = (driveSecs % 3600) ~/ 60;

        final labels = dayStops.map((s) => s.label).toList();

        allRouteOptions.add({
          'label': 'Ден $dayNum: ${labels.join(' → ')}',
          'day': dayNum,
          'ordered_stops': labels,
          'total_distance_km': totalKm.round(),
          'drive_time_readable': '${driveH}ч ${driveM}м',
          'admin_time_minutes': adminMinutes.round(),
          'total_time_readable': '${totalH}ч ${totalM}м',
          'num_stops': numStops,
          'color': dayColor.value,
        });
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
