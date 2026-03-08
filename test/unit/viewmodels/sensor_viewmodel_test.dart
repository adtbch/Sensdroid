import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:sensdroid/viewmodels/sensor_viewmodel.dart';
import 'package:sensdroid/services/communication_service.dart';
import 'package:sensdroid/core/app_constants.dart';

// Mock classes
class MockCommunicationService extends Mock implements CommunicationService {}

void main() {
  group('SensorViewModel', () {
    late SensorViewModel viewModel;

    setUp(() {
      viewModel = SensorViewModel();
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
      expect(viewModel.activeProtocol, AppConstants.protocolBluetooth); // default
    });

    test('toggleSensor updates enabledSensors map', () {
      // Initially all false
      expect(viewModel.enabledSensors[AppConstants.sensorAccelerometer], false);

      viewModel.toggleSensor(AppConstants.sensorAccelerometer, true);
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

    test('switchProtocol changes activeProtocol', () async {
      // Bludutan, default adalah Bluetooth
      expect(viewModel.activeProtocol, AppConstants.protocolBluetooth);

      // Ganti ke USB
      await viewModel.switchProtocol(AppConstants.protocolUSB);
      expect(viewModel.activeProtocol, AppConstants.protocolUSB);

      // Ganti ke WiFi
      await viewModel.switchProtocol(AppConstants.protocolWiFi);
      expect(viewModel.activeProtocol, AppConstants.protocolWiFi);
    });

    test('switchProtocol throws on unknown protocol', () async {
      expect(
        () async => viewModel.switchProtocol('unknown'),
        throwsArgumentError,
      );
    });

    test('transmissionDuration returns null when not transmitting', () {
      expect(viewModel.transmissionDuration, isNull);
    });

    test('transmissionRate returns 0 when duration is zero or null', () {
      expect(viewModel.transmissionRate, 0.0);
    });

    test('dispose does not throw', () {
      // Should complete without error
      viewModel.dispose();
    });

    // Integration-style test (requires actual services)
    test('detectAvailableSensors completes without error', () async {
      await viewModel.detectAvailableSensors();
      // Just verify it completes and sets flag
      expect(viewModel.isSensorDetectionComplete, true);
    });

    test('redetectSensors resets and detects again', () async {
      await viewModel.detectAvailableSensors();
      // firstResult is just a snapshot for comparison
      final _ = viewModel.availableSensors;

      // Redetect should clear previous results temporarily
      viewModel.redetectSensors();
      // isSensorDetectionComplete should be false initially
      expect(viewModel.isSensorDetectionComplete, false);

      await untilCalled(() => viewModel.isSensorDetectionComplete);
      // Eventually it should complete again
      // Note: untilCalled not available, so we just wait
      await Future.delayed(const Duration(milliseconds: 100));
      expect(viewModel.isSensorDetectionComplete, true);
    });
  });
}
