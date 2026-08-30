import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Manages the app's light/dark theme preference. Defaults to dark mode
/// (matching the original TikTok-style black background), but lets the
/// user switch to a light theme for menus/settings screens if preferred.
class ThemeController extends ChangeNotifier {
  static const String _prefsKey = 'is_dark_mode';

  bool isDarkMode = true;

  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    isDarkMode = prefs.getBool(_prefsKey) ?? true;
    notifyListeners();
  }

  Future<void> toggleDarkMode() async {
    isDarkMode = !isDarkMode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefsKey, isDarkMode);
  }

  ThemeData get themeData {
    if (isDarkMode) {
      return ThemeData.dark(useMaterial3: true).copyWith(
        scaffoldBackgroundColor: Colors.black,
      );
    }
    return ThemeData.light(useMaterial3: true).copyWith(
      scaffoldBackgroundColor: const Color(0xFFF5F5F5),
    );
  }
}
