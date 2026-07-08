import 'package:flutter/material.dart';

/// NumisTR Color Palette - ProKit Style
/// Ancient coin themed colors with professional look

// Primary Colors - Ancient Gold/Bronze theme
const Color numPrimary = Color(0xFF8B6914);        // Ancient Gold
const Color numPrimaryDark = Color(0xFF6B5010);    // Darker Gold
const Color numPrimaryLight = Color(0xFFAB8934);   // Lighter Gold
const Color numAccent = Color(0xFFCD853F);         // Peru/Bronze

// Secondary Colors
const Color numSecondary = Color(0xFF5D4E37);      // Ancient Bronze Dark
const Color numSecondaryLight = Color(0xFF8B7355); // Bronze Light

// Background Colors
const Color numScaffoldLight = Color(0xFFFAF8F5); // Warm white (parchment)
const Color numScaffoldDark = Color(0xFF1A1A1A);   // Dark mode background
const Color numCardLight = Color(0xFFFFFFFF);      // Card background light
const Color numCardDark = Color(0xFF2D2D2D);       // Card background dark
const Color numSurfaceLight = Color(0xFFF5F2ED);   // Surface light
const Color numSurfaceDark = Color(0xFF242424);    // Surface dark
const Color numBackgroundGrey = Color(0xFFF5F5F5); // Light grey background

// Text Colors
const Color numTextPrimary = Color(0xFF212121);    // Primary text
const Color numTextSecondary = Color(0xFF757575);  // Secondary text
const Color numTextHint = Color(0xFFBDBDBD);       // Hint text
const Color numTextOnPrimary = Color(0xFFFFFFFF);  // Text on primary color
const Color numTextOnDark = Color(0xFFE0E0E0);     // Text on dark background

// Status Colors
const Color numSuccess = Color(0xFF4CAF50);        // Success green
const Color numError = Color(0xFFE53935);          // Error red
const Color numWarning = Color(0xFFFFA726);        // Warning orange
const Color numInfo = Color(0xFF2196F3);           // Info blue

// Region Colors (for category chips)
const Color numRegionLydia = Color(0xFFFFD700);    // Gold
const Color numRegionIonia = Color(0xFF4169E1);    // Royal Blue
const Color numRegionMysia = Color(0xFF228B22);    // Forest Green
const Color numRegionCaria = Color(0xFFDC143C);    // Crimson
const Color numRegionLycia = Color(0xFF9932CC);    // Dark Orchid
const Color numRegionCilicia = Color(0xFFFF8C00);  // Dark Orange
const Color numRegionBithynia = Color(0xFF20B2AA); // Light Sea Green
const Color numRegionPontus = Color(0xFF8B4513);   // Saddle Brown
const Color numRegionCappadocia = Color(0xFF708090); // Slate Gray

// Material Colors
const Color numMaterialGold = Color(0xFFFFD700);   // AU - Gold
const Color numMaterialSilver = Color(0xFFC0C0C0); // AR - Silver
const Color numMaterialBronze = Color(0xFFCD7F32); // AE - Bronze

// UI Element Colors
const Color numDividerColor = Color(0xFFE0E0E0);
const Color numBorder = Color(0xFFE8E8E8);
const Color numShadow = Color(0x1A000000);
const Color numOverlay = Color(0x80000000);
const Color numRipple = Color(0x20000000);

// Shimmer Colors (for loading)
const Color numShimmerBase = Color(0xFFE0E0E0);
const Color numShimmerHighlight = Color(0xFFF5F5F5);

// Gradient Colors
const LinearGradient numPrimaryGradient = LinearGradient(
  colors: [numPrimary, numPrimaryLight],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);

const LinearGradient numGoldGradient = LinearGradient(
  colors: [Color(0xFFD4AF37), Color(0xFFF5E6A3), Color(0xFFD4AF37)],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);

const LinearGradient numDarkGradient = LinearGradient(
  colors: [Color(0xFF2D2D2D), Color(0xFF1A1A1A)],
  begin: Alignment.topCenter,
  end: Alignment.bottomCenter,
);

// ProKit Home Screen Gradients
const LinearGradient numGradientPrimary = LinearGradient(
  colors: [numPrimary, numPrimaryDark],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);

const LinearGradient numGradientSecondary = LinearGradient(
  colors: [numAccent, Color(0xFFFF8A50)],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);

const LinearGradient numGradientAccent = LinearGradient(
  colors: [Color(0xFF6B73FF), Color(0xFF9B59B6)],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);

/// Region color mapping
Map<String, Color> regionColors = {
  'lydia-coins': numRegionLydia,
  'ionia-coins': numRegionIonia,
  'mysia-coins': numRegionMysia,
  'caria-coins': numRegionCaria,
  'lycia-coins': numRegionLycia,
  'cilicia-coins': numRegionCilicia,
  'bithynia-coins': numRegionBithynia,
  'pontus-coins': numRegionPontus,
  'cappadocia-coins': numRegionCappadocia,
};

/// Material color mapping
Map<String, Color> materialColors = {
  'AU': numMaterialGold,
  'AR': numMaterialSilver,
  'AE': numMaterialBronze,
  'AV': numMaterialGold,     // Alternative gold
  'EL': Color(0xFFE5E4E2),   // Electrum - platinum-like
  'PB': Color(0xFF3B3B3B),   // Lead - dark gray
};

/// Get region color by code
Color getRegionColor(String? regionCode) {
  if (regionCode == null) return numPrimary;
  return regionColors[regionCode.toLowerCase()] ?? numPrimary;
}

/// Get material color by code
Color getMaterialColor(String? materialCode) {
  if (materialCode == null) return numMaterialBronze;
  return materialColors[materialCode.toUpperCase()] ?? numMaterialBronze;
}
