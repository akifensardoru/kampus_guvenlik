import 'package:flutter/material.dart';

class AppSettings extends ChangeNotifier {
  bool _isDarkMode = false; // Tema durumu
  bool _isEnglish = true; // Dil durumu


  bool get isDarkMode => _isDarkMode;
  bool get isEnglish => _isEnglish;

  // Tema değiştirme
  void toggleTheme() {
    _isDarkMode = !_isDarkMode;
    notifyListeners();
  }

  // Dil değiştirme
  void toggleLanguage() {
    _isEnglish = !_isEnglish;
    notifyListeners();
  }
}