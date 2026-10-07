import 'package:shared_preferences/shared_preferences.dart';

class NavigationStateService {
  static const _keyPrefix = 'last_navigation_tab';

  static String _key(String userId, String role) {
    return '$_keyPrefix|$role|$userId';
  }

  static Future<int?> loadTab({
    required String userId,
    required String role,
  }) async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getInt(_key(userId, role));
  }

  static Future<void> saveTab({
    required String userId,
    required String role,
    required int tab,
  }) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setInt(_key(userId, role), tab);
  }
}
