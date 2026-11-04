import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppThemeId { midnight, paper, forest, sand, graphite }

class AppTheme {
  final AppThemeId id;
  final String name;
  final bool isDark;
  final ColorScheme colorScheme;
  final ThemeData theme;

  AppTheme({
    required this.id,
    required this.name,
    required this.isDark,
    required this.colorScheme,
    required this.theme,
  });
}

class AppThemes {
  static final List<AppTheme> all = [
    _midnight,
    _paper,
    _forest,
    _sand,
    _graphite,
  ];

  static AppTheme of(AppThemeId id) => all.firstWhere((t) => t.id == id);

  static ThemeData _data(ColorScheme cs, Brightness brightness) {
    return ThemeData(
      useMaterial3: true,
      colorScheme: cs,
      brightness: brightness,
      scaffoldBackgroundColor: cs.surface,
      appBarTheme: AppBarTheme(
        backgroundColor: cs.surface,
        foregroundColor: cs.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w600,
          color: cs.onSurface,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: cs.surface,
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: cs.outlineVariant),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: cs.surfaceContainerHigh,
        isDense: true,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: cs.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: cs.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: cs.primary, width: 1.5),
        ),
      ),
      dividerTheme: DividerThemeData(color: cs.outlineVariant, thickness: 1),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: cs.inverseSurface,
        contentTextStyle: TextStyle(color: cs.onInverseSurface),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: cs.surfaceContainerHigh,
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: cs.surfaceContainerHigh,
        side: BorderSide(color: cs.outlineVariant),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        labelStyle: TextStyle(
          color: cs.onSurfaceVariant,
          fontWeight: FontWeight.w500,
          fontSize: 12,
        ),
      ),
      textTheme: const TextTheme(
        headlineSmall: TextStyle(fontWeight: FontWeight.w700),
        titleLarge: TextStyle(fontWeight: FontWeight.w600),
        titleMedium: TextStyle(fontWeight: FontWeight.w600),
        labelLarge: TextStyle(fontWeight: FontWeight.w600),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: cs.primary),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: cs.inverseSurface,
          borderRadius: BorderRadius.circular(6),
        ),
        textStyle: TextStyle(color: cs.onInverseSurface, fontSize: 12),
      ),
    );
  }

  static ColorScheme _scheme({
    required Color seed,
    required Brightness brightness,
    required Color surface,
    required Color onSurface,
    required Color surfaceHigh,
    required Color surfaceHighest,
    required Color primary,
    required Color secondary,
    required Color outline,
    required Color outlineVariant,
  }) {
    return ColorScheme.fromSeed(
      seedColor: seed,
      brightness: brightness,
    ).copyWith(
      surface: surface,
      onSurface: onSurface,
      surfaceContainerHigh: surfaceHigh,
      surfaceContainerHighest: surfaceHighest,
      primary: primary,
      secondary: secondary,
      outline: outline,
      outlineVariant: outlineVariant,
    );
  }

  static AppTheme _theme({
    required AppThemeId id,
    required String name,
    required Brightness brightness,
    required Color seed,
    required Color surface,
    required Color onSurface,
    required Color surfaceHigh,
    required Color surfaceHighest,
    required Color primary,
    required Color secondary,
    required Color outline,
    required Color outlineVariant,
  }) {
    final cs = _scheme(
      seed: seed,
      brightness: brightness,
      surface: surface,
      onSurface: onSurface,
      surfaceHigh: surfaceHigh,
      surfaceHighest: surfaceHighest,
      primary: primary,
      secondary: secondary,
      outline: outline,
      outlineVariant: outlineVariant,
    );
    return AppTheme(
      id: id,
      name: name,
      isDark: brightness == Brightness.dark,
      colorScheme: cs,
      theme: _data(cs, brightness),
    );
  }

  static final _midnight = _theme(
    id: AppThemeId.midnight,
    name: 'Midnight',
    brightness: Brightness.dark,
    seed: const Color(0xFF4C8DFF),
    surface: const Color(0xFF0F1115),
    onSurface: const Color(0xFFE6E8EC),
    surfaceHigh: const Color(0xFF161A21),
    surfaceHighest: const Color(0xFF1D222B),
    primary: const Color(0xFF4C8DFF),
    secondary: const Color(0xFF8B95A7),
    outline: const Color(0xFF2A2F3A),
    outlineVariant: const Color(0xFF1E232C),
  );

  static final _paper = _theme(
    id: AppThemeId.paper,
    name: 'Paper',
    brightness: Brightness.light,
    seed: const Color(0xFF2563EB),
    surface: const Color(0xFFFFFFFF),
    onSurface: const Color(0xFF111827),
    surfaceHigh: const Color(0xFFF6F7F9),
    surfaceHighest: const Color(0xFFEDEFF3),
    primary: const Color(0xFF2563EB),
    secondary: const Color(0xFF64748B),
    outline: const Color(0xFFD1D5DB),
    outlineVariant: const Color(0xFFE5E7EB),
  );

  static final _forest = _theme(
    id: AppThemeId.forest,
    name: 'Forest',
    brightness: Brightness.dark,
    seed: const Color(0xFF3FB950),
    surface: const Color(0xFF0D1210),
    onSurface: const Color(0xFFE4EAE6),
    surfaceHigh: const Color(0xFF141C18),
    surfaceHighest: const Color(0xFF1B2621),
    primary: const Color(0xFF3FB950),
    secondary: const Color(0xFF8FA89B),
    outline: const Color(0xFF28352E),
    outlineVariant: const Color(0xFF1C2721),
  );

  static final _sand = _theme(
    id: AppThemeId.sand,
    name: 'Sand',
    brightness: Brightness.light,
    seed: const Color(0xFFA16207),
    surface: const Color(0xFFFBFAF8),
    onSurface: const Color(0xFF1F1B16),
    surfaceHigh: const Color(0xFFF4F1EC),
    surfaceHighest: const Color(0xFFEAE5DD),
    primary: const Color(0xFFA16207),
    secondary: const Color(0xFF7C6F64),
    outline: const Color(0xFFD6CEC3),
    outlineVariant: const Color(0xFFE6E0D7),
  );

  static final _graphite = _theme(
    id: AppThemeId.graphite,
    name: 'Graphite',
    brightness: Brightness.dark,
    seed: const Color(0xFFF59E0B),
    surface: const Color(0xFF121212),
    onSurface: const Color(0xFFECECEC),
    surfaceHigh: const Color(0xFF1A1A1A),
    surfaceHighest: const Color(0xFF222222),
    primary: const Color(0xFFF59E0B),
    secondary: const Color(0xFFA3A3A3),
    outline: const Color(0xFF2E2E2E),
    outlineVariant: const Color(0xFF232323),
  );
}

class ThemeStore {
  static const _themeKey = 'betelgeuse_theme_id';
  static const _columnsKey = 'betelgeuse_column_configs';

  Future<AppThemeId> loadThemeId() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_themeKey);
    if (raw == null) return AppThemeId.midnight;
    return AppThemeId.values.firstWhere(
      (e) => e.toString() == raw,
      orElse: () => AppThemeId.midnight,
    );
  }

  Future<void> saveThemeId(AppThemeId id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeKey, id.toString());
  }

  Future<Map<String, ColumnConfig>> loadColumnConfigs() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_columnsKey);
    if (raw == null) return {};
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return map.map(
        (key, value) => MapEntry(
          key,
          ColumnConfig.fromJson(key, Map<String, dynamic>.from(value as Map)),
        ),
      );
    } catch (_) {
      return {};
    }
  }

  Future<void> saveColumnConfigs(Map<String, ColumnConfig> configs) async {
    final prefs = await SharedPreferences.getInstance();
    final map = configs.map((key, value) => MapEntry(key, value.toJson()));
    await prefs.setString(_columnsKey, jsonEncode(map));
  }
}

class ColumnConfig {
  final String optionId;
  String displayName;
  Color color;

  ColumnConfig({
    required this.optionId,
    required this.displayName,
    required this.color,
  });

  Map<String, dynamic> toJson() => {
    'name': displayName,
    'color': color.toARGB32().toRadixString(16).padLeft(8, '0'),
  };

  factory ColumnConfig.fromJson(String optionId, Map<String, dynamic> json) =>
      ColumnConfig(
        optionId: optionId,
        displayName: json['name'] ?? '',
        color: Color(
          int.tryParse(json['color'] ?? 'FF4C8DFF', radix: 16) ?? 0xFF4C8DFF,
        ),
      );
}
