import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'storage_service.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import '../models/models.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final String _baseUrl = dotenv.env['BACKEND_URL'] ?? '';
  final StorageService? _storageService;

  AuthService([this._storageService]);

  Future<void> signOut() async {
    await _auth.signOut();
    await _storageService?.clearSession();
  }


  Future<Map<String, dynamic>> signIn(String email, String password) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      final idToken = await credential.user?.getIdToken();
      if (idToken == null) throw Exception("Failed to get ID token");

      final cleanBaseUrl = _baseUrl.endsWith('/') ? _baseUrl.substring(0, _baseUrl.length - 1) : _baseUrl;
      final url = Uri.parse('$cleanBaseUrl/auth/profile');

      final response = await http.get(
        url,
        headers: {
          "Authorization": "Bearer $idToken",
          "Content-Type": "application/json",
        },
      );

      if (response.headers['content-type']?.contains('application/json') != true) {
        throw Exception(
          "Backend returned HTML instead of JSON.\nStatus: ${response.statusCode}\nBody: ${response.body.substring(0, 80)}",
        );
      }

      final profile = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return profile;
      } else {
        throw Exception(profile['message'] ?? 'Login failed');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<void> signUp({
    required String name,
    required String email,
    required String password,
    required String role,
    String? mainCity,
    String? phoneNumber,
    String? preferredCity,
  }) async {
    try {
      final cleanBaseUrl = _baseUrl.endsWith('/') ? _baseUrl.substring(0, _baseUrl.length - 1) : _baseUrl;
      final url = Uri.parse('$cleanBaseUrl/auth/sign_up');

      final Map<String, dynamic> payload = {
        'name': name,
        'email': email,
        'password': password,
        'role': role,
      };
      if (mainCity != null) payload['mainCity'] = mainCity;
      if (phoneNumber != null) payload['phoneNumber'] = phoneNumber;
      if (preferredCity != null) payload['preferredCity'] = preferredCity;

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );

      if (response.headers['content-type']?.contains('application/json') != true) {
        throw Exception(
          "Backend returned HTML instead of JSON.\nStatus: ${response.statusCode}\nBody: ${response.body.substring(0, 80)}",
        );
      }

      final result = jsonDecode(response.body);

      if (response.statusCode != 200) {
        throw Exception(result['message'] ?? 'Signup failed');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<void> switchRole(String newRole) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('No authenticated user found');

    final idToken = await user.getIdToken();
    if (idToken == null) throw Exception("Failed to get ID token");

    final cleanBaseUrl = _baseUrl.endsWith('/') ? _baseUrl.substring(0, _baseUrl.length - 1) : _baseUrl;
    final url = Uri.parse('$cleanBaseUrl/auth/change_role');

    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $idToken',
      },
      body: jsonEncode({'role': newRole}),
    );

    if (response.headers['content-type']?.contains('application/json') != true) {
      throw Exception(
        "Backend returned HTML instead of JSON.\nStatus: ${response.statusCode}\nBody: ${response.body.substring(0, 80)}",
      );
    }

    final result = jsonDecode(response.body);

    if (response.statusCode != 200) {
      throw Exception(result['message'] ?? 'Failed to switch role');
    }
  }

  Future<void> createSellerProfile({
    required String name,
    required String mainCity,
    required String phone,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('No authenticated user found');

    final seller = Seller(
      id: user.uid,
      name: name,
      mainCity: mainCity,
      phone: phone,
      email: user.email ?? '',
      createdAt: DateTime.now(),
    );

    await _db.collection('sellers').doc(user.uid).set(seller.toJson());
    await _syncTokenWithBackend(user, '/seller/profile', extraData: seller.toJson());
  }

  Future<void> createBuyerProfile({
    required String name,
    required String preferredCity,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('No authenticated user found');

    final buyer = Buyer(
      id: user.uid,
      name: name,
      preferredCity: preferredCity,
      email: user.email ?? '',
      createdAt: DateTime.now(),
    );

    await _db.collection('buyers').doc(user.uid).set(buyer.toJson());
    await _syncTokenWithBackend(user, '/buyer/profile', extraData: buyer.toJson());
  }

  Future<void> _syncTokenWithBackend(User user, String endpoint, {Map<String, dynamic>? extraData}) async {
    if (_baseUrl.isEmpty) return;

    final token = await user.getIdToken();
    final url = Uri.parse('$_baseUrl${endpoint.startsWith('/') ? endpoint.substring(1) : endpoint}');

    final body = {
      'idToken': token,
      'uid': user.uid,
      'email': user.email,
      ...?extraData,
    };

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );

      if (response.statusCode >= 400) {
        // Backend sync failed
      }
    } catch (e) {
      // Error syncing with backend
    }
  }
}
