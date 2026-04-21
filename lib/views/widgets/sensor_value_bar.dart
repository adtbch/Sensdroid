import 'package:flutter/material.dart';

/// Mini horizontal bar showing a sensor axis value relative to a max range.
class SensorValueBar extends StatelessWidget {
  final String label;
  final double value;
  final double maxAbsValue;
  final Color color;

  const SensorValueBar({
    super.key,
    required this.label,
    required this.value,
    this.maxAbsValue = 20.0,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final clamped = value.clamp(-maxAbsValue, maxAbsValue);
    // 0.0 = full left, 0.5 = center, 1.0 = full right
    final fraction = (clamped / maxAbsValue + 1.0) / 2.0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          SizedBox(
            width: 22,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: Stack(
                children: [
                  // Background track
                  Container(
                    height: 6,
                    color: colorScheme.surfaceContainerHighest.withOpacity(0.4),
                  ),
                  // Center line
                  Positioned(
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Container(
                        width: 1,
                        height: 6,
                        color: colorScheme.outline.withOpacity(0.3),
                      ),
                    ),
                  ),
                  // Value bar
                  Positioned.fill(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final center = constraints.maxWidth / 2;
                        final barStart =
                            fraction >= 0.5 ? center : fraction * constraints.maxWidth;
                        final barEnd = fraction >= 0.5
                            ? fraction * constraints.maxWidth
                            : center;

                        final width = (barEnd - barStart).abs().clamp(2.0, double.infinity);

                        return Align(
                          alignment: Alignment.centerLeft,
                          child: Padding(
                            padding: EdgeInsets.only(left: barStart),
                            child: Container(
                              width: width,
                              height: 6,
                              decoration: BoxDecoration(
                                color: color.withOpacity(0.85),
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 56,
            child: Text(
              value.toStringAsFixed(2),
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurface.withOpacity(0.85),
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
