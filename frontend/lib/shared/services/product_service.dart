import 'dart:convert';
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
    required String category,
    required String origin,
    required String image,
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
    required DateTime date,
    required String startTime,
    required String endTime,
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
      'date': date.toIso8601String(),
      'startTime': startTime,
      'endTime': endTime,
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
}
