import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:math' as math;
import 'package:sensdroid/viewmodels/sensor_viewmodel.dart';
import 'stats_primitives.dart';

typedef _YprRecord = ({double yaw, double pitch, double roll});

/// Card that displays live Yaw / Pitch / Roll from [orientationStream].
/// Provides zero-calibration controls via [viewModel].
class StatsYprCard extends StatelessWidget {
  const StatsYprCard({
    super.key,
    required this.orientationStream,
    required this.viewModel,
  });

  final Stream<_YprRecord> orientationStream;
  final SensorViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: StatsGlassCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _YprHeader(cs: cs, viewModel: viewModel),
            const SizedBox(height: 20),
            StreamBuilder<_YprRecord>(
              stream: orientationStream,
              builder: (context, snapshot) {
                final data = snapshot.data;
                final yaw   = _wrapDeg(_radToDeg(data?.yaw   ?? 0.0));
                final pitch = _wrapDeg(_radToDeg(data?.pitch ?? 0.0));
                final roll  = _wrapDeg(_radToDeg(data?.roll  ?? 0.0));
                return _YprAxes(cs: cs, yaw: yaw, pitch: pitch, roll: roll);
              },
            ),
          ],
        ),
      ),
    );
  }

  static double _radToDeg(double v) => v * 180.0 / math.pi;

  static double _wrapDeg(double v) {
    var w = (v + 180.0) % 360.0;
    if (w < 0) w += 360.0;
    return w - 180.0;
  }
}

// ── Header ──────────────────────────────────────────────────────────────────

class _YprHeader extends StatelessWidget {
  const _YprHeader({required this.cs, required this.viewModel});

  final ColorScheme cs;
  final SensorViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const StatsIconBox(
          icon: Icons.view_in_ar_rounded,
          color: Color(0xFFD500F9),
        ),
        const SizedBox(width: 10),
        Text(
          'Sensor Fusion  ·  YPR',
          style: GoogleFonts.inter(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: cs.onSurface,
          ),
        ),
        const Spacer(),
        if (viewModel.isYprZeroed) ...[
          const _ZeroedBadge(),
          const SizedBox(width: 6),
        ],
        _IconAction(
          icon: Icons.gps_fixed_rounded,
          tooltip: 'Set current orientation as zero',
          color: cs.primary,
          onTap: () => viewModel.zeroYpr(),
        ),
        if (viewModel.isYprZeroed) ...[
          const SizedBox(width: 2),
          _IconAction(
            icon: Icons.refresh_rounded,
            tooltip: 'Reset to absolute orientation',
            color: cs.onSurfaceVariant,
            onTap: () => viewModel.zeroYpr(reset: true),
          ),
        ],
      ],
    );
  }
}

// ── Axes ─────────────────────────────────────────────────────────────────────

class _YprAxes extends StatelessWidget {
  const _YprAxes({
    required this.cs,
    required this.yaw,
    required this.pitch,
    required this.roll,
  });

  final ColorScheme cs;
  final double yaw;
  final double pitch;
  final double roll;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _YprAxisRow(cs: cs, label: 'Yaw',   value: yaw,   color: const Color(0xFFD500F9)),
        const SizedBox(height: 10),
        _YprAxisRow(cs: cs, label: 'Pitch', value: pitch, color: cs.primary),
        const SizedBox(height: 10),
        _YprAxisRow(cs: cs, label: 'Roll',  value: roll,  color: cs.tertiary),
      ],
    );
  }
}

// ── Single axis row ───────────────────────────────────────────────────────────

class _YprAxisRow extends StatelessWidget {
  const _YprAxisRow({
    required this.cs,
    required this.label,
    required this.value,
    required this.color,
  });

  final ColorScheme cs;
  final String label;
  final double value; // degrees, range [-180, 180]
  final Color color;

  @override
  Widget build(BuildContext context) {
    final fraction = ((value + 180.0) / 360.0).clamp(0.0, 1.0);

    return Row(
      children: [
        SizedBox(
          width: 44,
          child: Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: cs.onSurfaceVariant,
            ),
          ),
        ),
        Expanded(child: _GaugeBar(fraction: fraction, color: color, cs: cs)),
        const SizedBox(width: 10),
        SizedBox(
          width: 56,
          child: Text(
            '${value.toStringAsFixed(1)}°',
            textAlign: TextAlign.right,
            style: GoogleFonts.jetBrainsMono(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: cs.onSurface,
            ),
          ),
        ),
      ],
    );
  }
}

// ── Bar gauge ─────────────────────────────────────────────────────────────────

class _GaugeBar extends StatelessWidget {
  const _GaugeBar({
    required this.fraction,
    required this.color,
    required this.cs,
  });

  final double fraction; // 0..1, 0.5 = centre
  final Color color;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (_, constraints) {
        final w = constraints.maxWidth;
        return Stack(
          clipBehavior: Clip.none,
          children: [
            // Track
            Container(
              height: 6,
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            // Fill from centre to thumb
            Positioned(
              left: fraction < 0.5 ? fraction * w : w * 0.5,
              width: (fraction - 0.5).abs() * w,
              child: Container(
                height: 6,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
            // Thumb
            Positioned(
              left: (fraction * w - 5).clamp(0.0, w - 10),
              child: Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
            ),
            // Centre tick
            Positioned(
              left: w / 2 - 0.5,
              top: -2,
              child: Container(
                width: 1,
                height: 10,
                color: cs.onSurface.withOpacity(0.25),
              ),
            ),
          ],
        );
      },
    );
  }
}

// ── Small atoms ───────────────────────────────────────────────────────────────

class _ZeroedBadge extends StatelessWidget {
  const _ZeroedBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.green.withOpacity(0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.green.withOpacity(0.5)),
      ),
      child: Text(
        'Zeroed',
        style: GoogleFonts.inter(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: Colors.green,
        ),
      ),
    );
  }
}

class _IconAction extends StatelessWidget {
  const _IconAction({
    required this.icon,
    required this.tooltip,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Icon(icon, size: 18, color: color),
        ),
      ),
    );
  }
}
