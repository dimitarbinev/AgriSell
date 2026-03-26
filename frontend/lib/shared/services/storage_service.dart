import 'package:shared_preferences/shared_preferences.dart';

class StorageService {
  static const String _lastRouteKey = 'last_route';
  
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
}
