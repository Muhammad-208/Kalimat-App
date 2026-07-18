import 'package:flutter/material.dart';

/// Design tokens taken verbatim from the Kalimat style tile (screen 7).
/// Two warm palettes: Light ("paper") and Dark ("night reading").
class KColors {
  KColors._();

  // ── Light ──────────────────────────────────────────────
  static const teal = Color(0xFF0F5B52); // primary
  static const brass = Color(0xFFB07C2E); // accent / counts
  static const paper = Color(0xFFF4EEE1); // screen background
  static const ink = Color(0xFF2A251C); // primary text

  static const paperCard = Color(0xFFFBF7EE); // raised surfaces
  static const paperLine = Color(0xFFE7DEC9); // hairlines / borders
  static const mist = Color(0xFFA79E8A); // muted text / placeholders
  static const sub = Color(0xFF6B6353); // secondary text

  static const tealTintBg = Color(0xFFE4EFEC); // chips
  static const tealTintBorder = Color(0xFFCFE2DC);
  static const explainBg = Color(0xFFEAF2EF); // "simplified explanation" card
  static const explainBorder = Color(0xFFD2E4DE);

  static const verseBg = Color(0xFFF2E4C6); // Quranic verse card
  static const verseBorder = Color(0xFFE0C990);
  static const brassText = Color(0xFF8A5E1E); // verse ref / warm labels

  static const disputeBg = Color(0xFFF3EFE6); // semitic cognate (dashed)
  static const disputeBorder = Color(0xFFC9BE9F);

  // ── Dark ("قراءة ليلية") ───────────────────────────────
  static const dBg = Color(0xFF13201D);
  static const dTeal = Color(0xFF5FC2B0);
  static const dBrass = Color(0xFFDBA94F);
  static const dText = Color(0xFFECE5D5);

  static const dCard = Color(0xFF1B2A26);
  static const dCardBorder = Color(0xFF2A3A35);
  static const dExplainBg = Color(0xFF17322D);
  static const dExplainBorder = Color(0xFF244A43);
  static const dSub = Color(0xFFA9A491);
  static const dMist = Color(0xFF8A8571);
  static const dBody = Color(0xFFC4BDAC);

  static const dVerseBg = Color(0xFF241D10);
  static const dVerseBorder = Color(0xFF4A3B1C);
  static const dVerseText = Color(0xFFF2E9D5);

  static const dDisputeBg = Color(0xFF20241D);
  static const dDisputeBorder = Color(0xFF4A4632);
}
