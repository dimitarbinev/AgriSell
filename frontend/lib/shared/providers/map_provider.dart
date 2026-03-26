import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

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
    required double sellerLat,
    required double sellerLng,
    required double pricePerKg,
    required double availableQty,
    required List<Map<String, dynamic>> cities,
  }) async {
    state = state.copyWith(isLoading: true);

    try {
      final backendUrl = dotenv.env['BACKEND_URL'] ?? 'http://localhost:8000';
      final response = await http.post(
        Uri.parse('$backendUrl/recommend-route'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'seller_lat': sellerLat,
          'seller_lng': sellerLng,
          'price_per_kg': pricePerKg,
          'available_qty': availableQty,
          'cities': cities,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final options = data['options'] as List;
        
        if (options.isNotEmpty) {
          final bestOption = options.first;
          _updateMapWithRoute(bestOption, cities);
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

  void _updateMapWithRoute(dynamic route, List<Map<String, dynamic>> allCities) {
    final markers = <Marker>{};
    final polylinePoints = <LatLng>[];

    // Add stops as markers
    for (final cityName in route['ordered_stops']) {
      final cityData = allCities.firstWhere((c) => c['name'] == cityName);
      final point = LatLng(
        (cityData['lat'] as num).toDouble(), 
        (cityData['lng'] as num).toDouble()
      );
      
      markers.add(
        Marker(
          markerId: MarkerId(cityName),
          position: point,
          infoWindow: InfoWindow(
            title: cityName,
            snippet: 'Demand: ${cityData['requested_qty']} kg',
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
