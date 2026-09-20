import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'editor_controller.dart';
import 'editor_home.dart';

class FlutterVisualUiEditorApp extends StatelessWidget {
  const FlutterVisualUiEditorApp({
    super.key,
    this.controller,
    this.bootstrap = true,
  });

  final EditorController? controller;
  final bool bootstrap;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Flutter Visual UI Editor',
      theme: _buildLightTheme(),
      home: EditorHomePage(
        controller: controller ?? EditorController(),
        bootstrap: bootstrap,
      ),
    );
  }
}

ThemeData _buildLightTheme() {
  final accent = ColorScheme.fromSeed(
    seedColor: const Color(0xFF116D6E),
    brightness: Brightness.light,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: accent.copyWith(
      surface: const Color(0xFFF8FAFC),
      surfaceContainerHighest: const Color(0xFFEFF6F8),
      primary: const Color(0xFF116D6E),
      secondary: const Color(0xFFD97706),
      tertiary: const Color(0xFF7C3AED),
    ),
    scaffoldBackgroundColor: const Color(0xFFF4F7FB),
    fontFamily: _desktopFontFamily(),
    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      ),
      margin: EdgeInsets.zero,
    ),
    dividerTheme: const DividerThemeData(
      color: Color(0xFFE2E8F0),
      thickness: 1,
      space: 1,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFFF7FAFC),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFF116D6E), width: 1.4),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: const Color(0xFF116D6E),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: const Color(0xFF0F172A),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        side: const BorderSide(color: Color(0xFFCBD5E1)),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: const Color(0xFF116D6E),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
    ),
  );
}

String _desktopFontFamily() {
  return switch (defaultTargetPlatform) {
    TargetPlatform.macOS => 'SF Pro Text',
    TargetPlatform.windows => 'Segoe UI',
    _ => 'Roboto',
  };
}
