import 'package:flutter/material.dart';

/// Palette warna global untuk aplikasi Smart Presensi.
class AppColors {
  static const primary = Color(0xFF5147E8);
  static const primaryDark = Color(0xFF342F9B);
  static const accent = Color(0xFF12B8C8);
  static const background = Color(0xFFF5F7FC);
  static const cardWhite = Colors.white;
  static const textDark = Color(0xFF202044);
  static const textMuted = Color(0xFF777B91);
  static const border = Color(0xFFE7EAF2);

  static const gradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primary, accent],
  );
}
