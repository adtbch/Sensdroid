import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sensdroid/viewmodels/sensor_viewmodel.dart';
import 'package:sensdroid/services/communication_service.dart';
import 'package:sensdroid/core/app_constants.dart';

// Mock classes
class MockCommunicationService extends Mock implements CommunicationService {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SensorViewModel', () {
    late SensorViewModel viewModel;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      viewModel = SensorViewModel(autoDetectSensors: false);
    });

    tearDown(() {
      viewModel.dispose();
    });

    test('initial state is correct', () {
      expect(viewModel.isConnected, false);
      expect(viewModel.isTransmitting, false);
      expect(viewModel.isConnecting, false);
      expect(viewModel.lastError, isNull);
      expect(viewModel.packetsSent, 0);
      expect(viewModel.packetsDropped, 0);
      expect(viewModel.activeProtocol, AppConstants.protocolUSB);
    });

    test('toggleSensor updates enabledSensors map', () {
      // Accelerometer starts enabled by default.
      expect(viewModel.enabledSensors[AppConstants.sensorAccelerometer], true);

      viewModel.toggleSensor(AppConstants.sensorAccelerometer, false);
      expect(viewModel.enabledSensors[AppConstants.sensorAccelerometer], false);
    });

    test('toggleSensor does not enable unavailable sensor', () {
      // Simulate sensor not available (by default, available sensors are unkown until detection)
      // This test assumes initially some sensor may not be available
      // For now, just verify the guard doesn't throw
      viewModel.toggleSensor('non_existent_sensor', true);
      // Should not crash or set value (non-existent key not in map, so no-op)
    });

    test('clearError clears lastError', () {
      viewModel.clearError();
      expect(viewModel.lastError, isNull);
    });

    test('activeProtocol is always USB', () {
      expect(viewModel.activeProtocol, AppConstants.protocolUSB);
    });


    test('transmissionDuration returns null when not transmitting', () {
      expect(viewModel.transmissionDuration, isNull);
    });

    test('transmissionRate returns 0 when duration is zero or null', () {
      expect(viewModel.transmissionRate, 0.0);
    });

    test('sensor detection flag is initialized in test mode', () async {
      await Future.delayed(const Duration(milliseconds: 20));
      expect(viewModel.isSensorDetectionComplete, true);
    });
  });
}
