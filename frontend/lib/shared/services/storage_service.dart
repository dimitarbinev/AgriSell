import 'package:firebase_storage/firebase_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import 'package:path/path.dart' as p;

class StorageService {
  final FirebaseStorage? _storage;
  static const String _lastRouteKey = 'last_route';
  
  StorageService([this._storage]);

  Future<void> saveLastRoute(String route) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastRouteKey, route);
  }

  Future<String?> getLastRoute() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_lastRouteKey);
  }

  Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_lastRouteKey);
  }

  Future<String> uploadProductImage(File imageFile, String sellerId) async {
    if (_storage == null) throw Exception('Firebase Storage not initialized');

    try {
      final fileName = '${DateTime.now().millisecondsSinceEpoch}${p.extension(imageFile.path)}';
      final ref = _storage!.ref().child('sellers/$sellerId/products/$fileName');
      
      // Use putFile and wait for completion
      final uploadTask = ref.putFile(imageFile);
      final snapshot = await uploadTask.whenComplete(() => null);
      
      if (snapshot.state == TaskState.error) {
        throw Exception('Storage upload failed: ${snapshot.state}');
      }

      return await snapshot.ref.getDownloadURL();
    } catch (e) {
      if (e is FirebaseException && e.code == 'object-not-found') {
        throw Exception('Firebase Storage Error: The storage bucket or path was not found. Please ensure Firebase Storage is enabled in your console.');
      }
      rethrow;
    }
  }
}
