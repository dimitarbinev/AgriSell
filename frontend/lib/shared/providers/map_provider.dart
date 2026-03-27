import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:convert';
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

class MapNotifier extends Notifier<MapState> {
  @override
  MapState build() => MapState();

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
        
        if (options.isNotEmpty) {
          final bestOption = options.first;
          _updateMapWithRoute(bestOption);
        }
        
        state = state.copyWith(
          routeOptions: options,
          isLoading: false,
        );
      } else {
        state = state.copyWith(isLoading: false);
      }
    } catch (e) {
      state = state.copyWith(isLoading: false);
    }
  }

  Future<void> fetchHardcodedRoute() async {
    state = state.copyWith(isLoading: true);
    
    final apiKey = dotenv.env['MAPS_KEY'] ?? '';
    final url = 'https://maps.googleapis.com/maps/api/directions/json?origin=Sofia,Bulgaria&destination=Sliven,Bulgaria&waypoints=Plovdiv,Bulgaria&key=$apiKey';
    
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'OK') {
          final pointsString = data['routes'][0]['overview_polyline']['points'];
          final decodedPoints = _decodePolyline(pointsString);
          
          final markers = <Marker>{};
          final cityNames = ['Sofia', 'Plovdiv', 'Sliven'];
          
          for (final city in cityNames) {
            final coords = AppConstants.cityLocations[city];
            if (coords != null) {
              markers.add(Marker(
                markerId: MarkerId(city),
                position: LatLng(coords.lat, coords.lng),
                infoWindow: InfoWindow(title: city, snippet: 'Demo Stop'),
                icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
              ));
            }
          }

          final polyline = Polyline(
            polylineId: const PolylineId('road_aware_route'),
            points: decodedPoints,
            color: const Color(0xFF2ECC71),
            width: 5,
            jointType: JointType.round,
            startCap: Cap.roundCap,
            endCap: Cap.roundCap,
          );

          state = state.copyWith(
            markers: markers,
            polylines: {polyline},
            routeOptions: [{
              'label': 'Sofia - Plovdiv - Sliven',
              'ordered_stops': cityNames,
              'total_distance_km': 301,
              'estimated_profit_bgn': 450,
              'travel_time_readable': '3h 25m',
            }],
            isLoading: false,
          );
        } else {
           state = state.copyWith(isLoading: false);
        }
      } else {
        state = state.copyWith(isLoading: false);
      }
    } catch (e) {
      state = state.copyWith(isLoading: false);
    }
  }

  List<LatLng> _decodePolyline(String poly) {
    var list = <LatLng>[];
    int index = 0;
    int len = poly.length;
    int lat = 0;
    int lng = 0;

    while (index < len) {
      int b;
      int shift = 0;
      int result = 0;
      do {
        b = poly.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lat += dlat;

      shift = 0;
      result = 0;
      do {
        b = poly.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lng += dlng;
      list.add(LatLng(lat / 1E5, lng / 1E5));
    }
    return list;
  }

  void _updateMapWithRoute(dynamic route) {
    final markers = <Marker>{};
    final polylinePoints = <LatLng>[];

    // Add stops as markers
    for (final cityName in route['ordered_stops']) {
      final coords = AppConstants.cityLocations[cityName];
      if (coords == null) continue;
      
      final point = LatLng(coords.lat, coords.lng);
      
      markers.add(
        Marker(
          markerId: MarkerId(cityName),
          position: point,
          infoWindow: InfoWindow(
            title: cityName,
            snippet: 'Recommended Stop',
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        ),
      );
      
      polylinePoints.add(point);
    }

    final polylines = {
      Polyline(
        polylineId: const PolylineId('recommended_route'),
        points: polylinePoints,
        color: const Color(0xFF2ECC71),
        width: 5,
        jointType: JointType.round,
        startCap: Cap.roundCap,
        endCap: Cap.roundCap,
      ),
    };

    state = state.copyWith(
      markers: markers,
      polylines: polylines,
    );
  }
}

final mapProvider = NotifierProvider<MapNotifier, MapState>(MapNotifier.new);
