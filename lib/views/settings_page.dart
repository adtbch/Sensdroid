import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:sensdroid/core/app_settings.dart';
import 'package:sensdroid/views/widgets/wifi_endpoint_config_dialog.dart';

/// Settings page untuk konfigurasi WiFi endpoint dan baud rate
class SettingsPage extends StatefulWidget {
  final AppSettings settings;

  const SettingsPage({
    super.key,
    required this.settings,
  });

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: const Text('Settings'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Text(
                    'Configuration',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      color: colorScheme.onSurface,
                      letterSpacing: -1,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Manage app settings and preferences',
                    style: TextStyle(
                      fontSize: 14,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // WiFi Settings Section
                  _buildSectionTitle('WiFi Settings', Icons.wifi_rounded, colorScheme),
                  const SizedBox(height: 12),
                  _buildGlassCard(
                    colorScheme,
                    child: _buildSettingItem(
                      colorScheme,
                      icon: Icons.dns_rounded,
                      title: 'Configure WiFi Endpoint',
                      subtitle: 'Set host, port, and endpoint path',
                      onTap: () => _showWiFiConfigDialog(context),
                    ),
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // USB Settings Section
                  _buildSectionTitle('USB Settings', Icons.usb_rounded, colorScheme),
                  const SizedBox(height: 12),
                  _buildGlassCard(
                    colorScheme,
                    child: _buildSettingItem(
                      colorScheme,
                      icon: Icons.speed_rounded,
                      title: 'USB Baud Rate',
                      subtitle: 'Current: ${widget.settings.usbBaudRate} bps',
                      onTap: () => _showBaudRateDialog(context),
                    ),
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // Performance Settings Section
                  _buildSectionTitle('Performance', Icons.flash_on, colorScheme),
                  const SizedBox(height: 12),
                  _buildGlassCard(
                    colorScheme,
                    child: _buildSettingItem(
                      colorScheme,
                      icon: widget.settings.performanceMode 
                          ? Icons.bolt_rounded 
                          : Icons.eco_rounded,
                      title: 'Performance Mode',
                      subtitle: widget.settings.performanceMode 
                          ? 'High Performance' 
                          : 'Battery Saver',
                      onTap: () => _togglePerformanceMode(),
                      trailing: Switch(
                        value: widget.settings.performanceMode,
                        onChanged: (value) => _togglePerformanceMode(),
                        activeColor: colorScheme.primary,
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // Current Settings Display
                  _buildSectionTitle('Current Settings', Icons.info_outline, colorScheme),
                  const SizedBox(height: 12),
                  _buildGlassCard(
                    colorScheme,
                    child: Column(
                      children: [
                        _buildSettingRow(colorScheme, 'Buffer Size', widget.settings.bufferSize.toString()),
                        Divider(color: colorScheme.outlineVariant.withOpacity(0.3)),
                        _buildSettingRow(colorScheme, 'Sampling Rate', '${widget.settings.samplingRate}ms'),
                        Divider(color: colorScheme.outlineVariant.withOpacity(0.3)),
                        _buildSettingRow(colorScheme, 'USB Baud Rate', '${widget.settings.usbBaudRate} bps'),
                        Divider(color: colorScheme.outlineVariant.withOpacity(0.3)),
                        _buildSettingRow(colorScheme, 'WiFi Endpoint', widget.settings.wifiEndpoint),
                        Divider(color: colorScheme.outlineVariant.withOpacity(0.3)),
                        _buildSettingRow(colorScheme, 'Performance Mode', widget.settings.performanceMode ? 'High' : 'Battery Saver'),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // Reset Settings
                  _buildSectionTitle('Danger Zone', Icons.warning_rounded, colorScheme),
                  const SizedBox(height: 12),
                  _buildGlassCard(
                    colorScheme,
                    child: _buildSettingItem(
                      colorScheme,
                      icon: Icons.refresh_rounded,
                      title: 'Reset to Defaults',
                      subtitle: 'Clear all custom settings',
                      onTap: () => _showResetDialog(context),
                      iconColor: colorScheme.error,
                    ),
                  ),
                  
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGlassCard(ColorScheme colorScheme, {required Widget child}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          decoration: BoxDecoration(
            color: colorScheme.surface.withOpacity(0.6),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: colorScheme.primary.withOpacity(0.2),
              width: 1,
            ),
          ),
          child: child,
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon, ColorScheme colorScheme) {
    return Row(
      children: [
        Icon(icon, color: colorScheme.primary, size: 20),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: colorScheme.onSurface,
          ),
        ),
      ],
    );
  }

  Widget _buildSettingItem(
    ColorScheme colorScheme, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Widget? trailing,
    Color? iconColor,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: (iconColor ?? colorScheme.primary).withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: iconColor ?? colorScheme.primary,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            if (trailing != null)
              trailing
            else
              Icon(
                Icons.chevron_right_rounded,
                color: colorScheme.onSurfaceVariant,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingRow(ColorScheme colorScheme, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: colorScheme.onSurface,
            ),
          ),
          Flexible(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 14,
                color: colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  void _showWiFiConfigDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return WiFiEndpointConfigDialog(
          settings: widget.settings,
        );
      },
    );
  }

  void _showBaudRateDialog(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: colorScheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(
              color: colorScheme.primary.withOpacity(0.2),
              width: 1,
            ),
          ),
          title: Row(
            children: [
              Icon(Icons.speed_rounded, color: colorScheme.primary),
              const SizedBox(width: 12),
              const Text('USB Baud Rate'),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Select baud rate for USB serial communication:',
                  style: TextStyle(
                    fontSize: 14,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),
                _buildBaudRateOption(context, 9600),
                _buildBaudRateOption(context, 19200),
                _buildBaudRateOption(context, 38400),
                _buildBaudRateOption(context, 57600),
                _buildBaudRateOption(context, 115200),
                _buildBaudRateOption(context, 230400),
                _buildBaudRateOption(context, 460800),
                _buildBaudRateOption(context, 921600),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildBaudRateOption(BuildContext context, int baudRate) {
    final colorScheme = Theme.of(context).colorScheme;
    final isSelected = widget.settings.usbBaudRate == baudRate;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isSelected 
            ? colorScheme.primary.withOpacity(0.15)
            : colorScheme.surfaceContainerHighest.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSelected 
              ? colorScheme.primary.withOpacity(0.5)
              : Colors.transparent,
          width: 1,
        ),
      ),
      child: ListTile(
        title: Text(
          '$baudRate bps',
          style: TextStyle(
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            color: isSelected ? colorScheme.primary : colorScheme.onSurface,
          ),
        ),
        trailing: isSelected 
            ? Icon(Icons.check_circle, color: colorScheme.primary)
            : null,
        onTap: () {
          setState(() {
            widget.settings.usbBaudRate = baudRate;
          });
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('USB baud rate set to $baudRate bps'),
              backgroundColor: colorScheme.primary,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          );
        },
      ),
    );
  }

  void _togglePerformanceMode() {
    final colorScheme = Theme.of(context).colorScheme;
    
    setState(() {
      widget.settings.performanceMode = !widget.settings.performanceMode;
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              widget.settings.performanceMode 
                  ? Icons.bolt_rounded 
                  : Icons.eco_rounded,
              color: Colors.white,
            ),
            const SizedBox(width: 12),
            Text(
              widget.settings.performanceMode 
                  ? 'Performance mode: High' 
                  : 'Performance mode: Battery Saver',
            ),
          ],
        ),
        backgroundColor: colorScheme.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  void _showResetDialog(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: colorScheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(
              color: colorScheme.error.withOpacity(0.3),
              width: 1,
            ),
          ),
          icon: Icon(
            Icons.warning_rounded,
            color: colorScheme.error,
            size: 48,
          ),
          title: const Text('Reset Settings'),
          content: Text(
            'Are you sure you want to reset all settings to default values? This action cannot be undone.',
            style: TextStyle(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                await widget.settings.resetToDefaults();
                if (!mounted) return;
                setState(() {});
                if (!mounted) return;
                final navigator = Navigator.of(context);
                final messenger = ScaffoldMessenger.of(context);
                navigator.pop();
                messenger.showSnackBar(
                  SnackBar(
                    content: const Row(
                      children: [
                        Icon(Icons.check_circle, color: Colors.white),
                        SizedBox(width: 12),
                        Text('Settings reset to defaults'),
                      ],
                    ),
                    backgroundColor: colorScheme.primary,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                );
              },
              style: FilledButton.styleFrom(
                backgroundColor: colorScheme.error,
              ),
              child: const Text('Reset'),
            ),
          ],
        );
      },
    );
  }
}
