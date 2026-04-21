import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:sensdroid/core/app_constants.dart';
import 'package:sensdroid/viewmodels/sensor_viewmodel.dart';
import 'package:sensdroid/views/widgets/animated_status_dot.dart';

class SensorsPage extends StatelessWidget {
  const SensorsPage({super.key});

  // Per-sensor accent colors
  static Color _accentColor(String key, ColorScheme cs) {
    switch (key) {
      case AppConstants.sensorAccelerometer:
        return cs.primary; // cyan
      case AppConstants.sensorGyroscope:
        return cs.secondary; // purple
      case AppConstants.sensorMagnetometer:
        return const Color(0xFFFF9800); // amber
      case AppConstants.sensorGPS:
        return cs.tertiary; // teal
      default:
        return cs.onSurfaceVariant;
    }
  }

  static IconData _icon(String key) {
    switch (key) {
      case AppConstants.sensorAccelerometer:
        return Icons.open_with_rounded;
      case AppConstants.sensorGyroscope:
        return Icons.threesixty_rounded;
      case AppConstants.sensorMagnetometer:
        return Icons.explore_rounded;
      case AppConstants.sensorGPS:
        return Icons.pin_drop_rounded;
      default:
        return Icons.sensors_rounded;
    }
  }

  static String _name(String key) {
    switch (key) {
      case AppConstants.sensorAccelerometer:
        return 'Accelerometer';
      case AppConstants.sensorGyroscope:
        return 'Gyroscope';
      case AppConstants.sensorMagnetometer:
        return 'Magnetometer';
      case AppConstants.sensorGPS:
        return 'GPS Location';
      default:
        return key;
    }
  }

  static String _description(String key) {
    switch (key) {
      case AppConstants.sensorAccelerometer:
        return 'Linear acceleration (m/s²)';
      case AppConstants.sensorGyroscope:
        return 'Angular velocity (rad/s)';
      case AppConstants.sensorMagnetometer:
        return 'Magnetic field (µT)';
      case AppConstants.sensorGPS:
        return 'Location & altitude';
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<SensorViewModel>(
      builder: (context, viewModel, child) {
        final cs = Theme.of(context).colorScheme;

        return CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // ─── Header ──────────────────────────────────────────────────────
            SliverAppBar(
              pinned: true,
              backgroundColor: cs.surface,
              elevation: 0,
              scrolledUnderElevation: 0,
              expandedHeight: 120,
              flexibleSpace: FlexibleSpaceBar(
                titlePadding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
                title: Text(
                  'Sensors',
                  style: GoogleFonts.inter(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: cs.onSurface,
                    letterSpacing: -0.3,
                  ),
                ),
                background: Stack(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            cs.secondaryContainer.withOpacity(0.2),
                            cs.surface,
                          ],
                        ),
                      ),
                    ),
                    Positioned(
                      right: -20,
                      top: -10,
                      child: Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: cs.secondary.withOpacity(0.07),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 44, 20, 52),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Sensor Selection',
                            style: GoogleFonts.inter(
                              fontSize: 26,
                              fontWeight: FontWeight.w900,
                              color: cs.onSurface,
                              letterSpacing: -0.8,
                            ),
                          ),
                          Text(
                            'Tap a card to enable/disable streaming',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              color: cs.onSurfaceVariant,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Column(
                  children: [
                    // Detection progress bar
                    if (!viewModel.isSensorDetectionComplete)
                      _detectionBanner(cs)
                    else
                      _headerActions(viewModel, cs),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),

            // ─── Sensor Grid ─────────────────────────────────────────────────
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              sliver: SliverGrid(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final entry =
                        viewModel.enabledSensors.entries.elementAt(index);
                    final isAvailable =
                        viewModel.availableSensors[entry.key] ?? false;
                    return _SensorCard(
                      sensorKey: entry.key,
                      isEnabled: entry.value,
                      isAvailable: isAvailable,
                      detectionComplete: viewModel.isSensorDetectionComplete,
                      isTransmitting: viewModel.isTransmitting,
                      onTap: () => viewModel.toggleSensor(
                        entry.key,
                        !entry.value,
                      ),
                    );
                  },
                  childCount: viewModel.enabledSensors.length,
                ),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 14,
                  crossAxisSpacing: 14,
                  childAspectRatio: 0.95,
                ),
              ),
            ),

            // ─── Sampling Info ────────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
                child: _SamplingCard(viewModel: viewModel),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _detectionBanner(ColorScheme cs) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: cs.tertiaryContainer.withOpacity(0.4),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: cs.tertiary.withOpacity(0.3)),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: cs.tertiary,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Detecting available sensors...',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: cs.onTertiaryContainer,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _headerActions(SensorViewModel viewModel, ColorScheme cs) {
    final activeCount =
        viewModel.enabledSensors.values.where((v) => v).length;
    final total = viewModel.enabledSensors.length;

    return Row(
      children: [
        // Active count pill
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: cs.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: cs.primary.withOpacity(0.25)),
          ),
          child: Text(
            '$activeCount / $total active',
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: cs.primary,
            ),
          ),
        ),
        const Spacer(),
        // Redetect button
        OutlinedButton.icon(
          onPressed: viewModel.redetectSensors,
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            side: BorderSide(color: cs.outline.withOpacity(0.4)),
            foregroundColor: cs.onSurfaceVariant,
          ),
          icon: const Icon(Icons.refresh_rounded, size: 16),
          label: Text(
            'Redetect',
            style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}

// ─── Sensor Card ───────────────────────────────────────────────────────────────

class _SensorCard extends StatefulWidget {
  final String sensorKey;
  final bool isEnabled;
  final bool isAvailable;
  final bool detectionComplete;
  final bool isTransmitting;
  final VoidCallback onTap;

  const _SensorCard({
    required this.sensorKey,
    required this.isEnabled,
    required this.isAvailable,
    required this.detectionComplete,
    required this.isTransmitting,
    required this.onTap,
  });

  @override
  State<_SensorCard> createState() => _SensorCardState();
}

class _SensorCardState extends State<_SensorCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _tapCtrl;
  late Animation<double> _tapScale;

  @override
  void initState() {
    super.initState();
    _tapCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
      reverseDuration: const Duration(milliseconds: 200),
    );
    _tapScale = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _tapCtrl, curve: Curves.easeIn),
    );
  }

  @override
  void dispose() {
    _tapCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDisabled =
        !widget.isAvailable && widget.detectionComplete;
    final color = SensorsPage._accentColor(widget.sensorKey, cs);

    return AnimatedBuilder(
      animation: _tapScale,
      builder: (context, child) => Transform.scale(
        scale: _tapScale.value,
        child: child,
      ),
      child: GestureDetector(
        onTapDown: isDisabled ? null : (_) => _tapCtrl.forward(),
        onTapUp: isDisabled
            ? null
            : (_) async {
                await _tapCtrl.reverse();
                widget.onTap();
              },
        onTapCancel: () => _tapCtrl.reverse(),
        child: Opacity(
          opacity: isDisabled ? 0.38 : 1.0,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOut,
            decoration: BoxDecoration(
              gradient: widget.isEnabled
                  ? LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        color.withOpacity(0.2),
                        color.withOpacity(0.06),
                      ],
                    )
                  : null,
              color: widget.isEnabled
                  ? null
                  : cs.surfaceContainerHigh.withOpacity(0.7),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: widget.isEnabled
                    ? color.withOpacity(0.5)
                    : cs.outline.withOpacity(0.2),
                width: widget.isEnabled ? 1.5 : 1,
              ),
              boxShadow: widget.isEnabled
                  ? [
                      BoxShadow(
                        color: color.withOpacity(0.18),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : null,
            ),
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Icon + status dot + check
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: widget.isEnabled
                            ? color.withOpacity(0.18)
                            : cs.surfaceContainerHighest.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        SensorsPage._icon(widget.sensorKey),
                        color: widget.isEnabled ? color : cs.onSurfaceVariant,
                        size: 22,
                      ),
                    ),
                    const Spacer(),
                    if (widget.isEnabled && widget.isTransmitting)
                      AnimatedStatusDot(
                        color: color,
                        size: 8,
                        animate: true,
                      )
                    else if (widget.isEnabled)
                      Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.check_rounded,
                          size: 12,
                          color: Colors.white,
                        ),
                      ),
                  ],
                ),
                const Spacer(),
                // Name + availability dot
                Text(
                  SensorsPage._name(widget.sensorKey),
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: widget.isEnabled ? color : cs.onSurface,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  SensorsPage._description(widget.sensorKey),
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    color: widget.isEnabled
                        ? color.withOpacity(0.7)
                        : cs.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: widget.isAvailable
                            ? const Color(0xFF00E676)
                            : cs.error,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      widget.isAvailable ? 'Available' : 'Not found',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: widget.isAvailable
                            ? const Color(0xFF00E676)
                            : cs.error,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Sampling Info Card ────────────────────────────────────────────────────────

class _SamplingCard extends StatelessWidget {
  final SensorViewModel viewModel;

  const _SamplingCard({required this.viewModel});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final hz = viewModel.samplingRate > 0
        ? '${(1000 / viewModel.samplingRate).toStringAsFixed(0)} Hz'
        : '∞ Hz';

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: cs.surfaceContainer.withOpacity(0.7),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: cs.outline.withOpacity(0.15)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: cs.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.tune_rounded, color: cs.primary, size: 20),
              ),
              const SizedBox(width: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Sampling Configuration',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: cs.onSurface,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Configure in Dashboard settings',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    hz,
                    style: GoogleFonts.inter(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: cs.tertiary,
                    ),
                  ),
                  Text(
                    '${viewModel.samplingRate} ms',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: cs.onSurfaceVariant,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
