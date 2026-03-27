import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';
import '../services/auth_service.dart';
import '../services/product_service.dart';
import '../services/storage_service.dart';

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
final backendBuyerReservationsProvider = FutureProvider<List<Reservation>>((ref) {
  return ref.watch(productServiceProvider).getMyReservations();
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
