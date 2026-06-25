import 'package:flutter/material.dart';
import 'package:hilla_ride/core/models/app_models.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppModeProvider extends ChangeNotifier {
  AppModeProvider() {
    _restoreSavedMode();
  }

  static const _modeKey = 'last_user_mode';

  UserRole? _selectedMode;
  var _restored = false;

  UserRole? get selectedMode => _selectedMode;
  bool get hasRestored => _restored;

  Future<void> _restoreSavedMode() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_modeKey);
    if (saved == UserRole.customer.name || saved == UserRole.driver.name) {
      _selectedMode = UserRoleX.fromString(saved);
    }
    _restored = true;
    notifyListeners();
  }

  Future<void> selectMode(UserRole mode) async {
    if (mode != UserRole.customer && mode != UserRole.driver) return;
    if (_selectedMode == mode) return;
    _selectedMode = mode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_modeKey, mode.name);
  }

  Future<void> clearMode() async {
    _selectedMode = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_modeKey);
    notifyListeners();
  }
}
