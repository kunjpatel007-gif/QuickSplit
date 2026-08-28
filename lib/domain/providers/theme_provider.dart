import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:campus_quicksplit/data/repositories/repositories.dart';

class ThemeProvider extends ChangeNotifier {
  final SettingsRepository _settingsRepository;
  ThemeMode _themeMode = ThemeMode.system;

  ThemeProvider(this._settingsRepository);

  ThemeMode get themeMode => _themeMode;

  bool get isDarkMode {
    if (_themeMode == ThemeMode.system) {
      return SchedulerBinding.instance.platformDispatcher.platformBrightness ==
          Brightness.dark;
    }
    return _themeMode == ThemeMode.dark;
  }

  Future<void> loadTheme() async {
    final mode = await _settingsRepository.getThemeMode();
    if (mode != null) {
      _themeMode = mode == 'dark' ? ThemeMode.dark : ThemeMode.light;
      notifyListeners();
    }
  }

  Future<void> toggleTheme() async {
    _themeMode = isDarkMode ? ThemeMode.light : ThemeMode.dark;
    await _settingsRepository.setThemeMode(
        _themeMode == ThemeMode.dark ? 'dark' : 'light');
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    if (mode != ThemeMode.system) {
      await _settingsRepository.setThemeMode(
          mode == ThemeMode.dark ? 'dark' : 'light');
    }
    notifyListeners();
  }
}
