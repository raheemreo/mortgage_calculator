import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsProvider with ChangeNotifier {
  String _currencyCode = 'USD';
  String _currencySymbol = '\$';
  String _themeName = 'System'; // 'Light', 'Dark', 'System'
  String _userName = '';
  String _userEmail = '';

  String get currencyCode => _currencyCode;
  String get currencySymbol => _currencySymbol;
  String get themeName => _themeName;
  String get userName => _userName;
  String get userEmail => _userEmail;

  final SharedPreferences _prefs;

  SettingsProvider(this._prefs) {
    _loadSettings();
  }

  void _loadSettings() {
    _currencyCode = _prefs.getString('currency_code') ?? 'USD';
    _currencySymbol = _getSymbolFromCode(_currencyCode);
    
    String savedTheme = _prefs.getString('theme_name') ?? 'System';
    if (savedTheme == 'Navy' || savedTheme == 'Emerald') {
      savedTheme = 'Light';
    }
    _themeName = savedTheme;
    
    _userName = _prefs.getString('user_name') ?? '';
    _userEmail = _prefs.getString('user_email') ?? '';
    notifyListeners();
  }

  void loadProfile() {
    _userName = _prefs.getString('user_name') ?? '';
    _userEmail = _prefs.getString('user_email') ?? '';
    notifyListeners();
  }

  Future<void> saveProfile(String name, String email) async {
    _userName = name;
    _userEmail = email;
    await _prefs.setString('user_name', name);
    await _prefs.setString('user_email', email);
    notifyListeners();
  }

  Future<void> setTheme(String name) async {
    _themeName = name;
    await _prefs.setString('theme_name', name);
    notifyListeners();
  }

  Future<void> setCurrency(String code) async {
    _currencyCode = code;
    _currencySymbol = _getSymbolFromCode(code);
    await _prefs.setString('currency_code', code);
    notifyListeners();
  }

  String _getSymbolFromCode(String code) {
    if (code.contains('USD')) return '\$';
    if (code.contains('CAD')) return '\$';
    if (code.contains('GBP')) return '£';
    if (code.contains('AUD')) return '\$';
    if (code.contains('EUR')) return '€';
    if (code.contains('INR')) return '₹';
    return '\$';
  }
}
