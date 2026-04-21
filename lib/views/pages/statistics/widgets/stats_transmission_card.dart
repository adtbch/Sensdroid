import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sensdroid/viewmodels/sensor_viewmodel.dart';
import 'stats_primitives.dart';

/// Shows packets sent/dropped, transmission rate, and duration.
class StatsTransmissionCard extends StatelessWidget {
  const StatsTransmissionCard({super.key, required this.viewModel});

  final SensorViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isTransmitting = viewModel.isTransmitting;

    return StatsGlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(cs, isTransmitting),
          const SizedBox(height: 18),
          _buildMetricGrid(cs),
          if (!isTransmitting) _buildIdleHint(cs),
        ],
      ),
    );
  }

  Widget _buildHeader(ColorScheme cs, bool isTransmitting) {
    return Row(
      children: [
        StatsIconBox(icon: Icons.analytics_rounded, color: cs.primary),
        const SizedBox(width: 10),
        Text(
          'Transmission',
          style: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: cs.onSurface,
          ),
        ),
        const Spacer(),
        if (isTransmitting)
          const StatsLiveBadge()
        else
          Text(
            'Idle',
            style: GoogleFonts.inter(
              fontSize: 12,
              color: cs.onSurfaceVariant,
              fontWeight: FontWeight.w500,
            ),
          ),
      ],
    );
  }

  Widget _buildMetricGrid(ColorScheme cs) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: StatsMetricTile(
                icon: Icons.upload_rounded,
                label: 'SENT',
                value: '${viewModel.packetsSent}',
                unit: 'packets',
                color: cs.primary,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: StatsMetricTile(
                icon: Icons.warning_rounded,
                label: 'DROPPED',
                value: '${viewModel.packetsDropped}',
                unit: 'packets',
                color: viewModel.packetsDropped > 0
                    ? cs.error
                    : cs.onSurfaceVariant.withOpacity(0.5),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: StatsMetricTile(
                icon: Icons.speed_rounded,
                label: 'RATE',
                value: viewModel.transmissionRate.toStringAsFixed(1),
                unit: 'pkt/s',
                color: cs.secondary,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: StatsMetricTile(
                icon: Icons.timer_outlined,
                label: 'DURATION',
                value: viewModel.transmissionDuration != null
                    ? statsFormatDuration(viewModel.transmissionDuration!)
                    : '0m 0s',
                unit: '',
                color: cs.tertiary,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildIdleHint(ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.info_outline,
            size: 13,
            color: cs.onSurfaceVariant.withOpacity(0.5),
          ),
          const SizedBox(width: 6),
          Text(
            'Start transmission from Dashboard',
            style: GoogleFonts.inter(
              fontSize: 12,
              color: cs.onSurfaceVariant.withOpacity(0.5),
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }
}
