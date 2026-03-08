import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:geolocator/geolocator.dart';
import 'package:sensdroid/core/app_constants.dart';
import 'package:sensdroid/viewmodels/sensor_viewmodel.dart';

class RawDataPage extends StatefulWidget {
  const RawDataPage({super.key});

  @override
  State<RawDataPage> createState() => _RawDataPageState();
}

class _RawDataPageState extends State<RawDataPage> {
  // Real-time sensor data
  AccelerometerEvent? _accelerometerData;
  GyroscopeEvent? _gyroscopeData;
  MagnetometerEvent? _magnetometerData;
  Position? _gpsData;

  // Subscriptions
  StreamSubscription<AccelerometerEvent>? _accelSub;
  StreamSubscription<GyroscopeEvent>? _gyroSub;
  StreamSubscription<MagnetometerEvent>? _magnetoSub;
  StreamSubscription<Position>? _gpsSub;

  bool _isPaused = false;

  @override
  void initState() {
    super.initState();
    _startListening();
  }

  @override
  void dispose() {
    _stopListening();
    super.dispose();
  }

  void _startListening() {
    final viewModel = context.read<SensorViewModel>();
    
    // Listen to accelerometer if enabled
    if (viewModel.enabledSensors[AppConstants.sensorAccelerometer] == true) {
      _accelSub = accelerometerEventStream().listen((event) {
        if (!_isPaused && mounted) {
          setState(() => _accelerometerData = event);
        }
      });
    }

    // Listen to gyroscope if enabled
    if (viewModel.enabledSensors[AppConstants.sensorGyroscope] == true) {
      _gyroSub = gyroscopeEventStream().listen((event) {
        if (!_isPaused && mounted) {
          setState(() => _gyroscopeData = event);
        }
      });
    }

    // Listen to magnetometer if enabled
    if (viewModel.enabledSensors[AppConstants.sensorMagnetometer] == true) {
      _magnetoSub = magnetometerEventStream().listen((event) {
        if (!_isPaused && mounted) {
          setState(() => _magnetometerData = event);
        }
      });
    }

    // Listen to GPS if enabled
    if (viewModel.enabledSensors[AppConstants.sensorGPS] == true) {
      _gpsSub = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.best,
          distanceFilter: 0,
        ),
      ).listen((position) {
        if (!_isPaused && mounted) {
          setState(() => _gpsData = position);
        }
      });
    }
  }

  void _stopListening() {
    _accelSub?.cancel();
    _gyroSub?.cancel();
    _magnetoSub?.cancel();
    _gpsSub?.cancel();
  }

  void _togglePause() {
    setState(() => _isPaused = !_isPaused);
  }

  void _resetData() {
    setState(() {
      _accelerometerData = null;
      _gyroscopeData = null;
      _magnetometerData = null;
      _gpsData = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final viewModel = context.watch<SensorViewModel>();

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(colorScheme),
                const SizedBox(height: 16),
                _buildControlButtons(colorScheme),
                const SizedBox(height: 24),
                if (!viewModel.isTransmitting)
                  _buildWarningBanner(colorScheme)
                else
                  _buildSensorDataCards(viewModel, colorScheme),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader(ColorScheme colorScheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.code_rounded, color: colorScheme.primary, size: 28),
            const SizedBox(width: 12),
            Text(
              'Raw Data',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w900,
                color: colorScheme.onSurface,
                letterSpacing: -1,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Real-time sensor values in raw format',
          style: TextStyle(
            fontSize: 14,
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildControlButtons(ColorScheme colorScheme) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _togglePause,
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            icon: Icon(_isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded),
            label: Text(_isPaused ? 'Resume' : 'Pause'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: FilledButton.icon(
            onPressed: _resetData,
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Reset'),
          ),
        ),
      ],
    );
  }

  Widget _buildWarningBanner(ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.errorContainer.withOpacity(0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.error.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: colorScheme.error, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Transmission not active. Start transmission from Dashboard to see live data.',
              style: TextStyle(
                color: colorScheme.onErrorContainer,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSensorDataCards(SensorViewModel viewModel, ColorScheme colorScheme) {
    return Column(
      children: [
        if (viewModel.enabledSensors[AppConstants.sensorAccelerometer] == true)
          _buildAccelerometerCard(colorScheme),
        if (viewModel.enabledSensors[AppConstants.sensorGyroscope] == true)
          _buildGyroscopeCard(colorScheme),
        if (viewModel.enabledSensors[AppConstants.sensorMagnetometer] == true)
          _buildMagnetometerCard(colorScheme),
        if (viewModel.enabledSensors[AppConstants.sensorGPS] == true)
          _buildGPSCard(colorScheme),
        if (viewModel.enabledSensors.values.every((e) => !e))
          _buildNoSensorsCard(colorScheme),
      ],
    );
  }

  Widget _buildAccelerometerCard(ColorScheme colorScheme) {
    return _buildDataCard(
      title: 'Accelerometer',
      icon: Icons.open_with_rounded,
      color: Colors.blue,
      colorScheme: colorScheme,
      data: _accelerometerData != null
          ? [
              DataRow(label: 'X', value: _accelerometerData!.x.toStringAsFixed(4), unit: 'm/s²'),
              DataRow(label: 'Y', value: _accelerometerData!.y.toStringAsFixed(4), unit: 'm/s²'),
              DataRow(label: 'Z', value: _accelerometerData!.z.toStringAsFixed(4), unit: 'm/s²'),
            ]
          : null,
    );
  }

  Widget _buildGyroscopeCard(ColorScheme colorScheme) {
    return _buildDataCard(
      title: 'Gyroscope',
      icon: Icons.threesixty_rounded,
      color: Colors.purple,
      colorScheme: colorScheme,
      data: _gyroscopeData != null
          ? [
              DataRow(label: 'X', value: _gyroscopeData!.x.toStringAsFixed(4), unit: 'rad/s'),
              DataRow(label: 'Y', value: _gyroscopeData!.y.toStringAsFixed(4), unit: 'rad/s'),
              DataRow(label: 'Z', value: _gyroscopeData!.z.toStringAsFixed(4), unit: 'rad/s'),
            ]
          : null,
    );
  }

  Widget _buildMagnetometerCard(ColorScheme colorScheme) {
    return _buildDataCard(
      title: 'Magnetometer',
      icon: Icons.explore_rounded,
      color: Colors.orange,
      colorScheme: colorScheme,
      data: _magnetometerData != null
          ? [
              DataRow(label: 'X', value: _magnetometerData!.x.toStringAsFixed(2), unit: 'µT'),
              DataRow(label: 'Y', value: _magnetometerData!.y.toStringAsFixed(2), unit: 'µT'),
              DataRow(label: 'Z', value: _magnetometerData!.z.toStringAsFixed(2), unit: 'µT'),
            ]
          : null,
    );
  }

  Widget _buildGPSCard(ColorScheme colorScheme) {
    return _buildDataCard(
      title: 'GPS Location',
      icon: Icons.pin_drop_rounded,
      color: Colors.green,
      colorScheme: colorScheme,
      data: _gpsData != null
          ? [
              DataRow(label: 'Latitude', value: _gpsData!.latitude.toStringAsFixed(6), unit: '°'),
              DataRow(label: 'Longitude', value: _gpsData!.longitude.toStringAsFixed(6), unit: '°'),
              DataRow(label: 'Altitude', value: _gpsData!.altitude.toStringAsFixed(2), unit: 'm'),
              DataRow(label: 'Speed', value: _gpsData!.speed.toStringAsFixed(2), unit: 'm/s'),
              DataRow(label: 'Accuracy', value: _gpsData!.accuracy.toStringAsFixed(2), unit: 'm'),
            ]
          : null,
    );
  }

  Widget _buildDataCard({
    required String title,
    required IconData icon,
    required Color color,
    required ColorScheme colorScheme,
    required List<DataRow>? data,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3), width: 2),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
              ),
              const Spacer(),
              if (!_isPaused)
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: Colors.green,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.green.withOpacity(0.5),
                        blurRadius: 8,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest.withOpacity(0.5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: data != null
                ? Column(
                    children: data
                        .map((row) => Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    row.label,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                  Row(
                                    children: [
                                      Text(
                                        row.value,
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: color,
                                          fontFamily: 'monospace',
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        row.unit,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: colorScheme.onSurfaceVariant,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ))
                        .toList(),
                  )
                : Center(
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text(
                        'Waiting for data...',
                        style: TextStyle(
                          fontSize: 13,
                          color: colorScheme.onSurfaceVariant,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoSensorsCard(ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withOpacity(0.5),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Icon(
            Icons.sensors_off_rounded,
            size: 64,
            color: colorScheme.onSurfaceVariant.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'No sensors enabled',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Go to Sensors tab to enable sensors',
            style: TextStyle(
              fontSize: 13,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class DataRow {
  final String label;
  final String value;
  final String unit;

  DataRow({required this.label, required this.value, required this.unit});
}
