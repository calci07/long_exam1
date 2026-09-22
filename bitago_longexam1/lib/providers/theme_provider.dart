import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider extends ChangeNotifier {
  ThemeProvider(this.preferences) {
    final saved = preferences.getString('theme_mode');
    mode = ThemeMode.values.firstWhere(
      (value) => value.name == saved,
      orElse: () => ThemeMode.system,
    );
  }
  final SharedPreferences preferences;
  late ThemeMode mode;

  Future<void> setMode(ThemeMode value) async {
    if (!await preferences.setString('theme_mode', value.name)) {
      throw Exception('Could not save the theme.');
    }
    mode = value;
    notifyListeners();
  }
}
