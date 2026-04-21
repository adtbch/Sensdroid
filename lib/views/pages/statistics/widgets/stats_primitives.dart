import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// A frosted-glass-style card used throughout the Statistics page.
class StatsGlassCard extends StatelessWidget {
  const StatsGlassCard({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh.withOpacity(0.95),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cs.primary.withOpacity(0.12), width: 1),
      ),
      child: child,
    );
  }
}

/// Coloured icon in a rounded box — used in card headers.
class StatsIconBox extends StatelessWidget {
  const StatsIconBox({
    super.key,
    required this.icon,
    required this.color,
  });

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, color: color, size: 18),
    );
  }
}

/// Small metric tile used inside the transmission card.
class StatsMetricTile extends StatelessWidget {
  const StatsMetricTile({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    required this.unit,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final String unit;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 13, color: color),
              const SizedBox(width: 5),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: cs.onSurface,
            ),
          ),
          if (unit.isNotEmpty)
            Text(
              unit,
              style: GoogleFonts.inter(
                fontSize: 10,
                color: cs.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
        ],
      ),
    );
  }
}

/// Animated "LIVE" badge shown when transmission is active.
class StatsLiveBadge extends StatelessWidget {
  const StatsLiveBadge({super.key});

  @override
  Widget build(BuildContext context) {
    // Import AnimatedStatusDot from the shared widgets package.
    return const _LiveBadgeImpl();
  }
}

class _LiveBadgeImpl extends StatelessWidget {
  const _LiveBadgeImpl();

  static const _green = Color(0xFF00E676);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: _green.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _green.withOpacity(0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: const BoxDecoration(
              color: _green,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            'LIVE',
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: _green,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

/// Small icon button used in card toolbars.
class StatsControlButton extends StatelessWidget {
  const StatsControlButton({
    super.key,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Icon(icon, color: color, size: 18),
      ),
    );
  }
}

/// Formats a [Duration] as "Xm Ys".
String statsFormatDuration(Duration d) =>
    '${d.inMinutes}m ${d.inSeconds % 60}s';
