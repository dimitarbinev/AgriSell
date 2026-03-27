import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';
import '../models/route_stop.dart';
import '../services/auth_service.dart';
import '../services/product_service.dart';
import '../services/storage_service.dart';
import '../../core/constants.dart';

// ─── Service Providers ───
final authServiceProvider = Provider<AuthService>((ref) => AuthService());
final productServiceProvider = Provider<ProductService>((ref) => ProductService());
final storageServiceProvider = Provider<StorageService>((ref) {
  return StorageService(ref.watch(firebaseStorageProvider));
});

// ─── Firebase Instance Providers ───
final firebaseAuthProvider = Provider<FirebaseAuth>(
  (ref) => FirebaseAuth.instance,
);

final firestoreProvider = Provider<FirebaseFirestore>(
  (ref) => FirebaseFirestore.instance,
);

final firebaseStorageProvider = Provider<FirebaseStorage>(
  (ref) => FirebaseStorage.instance,
);

// ─── Auth State ───
final authStateProvider = StreamProvider<User?>((ref) {
  return ref.watch(firebaseAuthProvider).authStateChanges();
});

// ─── User Profile & Role (Reactive) ───
final userProfileProvider = StreamProvider<Map<String, dynamic>?>((ref) {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return Stream.value(null);

  return ref
      .watch(firestoreProvider)
      .collection('users')
      .doc(user.uid)
      .snapshots()
      .map((doc) => doc.exists ? doc.data() : null);
});

final userRoleProvider = Provider<String?>((ref) {
  final profile = ref.watch(userProfileProvider).value;
  return profile?['role'] as String?;
});



// ─── Current Seller Profile ───
final reactiveSellerProvider = StreamProvider<Seller?>((ref) {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return Stream.value(null);

  return ref
      .watch(firestoreProvider)
      .collection('sellers')
      .doc(user.uid)
      .snapshots()
      .map((doc) {
    if (!doc.exists) {
      // Fallback to Auth name if Firestore doc doesn't exist yet
      return Seller(
        id: user.uid,
        name: user.displayName ?? '',
        mainCity: '',
        phone: '',
        email: user.email ?? '',
        createdAt: DateTime.now(),
      );
    }
    return Seller.fromJson(doc.data()!, doc.id);
  });
});

// ─── Current Buyer Profile ───
final currentBuyerProvider = StreamProvider<Buyer?>((ref) {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return Stream.value(null);

  return ref
      .watch(firestoreProvider)
      .collection('buyers')
      .doc(user.uid)
      .snapshots()
      .map((doc) {
    if (!doc.exists) {
      // Fallback to Auth name if Firestore doc doesn't exist yet
      return Buyer(
        id: user.uid,
        name: user.displayName ?? '',
        preferredCity: '',
        email: user.email ?? '',
        createdAt: DateTime.now(),
      );
    }
    return Buyer.fromJson(doc.data()!, doc.id);
  });
});

// ─── All Active Listings (Backend Powered) ───
final activeListingsProvider = FutureProvider<List<Listing>>((ref) {
  return ref.watch(productServiceProvider).getAvailableListings();
});

// ─── Seller's Listings ───
final sellerListingsProvider =
    StreamProvider.family<List<Listing>, String>((ref, sellerId) {
  final firestore = ref.watch(firestoreProvider);

  return firestore
      .collection('users')
      .doc(sellerId)
      .collection('products')
      .snapshots()
      .asyncMap((productSnap) async {
    final List<Listing> sellerListings = [];

    for (final productDoc in productSnap.docs) {
      final productData = productDoc.data();
      final listingsSnap = await productDoc.reference.collection('listings').get();

      for (final listingDoc in listingsSnap.docs) {
        sellerListings.add(Listing.fromFirestore(
          productData: productData,
          listingData: listingDoc.data(),
          listingId: listingDoc.id,
          sellerId: sellerId,
          productId: productDoc.id,
        ));
      }
    }
    return sellerListings;
  });
});

// ─── Seller's Products ───
final sellerProductsProvider = FutureProvider<List<Product>>((ref) {
  return ref.watch(productServiceProvider).getProducts();
});

// ─── Listing Reservations ───
final listingReservationsProvider =
    StreamProvider.family<List<Reservation>, String>((ref, listingId) {
      return ref
          .watch(firestoreProvider)
          .collection('reservations')
          .where('listingId', isEqualTo: listingId)
          .snapshots()
          .map(
            (snap) =>
                snap.docs
                    .map((d) => Reservation.fromJson(d.data(), d.id))
                    .toList(),
          );
    });

// ─── Buyer's Reservations ───
final buyerReservationsProvider =
    StreamProvider.family<List<Reservation>, String>((ref, buyerId) {
      return ref
          .watch(firestoreProvider)
          .collection('reservations')
          .where('buyerId', isEqualTo: buyerId)
          .snapshots()
          .map(
            (snap) =>
                snap.docs
                    .map((d) => Reservation.fromJson(d.data(), d.id))
                    .toList(),
          );
    });

// ─── Buyer's Reservations (Backend) ───
final backendBuyerReservationsProvider = FutureProvider<List<Reservation>>((ref) async {
  return ref.read(productServiceProvider).getMyReservations();
});

final myReviewsProvider = StreamProvider<List<Review>>((ref) {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return Stream.value([]);
  
  return ref.watch(firestoreProvider)
      .collection('reviews')
      .where('sellerId', isEqualTo: user.uid)
      .snapshots()
      .map((snap) => snap.docs.map((d) => Review.fromJson(d.data(), d.id)).toList());
});

final sellerReviewStatsProvider = Provider<AsyncValue<({double rating, int totalReviews})>>((ref) {
  final reviewsAsync = ref.watch(myReviewsProvider);
  return reviewsAsync.whenData((reviews) {
    if (reviews.isEmpty) {
      return (rating: 0.0, totalReviews: 0);
    }

    final total = reviews.length;
    final avg = reviews.fold<double>(0.0, (acc, r) => acc + r.rating) / total;
    return (rating: avg, totalReviews: total);
  });
});

final myReservationsProvider = StreamProvider<List<Reservation>>((ref) {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return Stream.value([]);

  return ref
      .watch(firestoreProvider)
      .collection('reservations')
      .where('buyerId', isEqualTo: user.uid)
      .snapshots()
      .map((snap) {
        final reservations =
            snap.docs.map((d) => Reservation.fromJson(d.data(), d.id)).toList();
        reservations.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        return reservations;
      });
});

// ─── Seller Reviews ───
final sellerReviewsProvider = StreamProvider.family<List<Review>, String>((
  ref,
  sellerId,
) {
  return ref
      .watch(firestoreProvider)
      .collection('reviews')
      .where('sellerId', isEqualTo: sellerId)
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map(
        (snap) =>
            snap.docs.map((d) => Review.fromJson(d.data(), d.id)).toList(),
      );
});

// ─── Notifications ───
final notificationsProvider =
    StreamProvider.family<List<AppNotification>, String>((ref, userId) {
      return ref
          .watch(firestoreProvider)
          .collection('notifications')
          .where('userId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .limit(50)
          .snapshots()
          .map(
            (snap) =>
                snap.docs
                    .map((d) => AppNotification.fromJson(d.data(), d.id))
                    .toList(),
          );
    });

// ─── Seller's Route Info (Cities + Reservations) ───
class SellerRouteInfo {
  /// One stop per deliverable reservation (plus optional depot), not deduped by city.
  final List<SellerRouteStop> stops;
  final int totalReservations;
  final List<Reservation> reservations;

  SellerRouteInfo({
    required this.stops,
    required this.totalReservations,
    required this.reservations,
  });
}

/// Seller delivery route: built from **all** Firebase reservations for this seller
/// that are still deliverable (active / confirmed), using listing city when possible,
/// then buyer profile city as fallback for map coordinates.
final sellerReservationCitiesProvider = StreamProvider.family<SellerRouteInfo, String>((ref, sellerId) {
  final firestore = ref.watch(firestoreProvider);
  final sellerAsync = ref.watch(reactiveSellerProvider);

  /// Listing id → city string as stored in Firestore (for route resolution).
  Future<Map<String, String>> fetchListingCities() async {
    final productSnap = await firestore
        .collection('users')
        .doc(sellerId)
        .collection('products')
        .get();

    final map = <String, String>{};
    for (final productDoc in productSnap.docs) {
      final productData = productDoc.data();
      final listingsSnap = await productDoc.reference.collection('listings').get();
      for (final listingDoc in listingsSnap.docs) {
        final data = listingDoc.data();
        final city =
            (data['city'] ?? productData['origin'] ?? productData['mainCity']) as String? ?? '';
        map[listingDoc.id] = city;
      }
    }
    return map;
  }

  return firestore
      .collection('reservations')
      .snapshots()
      .asyncMap((snap) async {
    final listingCityById = await fetchListingCities();
    final sellerListingIds = listingCityById.keys.toSet();

    final all = snap.docs
        .map((d) => Reservation.fromJson(d.data(), d.id))
        .where((r) =>
            r.sellerId == sellerId ||
            (r.listingId.isNotEmpty && sellerListingIds.contains(r.listingId)))
        .toList();

    // Every reservation that still counts for delivery (not cancelled / completed).
    final reservations = all.where((r) {
      final s = r.status;
      return s != AppConstants.reservationCancelled && s != AppConstants.reservationCompleted;
    }).toList();

    final buyerCityCache = <String, String>{};

    Future<String?> buyerLocationRaw(String buyerId) async {
      if (buyerId.isEmpty) return null;
      if (buyerCityCache.containsKey(buyerId)) {
        final c = buyerCityCache[buyerId]!;
        return c.isEmpty ? null : c;
      }
      var raw = '';
      final userDoc = await firestore.collection('users').doc(buyerId).get();
      if (userDoc.exists) {
        final data = userDoc.data()!;
        raw = (data['preferredCity'] as String?) ??
            (data['mainCity'] as String?) ??
            (data['city'] as String?) ??
            (data['deliveryCity'] as String?) ??
            '';
      }
      if (raw.isEmpty) {
        final buyerDoc = await firestore.collection('buyers').doc(buyerId).get();
        if (buyerDoc.exists) {
          final data = buyerDoc.data()!;
          raw = (data['preferredCity'] as String?) ??
              (data['mainCity'] as String?) ??
              (data['city'] as String?) ??
              (data['deliveryCity'] as String?) ??
              '';
        }
      }
      buyerCityCache[buyerId] = raw;
      return raw.trim().isEmpty ? null : raw;
    }

    final List<SellerRouteStop> stops = [];

    // Optional start point: seller base (routing anchor).
    final seller = sellerAsync.value;
    if (seller != null && seller.mainCity.isNotEmpty) {
      final mc = AppConstants.resolveCityForMap(seller.mainCity);
      if (mc != null) {
        stops.add(SellerRouteStop(
          id: '__depot__',
          city: mc,
          label: 'Старт · $mc',
        ));
      }
    }

    // One stop per reservation. Prefer **buyer’s** city (profile) so each stop can differ;
    // reservation/listing city often mirrors the offer location for every row.
    for (final r in reservations) {
      String? city = AppConstants.resolveCityForMap(await buyerLocationRaw(r.buyerId));
      city ??= AppConstants.resolveCityForMap(r.city);
      city ??= AppConstants.resolveCityForMap(listingCityById[r.listingId]);
      if (city != null) {
        final name = (r.buyerName?.trim().isNotEmpty == true)
            ? r.buyerName!.trim()
            : 'Клиент';
        stops.add(SellerRouteStop(
          id: r.id,
          city: city,
          label: '$city · $name',
        ));
      }
    }

    return SellerRouteInfo(
      stops: stops,
      totalReservations: reservations.length,
      reservations: reservations,
    );
  });
});

final unreadNotificationCountProvider = Provider.family<int, String>((
  ref,
  userId,
) {
  final notifications = ref.watch(notificationsProvider(userId));
  return notifications.when(
    data: (list) => list.where((n) => !n.read).length,
    loading: () => 0,
    error: (_, _) => 0,
  );
});

// ─── Selected Category Filter ───
class SelectedCategoryNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void setCategory(String? category) => state = category;
}

final selectedCategoryProvider = NotifierProvider<SelectedCategoryNotifier, String?>(SelectedCategoryNotifier.new);

// ─── Search Query ───
class SearchQueryNotifier extends Notifier<String> {
  @override
  String build() => '';

  void setQuery(String query) => state = query;
}

final searchQueryProvider = NotifierProvider<SearchQueryNotifier, String>(SearchQueryNotifier.new);

// ─── Filtered Listings ───
final filteredListingsProvider = Provider<AsyncValue<List<Listing>>>((ref) {
  final listings = ref.watch(activeListingsProvider);
  final category = ref.watch(selectedCategoryProvider);
  final query = ref.watch(searchQueryProvider).toLowerCase();

  return listings.whenData((list) {
    var filtered = list;
    if (category != null && category.isNotEmpty) {
      filtered =
          filtered.where((l) => l.productCategory == category).toList();
    }
    if (query.isNotEmpty) {
      filtered =
          filtered
              .where(
                (l) =>
                    l.productName.toLowerCase().contains(query) ||
                    l.city.toLowerCase().contains(query) ||
                    (l.sellerName?.toLowerCase().contains(query) ?? false),
              )
              .toList();
    }
    return filtered;
  });
});

// ─── Seller Public Profile (for buyer view) ───
final sellerProfileProvider =
    FutureProvider.family<Map<String, dynamic>, String>((ref, sellerId) async {
  return ref.watch(productServiceProvider).getSellerProfile(sellerId);
});

// ─── Saved Sellers ───
final savedSellersProvider = StreamProvider<List<String>>((ref) {
  return ref.watch(productServiceProvider).getSavedSellerIds();
});

// ─── Theme Mode ───
class ThemeModeNotifier extends AsyncNotifier<ThemeMode> {
  static const _key = 'dark_mode';

  @override
  Future<ThemeMode> build() async {
    final prefs = await SharedPreferences.getInstance();
    final isDark = prefs.getBool(_key) ?? true;
    return isDark ? ThemeMode.dark : ThemeMode.light;
  }

  Future<void> toggle() async {
    final current = await future;
    final isDark = current == ThemeMode.dark;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, !isDark);
    state = AsyncValue.data(!isDark ? ThemeMode.dark : ThemeMode.light);
  }
}

final themeModeProvider =
    AsyncNotifierProvider<ThemeModeNotifier, ThemeMode>(ThemeModeNotifier.new);

// ─── Notifications Enabled ───
class NotificationsNotifier extends AsyncNotifier<bool> {
  static const _key = 'notifications_enabled';

  @override
  Future<bool> build() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_key) ?? true;
  }

  Future<void> toggle() async {
    final current = await future;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, !current);
    state = AsyncValue.data(!current);
  }
}

final notificationsEnabledProvider =
    AsyncNotifierProvider<NotificationsNotifier, bool>(NotificationsNotifier.new);
