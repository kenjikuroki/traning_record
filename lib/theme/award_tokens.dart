import 'package:flutter/material.dart';

class AwardTokens {
  // Gold palette
  static const Color gold50 = Color(0xFFFFF7DA);
  static const Color gold100 = Color(0xFFFBEFC4);
  static const Color gold200 = Color(0xFFF7E7A9);
  static const Color gold300 = Color(0xFFEFD486);
  static const Color gold400 = Color(0xFFE7C766);
  static const Color gold600 = Color(0xFFCFA349);
  static const Color gold800 = Color(0xFF8F6B2C);

  // Medal accents
  static const Color bronzeMain = Color(0xFFE6B17A);
  static const Color bronzeDeep = Color(0xFFC98A4C);
  static const Color silverLight = Color(0xFFE7EEF4);
  static const Color silverMain = Color(0xFFC9D2DB);
  static const Color platinumLight = Color(0xFFF0F4F7);
  static const Color platinumMain = Color(0xFFDDE5EC);

  // Layout
  static const double borderRadius = 28.0;
  static const double outerBorder = 6.0;
  static const double innerBorder = 1.0;
  static const EdgeInsets innerPadding =
      EdgeInsets.symmetric(horizontal: 24, vertical: 28);

  // Shadows
  static const BoxShadow outerShadow = BoxShadow(
    color: Color(0x29000000), // 16%
    offset: Offset(0, 12),
    blurRadius: 40,
    spreadRadius: 0.5,
  );
}
