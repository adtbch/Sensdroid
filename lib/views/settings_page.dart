import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sensdroid/core/app_constants.dart';
import 'package:sensdroid/core/app_settings.dart';
import 'package:sensdroid/viewmodels/sensor_viewmodel.dart';

/// Settings page focused on USB UART serial communication.
class SettingsPage extends StatefulWidget {
  final AppSettings settings;
  final SensorViewModel viewModel;

  const SettingsPage({
    super.key,
    required this.settings,
    required this.viewModel,
  });

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late int _selectedBaudRate;
  bool _reconnectOnBaudChange = true;

  @override
  void initState() {
    super.initState();
    _selectedBaudRate = widget.settings.usbBaudRate;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        title: const Text('Settings'),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_rounded, color: cs.onSurfaceVariant),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Text(
                    'Serial Configuration',
                    style: GoogleFonts.inter(
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      color: cs.onSurface,
                      letterSpacing: -0.8,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'USB UART baudrate and transmission settings',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: cs.onSurfaceVariant,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 20),
                  _buildUartSection(cs),
                  const SizedBox(height: 16),
                  _buildTransmissionSection(cs),
                  const SizedBox(height: 16),
                  _buildCurrentSettingsSection(cs),
                  const SizedBox(height: 16),
                  _buildDangerSection(cs),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── UART Section ─────────────────────────────────────────────────────────────

  Widget _buildUartSection(ColorScheme cs) {
    final baudPresets = AppConstants.usbBaudRatePresets;

    return _glassCard(
      cs,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('USB UART Baudrate', Icons.usb_rounded, cs.primary, cs),
          const SizedBox(height: 8),
          Text(
            'Range: ${AppConstants.usbMinBaudRate} – ${AppConstants.usbMaxBaudRate} bps',
            style: GoogleFonts.inter(
              color: cs.onSurfaceVariant,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 14),
          // Current baud display
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: cs.primary.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: cs.primary.withOpacity(0.2)),
            ),
            child: Row(
              children: [
                Icon(Icons.speed_rounded, color: cs.primary, size: 18),
                const SizedBox(width: 10),
                Text(
                  '$_selectedBaudRate bps',
                  style: GoogleFonts.jetBrainsMono(
                    fontWeight: FontWeight.w700,
                    color: cs.primary,
                    fontSize: 15,
                  ),
                ),
                const Spacer(),
                Text(
                  'current',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    color: cs.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          // Preset chips
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: baudPresets.map((baud) {
              final isSelected = _selectedBaudRate == baud;
              return GestureDetector(
                onTap: () => _applyBaudRate(baud),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? cs.primary.withOpacity(0.15)
                        : cs.surfaceContainerHighest.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isSelected
                          ? cs.primary.withOpacity(0.5)
                          : cs.outline.withOpacity(0.2),
                      width: isSelected ? 1.5 : 1,
                    ),
                  ),
                  child: Text(
                    '$baud',
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: isSelected ? cs.primary : cs.onSurfaceVariant,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          if (widget.viewModel.isConnected) ...[
            const SizedBox(height: 14),
            _divider(cs),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Reconnect after baudrate change',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: cs.onSurface,
                        ),
                      ),
                      Text(
                        'Required to apply on active link',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Switch.adaptive(
                  value: _reconnectOnBaudChange,
                  onChanged: (v) => setState(() => _reconnectOnBaudChange = v),
                ),
              ],
            ),
          ],
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _showCustomBaudDialog,
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                side: BorderSide(color: cs.outline.withOpacity(0.3)),
                foregroundColor: cs.onSurface,
              ),
              icon: Icon(Icons.tune_rounded, size: 16, color: cs.primary),
              label: Text(
                'Set Custom Baudrate',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Transmission Section ─────────────────────────────────────────────────────

  Widget _buildTransmissionSection(ColorScheme cs) {
    return _glassCard(
      cs,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle(
            'Transmission',
            Icons.send_rounded,
            cs.secondary,
            cs,
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Text(
                'Sampling interval',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: cs.onSurfaceVariant,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              Text(
                '${widget.viewModel.samplingRate} ms (Auto)',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w800,
                  color: cs.secondary,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Sampling rate is automatically locked and optimized based on the selected ${widget.viewModel.usbBaudRate} bps Baud Rate and active sensors to prevent buffer overflow.',
            style: GoogleFonts.inter(
              fontSize: 11,
              color: cs.onSurfaceVariant.withOpacity(0.8),
              fontStyle: FontStyle.italic,
            ),
          ),
          _divider(cs),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '3D Sensor Fusion (YPR)',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: cs.onSurface,
                      ),
                    ),
                    Text(
                      'Send Yaw, Pitch, Roll instead of XYZ',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Switch.adaptive(
                value: widget.viewModel.useSensorFusionMode,
                activeColor: cs.secondary,
                onChanged: (v) {
                  setState(() {
                    widget.viewModel.toggleSensorFusionMode(v);
                  });
                },
              ),
            ],
          ),
          _divider(cs),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Performance Mode',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: cs.onSurface,
                      ),
                    ),
                    Text(
                      widget.settings.performanceMode
                          ? 'Higher throughput, more battery'
                          : 'Balanced power usage',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Switch.adaptive(
                value: widget.settings.performanceMode,
                onChanged: (v) =>
                    setState(() => widget.settings.performanceMode = v),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── Current Settings Section ─────────────────────────────────────────────────

  Widget _buildCurrentSettingsSection(ColorScheme cs) {
    return _glassCard(
      cs,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('Current Values', Icons.info_outline_rounded, cs.tertiary, cs),
          const SizedBox(height: 14),
          _settingRow(cs, icon: Icons.cable_rounded, label: 'Protocol', value: 'USB UART'),
          _divider(cs),
          _settingRow(
            cs,
            icon: Icons.speed_rounded,
            label: 'Baudrate',
            value: '${widget.settings.usbBaudRate} bps',
          ),
          _divider(cs),
          _settingRow(
            cs,
            icon: Icons.timer_rounded,
            label: 'Sampling Rate',
            value: '${widget.settings.samplingRate} ms',
          ),
          _divider(cs),
          _settingRow(
            cs,
            icon: Icons.storage_rounded,
            label: 'Buffer Size',
            value: '${widget.settings.bufferSize}',
          ),
          _divider(cs),
          _settingRow(
            cs,
            icon: Icons.bolt_rounded,
            label: 'Performance',
            value: widget.settings.performanceMode ? 'High' : 'Balanced',
          ),
        ],
      ),
    );
  }

  // ─── Danger Section ───────────────────────────────────────────────────────────

  Widget _buildDangerSection(ColorScheme cs) {
    return _glassCard(
      cs,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('Reset', Icons.warning_amber_rounded, cs.error, cs),
          const SizedBox(height: 6),
          Text(
            'This will reset all serial configuration to factory defaults.',
            style: GoogleFonts.inter(
              fontSize: 12,
              color: cs.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: cs.error,
                side: BorderSide(color: cs.error.withOpacity(0.35)),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: _showResetDialog,
              icon: Icon(Icons.restart_alt_rounded, size: 18, color: cs.error),
              label: Text(
                'Reset to Defaults',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Helpers ──────────────────────────────────────────────────────────────────

  Widget _glassCard(ColorScheme cs, {required Widget child}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: cs.surfaceContainer.withOpacity(0.7),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: cs.primary.withOpacity(0.12),
              width: 1,
            ),
          ),
          child: child,
        ),
      ),
    );
  }

  Widget _sectionTitle(
    String title,
    IconData icon,
    Color color,
    ColorScheme cs,
  ) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 16),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: cs.onSurface,
          ),
        ),
      ],
    );
  }

  Widget _settingRow(
    ColorScheme cs, {
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Icon(icon, size: 14, color: cs.onSurfaceVariant),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: GoogleFonts.inter(
              color: cs.onSurfaceVariant,
              fontSize: 13,
            ),
          ),
        ),
        Text(
          value,
          style: GoogleFonts.inter(
            color: cs.primary,
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
        ),
      ],
    );
  }

  Widget _divider(ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Divider(height: 1, color: cs.outline.withOpacity(0.15)),
    );
  }

  // ─── Dialogs ──────────────────────────────────────────────────────────────────

  Future<void> _applyBaudRate(int baudRate) async {
    final reconnect = widget.viewModel.isConnected ? _reconnectOnBaudChange : false;
    final success = await widget.viewModel.updateUsbBaudRate(
      baudRate,
      reconnectIfConnected: reconnect,
    );
    if (!mounted) return;

    if (success) {
      setState(() => _selectedBaudRate = baudRate);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Baudrate set to $baudRate bps'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(widget.viewModel.lastError ?? 'Failed to set baudrate'),
        backgroundColor: Theme.of(context).colorScheme.error,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _showCustomBaudDialog() async {
    final cs = Theme.of(context).colorScheme;
    final controller = TextEditingController(text: '$_selectedBaudRate');

    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Custom Baudrate'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Enter baudrate from ${AppConstants.usbMinBaudRate} to ${AppConstants.usbMaxBaudRate}.',
              style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Baudrate',
                suffixText: 'bps',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final baudRate = int.tryParse(controller.text.trim());
              if (baudRate == null) return;
              Navigator.of(context).pop();
              await _applyBaudRate(baudRate);
            },
            child: const Text('Apply'),
          ),
        ],
      ),
    );
    controller.dispose();
  }

  Future<void> _showResetDialog() async {
    final cs = Theme.of(context).colorScheme;

    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset Settings'),
        content: const Text(
          'Reset all serial settings to factory defaults? This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: cs.error),
            onPressed: () async {
              final navigator = Navigator.of(context);
              final messenger = ScaffoldMessenger.of(context);

              await widget.settings.resetToDefaults();
              await widget.viewModel.updateUsbBaudRate(
                AppSettings.defaultUSBBaudRate,
                reconnectIfConnected: widget.viewModel.isConnected,
              );
              widget.settings.performanceMode = AppSettings.defaultPerformanceMode;

              if (!mounted) return;
              setState(() => _selectedBaudRate = AppSettings.defaultUSBBaudRate);
              navigator.pop();
              messenger.showSnackBar(
                const SnackBar(
                  content: Text('Settings reset to defaults'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            child: const Text('Reset'),
          ),
        ],
      ),
    );
  }
}
