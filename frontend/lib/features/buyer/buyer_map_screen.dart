import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../shared/models/models.dart';
import '../../shared/providers/providers.dart';
import '../../shared/widgets/seller_card.dart';
import '../../shared/widgets/nature_scaffold.dart';

class BuyerMapScreen extends ConsumerStatefulWidget {
  const BuyerMapScreen({super.key});

  @override
  ConsumerState<BuyerMapScreen> createState() => _BuyerMapScreenState();
}

class _BuyerMapScreenState extends ConsumerState<BuyerMapScreen> {
  static const LatLng _defaultCenter = LatLng(42.6977, 23.3219);

  final _searchController = TextEditingController();
  String _searchQuery = '';
  GoogleMapController? _mapController;
  int _lastFitMarkerCount = -1;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text;
        _lastFitMarkerCount = -1;
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _fitCameraToMarkers(List<_MapMarker> markers) {
    if (_mapController == null || markers.isEmpty) return;
    if (markers.length == _lastFitMarkerCount) return;
    _lastFitMarkerCount = markers.length;

    if (markers.length == 1) {
      _mapController!.animateCamera(
        CameraUpdate.newLatLngZoom(markers.first.position, 8.5),
      );
      return;
    }

    double minLat = markers.first.position.latitude;
    double maxLat = minLat;
    double minLng = markers.first.position.longitude;
    double maxLng = minLng;
    for (final m in markers) {
      final p = m.position;
      minLat = math.min(minLat, p.latitude);
      maxLat = math.max(maxLat, p.latitude);
      minLng = math.min(minLng, p.longitude);
      maxLng = math.max(maxLng, p.longitude);
    }
    final pad = 0.35;
    _mapController!.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(minLat - pad, minLng - pad),
          northeast: LatLng(maxLat + pad, maxLng + pad),
        ),
        56,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sellersAsync = ref.watch(mapSellersProvider);
    final usersAsync = ref.watch(mapDirectoryUsersProvider);
    final listingsAsync = ref.watch(activeListingsProvider);
    final currentUserId = ref.watch(authStateProvider).value?.uid;

    final listings = listingsAsync.maybeWhen(
      data: (l) => l,
      orElse: () => <Listing>[],
    );

    final markers = sellersAsync.maybeWhen(
      data: (sellers) {
        return usersAsync.maybeWhen(
          data: (dirUsers) => _buildCombinedMapMarkers(
            sellers: sellers,
            directoryUsers: dirUsers,
            listings: listings,
            currentUserId: currentUserId,
            search: _searchQuery,
          ),
          orElse: () => _buildCombinedMapMarkers(
            sellers: sellers,
            directoryUsers: const [],
            listings: listings,
            currentUserId: currentUserId,
            search: _searchQuery,
          ),
        );
      },
      orElse: () => <_MapMarker>[],
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fitCameraToMarkers(markers);
    });

    LatLng center = _defaultCenter;
    if (markers.isNotEmpty) {
      center = markers.first.position;
    }

    final loading = sellersAsync.isLoading || usersAsync.isLoading;

    return NatureScaffold(
      safeArea: false,
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: center,
              zoom: markers.length <= 1 ? 7.5 : 6.2,
            ),
            onMapCreated: (c) {
              _mapController = c;
              _lastFitMarkerCount = -1;
              _fitCameraToMarkers(markers);
            },
            markers: markers
                .map(
                  (m) => Marker(
                    markerId: MarkerId(m.userId),
                    position: m.position,
                    onTap: () => _showPinSheet(context, m),
                    infoWindow: InfoWindow(
                      title: m.displayName,
                      snippet: m.opensSellerProfile
                          ? '${m.city} · ★ ${m.rating.toStringAsFixed(1)}'
                          : '${m.city} · ${m.roleLabel}',
                    ),
                    icon: BitmapDescriptor.defaultMarkerWithHue(
                      m.opensSellerProfile
                          ? BitmapDescriptor.hueGreen
                          : BitmapDescriptor.hueAzure,
                    ),
                  ),
                )
                .toSet(),
            myLocationEnabled: true,
            zoomControlsEnabled: false,
          ),

          if (loading)
            const Positioned(
              left: 0,
              right: 0,
              top: 0,
              child: LinearProgressIndicator(minHeight: 3, color: AppTheme.accentGreen),
            ),

          Positioned(
            top: MediaQuery.of(context).padding.top + 12,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              decoration: glassDecoration(),
              child: TextField(
                controller: _searchController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Търси хора наблизо...',
                  hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.4)),
                  prefixIcon: const Icon(Icons.search, size: 22, color: Colors.white70),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                ),
              ),
            ),
          ),


          if (markers.isEmpty &&
              sellersAsync.hasValue &&
              usersAsync.hasValue &&
              !loading)
            Positioned(
              left: 20,
              right: 20,
              bottom: 100,
              child: Material(
                color: AppTheme.cardSurface.withValues(alpha: 0.92),
                borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    (sellersAsync.value ?? []).isEmpty && (usersAsync.value ?? []).isEmpty
                        ? 'Няма записи в sellers / users с град, който картата разпознава.'
                        : 'Няма резултати по филтъра или градът не е в списъка — вижте resolveCityForMap в constants.',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 13),
                  ),
                ),
              ),
            ),

          if (sellersAsync.hasError)
            Positioned(
              left: 20,
              right: 20,
              bottom: 100,
              child: Material(
                color: AppTheme.cardSurface.withValues(alpha: 0.92),
                borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    'sellers: ${sellersAsync.error}',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 13),
                  ),
                ),
              ),
            ),

          if (usersAsync.hasError)
            Positioned(
              left: 20,
              right: 20,
              bottom: usersAsync.hasError && sellersAsync.hasError ? 52 : 100,
              child: Material(
                color: AppTheme.cardSurface.withValues(alpha: 0.92),
                borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    'users: ${usersAsync.error}',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 13),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _showPinSheet(BuildContext context, _MapMarker m) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xFF1A2B1A).withValues(alpha: 0.95),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            SellerCard(
              name: m.displayName,
              rating: m.rating,
              city: m.city,
              productChips: m.products,
              onTap: () {
                Navigator.pop(ctx);
                if (m.opensSellerProfile) {
                  context.push('/buyer/seller/${m.userId}');
                }
              },
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accentGreen,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                  ),
                  elevation: 0,
                ),
                onPressed: () {
                  Navigator.pop(ctx);
                  if (m.opensSellerProfile) {
                    context.push('/buyer/seller/${m.userId}');
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Публичен профил е наличен само за продавачите с обяви.'),
                      ),
                    );
                  }
                },
                child: Text(
                  m.opensSellerProfile
                      ? 'Към профила на продавача'
                      : 'Само продавачи имат магазин профил',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            SizedBox(height: MediaQuery.of(ctx).padding.bottom + 10),
          ],
        ),
      ),
    );
  }
}

List<_MapMarker> _buildCombinedMapMarkers({
  required List<Seller> sellers,
  required List<MapDirectoryUser> directoryUsers,
  required List<Listing> listings,
  String? currentUserId,
  required String search,
}) {

  List<String> productChipsForSeller(String sellerId) {
    final names = listings
        .where((l) => l.sellerId == sellerId)
        .map((l) => l.productName)
        .toSet()
        .take(6)
        .toList();
    if (names.isEmpty) return const ['Натисни за профил'];
    return names;
  }

  final raw = <_MapMarker>[];

  final filteredSellers = sellers.where((s) {
    if (currentUserId != null && s.id == currentUserId) return false;
    if (search.trim().isNotEmpty) {
      final q = search.toLowerCase();
      final cityResolved = AppConstants.resolveCityForMap(s.mainCity) ?? s.mainCity;
      if (!s.name.toLowerCase().contains(q) && !cityResolved.toLowerCase().contains(q)) {
        return false;
      }
    }
    return true;
  });

  for (final s in filteredSellers) {
    final city = AppConstants.resolveCityForMap(s.mainCity);
    if (city == null) continue;
    final coords = AppConstants.cityLocations[city];
    if (coords == null) continue;
    raw.add(_MapMarker(
      position: LatLng(coords.lat, coords.lng),
      userId: s.id,
      displayName: s.name.trim().isEmpty ? 'Продавач' : s.name.trim(),
      city: city,
      rating: s.rating,
      products: productChipsForSeller(s.id),
      opensSellerProfile: true,
      roleLabel: 'Продавач',
    ));
  }
  final onMapSellerIds = raw.map((m) => m.userId).toSet();

  for (final u in directoryUsers) {
    if (currentUserId != null && u.id == currentUserId) continue;
    if (onMapSellerIds.contains(u.id)) continue;

    if (search.trim().isNotEmpty) {
      final q = search.toLowerCase();
      if (!u.name.toLowerCase().contains(q) && !u.resolvedCity.toLowerCase().contains(q)) {
        continue;
      }
    }

    final coords = AppConstants.cityLocations[u.resolvedCity];
    if (coords == null) continue;

    final isSellerRole = u.role == 'seller';
    final label = isSellerRole ? 'Продавач (профил)' : 'Купувач';

    raw.add(_MapMarker(
      position: LatLng(coords.lat, coords.lng),
      userId: u.id,
      displayName: u.name,
      city: u.resolvedCity,
      rating: 0,
      products: [label],
      opensSellerProfile: isSellerRole,
      roleLabel: label,
    ));
  }

  return _spreadPinsByCity(raw);
}

/// Offset pins that share the same city so they remain visible.
List<_MapMarker> _spreadPinsByCity(List<_MapMarker> pins) {
  final byCity = <String, List<_MapMarker>>{};
  for (final p in pins) {
    byCity.putIfAbsent(p.city, () => []).add(p);
  }
  final out = <_MapMarker>[];
  for (final entry in byCity.entries) {
    final city = entry.key;
    final list = entry.value;
    final coords = AppConstants.cityLocations[city]!;
    final base = LatLng(coords.lat, coords.lng);
    for (var i = 0; i < list.length; i++) {
      final m = list[i];
      final pos = list.length <= 1
          ? base
          : LatLng(
              base.latitude + 0.004 * math.cos(2 * math.pi * i / list.length),
              base.longitude + 0.004 * math.sin(2 * math.pi * i / list.length),
            );
      out.add(_MapMarker(
        position: pos,
        userId: m.userId,
        displayName: m.displayName,
        city: m.city,
        rating: m.rating,
        products: m.products,
        opensSellerProfile: m.opensSellerProfile,
        roleLabel: m.roleLabel,
      ));
    }
  }
  return out;
}

class _MapMarker {
  final LatLng position;
  final String userId;
  final String displayName;
  final String city;
  final double rating;
  final List<String> products;
  final bool opensSellerProfile;
  final String roleLabel;

  const _MapMarker({
    required this.position,
    required this.userId,
    required this.displayName,
    required this.city,
    required this.rating,
    required this.products,
    required this.opensSellerProfile,
    required this.roleLabel,
  });
}

