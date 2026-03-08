import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sensdroid/core/app_constants.dart';
import 'package:sensdroid/viewmodels/sensor_viewmodel.dart';
import 'package:sensdroid/views/widgets/device_scan_dialog.dart';
import 'package:sensdroid/views/settings_page.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  String? _selectedDevice;
  final TextEditingController _wifiAddressController = TextEditingController();

  @override
  void dispose() {
    _wifiAddressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<SensorViewModel>(
      builder: (context, viewModel, child) {
        final colorScheme = Theme.of(context).colorScheme;
        
        return Scaffold(
          backgroundColor: colorScheme.surface,
          appBar: AppBar(
            title: const Text('Sensdroid'),
            actions: [
              IconButton(
                icon: const Icon(Icons.settings),
                onPressed: () {
                  final settings = viewModel.settings;
                  if (settings == null) return;
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => SettingsPage(settings: settings),
                    ),
                  );
                },
              ),
            ],
          ),
          body: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildWelcomeHeader(viewModel, colorScheme),
                      const SizedBox(height: 24),
                      _buildProtocolSelector(viewModel, colorScheme),
                      const SizedBox(height: 20),
                      _buildConnectionSection(viewModel, colorScheme),
                      const SizedBox(height: 20),
                      _buildSamplingRateControl(viewModel, colorScheme),
                      const SizedBox(height: 20),
                      if (viewModel.isConnected) ...[
                        _buildSensorOverview(viewModel, colorScheme),
                        const SizedBox(height: 20),
                      ],
                      _buildTransmissionControl(viewModel, colorScheme),
                      const SizedBox(height: 20),
                      _buildStatistics(viewModel, colorScheme),
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

  Widget _buildWelcomeHeader(SensorViewModel viewModel, ColorScheme colorScheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Dashboard',
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.w900,
            color: colorScheme.onSurface,
            letterSpacing: -1,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Manage connections and control data transmission',
          style: TextStyle(
            fontSize: 14,
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildProtocolSelector(SensorViewModel viewModel, ColorScheme colorScheme) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: colorScheme.surface.withOpacity(0.6),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: colorScheme.primary.withOpacity(0.2),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              _buildProtocolOption(
                viewModel,
                AppConstants.protocolBluetooth,
                Icons.bluetooth_rounded,
                'Bluetooth',
                colorScheme,
              ),
              _buildProtocolOption(
                viewModel,
                AppConstants.protocolUSB,
                Icons.usb_rounded,
                'USB',
                colorScheme,
              ),
              _buildProtocolOption(
                viewModel,
                AppConstants.protocolWiFi,
                Icons.wifi_rounded,
                'WiFi',
                colorScheme,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProtocolOption(
    SensorViewModel viewModel,
    String protocol,
    IconData icon,
    String label,
    ColorScheme colorScheme,
  ) {
    final isSelected = viewModel.activeProtocol == protocol;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          viewModel.switchProtocol(protocol);
          setState(() => _selectedDevice = null);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? colorScheme.surface : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    )
                  ]
                : [],
          ),
          child: Column(
            children: [
              Icon(
                icon,
                color: isSelected ? colorScheme.primary : colorScheme.onSurfaceVariant,
                size: 24,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected ? colorScheme.primary : colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildConnectionSection(SensorViewModel viewModel, ColorScheme colorScheme) {
    final isConnected = viewModel.isConnected;
    
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: colorScheme.surface.withOpacity(0.6),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: colorScheme.primary.withOpacity(0.2),
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.hub_outlined, color: colorScheme.primary, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Connection',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                  _buildStatusBadge(viewModel, colorScheme),
                ],
              ),
              if (viewModel.lastError != null && !isConnected && !viewModel.isConnecting) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colorScheme.errorContainer.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline_rounded, color: colorScheme.error, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          viewModel.lastError!,
                          style: TextStyle(color: colorScheme.onErrorContainer, fontSize: 13),
                        ),
                      ),
                      InkWell(
                        onTap: () => viewModel.clearError(),
                        child: Icon(Icons.close, size: 18, color: colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 16),
              if (isConnected)
                _buildConnectedState(viewModel, colorScheme)
              else if (viewModel.activeProtocol == AppConstants.protocolWiFi)
                _buildWiFiInput(viewModel, colorScheme)
              else
                _buildDeviceScanner(viewModel, colorScheme),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(SensorViewModel viewModel, ColorScheme colorScheme) {
    Color color;
    String text;
    IconData icon;

    if (viewModel.isConnecting) {
      color = colorScheme.tertiary;
      text = 'Connecting';
      icon = Icons.sync_rounded;
    } else if (viewModel.isConnected) {
      color = Colors.green;
      text = 'Connected';
      icon = Icons.check_circle_rounded;
    } else {
      color = colorScheme.outline;
      text = 'Offline';
      icon = Icons.cloud_off_rounded;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            text.toUpperCase(),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConnectedState(SensorViewModel viewModel, ColorScheme colorScheme) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colorScheme.primaryContainer.withOpacity(0.3),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: colorScheme.surface,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.devices_rounded, color: colorScheme.primary),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      viewModel.connectionInfo?.deviceName ?? 'Unknown Device',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    Text(
                      viewModel.connectionInfo?.address ?? '',
                      style: TextStyle(
                        color: colorScheme.onSurfaceVariant,
                        fontSize: 12,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () => viewModel.disconnect(),
            style: OutlinedButton.styleFrom(
              foregroundColor: colorScheme.error,
              side: BorderSide(color: colorScheme.error.withOpacity(0.5)),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            icon: const Icon(Icons.link_off_rounded),
            label: const Text('Disconnect'),
          ),
        ),
      ],
    );
  }

  Widget _buildWiFiInput(SensorViewModel viewModel, ColorScheme colorScheme) {
    return Column(
      children: [
        TextField(
          controller: _wifiAddressController,
          decoration: InputDecoration(
            labelText: 'IP Address : Port',
            hintText: '192.168.1.100:8080',
            prefixIcon: const Icon(Icons.wifi_tethering_rounded),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            filled: true,
            fillColor: colorScheme.surfaceContainerHighest.withOpacity(0.3),
          ),
          keyboardType: TextInputType.url,
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: () {
              final address = _wifiAddressController.text.trim();
              if (address.isNotEmpty) {
                viewModel.connect(address);
              }
            },
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            icon: const Icon(Icons.link_rounded),
            label: const Text('Connect'),
          ),
        ),
      ],
    );
  }

  Widget _buildDeviceScanner(SensorViewModel viewModel, ColorScheme colorScheme) {
    return Column(
      children: [
        if (_selectedDevice != null)
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: colorScheme.secondaryContainer.withOpacity(0.4),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: colorScheme.secondary.withOpacity(0.2)),
            ),
            child: Row(
              children: [
                Icon(Icons.smartphone_rounded, color: colorScheme.secondary),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _selectedDevice!.split('||').first,
                    style: TextStyle(fontWeight: FontWeight.w600, color: colorScheme.onSecondaryContainer),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 20),
                  onPressed: () => setState(() => _selectedDevice = null),
                  color: colorScheme.onSecondaryContainer,
                ),
              ],
            ),
          ),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: () async {
              final device = await showDialog<String>(
                context: context,
                builder: (context) => DeviceScanDialog(
                  onScan: () => viewModel.scanDevices(),
                  protocolType: viewModel.activeProtocol,
                ),
              );
              if (device != null) {
                setState(() => _selectedDevice = device);
                viewModel.connect(device);
              }
            },
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            icon: const Icon(Icons.search_rounded),
            label: const Text('Scan Devices'),
          ),
        ),
      ],
    );
  }

  Widget _buildSensorOverview(SensorViewModel viewModel, ColorScheme colorScheme) {
    final activeSensors = viewModel.enabledSensors.entries.where((e) => e.value).length;
    
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                colorScheme.tertiaryContainer.withOpacity(0.3),
                colorScheme.primaryContainer.withOpacity(0.2),
              ],
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: colorScheme.primary.withOpacity(0.2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.sensors_rounded, color: colorScheme.tertiary, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Active Sensors',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: colorScheme.tertiary.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '$activeSensors / ${viewModel.enabledSensors.length}',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: colorScheme.tertiary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: viewModel.enabledSensors.entries.map((entry) {
                  final isActive = entry.value;
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: isActive 
                          ? colorScheme.primary.withOpacity(0.15) 
                          : colorScheme.surfaceContainerHighest.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isActive 
                            ? colorScheme.primary.withOpacity(0.3) 
                            : colorScheme.outline.withOpacity(0.2),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _getSensorIcon(entry.key),
                          size: 16,
                          color: isActive ? colorScheme.primary : colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _getSensorName(entry.key),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                            color: isActive ? colorScheme.primary : colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSamplingRateControl(SensorViewModel viewModel, ColorScheme colorScheme) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: colorScheme.surface.withOpacity(0.6),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: colorScheme.secondary.withOpacity(0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.speed_rounded, color: colorScheme.secondary, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Sampling Rate',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: colorScheme.secondaryContainer.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${viewModel.samplingRate} ms',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: colorScheme.secondary,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Text(
                    '0 ms',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  Expanded(
                    child: SliderTheme(
                      data: SliderThemeData(
                        activeTrackColor: colorScheme.secondary,
                        inactiveTrackColor: colorScheme.surfaceContainerHighest,
                        thumbColor: colorScheme.secondary,
                        overlayColor: colorScheme.secondary.withOpacity(0.2),
                        trackHeight: 4,
                      ),
                      child: Slider(
                        value: viewModel.samplingRate.toDouble(),
                        min: 0,
                        max: 100,
                        divisions: 100,
                        onChanged: viewModel.isTransmitting 
                            ? null 
                            : (value) => viewModel.updateSamplingRate(value.toInt()),
                      ),
                    ),
                  ),
                  Text(
                    '100 ms',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: colorScheme.secondaryContainer.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.flash_on, color: colorScheme.secondary, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      viewModel.samplingRate > 0 
                          ? 'Frequency: ${(1000 / viewModel.samplingRate).toStringAsFixed(1)} Hz'
                          : 'Frequency: ∞ Hz (Max)',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
              if (viewModel.isTransmitting) ...[
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.lock_rounded, size: 14, color: colorScheme.onSurfaceVariant),
                    const SizedBox(width: 4),
                    Text(
                      'Locked during transmission',
                      style: TextStyle(
                        fontSize: 11,
                        color: colorScheme.onSurfaceVariant,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  IconData _getSensorIcon(String sensorType) {
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
        return Icons.sensors;
    }
  }

  String _getSensorName(String sensorType) {
    switch (sensorType) {
      case AppConstants.sensorAccelerometer:
        return 'Accel';
      case AppConstants.sensorGyroscope:
        return 'Gyro';
      case AppConstants.sensorMagnetometer:
        return 'Mag';
      case AppConstants.sensorGPS:
        return 'GPS';
      default:
        return sensorType;
    }
  }

  Widget _buildTransmissionControl(SensorViewModel viewModel, ColorScheme colorScheme) {
    if (!viewModel.isConnected) return const SizedBox.shrink();

    final isTransmitting = viewModel.isTransmitting;
    final canStart = viewModel.enabledSensors.values.any((e) => e);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      child: SizedBox(
        width: double.infinity,
        height: 64,
        child: isTransmitting
            ? FilledButton.icon(
                onPressed: () => viewModel.stopTransmission(),
                style: FilledButton.styleFrom(
                  backgroundColor: colorScheme.error,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 4,
                  shadowColor: colorScheme.error.withOpacity(0.4),
                ),
                icon: const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                ),
                label: const Text(
                  'STOP TRANSMITTING',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              )
            : FilledButton.icon(
                onPressed: canStart ? () => viewModel.startTransmission() : null,
                style: FilledButton.styleFrom(
                  backgroundColor: colorScheme.primary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 4,
                  shadowColor: colorScheme.primary.withOpacity(0.4),
                ),
                icon: const Icon(Icons.rocket_launch_rounded, size: 24),
                label: const Text(
                  'START TRANSMISSION',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
      ),
    );
  }

  Widget _buildStatistics(SensorViewModel viewModel, ColorScheme colorScheme) {
    if (!viewModel.isTransmitting && viewModel.packetsSent == 0) return const SizedBox.shrink();

    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                colorScheme.primaryContainer.withOpacity(0.3),
                colorScheme.secondaryContainer.withOpacity(0.3),
              ],
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: colorScheme.primary.withOpacity(0.2)),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Icon(Icons.analytics_outlined, color: colorScheme.primary, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Live Statistics',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  const Spacer(),
                  if (viewModel.isTransmitting)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Text(
                            'LIVE',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: _buildStatItem(
                      'SENT',
                      '${viewModel.packetsSent}',
                      Icons.upload_rounded,
                      colorScheme.primary,
                      colorScheme,
                    ),
                  ),
                  Container(width: 1, height: 50, color: colorScheme.outlineVariant.withOpacity(0.5)),
                  Expanded(
                    child: _buildStatItem(
                      'DROPPED',
                      '${viewModel.packetsDropped}',
                      Icons.warning_rounded,
                      viewModel.packetsDropped > 0 ? colorScheme.error : colorScheme.onSurfaceVariant,
                      colorScheme,
                    ),
                  ),
                  Container(width: 1, height: 50, color: colorScheme.outlineVariant.withOpacity(0.5)),
                  Expanded(
                    child: _buildStatItem(
                      'RATE',
                      '${viewModel.transmissionRate.toStringAsFixed(1)} Hz',
                      Icons.speed_rounded,
                      colorScheme.tertiary,
                      colorScheme,
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

  Widget _buildStatItem(String label, String value, IconData icon, Color color, ColorScheme colorScheme) {
    return Column(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: colorScheme.onSurfaceVariant.withOpacity(0.7),
            letterSpacing: 1,
          ),
        ),
      ],
    );
  }
}
