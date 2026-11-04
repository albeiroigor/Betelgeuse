import 'package:flutter/material.dart';

import 'app_theme.dart';

class ThemeNotifier extends ChangeNotifier {
  AppThemeId _current = AppThemeId.midnight;
  bool _loaded = false;

  AppThemeId get current => _current;

  Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    _current = await ThemeStore().loadThemeId();
    notifyListeners();
  }

  Future<void> setTheme(AppThemeId id) async {
    _current = id;
    await ThemeStore().saveThemeId(id);
    notifyListeners();
  }

  Future<void> cycleTheme() async {
    final all = AppThemes.all;
    final idx = all.indexWhere((t) => t.id == _current);
    final next = all[(idx + 1) % all.length];
    await setTheme(next.id);
  }
}
