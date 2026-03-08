import 'package:flutter/material.dart';
import 'package:sensdroid/views/settings_page.dart';
import 'package:provider/provider.dart';
import 'package:sensdroid/viewmodels/sensor_viewmodel.dart';
import 'package:sensdroid/core/app_constants.dart';
import 'package:sensdroid/views/widgets/device_scan_dialog.dart';

/// Main home page - provides UI for sensor selection, protocol switching,
/// and transmission control
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String? _selectedDevice;
  final TextEditingController _wifiAddressController = TextEditingController();

  @override
  void dispose() {
    _wifiAddressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sensdroid'),
        elevation: 2,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              final settings = context.read<SensorViewModel>().settings;
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
      body: SafeArea(
        child: Consumer<SensorViewModel>(
          builder: (context, viewModel, child) {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Protocol Selection
                  _buildProtocolSelector(viewModel),
                  const SizedBox(height: 24),
                  
                  // Connection Section
                  _buildConnectionSection(viewModel),
                  const SizedBox(height: 24),
                  
                  // Sensor Selection
                  _buildSensorSelection(viewModel),
                  const SizedBox(height: 24),
                  
                  // Sampling Rate Control
                  _buildSamplingRateControl(viewModel),
                  const SizedBox(height: 24),
                  
                  // Transmission Control
                  _buildTransmissionControl(viewModel),
                  const SizedBox(height: 24),
                  
                  // Statistics
                  _buildStatistics(viewModel),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildProtocolSelector(SensorViewModel viewModel) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Communication Protocol',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(
                  value: AppConstants.protocolBluetooth,
                  label: Text('Bluetooth'),
                  icon: Icon(Icons.bluetooth),
                ),
                ButtonSegment(
                  value: AppConstants.protocolUSB,
                  label: Text('USB'),
                  icon: Icon(Icons.usb),
                ),
                ButtonSegment(
                  value: AppConstants.protocolWiFi,
                  label: Text('WiFi'),
                  icon: Icon(Icons.wifi),
                ),
              ],
              selected: {viewModel.activeProtocol},
              onSelectionChanged: (Set<String> selection) {
                viewModel.switchProtocol(selection.first);
                _selectedDevice = null;
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConnectionSection(SensorViewModel viewModel) {
    final theme = Theme.of(context);
    final connectionInfo = viewModel.connectionInfo;
    final isConnected = viewModel.isConnected;
    final isConnecting = viewModel.isConnecting;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.settings_input_antenna,
                  color: theme.colorScheme.primary,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Text(
                  'CONNECTION',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const Spacer(),
                _buildConnectionBadge(theme, isConnected, isConnecting),
              ],
            ),
            const SizedBox(height: 16),

            // Error message banner
            if (viewModel.lastError != null && !isConnected && !isConnecting)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: theme.colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: theme.colorScheme.error.withOpacity(0.5),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.error_outline,
                      color: theme.colorScheme.error,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        viewModel.lastError!,
                        style: TextStyle(
                          color: theme.colorScheme.onErrorContainer,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => viewModel.clearError(),
                      child: Icon(
                        Icons.close,
                        size: 16,
                        color: theme.colorScheme.error,
                      ),
                    ),
                  ],
                ),
              ),
            
            if (viewModel.activeProtocol == AppConstants.protocolWiFi)
              _buildWiFiInput(viewModel)
            else
              _buildDeviceScanner(viewModel),
            
            if (isConnected) ...[  
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: theme.colorScheme.primary.withOpacity(0.3),
                  ),
                ),
                child: Column(
                  children: [
                    _buildInfoRow(theme, Icons.device_hub,
                        'DEVICE', connectionInfo?.deviceName ?? 'Unknown'),
                    const SizedBox(height: 6),
                    _buildInfoRow(theme, Icons.tag,
                        'ADDRESS', connectionInfo?.address ?? 'Unknown'),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => viewModel.disconnect(),
                  icon: const Icon(Icons.link_off, size: 18),
                  label: const Text('DISCONNECT'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    side: BorderSide(
                      color: theme.colorScheme.error.withOpacity(0.6),
                    ),
                    foregroundColor: theme.colorScheme.error,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildConnectionBadge(ThemeData theme, bool isConnected, bool isConnecting) {
    if (isConnecting) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: theme.colorScheme.secondary.withOpacity(0.2),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: theme.colorScheme.secondary.withOpacity(0.5)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 10,
              height: 10,
              child: CircularProgressIndicator(
                strokeWidth: 1.5,
                valueColor: AlwaysStoppedAnimation(theme.colorScheme.secondary),
              ),
            ),
            const SizedBox(width: 6),
            Text(
              'CONNECTING',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
                color: theme.colorScheme.secondary,
              ),
            ),
          ],
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isConnected
            ? theme.colorScheme.primary.withOpacity(0.2)
            : theme.colorScheme.onSurface.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isConnected
              ? theme.colorScheme.primary.withOpacity(0.5)
              : theme.colorScheme.onSurface.withOpacity(0.2),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isConnected
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurface.withOpacity(0.3),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            isConnected ? 'CONNECTED' : 'DISCONNECTED',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
              color: isConnected
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurface.withOpacity(0.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(ThemeData theme, IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 14, color: theme.colorScheme.primary.withOpacity(0.7)),
        const SizedBox(width: 6),
        Text(
          '$label: ',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            letterSpacing: 1,
            color: theme.colorScheme.onSurface.withOpacity(0.5),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildWiFiInput(SensorViewModel viewModel) {
    final theme = Theme.of(context);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _wifiAddressController,
          style: const TextStyle(fontWeight: FontWeight.w500),
          decoration: InputDecoration(
            labelText: 'IP ADDRESS : PORT',
            labelStyle: TextStyle(
              letterSpacing: 1.5,
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.primary,
            ),
            hintText: '192.168.1.100:8080',
            helperText: 'Enter IP address and port of target device',
            helperMaxLines: 2,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: theme.colorScheme.primary),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: theme.colorScheme.onSurface.withOpacity(0.3),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: theme.colorScheme.primary, width: 2),
            ),
            prefixIcon: Icon(Icons.computer, color: theme.colorScheme.primary),
          ),
          keyboardType: TextInputType.url,
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () async {
              final address = _wifiAddressController.text.trim();
              if (address.isNotEmpty) {
                final success = await viewModel.connect(address);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Row(
                        children: [
                          Icon(
                            success ? Icons.check_circle : Icons.error_outline,
                            color: Colors.white,
                            size: 18,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              success
                                  ? 'Connected to $address'
                                  : viewModel.lastError ?? 'Connection failed',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      backgroundColor: success
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.error,
                      duration: const Duration(seconds: 3),
                    ),
                  );
                }
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Row(
                      children: [
                        Icon(Icons.error_outline, color: Colors.white),
                        SizedBox(width: 12),
                        Text('Please enter IP address'),
                      ],
                    ),
                    backgroundColor: Theme.of(context).colorScheme.error,
                  ),
                );
              }
            },
            icon: const Icon(Icons.link),
            label: const Text('CONNECT'),
          ),
        ),
      ],
    );
  }

  Widget _buildDeviceScanner(SensorViewModel viewModel) {
    final theme = Theme.of(context);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: _selectedDevice != null
                  ? theme.colorScheme.primary.withOpacity(0.5)
                  : theme.colorScheme.onSurface.withOpacity(0.3),
              width: _selectedDevice != null ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                _selectedDevice != null ? Icons.check_circle : Icons.device_hub,
                color: _selectedDevice != null
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurface.withOpacity(0.5),
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _selectedDevice != null ? 'SELECTED DEVICE' : 'NO DEVICE',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                        color: _selectedDevice != null
                            ? theme.colorScheme.primary
                            : theme.colorScheme.onSurface.withOpacity(0.5),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      // Decode "Name||address" format — show only name in card
                      _selectedDevice != null
                          ? (_selectedDevice!.contains('||')
                              ? _selectedDevice!.split('||').first
                              : _selectedDevice!)
                          : 'Tap scan to discover devices',
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: 14,
                        color: _selectedDevice != null
                            ? theme.colorScheme.onSurface
                            : theme.colorScheme.onSurface.withOpacity(0.5),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (_selectedDevice != null &&
                        _selectedDevice!.contains('||'))
                      Text(
                        _selectedDevice!.split('||').last,
                        style: TextStyle(
                          fontSize: 11,
                          fontFamily: 'monospace',
                          color:
                              theme.colorScheme.onSurface.withOpacity(0.45),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              flex: 2,
              child: ElevatedButton.icon(
                onPressed: () async {
                  final selectedDevice = await showDialog<String>(
                    context: context,
                    barrierDismissible: false,
                    builder: (context) => DeviceScanDialog(
                      onScan: () => viewModel.scanDevices(),
                      protocolType: viewModel.activeProtocol,
                    ),
                  );
                  
                  if (selectedDevice != null && mounted) {
                    setState(() {
                      _selectedDevice = selectedDevice;
                    });
                    final success = await viewModel.connect(selectedDevice);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Row(
                            children: [
                              Icon(
                                success ? Icons.check_circle : Icons.error_outline,
                                color: Colors.white,
                                size: 18,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  success
                                      ? 'Connected to $selectedDevice'
                                      : viewModel.lastError ?? 'Connection failed',
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          backgroundColor: success
                              ? theme.colorScheme.primary
                              : theme.colorScheme.error,
                          duration: const Duration(seconds: 3),
                        ),
                      );
                    }
                  }
                },
                icon: const Icon(Icons.search, size: 20),
                label: const Text('SCAN DEVICES'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
            if (_selectedDevice != null) ...[
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    setState(() {
                      _selectedDevice = null;
                    });
                  },
                  icon: const Icon(Icons.clear, size: 18),
                  label: const Text('CLEAR'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: BorderSide(
                      color: theme.colorScheme.error.withOpacity(0.5),
                    ),
                    foregroundColor: theme.colorScheme.error,
                  ),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildSensorSelection(SensorViewModel viewModel) {
    final theme = Theme.of(context);
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.sensors, color: theme.colorScheme.primary, size: 18),
                const SizedBox(width: 8),
                Text(
                  'SENSOR SELECTION',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const Spacer(),
                if (!viewModel.isSensorDetectionComplete)
                  Row(
                    children: [
                      SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(
                          strokeWidth: 1.5,
                          valueColor: AlwaysStoppedAnimation(
                            theme.colorScheme.secondary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'DETECTING...',
                        style: TextStyle(
                          fontSize: 10,
                          letterSpacing: 1,
                          color: theme.colorScheme.secondary,
                        ),
                      ),
                    ],
                  )
                else
                  Row(
                    children: [
                      Text(
                        '${viewModel.availableSensors.values.where((v) => v).length}/${viewModel.availableSensors.length} AVAILABLE',
                        style: TextStyle(
                          fontSize: 10,
                          letterSpacing: 1,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onSurface.withOpacity(0.5),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Re-detect button — useful after granting permissions
                      GestureDetector(
                        onTap: () => viewModel.redetectSensors(),
                        child: Icon(
                          Icons.refresh,
                          size: 16,
                          color: theme.colorScheme.secondary,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 12),
            ...viewModel.enabledSensors.entries.map((entry) {
              final isAvailable = viewModel.availableSensors[entry.key] ?? false;
              final isDetectionDone = viewModel.isSensorDetectionComplete;
              return _buildSensorTile(
                theme: theme,
                sensorKey: entry.key,
                isEnabled: entry.value,
                isAvailable: isAvailable,
                isDetecting: !isDetectionDone,
                isTransmitting: viewModel.isTransmitting,
                onChanged: (value) =>
                    viewModel.toggleSensor(entry.key, value ?? false),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildSensorTile({
    required ThemeData theme,
    required String sensorKey,
    required bool isEnabled,
    required bool isAvailable,
    required bool isDetecting,
    required bool isTransmitting,
    required ValueChanged<bool?> onChanged,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isEnabled
            ? theme.colorScheme.primary.withOpacity(0.08)
            : theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isEnabled
              ? theme.colorScheme.primary.withOpacity(0.4)
              : theme.colorScheme.onSurface.withOpacity(0.1),
          width: isEnabled ? 1.5 : 1,
        ),
      ),
      child: CheckboxListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        title: Row(
          children: [
            Text(
              _getSensorDisplayName(sensorKey),
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: !isAvailable && !isDetecting
                    ? theme.colorScheme.onSurface.withOpacity(0.4)
                    : null,
              ),
            ),
            const SizedBox(width: 8),
            _buildAvailabilityBadge(theme, isAvailable, isDetecting),
          ],
        ),
        subtitle: Text(
          _getSensorDescription(sensorKey),
          style: TextStyle(
            fontSize: 12,
            color: !isAvailable && !isDetecting
                ? theme.colorScheme.onSurface.withOpacity(0.3)
                : theme.colorScheme.onSurface.withOpacity(0.6),
          ),
        ),
        value: isEnabled,
        onChanged: (isTransmitting || (!isAvailable && !isDetecting))
            ? null
            : onChanged,
        activeColor: theme.colorScheme.primary,
        checkColor: theme.colorScheme.onPrimary,
      ),
    );
  }

  Widget _buildAvailabilityBadge(ThemeData theme, bool isAvailable, bool isDetecting) {
    if (isDetecting) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: theme.colorScheme.secondary.withOpacity(0.15),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          'DETECTING',
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
            color: theme.colorScheme.secondary,
          ),
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: isAvailable
            ? theme.colorScheme.primary.withOpacity(0.15)
            : theme.colorScheme.error.withOpacity(0.15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        isAvailable ? 'AVAILABLE' : 'NOT FOUND',
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
          color: isAvailable
              ? theme.colorScheme.primary
              : theme.colorScheme.error,
        ),
      ),
    );
  }

  Widget _buildSamplingRateControl(SensorViewModel viewModel) {
    final theme = Theme.of(context);
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.speed, color: theme.colorScheme.primary, size: 20),
                const SizedBox(width: 8),
                Text(
                  'SAMPLING RATE',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    theme.colorScheme.primary.withOpacity(0.2),
                    theme.colorScheme.secondary.withOpacity(0.1),
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: theme.colorScheme.primary,
                  width: 2,
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'FIXED - MINIMUM LATENCY',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 2,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Icon(
                              Icons.flash_on,
                              color: theme.colorScheme.primary,
                              size: 32,
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${viewModel.samplingRate} ms',
                                  style: TextStyle(
                                    fontSize: 28,
                                    fontWeight: FontWeight.bold,
                                    color: theme.colorScheme.onSurface,
                                  ),
                                ),
                                Text(
                                  viewModel.samplingRate > 0
                                      ? '${(1000 / viewModel.samplingRate).toStringAsFixed(1)} Hz'
                                      : '∞ Hz',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                    color: theme.colorScheme.onSurface.withOpacity(0.7),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: theme.colorScheme.primary.withOpacity(0.5),
                        width: 1,
                      ),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          Icons.lock,
                          color: theme.colorScheme.primary,
                          size: 24,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'LOCKED',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.5,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTransmissionControl(SensorViewModel viewModel) {
    final theme = Theme.of(context);
    final canStart = viewModel.isConnected &&
        viewModel.enabledSensors.values.any((enabled) => enabled);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  Icons.send,
                  color: theme.colorScheme.primary,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Text(
                  'TRANSMISSION CONTROL',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (!canStart && !viewModel.isTransmitting) ...[  
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: theme.colorScheme.onSurface.withOpacity(0.1),
                  ),
                ),
                child: Text(
                  !viewModel.isConnected
                      ? '⚠  Connect to a device first'
                      : '⚠  Enable at least one sensor',
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.onSurface.withOpacity(0.5),
                  ),
                ),
              ),
            ],
            if (viewModel.isTransmitting)
              ElevatedButton.icon(
                onPressed: () => viewModel.stopTransmission(),
                icon: const Icon(Icons.stop, size: 20),
                label: const Text('STOP TRANSMISSION'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.error,
                  foregroundColor: theme.colorScheme.onError,
                  padding: const EdgeInsets.all(16),
                ),
              )
            else
              ElevatedButton.icon(
                onPressed: canStart
                    ? () async {
                        try {
                          await viewModel.startTransmission();
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Row(
                                  children: [
                                    const Icon(
                                      Icons.error_outline,
                                      color: Colors.white,
                                      size: 18,
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        e.toString().replaceFirst('Exception: ', ''),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                                backgroundColor: theme.colorScheme.error,
                                duration: const Duration(seconds: 4),
                              ),
                            );
                          }
                        }
                      }
                    : null,
                icon: const Icon(Icons.play_arrow, size: 20),
                label: const Text('START TRANSMISSION'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: theme.colorScheme.onPrimary,
                  padding: const EdgeInsets.all(16),
                  disabledBackgroundColor:
                      theme.colorScheme.onSurface.withOpacity(0.12),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatistics(SensorViewModel viewModel) {
    final theme = Theme.of(context);
    final isActive = viewModel.isTransmitting ||
        viewModel.packetsSent > 0 ||
        viewModel.packetsDropped > 0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.bar_chart, color: theme.colorScheme.primary, size: 18),
                const SizedBox(width: 8),
                Text(
                  'STATISTICS',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const Spacer(),
                if (viewModel.isTransmitting)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          'LIVE',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    theme,
                    Icons.upload,
                    'SENT',
                    '${viewModel.packetsSent}',
                    'packets',
                    theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildStatCard(
                    theme,
                    Icons.warning_amber_rounded,
                    'DROPPED',
                    '${viewModel.packetsDropped}',
                    'packets',
                    viewModel.packetsDropped > 0
                        ? theme.colorScheme.error
                        : theme.colorScheme.onSurface.withOpacity(0.3),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildStatCard(
                    theme,
                    Icons.speed,
                    'RATE',
                    viewModel.transmissionRate.toStringAsFixed(1),
                    'pkt/s',
                    theme.colorScheme.secondary,
                  ),
                ),
              ],
            ),
            if (viewModel.transmissionDuration != null) ...[  
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: theme.colorScheme.onSurface.withOpacity(0.1),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.timer_outlined,
                      size: 16,
                      color: theme.colorScheme.secondary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'ELAPSED  ',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2,
                        color: theme.colorScheme.onSurface.withOpacity(0.5),
                      ),
                    ),
                    Text(
                      _formatDuration(viewModel.transmissionDuration!),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.secondary,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (!isActive)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Statistics will appear during transmission',
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.onSurface.withOpacity(0.4),
                    fontStyle: FontStyle.italic,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(
    ThemeData theme,
    IconData icon,
    String label,
    String value,
    String unit,
    Color accentColor,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: accentColor.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: accentColor.withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: accentColor),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                  color: accentColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface,
            ),
          ),
          Text(
            unit,
            style: TextStyle(
              fontSize: 10,
              color: theme.colorScheme.onSurface.withOpacity(0.5),
            ),
          ),
        ],
      ),
    );
  }

  String _getSensorDisplayName(String sensorType) {
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

  String _getSensorDescription(String sensorType) {
    switch (sensorType) {
      case AppConstants.sensorAccelerometer:
        return 'Linear acceleration (m/s²)';
      case AppConstants.sensorGyroscope:
        return 'Rotation rate (rad/s)';
      case AppConstants.sensorMagnetometer:
        return 'Magnetic field (µT)';
      case AppConstants.sensorGPS:
        return 'Location (lat, lon, alt, speed)';
      default:
        return '';
    }
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '${minutes}m ${seconds}s';
  }
}
