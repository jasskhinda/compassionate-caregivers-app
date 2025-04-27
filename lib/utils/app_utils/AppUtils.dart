import 'package:flutter/material.dart';

class AppUtils {
  // Get theme colors easily
  static ColorScheme getColorScheme(BuildContext context) {
    return Theme.of(context).colorScheme;
  }

  // Get theme colors easily
  static Size getScreenSize(BuildContext context) {
    return MediaQuery.of(context).size;
  }
}