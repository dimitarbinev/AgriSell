import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import '../models/models.dart';

class ProductService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final String _baseUrl = dotenv.env['BACKEND_URL'] ?? '';

  Future<void> addProduct({
    required String productName,
    required double minThreshold,
    required double maxCapacity,
    required double availableQuantity,
    required String category,
    required String origin,
    String? image,
    required double pricePerKg,
    required String season,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('No authenticated user found');
    }

    final idToken = await user.getIdToken();
    if (idToken == null) {
      throw Exception('Failed to retrieve authentication token');
    }

    final cleanBaseUrl = _baseUrl.endsWith('/') ? _baseUrl.substring(0, _baseUrl.length - 1) : _baseUrl;
    final url = Uri.parse('$cleanBaseUrl/seller/product');

    final payload = {
      'productName': productName,
      'minThreshold': minThreshold,
      'maxCapacity': maxCapacity,
      'availableQuantity': availableQuantity,
      'category': category,
      'origin': origin,
      'image': image,
      'pricePerKg': pricePerKg,
      'season': season,
    };

    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $idToken',
      },
      body: jsonEncode(payload),
    );

    if (response.headers['content-type']?.contains('application/json') != true) {
      throw Exception(
        'Backend returned HTML instead of JSON.\nStatus: ${response.statusCode}\nBody: ${response.body.substring(0, 80)}',
      );
    }

    final result = jsonDecode(response.body);

    if (response.statusCode != 200) {
      throw Exception(result['message'] ?? 'Failed to add product');
    }
  }

  /// Calls the AI /price-suggestion endpoint.
  /// Returns a map with keys: product, quarterly_prices, overall_average,
  /// season_average, suggested_price, season, unit.
  /// Returns null if the product is not in the NSI Excel data.
  Future<Map<String, dynamic>?> getPriceSuggestion(
    String productName, {
    String? season,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return null;
    final idToken = await user.getIdToken();
    if (idToken == null) return null;

    try {
      final cleanBaseUrl =
          _baseUrl.endsWith('/') ? _baseUrl.substring(0, _baseUrl.length - 1) : _baseUrl;
      final url = Uri.parse('$cleanBaseUrl/price-suggestion');
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $idToken',
        },
        body: jsonEncode({
          'product_name': productName,
          if (season != null) 'season': season,
        }),
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
    } catch (e) {
      print('Price suggestion error: $e');
    }
    return null;
  }

  Future<String?> classifyProduct(String productName) async {
    final user = _auth.currentUser;
    if (user == null) return null;

    final idToken = await user.getIdToken();
    if (idToken == null) return null;

    try {
      final cleanBaseUrl = _baseUrl.endsWith('/') ? _baseUrl.substring(0, _baseUrl.length - 1) : _baseUrl;
      final url = Uri.parse('$cleanBaseUrl/classify-product');

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $idToken',
        },
        body: jsonEncode({'product_name': productName}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['category'] as String?;
      }
    } catch (e) {
      print('Classification error: $e');
    }
    return null;
  }

  Future<List<Product>> getProducts() async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('No authenticated user found');

    final idToken = await user.getIdToken();
    if (idToken == null) throw Exception('Failed to retrieve authentication token');

    final cleanBaseUrl = _baseUrl.endsWith('/') ? _baseUrl.substring(0, _baseUrl.length - 1) : _baseUrl;
    final url = Uri.parse('$cleanBaseUrl/seller/getProducts');

    final response = await http.get(
      url,
      headers: {
        'Authorization': 'Bearer $idToken',
      },
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to load products: ${response.body}');
    }

    final List<dynamic> data = jsonDecode(response.body);
    return data.map((item) => Product.fromJson(item, item['id'] ?? '')).toList();
  }

  Future<void> confirmListing({
    required String productId,
    required String city,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('No authenticated user found');

    final idToken = await user.getIdToken();
    if (idToken == null) throw Exception('Failed to retrieve authentication token');

    final cleanBaseUrl = _baseUrl.endsWith('/') ? _baseUrl.substring(0, _baseUrl.length - 1) : _baseUrl;
    final url = Uri.parse('$cleanBaseUrl/seller/confirmation');

    final payload = {
      'productId': productId,
      'city': city,
      'startDate': startDate.toIso8601String(),
      'endDate': endDate.toIso8601String(),
    };

    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $idToken',
      },
      body: jsonEncode(payload),
    );

    if (response.statusCode != 200) {
      final result = jsonDecode(response.body);
      throw Exception(result['message'] ?? 'Failed to confirm listing');
    }
  }

  Future<List<Listing>> getAvailableListings() async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('No authenticated user found');

    final idToken = await user.getIdToken();
    if (idToken == null) throw Exception('Failed to retrieve authentication token');

    final cleanBaseUrl = _baseUrl.endsWith('/') ? _baseUrl.substring(0, _baseUrl.length - 1) : _baseUrl;
    final url = Uri.parse('$cleanBaseUrl/buyer/available_listings');

    final response = await http.get(
      url,
      headers: {
        'Authorization': 'Bearer $idToken',
      },
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to load available listings: ${response.body}');
    }

    final List<dynamic> data = jsonDecode(response.body);
    return data.map((item) => Listing.fromJson(item, item['id'] ?? '')).toList();
  }

  Future<void> updateListingStatus({
    required String productId,
    required String listingId,
    required int status,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('No authenticated user found');

    final idToken = await user.getIdToken();
    if (idToken == null) throw Exception('Failed to retrieve authentication token');

    final cleanBaseUrl = _baseUrl.endsWith('/') ? _baseUrl.substring(0, _baseUrl.length - 1) : _baseUrl;
    final url = Uri.parse('$cleanBaseUrl/seller/updateStatus');

    final payload = {
      'productId': productId,
      'listingId': listingId,
      'status': status,
    };

    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $idToken',
      },
      body: jsonEncode(payload),
    );

    if (response.statusCode != 200) {
      final result = jsonDecode(response.body);
      throw Exception(result['message'] ?? 'Failed to update listing status');
    }
  }

  Future<void> placeOrder({
    required String listingId,
    required String sellerId,
    required String productId,
    required double quantity,
    required double deposit,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('No authenticated user found');

    final idToken = await user.getIdToken();
    if (idToken == null) throw Exception('Failed to retrieve authentication token');

    final cleanBaseUrl = _baseUrl.endsWith('/') ? _baseUrl.substring(0, _baseUrl.length - 1) : _baseUrl;
    final url = Uri.parse('$cleanBaseUrl/buyer/place_order');

    final payload = {
      'listingId': listingId,
      'sellerId': sellerId,
      'productId': productId,
      'quantity': quantity,
      'deposit': deposit,
    };


    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $idToken',
      },
      body: jsonEncode(payload),
    );

    if (response.statusCode != 200) {
      final result = jsonDecode(response.body);
      throw Exception(result['message'] ?? 'Failed to place order');
    }
  }

  Future<Map<String, dynamic>> getSellerProfile(String sellerId) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('No authenticated user found');

    final idToken = await user.getIdToken();
    if (idToken == null) throw Exception('Failed to retrieve authentication token');

    final cleanBaseUrl = _baseUrl.endsWith('/') ? _baseUrl.substring(0, _baseUrl.length - 1) : _baseUrl;
    final url = Uri.parse('$cleanBaseUrl/buyer/seller/$sellerId');

    final response = await http.get(
      url,
      headers: {
        'Authorization': 'Bearer $idToken',
      },
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to load seller profile: ${response.body}');
    }

    return jsonDecode(response.body);
  }

  Future<void> toggleSaveSeller(String sellerId) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('No authenticated user found');

    final firestore = FirebaseFirestore.instance;
    final docRef = firestore
        .collection('buyers')
        .doc(user.uid)
        .collection('savedSellers')
        .doc(sellerId);

    final doc = await docRef.get();
    if (doc.exists) {
      await docRef.delete();
    } else {
      await docRef.set({
        'savedAt': FieldValue.serverTimestamp(),
      });
    }
  }

  Stream<List<String>> getSavedSellerIds() {
    final user = _auth.currentUser;
    if (user == null) return Stream.value([]);

    return FirebaseFirestore.instance
        .collection('buyers')
        .doc(user.uid)
        .collection('savedSellers')
        .snapshots()
        .map((snap) => snap.docs.map((doc) => doc.id).toList());
  }

  Future<List<Reservation>> getMyReservations() async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('No authenticated user found');

    final idToken = await user.getIdToken();
    if (idToken == null) throw Exception('Failed to retrieve authentication token');

    final cleanBaseUrl = _baseUrl.endsWith('/') ? _baseUrl.substring(0, _baseUrl.length - 1) : _baseUrl;
    final url = Uri.parse('$cleanBaseUrl/buyer/my_reservations');

    final response = await http.get(
      url,
      headers: {
        'Authorization': 'Bearer $idToken',
      },
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to load reservations: ${response.body}');
    }

    final List<dynamic> data = jsonDecode(response.body);
    return data.map((item) => Reservation.fromJson(item, item['id'] ?? '')).toList();
  }

  Future<void> submitReview({
    required String sellerId,
    required double rating,
    required String comment,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('No authenticated user found');

    final idToken = await user.getIdToken();
    if (idToken == null) throw Exception('Failed to retrieve authentication token');

    final cleanBaseUrl = _baseUrl.endsWith('/') ? _baseUrl.substring(0, _baseUrl.length - 1) : _baseUrl;
    final url = Uri.parse('$cleanBaseUrl/buyer/review');

    final payload = {
      'sellerId': sellerId,
      'rating': rating,
      'comment': comment,
    };

    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $idToken',
      },
      body: jsonEncode(payload),
    );

    if (response.statusCode != 200) {
      final result = jsonDecode(response.body);
      throw Exception(result['message'] ?? 'Failed to submit review');
    }
  }

  Future<void> cancelReservation(String reservationId) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('No authenticated user found');

    final idToken = await user.getIdToken();
    if (idToken == null) throw Exception('Failed to retrieve authentication token');

    final cleanBaseUrl = _baseUrl.endsWith('/') ? _baseUrl.substring(0, _baseUrl.length - 1) : _baseUrl;
    final url = Uri.parse('$cleanBaseUrl/buyer/cancel_reservation/$reservationId');

    final response = await http.post(
      url,
      headers: {
        'Authorization': 'Bearer $idToken',
      },
    );

    if (response.statusCode != 200) {
      final result = jsonDecode(response.body);
      throw Exception(result['message'] ?? 'Failed to cancel reservation');
    }
  }

  Future<List<Review>> getMyReviews() async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('No authenticated user found');

    final idToken = await user.getIdToken();
    if (idToken == null) throw Exception('Failed to retrieve authentication token');

    final cleanBaseUrl = _baseUrl.endsWith('/') ? _baseUrl.substring(0, _baseUrl.length - 1) : _baseUrl;
    final url = Uri.parse('$cleanBaseUrl/buyer/my_reviews');

    final response = await http.get(
      url,
      headers: {
        'Authorization': 'Bearer $idToken',
      },
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to load my reviews: ${response.body}');
    }

    final List<dynamic> data = jsonDecode(response.body);
    return data.map((item) => Review.fromJson(item, item['id'] ?? '')).toList();
  }
}
