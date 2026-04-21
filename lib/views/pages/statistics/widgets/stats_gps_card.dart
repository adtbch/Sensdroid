import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:geolocator/geolocator.dart';
import 'stats_primitives.dart';

/// Displays live GPS data (lat, lon, altitude, speed) from a [Stream<Position>].
class StatsGpsCard extends StatelessWidget {
  const StatsGpsCard({super.key, required this.stream});

  final Stream<Position> stream;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = cs.tertiary;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: StatsGlassCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                StatsIconBox(icon: Icons.pin_drop_rounded, color: color),
                const SizedBox(width: 10),
                Text(
                  'GPS Location',
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: cs.onSurface,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            StreamBuilder<Position>(
              stream: stream,
              builder: (context, snapshot) {
                if (!snapshot.hasData) return _GpsWaiting(color: color);
                final p = snapshot.data!;
                return Column(
                  children: [
                    _GpsRow(cs: cs, label: 'Latitude',  value: '${p.latitude.toStringAsFixed(6)}°',  color: color),
                    _GpsRow(cs: cs, label: 'Longitude', value: '${p.longitude.toStringAsFixed(6)}°', color: color),
                    _GpsRow(cs: cs, label: 'Altitude',  value: '${p.altitude.toStringAsFixed(1)} m', color: color),
                    _GpsRow(cs: cs, label: 'Speed',     value: '${p.speed.toStringAsFixed(2)} m/s',  color: color),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _GpsWaiting extends StatelessWidget {
  const _GpsWaiting({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: color.withValues(alpha: 0.4),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            'Waiting for GPS fix...',
            style: GoogleFonts.inter(
              fontSize: 13,
              color: cs.onSurfaceVariant,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }
}

class _GpsRow extends StatelessWidget {
  const _GpsRow({
    required this.cs,
    required this.label,
    required this.value,
    required this.color,
  });

  final ColorScheme cs;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: cs.onSurfaceVariant,
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              value,
              style: GoogleFonts.jetBrainsMono(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
