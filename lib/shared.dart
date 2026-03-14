import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

const baseUrl = "http://10.66.139.169:9000";

class BM {
  static const bg = Color(0xFF0A0A0A);
  static const surface = Color(0xFF111111);
  static const surfaceAlt = Color(0xFF1A1A1A);
  static const border = Color(0xFF262626);

  static const accent = Color(0xFFFFFFFF); // white accent
  static const accentSoft = Color(0x1AFFFFFF);
  static const accentGlow = Color(0x33FFFFFF);

  static const blue = Color(0xFF3B82F6);

  static const textPri = Color(0xFFF4F4F5);
  static const textSec = Color(0xFFA1A1AA);
  static const textTer = Color(0xFF52525B);

  static const danger = Color(0xFFEF4444);
  static const warn = Color(0xFFF59E0B);
  static const success = Color(0xFF22C55E);
}

// ==========================================
// SHARED WIDGETS
// ==========================================
class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final double radius;
  final Color? border;

  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.radius = 18,
    this.border,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: BM.surface,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: border ?? BM.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.35),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }
}

class AccentButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;
  final IconData? icon;

  const AccentButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: BM.accent,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: BM.accentGlow,
              blurRadius: 22,
              offset: const Offset(0, 7),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon, color: BM.bg, size: 18),
              const SizedBox(width: 9),
            ],
            Text(
              label,
              style: const TextStyle(
                color: BM.bg,
                fontSize: 16,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class VDivider extends StatelessWidget {
  const VDivider();

  @override
  Widget build(BuildContext context) =>
      Container(width: 1, height: 36, color: BM.border);
}

class StatBadge extends StatelessWidget {
  final String value;
  final String label;

  const StatBadge({super.key, required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: BM.accent,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            color: BM.textSec,
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class KRow extends StatelessWidget {
  final String label;
  final String value;
  const KRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: BM.textSec, fontSize: 13)),
          Text(
            value,
            style: const TextStyle(
              color: BM.accent,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

// ==========================================
// ALL BLANKMAPS DATA
// ==========================================
final List<Map<String, dynamic>> allBlankMaps = [
  {
    'tag': 'r/Dustbins',
    'desc': 'Track public dustbins to stop littering.',
    'pins': '1,204',
    'icon': CupertinoIcons.trash,
    'hot': true,
  },
  {
    'tag': 'r/Potholes',
    'desc': 'Warning tags for dangerous road damage.',
    'pins': '842',
    'icon': CupertinoIcons.exclamationmark_triangle,
    'hot': true,
  },
  {
    'tag': 'r/CleanToilets',
    'desc': 'Verified usable public restrooms.',
    'pins': '610',
    'icon': CupertinoIcons.checkmark_shield,
    'hot': false,
  },
  {
    'tag': 'r/SafeWalking',
    'desc': 'Well-lit, safe routes for night walks.',
    'pins': '430',
    'icon': CupertinoIcons.moon_stars,
    'hot': false,
  },
  {
    'tag': 'r/FreeWater',
    'desc': 'Public drinking water points.',
    'pins': '290',
    'icon': CupertinoIcons.drop,
    'hot': false,
  },
  {
    'tag': 'r/StreetFood',
    'desc': 'Best street food verified by locals.',
    'pins': '780',
    'icon': CupertinoIcons.cart,
    'hot': true,
  },
  {
    'tag': 'r/BrokenLights',
    'desc': 'Broken streetlights and dark zones.',
    'pins': '215',
    'icon': CupertinoIcons.lightbulb,
    'hot': false,
  },
  {
    'tag': 'r/PublicParks',
    'desc': 'Clean and accessible public parks.',
    'pins': '320',
    'icon': CupertinoIcons.tree,
    'hot': false,
  },
  {
    'tag': 'r/Flooding',
    'desc': 'Waterlogging zones during monsoon.',
    'pins': '198',
    'icon': CupertinoIcons.cloud_rain,
    'hot': false,
  },
  {
    'tag': 'r/ATMs',
    'desc': 'Working ATMs in your area.',
    'pins': '540',
    'icon': CupertinoIcons.creditcard,
    'hot': false,
  },
  {
    'tag': 'r/Hospitals',
    'desc': 'Accessible public hospitals and clinics.',
    'pins': '410',
    'icon': CupertinoIcons.heart_circle,
    'hot': false,
  },
  {
    'tag': 'r/FreeWifi',
    'desc': "Public WiFi hotspots that actually work.",
    'pins': '370',
    'icon': CupertinoIcons.wifi,
    'hot': false,
  },
  {
    'tag': 'r/Pharmacies',
    'desc': 'Open pharmacies and medical stores.',
    'pins': '260',
    'icon': CupertinoIcons.bandage,
    'hot': false,
  },
  {
    'tag': 'r/BusStops',
    'desc': 'Working bus stops with route info.',
    'pins': '890',
    'icon': CupertinoIcons.bus,
    'hot': true,
  },
  {
    'tag': 'r/EVCharging',
    'desc': 'Electric vehicle charging stations.',
    'pins': '145',
    'icon': CupertinoIcons.car,
    'hot': false,
  },
  {
    'tag': 'r/StrayAnimals',
    'desc': 'Feeding spots and shelters for strays.',
    'pins': '175',
    'icon': CupertinoIcons.paw,
    'hot': false,
  },
  {
    'tag': 'r/NoisePollution',
    'desc': 'Zones with excessive noise complaints.',
    'pins': '132',
    'icon': CupertinoIcons.speaker_slash,
    'hot': false,
  },
  {
    'tag': 'r/Libraries',
    'desc': 'Free public libraries and reading rooms.',
    'pins': '88',
    'icon': CupertinoIcons.book,
    'hot': false,
  },
];
