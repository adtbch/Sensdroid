import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sensdroid/views/widgets/sensor_value_bar.dart';
import 'stats_primitives.dart';

/// Generic card that streams data from any sensor type [T] and renders
/// a labelled value bar per channel (X / Y / Z etc.).
///
/// Example:
/// ```dart
/// StatsStreamCard<AccelerometerEvent>(
///   title: 'Accelerometer',
///   icon: Icons.open_with_rounded,
///   unit: 'm/s²',
///   color: cs.primary,
///   stream: _accelCtrl.stream,
///   toData: (e) => {'X': e.x, 'Y': e.y, 'Z': e.z},
///   maxAbsValue: 20,
/// )
/// ```
class StatsStreamCard<T> extends StatelessWidget {
  const StatsStreamCard({
    super.key,
    required this.title,
    required this.icon,
    required this.unit,
    required this.color,
    required this.stream,
    required this.toData,
    required this.maxAbsValue,
  });

  final String title;
  final IconData icon;
  final String unit;
  final Color color;
  final Stream<T> stream;
  final Map<String, double> Function(T) toData;
  final double maxAbsValue;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: StatsGlassCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(cs),
            const SizedBox(height: 16),
            StreamBuilder<T>(
              stream: stream,
              builder: (context, snapshot) {
                if (!snapshot.hasData) return _buildWaiting(cs);
                final data = toData(snapshot.data as T);
                return Column(
                  children: data.entries
                      .map(
                        (e) => SensorValueBar(
                          label: e.key,
                          value: e.value,
                          maxAbsValue: maxAbsValue,
                          color: color,
                        ),
                      )
                      .toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(ColorScheme cs) {
    return Row(
      children: [
        StatsIconBox(icon: icon, color: color),
        const SizedBox(width: 10),
        Text(
          title,
          style: GoogleFonts.inter(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: cs.onSurface,
          ),
        ),
        const Spacer(),
        Text(
          unit,
          style: GoogleFonts.inter(
            fontSize: 11,
            color: cs.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildWaiting(ColorScheme cs) {
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
            'Waiting for data...',
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
