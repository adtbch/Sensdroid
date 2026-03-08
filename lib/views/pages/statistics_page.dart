import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:geolocator/geolocator.dart';
import 'package:sensdroid/core/app_constants.dart';
import 'package:sensdroid/viewmodels/sensor_viewmodel.dart';
import 'package:sensdroid/views/settings_page.dart';

class StatisticsPage extends StatefulWidget {
  const StatisticsPage({super.key});

  @override
  State<StatisticsPage> createState() => _StatisticsPageState();
}

class _StatisticsPageState extends State<StatisticsPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

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
    _tabController = TabController(length: 2, vsync: this);
    _startListening();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _stopListening();
    super.dispose();
  }

  void _startListening() {
    final viewModel = context.read<SensorViewModel>();

    if (viewModel.enabledSensors[AppConstants.sensorAccelerometer] == true) {
      _accelSub = accelerometerEventStream().listen((event) {
        if (!_isPaused && mounted) {
          setState(() => _accelerometerData = event);
        }
      });
    }

    if (viewModel.enabledSensors[AppConstants.sensorGyroscope] == true) {
      _gyroSub = gyroscopeEventStream().listen((event) {
        if (!_isPaused && mounted) {
          setState(() => _gyroscopeData = event);
        }
      });
    }

    if (viewModel.enabledSensors[AppConstants.sensorMagnetometer] == true) {
      _magnetoSub = magnetometerEventStream().listen((event) {
        if (!_isPaused && mounted) {
          setState(() => _magnetometerData = event);
        }
      });
    }

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
            bottom: TabBar(
              controller: _tabController,
              indicatorColor: colorScheme.primary,
              labelColor: colorScheme.primary,
              unselectedLabelColor: colorScheme.onSurface.withOpacity(0.6),
              tabs: const [
                Tab(icon: Icon(Icons.bar_chart), text: 'Statistics'),
                Tab(icon: Icon(Icons.sensors), text: 'Raw Data'),
              ],
            ),
          ),
          body: TabBarView(
            controller: _tabController,
            children: [
              _buildStatisticsTab(viewModel, colorScheme),
              _buildRawDataTab(viewModel, colorScheme),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatisticsTab(
      SensorViewModel viewModel, ColorScheme colorScheme) {
    final isTransmitting = viewModel.isTransmitting;

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildGlassCard(
                  colorScheme,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.analytics, color: colorScheme.primary),
                          const SizedBox(width: 12),
                          Text(
                            'Transmission Statistics',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: colorScheme.onSurface,
                            ),
                          ),
                          const Spacer(),
                          if (isTransmitting)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: colorScheme.primary.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: colorScheme.primary.withOpacity(0.5),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: colorScheme.primary,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'LIVE',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: colorScheme.primary,
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
                            child: _buildStatCard(
                              colorScheme,
                              icon: Icons.upload_rounded,
                              label: 'SENT',
                              value: '${viewModel.packetsSent}',
                              unit: 'packets',
                              color: colorScheme.primary,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildStatCard(
                              colorScheme,
                              icon: Icons.warning_rounded,
                              label: 'DROPPED',
                              value: '${viewModel.packetsDropped}',
                              unit: 'packets',
                              color: viewModel.packetsDropped > 0
                                  ? colorScheme.error
                                  : colorScheme.onSurface.withOpacity(0.3),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _buildStatCard(
                              colorScheme,
                              icon: Icons.speed_rounded,
                              label: 'RATE',
                              value:
                                  viewModel.transmissionRate.toStringAsFixed(1),
                              unit: 'pkt/s',
                              color: colorScheme.secondary,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildStatCard(
                              colorScheme,
                              icon: Icons.timer_outlined,
                              label: 'DURATION',
                              value: viewModel.transmissionDuration != null
                                  ? _formatDuration(
                                      viewModel.transmissionDuration!)
                                  : '0m 0s',
                              unit: '',
                              color: colorScheme.tertiary,
                            ),
                          ),
                        ],
                      ),
                      if (!isTransmitting)
                        Padding(
                          padding: const EdgeInsets.only(top: 16),
                          child: Text(
                            'Start transmission to see live statistics',
                            style: TextStyle(
                              fontSize: 13,
                              color: colorScheme.onSurface.withOpacity(0.5),
                              fontStyle: FontStyle.italic,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _buildGlassCard(
                  colorScheme,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.sensors_rounded,
                              color: colorScheme.secondary),
                          const SizedBox(width: 12),
                          Text(
                            'Active Sensors',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: colorScheme.onSurface,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _buildActiveSensorsList(viewModel, colorScheme),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRawDataTab(SensorViewModel viewModel, ColorScheme colorScheme) {
    final hasEnabledSensors =
        viewModel.enabledSensors.values.any((enabled) => enabled);

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _buildGlassCard(
                        colorScheme,
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            Icon(
                              _isPaused
                                  ? Icons.play_circle_outline
                                  : Icons.pause_circle_outline,
                              color: colorScheme.primary,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _isPaused ? 'Paused' : 'Live',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: colorScheme.onSurface,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    IconButton.filledTonal(
                      onPressed: _togglePause,
                      icon: Icon(_isPaused ? Icons.play_arrow : Icons.pause),
                      style: IconButton.styleFrom(
                        backgroundColor: colorScheme.primary.withOpacity(0.2),
                        foregroundColor: colorScheme.primary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filledTonal(
                      onPressed: _resetData,
                      icon: const Icon(Icons.refresh),
                      style: IconButton.styleFrom(
                        backgroundColor: colorScheme.secondary.withOpacity(0.2),
                        foregroundColor: colorScheme.secondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (!hasEnabledSensors)
                  _buildGlassCard(
                    colorScheme,
                    child: Column(
                      children: [
                        Icon(
                          Icons.sensors_off,
                          size: 64,
                          color: colorScheme.onSurface.withOpacity(0.3),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No sensors enabled',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: colorScheme.onSurface.withOpacity(0.6),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Enable sensors from the Dashboard',
                          style: TextStyle(
                            fontSize: 14,
                            color: colorScheme.onSurface.withOpacity(0.4),
                          ),
                        ),
                      ],
                    ),
                  )
                else ...[
                  if (viewModel.enabledSensors[AppConstants.sensorAccelerometer] ==
                      true)
                    _buildSensorDataCard(
                      colorScheme,
                      title: 'Accelerometer',
                      icon: Icons.speed,
                      unit: 'm/s²',
                      data: _accelerometerData != null
                          ? {
                              'X': _accelerometerData!.x,
                              'Y': _accelerometerData!.y,
                              'Z': _accelerometerData!.z,
                            }
                          : null,
                    ),
                  if (viewModel.enabledSensors[AppConstants.sensorGyroscope] ==
                      true)
                    _buildSensorDataCard(
                      colorScheme,
                      title: 'Gyroscope',
                      icon: Icons.threesixty,
                      unit: 'rad/s',
                      data: _gyroscopeData != null
                          ? {
                              'X': _gyroscopeData!.x,
                              'Y': _gyroscopeData!.y,
                              'Z': _gyroscopeData!.z,
                            }
                          : null,
                    ),
                  if (viewModel.enabledSensors[AppConstants.sensorMagnetometer] ==
                      true)
                    _buildSensorDataCard(
                      colorScheme,
                      title: 'Magnetometer',
                      icon: Icons.explore,
                      unit: 'µT',
                      data: _magnetometerData != null
                          ? {
                              'X': _magnetometerData!.x,
                              'Y': _magnetometerData!.y,
                              'Z': _magnetometerData!.z,
                            }
                          : null,
                    ),
                  if (viewModel.enabledSensors[AppConstants.sensorGPS] == true)
                    _buildSensorDataCard(
                      colorScheme,
                      title: 'GPS',
                      icon: Icons.location_on,
                      unit: '',
                      data: _gpsData != null
                          ? {
                              'Latitude': _gpsData!.latitude,
                              'Longitude': _gpsData!.longitude,
                              'Altitude': _gpsData!.altitude,
                              'Speed': _gpsData!.speed,
                            }
                          : null,
                    ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGlassCard(
    ColorScheme colorScheme, {
    required Widget child,
    EdgeInsets padding = const EdgeInsets.all(20),
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: padding,
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

  Widget _buildStatCard(
    ColorScheme colorScheme, {
    required IconData icon,
    required String label,
    required String value,
    required String unit,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface,
            ),
          ),
          if (unit.isNotEmpty)
            Text(
              unit,
              style: TextStyle(
                fontSize: 11,
                color: colorScheme.onSurface.withOpacity(0.5),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildActiveSensorsList(
      SensorViewModel viewModel, ColorScheme colorScheme) {
    final enabledSensorTypes = viewModel.enabledSensors.entries
        .where((entry) => entry.value)
        .map((entry) => entry.key)
        .toList();

    if (enabledSensorTypes.isEmpty) {
      return Text(
        'No sensors enabled',
        style: TextStyle(
          fontSize: 14,
          color: colorScheme.onSurface.withOpacity(0.5),
          fontStyle: FontStyle.italic,
        ),
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: enabledSensorTypes.map((sensorType) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: colorScheme.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: colorScheme.primary.withOpacity(0.3),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _getSensorIcon(sensorType),
                size: 16,
                color: colorScheme.primary,
              ),
              const SizedBox(width: 6),
              Text(
                _getSensorDisplayName(sensorType),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurface,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSensorDataCard(
    ColorScheme colorScheme, {
    required String title,
    required IconData icon,
    required String unit,
    required Map<String, double>? data,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: _buildGlassCard(
        colorScheme,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: colorScheme.primary),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (data == null)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text(
                    'Waiting for data...',
                    style: TextStyle(
                      fontSize: 14,
                      color: colorScheme.onSurface.withOpacity(0.5),
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              )
            else
              ...data.entries.map((entry) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        entry.key,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: colorScheme.onSurface.withOpacity(0.7),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: colorScheme.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${entry.value.toStringAsFixed(4)} $unit',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: colorScheme.primary,
                            fontFeatures: const [
                              FontFeature.tabularFigures()
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  IconData _getSensorIcon(String sensorType) {
    switch (sensorType) {
      case AppConstants.sensorAccelerometer:
        return Icons.speed;
      case AppConstants.sensorGyroscope:
        return Icons.threesixty;
      case AppConstants.sensorMagnetometer:
        return Icons.explore;
      case AppConstants.sensorGPS:
        return Icons.location_on;
      default:
        return Icons.sensors;
    }
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

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '${minutes}m ${seconds}s';
  }
}
