import 'package:flutter/material.dart';

class RoomThemeData {
  final String id;
  final String name;
  final IconData icon;
  final List<Color> gradientColors;
  final Color accentColor;
  final Color cardColor;
  final Color badgeColor;

  const RoomThemeData({
    required this.id,
    required this.name,
    required this.icon,
    required this.gradientColors,
    required this.accentColor,
    required this.cardColor,
    required this.badgeColor,
  });

  static const List<RoomThemeData> presetThemes = [
    RoomThemeData(
      id: 'dusk_twilight',
      name: 'Dusk Twilight',
      icon: Icons.nightlight_round,
      gradientColors: [
        Color(0xFF151838),
        Color(0xFF231A47),
        Color(0xFF381A4C),
        Color(0xFF261234),
      ],
      accentColor: Color(0xFF06B6D4),
      cardColor: Color(0x3B000000),
      badgeColor: Color(0xFF06B6D4),
    ),
    RoomThemeData(
      id: 'cyber_neon',
      name: 'Cyber Neon',
      icon: Icons.electric_bolt_rounded,
      gradientColors: [
        Color(0xFF030712),
        Color(0xFF1E1B4B),
        Color(0xFF4C0519),
        Color(0xFF020617),
      ],
      accentColor: Color(0xFF00F0FF),
      cardColor: Color(0x4D000000),
      badgeColor: Color(0xFFFF007F),
    ),
    RoomThemeData(
      id: 'rose_velvet',
      name: 'Rose Velvet',
      icon: Icons.favorite_rounded,
      gradientColors: [
        Color(0xFF2A081D),
        Color(0xFF4A0E2E),
        Color(0xFF3B0721),
        Color(0xFF1F0314),
      ],
      accentColor: Color(0xFFFB7185),
      cardColor: Color(0x3B350522),
      badgeColor: Color(0xFFF43F5E),
    ),
    RoomThemeData(
      id: 'golden_luxury',
      name: 'Golden Luxury',
      icon: Icons.workspace_premium_rounded,
      gradientColors: [
        Color(0xFF14120B),
        Color(0xFF2C2410),
        Color(0xFF3D3012),
        Color(0xFF18150B),
      ],
      accentColor: Color(0xFFFBBF24),
      cardColor: Color(0x3D251E07),
      badgeColor: Color(0xFFF59E0B),
    ),
    RoomThemeData(
      id: 'cosmic_galaxy',
      name: 'Cosmic Galaxy',
      icon: Icons.auto_awesome_rounded,
      gradientColors: [
        Color(0xFF070B19),
        Color(0xFF141B3B),
        Color(0xFF281845),
        Color(0xFF0A0C1B),
      ],
      accentColor: Color(0xFFA855F7),
      cardColor: Color(0x3D110D2D),
      badgeColor: Color(0xFF9333EA),
    ),
    RoomThemeData(
      id: 'sunset_horizon',
      name: 'Sunset Horizon',
      icon: Icons.wb_twilight_rounded,
      gradientColors: [
        Color(0xFF2E0C15),
        Color(0xFF4D1720),
        Color(0xFF381B2B),
        Color(0xFF1C0A10),
      ],
      accentColor: Color(0xFFF97316),
      cardColor: Color(0x382A0B12),
      badgeColor: Color(0xFFEA580C),
    ),
    RoomThemeData(
      id: 'emerald_palace',
      name: 'Emerald Palace',
      icon: Icons.shield_moon_rounded,
      gradientColors: [
        Color(0xFF051D14),
        Color(0xFF0A3324),
        Color(0xFF08261B),
        Color(0xFF03140E),
      ],
      accentColor: Color(0xFF10B981),
      cardColor: Color(0x3B052116),
      badgeColor: Color(0xFF059669),
    ),
    RoomThemeData(
      id: 'ocean_abyss',
      name: 'Ocean Abyss',
      icon: Icons.water_rounded,
      gradientColors: [
        Color(0xFF031525),
        Color(0xFF0A2540),
        Color(0xFF093557),
        Color(0xFF020D18),
      ],
      accentColor: Color(0xFF38BDF8),
      cardColor: Color(0x3B041E34),
      badgeColor: Color(0xFF0284C7),
    ),
    RoomThemeData(
      id: 'retro_synthwave',
      name: 'Retro Synthwave',
      icon: Icons.album_rounded,
      gradientColors: [
        Color(0xFF1C0838),
        Color(0xFF2E0854),
        Color(0xFF3D0C4A),
        Color(0xFF150426),
      ],
      accentColor: Color(0xFFEC4899),
      cardColor: Color(0x3D24053E),
      badgeColor: Color(0xFFDB2777),
    ),
    RoomThemeData(
      id: 'midnight_dream',
      name: 'Midnight Dream',
      icon: Icons.bedtime_rounded,
      gradientColors: [
        Color(0xFF0F172A),
        Color(0xFF1E293B),
        Color(0xFF27272A),
        Color(0xFF090D16),
      ],
      accentColor: Color(0xFF818CF8),
      cardColor: Color(0x3D131A2D),
      badgeColor: Color(0xFF6366F1),
    ),
  ];
}
