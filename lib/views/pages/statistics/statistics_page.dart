import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:sensdroid/core/app_constants.dart';
import 'package:sensdroid/viewmodels/sensor_viewmodel.dart';
import 'package:sensdroid/views/settings_page.dart';
import 'widgets/stats_primitives.dart';
import 'widgets/stats_transmission_card.dart';
import 'widgets/stats_stream_card.dart';
import 'widgets/stats_ypr_card.dart';
import 'widgets/stats_gps_card.dart';

export 'widgets/stats_primitives.dart';
export 'widgets/stats_transmission_card.dart';
export 'widgets/stats_stream_card.dart';
export 'widgets/stats_ypr_card.dart';
export 'widgets/stats_gps_card.dart';

class StatisticsPage extends StatefulWidget {
  const StatisticsPage({super.key});

  @override
  State<StatisticsPage> createState() => _StatisticsPageState();
}

class _StatisticsPageState extends State<StatisticsPage> {
  // ── ViewModel reference ────────────────────────────────────────────────────
  late SensorViewModel _viewModel;

  // ── Per-sensor broadcast controllers (UI listens via StreamBuilder) ────────
  final _accelCtrl   = StreamController<AccelerometerEvent>.broadcast();
  final _gyroCtrl    = StreamController<GyroscopeEvent>.broadcast();
  final _magnetoCtrl = StreamController<MagnetometerEvent>.broadcast();
  final _yprCtrl     =
      StreamController<({double yaw, double pitch, double roll})>.broadcast();
  final _gpsCtrl     = StreamController<Position>.broadcast();

  // ── Subscriptions ──────────────────────────────────────────────────────────
  StreamSubscription<AccelerometerEvent>? _accelSub;
  StreamSubscription<GyroscopeEvent>? _gyroSub;
  StreamSubscription<MagnetometerEvent>? _magnetoSub;
  StreamSubscription<({double yaw, double pitch, double roll})>? _yprSub;
  StreamSubscription<Position>? _gpsSub;

  // ── State flags ────────────────────────────────────────────────────────────
  bool _isPaused = false;
  bool _fusionPreviewActive = false;

  // ── UI throttle ────────────────────────────────────────────────────────────
  static const _rawUiThrottleMs = 33; // ~30 fps for raw sensors
  DateTime _lastAccelFwd   = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime _lastGyroFwd    = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime _lastMagnetoFwd = DateTime.fromMillisecondsSinceEpoch(0);

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _viewModel = context.read<SensorViewModel>();
    _viewModel.addListener(_onViewModelChanged);
    _startListening();
  }

  @override
  void dispose() {
    _stopListening();
    _viewModel.removeListener(_onViewModelChanged);
    _accelCtrl.close();
    _gyroCtrl.close();
    _magnetoCtrl.close();
    _yprCtrl.close();
    _gpsCtrl.close();
    super.dispose();
  }

  // ── Subscription management ────────────────────────────────────────────────

  void _onViewModelChanged() => _syncModeSubscriptions();

  void _startListening() {
    // Forward fused YPR from ViewModel (only active when fusion mode is on).
    _yprSub = _viewModel.fusedOrientationStream.listen((e) {
      if (!_isPaused && mounted) _yprCtrl.add(e);
    });

    _syncModeSubscriptions();

    if (_viewModel.enabledSensors[AppConstants.sensorGPS] == true) {
      _gpsSub = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.best,
          distanceFilter: 0,
        ),
      ).listen((p) {
        if (!_isPaused) _gpsCtrl.add(p);
      });
    }
  }

  void _syncModeSubscriptions() {
    if (!mounted) return;
    if (_viewModel.useSensorFusionMode) {
      if (!_fusionPreviewActive) {
        _viewModel.startFusionPreview();
        _fusionPreviewActive = true;
      }
      _stopRawImuListening();
    } else {
      if (_fusionPreviewActive) {
        _viewModel.stopFusionPreview();
        _fusionPreviewActive = false;
      }
      _startRawImuListening();
    }
  }

  void _startRawImuListening() {
    if (_accelSub != null || _gyroSub != null || _magnetoSub != null) return;
    const period = Duration(milliseconds: 5);

    _accelSub = accelerometerEventStream(samplingPeriod: period).listen((e) {
      if (_isPaused || !mounted) return;
      if (_viewModel.enabledSensors[AppConstants.sensorAccelerometer] == true) {
        final now = DateTime.now();
        if (now.difference(_lastAccelFwd).inMilliseconds >= _rawUiThrottleMs) {
          _lastAccelFwd = now;
          _accelCtrl.add(e);
        }
      }
    });

    _gyroSub = gyroscopeEventStream(samplingPeriod: period).listen((e) {
      if (_isPaused || !mounted) return;
      if (_viewModel.enabledSensors[AppConstants.sensorGyroscope] == true) {
        final now = DateTime.now();
        if (now.difference(_lastGyroFwd).inMilliseconds >= _rawUiThrottleMs) {
          _lastGyroFwd = now;
          _gyroCtrl.add(e);
        }
      }
    });

    _magnetoSub = magnetometerEventStream(samplingPeriod: period).listen((e) {
      if (_isPaused || !mounted) return;
      if (_viewModel.enabledSensors[AppConstants.sensorMagnetometer] == true) {
        final now = DateTime.now();
        if (now.difference(_lastMagnetoFwd).inMilliseconds >= _rawUiThrottleMs) {
          _lastMagnetoFwd = now;
          _magnetoCtrl.add(e);
        }
      }
    });
  }

  void _stopRawImuListening() {
    _accelSub?.cancel();   _accelSub   = null;
    _gyroSub?.cancel();    _gyroSub    = null;
    _magnetoSub?.cancel(); _magnetoSub = null;
  }

  void _stopListening() {
    if (_fusionPreviewActive) {
      _viewModel.stopFusionPreview();
      _fusionPreviewActive = false;
    }
    _stopRawImuListening();
    _yprSub?.cancel(); _yprSub = null;
    _gpsSub?.cancel();
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Consumer<SensorViewModel>(
      builder: (context, viewModel, _) {
        final cs = Theme.of(context).colorScheme;
        return Scaffold(
          backgroundColor: cs.surface,
          body: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              _buildSliverAppBar(viewModel, cs),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 40),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      StatsTransmissionCard(viewModel: viewModel),
                      const SizedBox(height: 14),
                      _buildSensorSection(viewModel, cs),
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

  // ── AppBar ────────────────────────────────────────────────────────────────

  Widget _buildSliverAppBar(SensorViewModel viewModel, ColorScheme cs) {
    return SliverAppBar(
      pinned: true,
      backgroundColor: cs.surface,
      elevation: 0,
      scrolledUnderElevation: 0,
      expandedHeight: 120,
      actions: [
        IconButton(
          icon: Icon(Icons.settings_rounded, color: cs.onSurfaceVariant),
          onPressed: () {
            final settings = viewModel.settings;
            if (settings == null) return;
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    SettingsPage(settings: settings, viewModel: viewModel),
              ),
            );
          },
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
        title: Text(
          'Statistics',
          style: GoogleFonts.inter(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: cs.onSurface,
            letterSpacing: -0.3,
          ),
        ),
        background: _AppBarBackground(cs: cs),
      ),
    );
  }

  // ── Sensor section (fusion card OR raw cards) ─────────────────────────────

  Widget _buildSensorSection(SensorViewModel viewModel, ColorScheme cs) {
    if (viewModel.useSensorFusionMode) {
      return Column(
        children: [
          StatsYprCard(
            orientationStream: _yprCtrl.stream,
            viewModel: viewModel,
          ),
          if (viewModel.enabledSensors[AppConstants.sensorGPS] == true)
            StatsGpsCard(stream: _gpsCtrl.stream),
        ],
      );
    }

    return Column(
      children: [
        if (viewModel.enabledSensors[AppConstants.sensorAccelerometer] == true)
          StatsStreamCard<AccelerometerEvent>(
            title: 'Accelerometer',
            icon: Icons.open_with_rounded,
            unit: 'm/s²',
            color: cs.primary,
            stream: _accelCtrl.stream,
            toData: (e) => {'X': e.x, 'Y': e.y, 'Z': e.z},
            maxAbsValue: 20,
          ),
        if (viewModel.enabledSensors[AppConstants.sensorGyroscope] == true)
          StatsStreamCard<GyroscopeEvent>(
            title: 'Gyroscope',
            icon: Icons.threesixty_rounded,
            unit: 'rad/s',
            color: cs.secondary,
            stream: _gyroCtrl.stream,
            toData: (e) => {'X': e.x, 'Y': e.y, 'Z': e.z},
            maxAbsValue: 10,
          ),
        if (viewModel.enabledSensors[AppConstants.sensorMagnetometer] == true)
          StatsStreamCard<MagnetometerEvent>(
            title: 'Magnetometer',
            icon: Icons.explore_rounded,
            unit: 'µT',
            color: const Color(0xFFFF9800),
            stream: _magnetoCtrl.stream,
            toData: (e) => {'X': e.x, 'Y': e.y, 'Z': e.z},
            maxAbsValue: 100,
          ),
        if (viewModel.enabledSensors[AppConstants.sensorGPS] == true)
          StatsGpsCard(stream: _gpsCtrl.stream),
      ],
    );
  }
}

// ── AppBar background (extracted to avoid rebuilding with Consumer) ──────────

class _AppBarBackground extends StatelessWidget {
  const _AppBarBackground({required this.cs});
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [cs.tertiaryContainer.withOpacity(0.2), cs.surface],
            ),
          ),
        ),
        Positioned(
          right: -20,
          top: -10,
          child: Container(
            width: 130,
            height: 130,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: cs.tertiary.withOpacity(0.07),
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
                'Live Statistics',
                style: GoogleFonts.inter(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  color: cs.onSurface,
                  letterSpacing: -0.8,
                ),
              ),
              Text(
                'Transmission metrics & sensor data',
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
    );
  }
}
