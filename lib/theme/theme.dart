import 'package:flutter/material.dart';

ThemeData lightMode = ThemeData(
    colorScheme: ColorScheme.light(
      surface: Colors.grey.shade300,
      onSurface: Colors.grey.shade900,
      primary: Colors.grey.shade500,
      secondary: Colors.grey.shade200,
      onSecondary: Colors.grey.shade800,
      tertiary: Color(0xFF69c8cc),
      tertiaryContainer: Color(0xFF69c8cc),
      primaryFixed: Colors.white,
      surfaceBright: Colors.brown.shade300,
    )
);

ThemeData darkMode = ThemeData(
    colorScheme: ColorScheme.dark(
        surface: Colors.grey.shade900,
        onSurface: Colors.grey.shade300,
        primary: Colors.grey.shade600,
        secondary: Colors.grey.shade800,
        onSecondary: Colors.grey.shade200,
        tertiary: Color(0xFF69c8cc),
        tertiaryContainer: Color(0xFF69c8cc),
        primaryFixed: Colors.black
    )
);