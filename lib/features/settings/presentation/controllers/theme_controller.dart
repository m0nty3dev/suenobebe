import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _themeKey = 'theme_mode';

// ThemeModeNotifier accepts an optional initialTheme that is read in main()
// before runApp so the first frame never flashes ThemeMode.system incorrectly.
class ThemeModeNotifier extends Notifier<ThemeMode> {
  ThemeModeNotifier({this.initialTheme = ThemeMode.system});
  final ThemeMode initialTheme;

  @override
  ThemeMode build() => initialTheme;

  Future<void> setTheme(ThemeMode mode) async {
    state = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeKey, mode.name);
  }
}

final themeModeNotifierProvider =
    NotifierProvider<ThemeModeNotifier, ThemeMode>(ThemeModeNotifier.new);

final themeModeProvider = Provider<ThemeMode>((ref) {
  return ref.watch(themeModeNotifierProvider);
});
