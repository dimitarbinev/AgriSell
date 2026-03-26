import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/models.dart';
import '../services/auth_service.dart';
import '../services/product_service.dart';

// ─── Service Providers ───
final authServiceProvider = Provider<AuthService>((ref) => AuthService());
final productServiceProvider = Provider<ProductService>((ref) => ProductService());

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

// ─── User Role ───
class UserRoleNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void setRole(String? role) => state = role;
}

final userRoleProvider = NotifierProvider<UserRoleNotifier, String?>(UserRoleNotifier.new);

// ─── Registration Data ───
class RegistrationDataNotifier extends Notifier<Map<String, String>> {
  @override
  Map<String, String> build() => {};

  void updateData(Map<String, String> data) {
    state = {...state, ...data};
  }

  void clear() => state = {};
}

final registrationDataProvider = NotifierProvider<RegistrationDataNotifier, Map<String, String>>(RegistrationDataNotifier.new);

// ─── Current Seller Profile ───
final currentSellerProvider = FutureProvider<Seller?>((ref) {
  final authState = ref.watch(authStateProvider);
  return authState.when(
    data: (user) async {
      if (user == null) return null;
      final doc =
          await ref
              .read(firestoreProvider)
              .collection('sellers')
              .doc(user.uid)
              .get();
      if (!doc.exists) return null;
      return Seller.fromJson(doc.data()!, doc.id);
    },
    loading: () => null,
    error: (_, _) => null,
  );
});

// ─── Current Buyer Profile ───
final currentBuyerProvider = FutureProvider<Buyer?>((ref) {
  final authState = ref.watch(authStateProvider);
  return authState.when(
    data: (user) async {
      if (user == null) return null;
      final doc =
          await ref
              .read(firestoreProvider)
              .collection('buyers')
              .doc(user.uid)
              .get();
      if (!doc.exists) return null;
      return Buyer.fromJson(doc.data()!, doc.id);
    },
    loading: () => null,
    error: (_, _) => null,
  );
});

// ─── All Active Listings ───
final activeListingsProvider = StreamProvider<List<Listing>>((ref) {
  return ref
      .watch(firestoreProvider)
      .collection('listings')
      .where('status', whereIn: ['active', 'threshold_reached'])
      .snapshots()
      .map(
        (snap) =>
            snap.docs.map((d) => Listing.fromJson(d.data(), d.id)).toList(),
      );
});

// ─── Seller's Listings ───
final sellerListingsProvider = StreamProvider.family<List<Listing>, String>((
  ref,
  sellerId,
) {
  return ref
      .watch(firestoreProvider)
      .collection('listings')
      .where('sellerId', isEqualTo: sellerId)
      .snapshots()
      .map(
        (snap) =>
            snap.docs.map((d) => Listing.fromJson(d.data(), d.id)).toList(),
      );
});

// ─── Seller's Products ───
final sellerProductsProvider = StreamProvider.family<List<Product>, String>((
  ref,
  sellerId,
) {
  return ref
      .watch(firestoreProvider)
      .collection('products')
      .where('sellerId', isEqualTo: sellerId)
      .snapshots()
      .map(
        (snap) =>
            snap.docs.map((d) => Product.fromJson(d.data(), d.id)).toList(),
      );
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
