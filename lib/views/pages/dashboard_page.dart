import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:sensdroid/core/app_constants.dart';
import 'package:sensdroid/viewmodels/sensor_viewmodel.dart';
import 'package:sensdroid/views/settings_page.dart';
import 'package:sensdroid/views/widgets/animated_status_dot.dart';
import 'package:sensdroid/views/widgets/device_scan_dialog.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage>
    with SingleTickerProviderStateMixin {
  String? _selectedDevice;
  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(
      begin: 0.85,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<SensorViewModel>(
      builder: (context, viewModel, child) {
        final colorScheme = Theme.of(context).colorScheme;

        return Scaffold(
          backgroundColor: colorScheme.surface,
          body: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              _buildSliverAppBar(viewModel, colorScheme),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 16),
                      _buildConnectionCard(viewModel, colorScheme),
                      const SizedBox(height: 14),
                      _buildStatsRow(viewModel, colorScheme),
                      const SizedBox(height: 14),
                      _buildTransmissionCard(viewModel, colorScheme),
                      const SizedBox(height: 14),
                      _buildActiveSensorsChips(viewModel, colorScheme),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ─── Sliver App Bar (Hero Header) ───────────────────────────────────────────

  Widget _buildSliverAppBar(
    SensorViewModel viewModel,
    ColorScheme colorScheme,
  ) {
    return SliverAppBar(
      expandedHeight: 140,
      pinned: true,
      backgroundColor: colorScheme.surface,
      elevation: 0,
      scrolledUnderElevation: 0,
      actions: [
        IconButton(
          icon: Icon(
            Icons.settings_rounded,
            color: colorScheme.onSurfaceVariant,
          ),
          onPressed: () {
            final settings = viewModel.settings;
            if (settings == null) return;
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) =>
                    SettingsPage(settings: settings, viewModel: viewModel),
              ),
            );
          },
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
        title: Row(
          children: [
            _connectionDot(viewModel, colorScheme),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Sensdroid',
                style: GoogleFonts.inter(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: colorScheme.onSurface,
                  letterSpacing: -0.3,
                ),
              ),
            ),
          ],
        ),
        background: Stack(
          children: [
            // Gradient background
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    colorScheme.primaryContainer.withOpacity(0.25),
                    colorScheme.surface,
                  ],
                ),
              ),
            ),
            // Decorative circles
            Positioned(
              right: -30,
              top: -20,
              child: Container(
                width: 160,
                height: 160,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: colorScheme.primary.withOpacity(0.06),
                ),
              ),
            ),
            Positioned(
              right: 40,
              top: 10,
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: colorScheme.secondary.withOpacity(0.08),
                ),
              ),
            ),
            // Content (hidden when app bar is collapsed to avoid overflow).
            Positioned.fill(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  if (constraints.maxHeight < 96) {
                    return const SizedBox.shrink();
                  }

                  return Padding(
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'USB Serial Control',
                          style: GoogleFonts.inter(
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                            color: colorScheme.onSurface,
                            letterSpacing: -0.8,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'ESP over UART via USB OTG',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _connectionDot(SensorViewModel viewModel, ColorScheme colorScheme) {
    final Color dotColor;
    final bool animate;

    if (viewModel.isConnecting) {
      dotColor = colorScheme.tertiary;
      animate = true;
    } else if (viewModel.isConnected) {
      dotColor = const Color(0xFF00E676);
      animate = viewModel.isTransmitting;
    } else {
      dotColor = colorScheme.outline;
      animate = false;
    }

    return AnimatedStatusDot(color: dotColor, size: 9, animate: animate);
  }

  // ─── Connection Card ─────────────────────────────────────────────────────────

  Widget _buildConnectionCard(
    SensorViewModel viewModel,
    ColorScheme colorScheme,
  ) {
    return _glassCard(
      colorScheme,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(
            children: [
              _sectionIcon(Icons.usb_rounded, colorScheme.primary, colorScheme),
              const SizedBox(width: 10),
              Text(
                'USB Connection',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: colorScheme.onSurface,
                ),
              ),
              const Spacer(),
              _statusBadge(viewModel, colorScheme),
            ],
          ),
          const SizedBox(height: 12),
          // Baudrate display
          _infoChip(
            icon: Icons.speed_rounded,
            label: 'Baudrate: ${viewModel.usbBaudRate} bps',
            colorScheme: colorScheme,
          ),
          // Error banner
          if (viewModel.lastError != null && !viewModel.isConnected) ...{
            const SizedBox(height: 10),
            _errorBanner(viewModel.lastError!, colorScheme),
          },
          const SizedBox(height: 14),
          // Connected info or scan controls
          if (viewModel.isConnected)
            _buildConnectedInfo(viewModel, colorScheme)
          else
            _buildScanControls(viewModel, colorScheme),
        ],
      ),
    );
  }

  Widget _buildConnectedInfo(
    SensorViewModel viewModel,
    ColorScheme colorScheme,
  ) {
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF00E676).withOpacity(0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: const Color(0xFF00E676).withOpacity(0.25),
            ),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.memory_rounded,
                color: Color(0xFF00E676),
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      viewModel.connectionInfo?.deviceName ?? 'USB Device',
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    Text(
                      viewModel.connectionInfo?.address ?? '-',
                      style: GoogleFonts.jetBrainsMono(
                        color: colorScheme.onSurfaceVariant,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () async {
              await viewModel.disconnect();
              if (!mounted) return;
              setState(() => _selectedDevice = null);
            },
            icon: const Icon(Icons.link_off_rounded, size: 18),
            label: const Text('Disconnect'),
            style: OutlinedButton.styleFrom(
              foregroundColor: colorScheme.error,
              side: BorderSide(color: colorScheme.error.withOpacity(0.4)),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildScanControls(
    SensorViewModel viewModel,
    ColorScheme colorScheme,
  ) {
    return Column(
      children: [
        if (_selectedDevice != null)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: colorScheme.secondaryContainer.withOpacity(0.3),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              'Selected: ${_selectedDevice!.split('||').first}',
              style: GoogleFonts.inter(
                color: colorScheme.onSurface,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: viewModel.isConnecting
                ? null
                : () async {
                    final selected = await showDialog<String>(
                      context: context,
                      builder: (context) => DeviceScanDialog(
                        onScan: () => viewModel.scanDevices(),
                      ),
                    );
                    if (selected == null || !mounted) return;
                    setState(() => _selectedDevice = selected);
                    final success = await viewModel.connect(selected);
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          success
                              ? 'Connected to ${selected.split('||').first}'
                              : (viewModel.lastError ?? 'Connection failed'),
                        ),
                        behavior: SnackBarBehavior.floating,
                        backgroundColor: success
                            ? colorScheme.primary
                            : colorScheme.error,
                      ),
                    );
                  },
            icon: viewModel.isConnecting
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.search_rounded, size: 18),
            label: Text(
              viewModel.isConnecting ? 'Connecting...' : 'Scan USB Devices',
            ),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ─── Stats Row ───────────────────────────────────────────────────────────────

  Widget _buildStatsRow(SensorViewModel viewModel, ColorScheme colorScheme) {
    return Row(
      children: [
        Expanded(
          child: _miniStatCard(
            label: 'Sent',
            value: '${viewModel.packetsSent}',
            icon: Icons.upload_rounded,
            color: colorScheme.primary,
            colorScheme: colorScheme,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _miniStatCard(
            label: 'Dropped',
            value: '${viewModel.packetsDropped}',
            icon: Icons.warning_rounded,
            color: viewModel.packetsDropped > 0
                ? colorScheme.error
                : colorScheme.onSurfaceVariant,
            colorScheme: colorScheme,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _miniStatCard(
            label: 'pkt/s',
            value: viewModel.transmissionRate.toStringAsFixed(1),
            icon: Icons.speed_rounded,
            color: colorScheme.secondary,
            colorScheme: colorScheme,
          ),
        ),
      ],
    );
  }

  Widget _miniStatCard({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
    required ColorScheme colorScheme,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(height: 6),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  // ─── Transmission Card ───────────────────────────────────────────────────────

  Widget _buildTransmissionCard(
    SensorViewModel viewModel,
    ColorScheme colorScheme,
  ) {
    final canStart = viewModel.enabledSensors.values.any((v) => v);
    final isTransmitting = viewModel.isTransmitting;

    return _glassCard(
      colorScheme,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _sectionIcon(
                isTransmitting
                    ? Icons.wifi_tethering_rounded
                    : Icons.send_rounded,
                isTransmitting ? const Color(0xFF00E676) : colorScheme.primary,
                colorScheme,
              ),
              const SizedBox(width: 10),
              Text(
                'Transmission',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: colorScheme.onSurface,
                ),
              ),
              const Spacer(),
              if (isTransmitting) _liveBadge(colorScheme),
            ],
          ),
          const SizedBox(height: 14),
          // Sampling rate slider
          Row(
            children: [
              Icon(Icons.tune_rounded, size: 16, color: colorScheme.secondary),
              const SizedBox(width: 6),
              Text(
                'Sampling Rate',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              Text(
                viewModel.samplingRate > 0
                    ? '${viewModel.samplingRate} ms  ·  ${(1000 / viewModel.samplingRate).toStringAsFixed(0)} Hz'
                    : 'Max Hz',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: colorScheme.secondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Auto-Optimized for ${viewModel.usbBaudRate} bps & Active Sensors',
            style: GoogleFonts.inter(
              fontSize: 11,
              color: colorScheme.onSurfaceVariant.withOpacity(0.8),
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(height: 12),
          // Big action button
          SizedBox(
            width: double.infinity,
            height: 52,
            child: isTransmitting
                ? AnimatedBuilder(
                    animation: _pulseAnim,
                    builder: (context, child) {
                      return Opacity(opacity: _pulseAnim.value, child: child);
                    },
                    child: FilledButton.icon(
                      onPressed: viewModel.stopTransmission,
                      style: FilledButton.styleFrom(
                        backgroundColor: colorScheme.error,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      icon: const Icon(Icons.stop_circle_rounded),
                      label: const Text('Stop Transmission'),
                    ),
                  )
                : FilledButton.icon(
                    onPressed: (!viewModel.isConnected || !canStart)
                        ? null
                        : () async {
                            try {
                              await viewModel.startTransmission();
                            } catch (_) {
                              if (!mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    viewModel.lastError ??
                                        'Failed to start transmission',
                                  ),
                                  backgroundColor: colorScheme.error,
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            }
                          },
                    style: FilledButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: const Text('Start Transmission'),
                  ),
          ),
          if (!viewModel.isConnected)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 12,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Connect a USB device first',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // ─── Active Sensors Chips ─────────────────────────────────────────────────────

  Widget _buildActiveSensorsChips(
    SensorViewModel viewModel,
    ColorScheme colorScheme,
  ) {
    final active = viewModel.enabledSensors.entries
        .where((e) => e.value)
        .map((e) => e.key)
        .toList();

    return _glassCard(
      colorScheme,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _sectionIcon(
                Icons.sensors_rounded,
                colorScheme.tertiary,
                colorScheme,
              ),
              const SizedBox(width: 10),
              Text(
                'Active Sensors',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: colorScheme.onSurface,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: colorScheme.tertiary.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${active.length}/${viewModel.enabledSensors.length}',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: colorScheme.tertiary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (active.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'No sensors enabled. Go to the Sensors tab to enable them.',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: colorScheme.onSurfaceVariant,
                  fontStyle: FontStyle.italic,
                ),
              ),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: active.map((key) {
                final color = _sensorColor(key, colorScheme);
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: color.withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(_sensorIcon(key), size: 14, color: color),
                      const SizedBox(width: 6),
                      Text(
                        _sensorName(key),
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: color,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  // ─── Helpers ─────────────────────────────────────────────────────────────────

  Widget _glassCard(ColorScheme colorScheme, {required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh.withOpacity(
          0.95,
        ), // Matte solid alternative
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: colorScheme.primary.withOpacity(0.12),
          width: 1,
        ),
      ),
      child: child,
    );
  }

  Widget _sectionIcon(IconData icon, Color color, ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, color: color, size: 18),
    );
  }

  Widget _statusBadge(SensorViewModel viewModel, ColorScheme colorScheme) {
    Color color;
    String text;
    IconData icon;

    if (viewModel.isConnecting) {
      color = colorScheme.tertiary;
      text = 'Connecting';
      icon = Icons.wifi_find_rounded;
    } else if (viewModel.isConnected) {
      color = const Color(0xFF00E676);
      text = 'Connected';
      icon = Icons.check_circle_rounded;
    } else {
      color = colorScheme.outline;
      text = 'Offline';
      icon = Icons.link_off_rounded;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 5),
          Text(
            text,
            style: GoogleFonts.inter(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Widget _liveBadge(ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFF00E676).withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF00E676).withOpacity(0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedStatusDot(
            color: const Color(0xFF00E676),
            size: 7,
            animate: true,
          ),
          const SizedBox(width: 6),
          Text(
            'LIVE',
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF00E676),
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoChip({
    required IconData icon,
    required String label,
    required ColorScheme colorScheme,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withOpacity(0.4),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: colorScheme.primary),
          const SizedBox(width: 6),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _errorBanner(String message, ColorScheme colorScheme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.errorContainer.withOpacity(0.5),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: colorScheme.error.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline_rounded, size: 16, color: colorScheme.error),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.inter(
                color: colorScheme.onErrorContainer,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _sensorColor(String key, ColorScheme colorScheme) {
    switch (key) {
      case AppConstants.sensorAccelerometer:
        return colorScheme.primary;
      case AppConstants.sensorGyroscope:
        return colorScheme.secondary;
      case AppConstants.sensorMagnetometer:
        return const Color(0xFFFF9800);
      case AppConstants.sensorGPS:
        return colorScheme.tertiary;
      default:
        return colorScheme.onSurfaceVariant;
    }
  }

  IconData _sensorIcon(String sensorType) {
    switch (sensorType) {
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

  String _sensorName(String sensorType) {
    switch (sensorType) {
      case AppConstants.sensorAccelerometer:
        return 'Accelerometer';
      case AppConstants.sensorGyroscope:
        return 'Gyroscope';
      case AppConstants.sensorMagnetometer:
        return 'Magnetometer';
      case AppConstants.sensorGPS:
        return 'GPS';
      default:
        return sensorType;
    }
  }
}
