import 'package:sensdroid/models/sensor_data.dart';
import 'package:sensdroid/models/connection_info.dart';
import 'package:sensdroid/core/logger.dart';

/// Abstract base class for all communication services
/// This ensures protocol switching is seamless by providing a common interface
abstract class CommunicationService {
  static const int _defaultRetryCount = 3;
  static const Duration _baseRetryDelay = Duration(milliseconds: 100);

  /// Current connection state
  ConnectionInfo get connectionInfo;

  /// Stream of connection state changes
  Stream<ConnectionInfo> get connectionStream;

  /// Initialize the service and check for availability
  Future<bool> initialize();

  /// Connect to a device/endpoint
  /// [address] is a USB device identifier (e.g. VID:PID)
  Future<bool> connect(String address);

  /// Disconnect from the current connection
  Future<void> disconnect();

  /// Send sensor data through the communication channel
  /// Returns true if data was sent successfully
  Future<bool> sendData(SensorData data);

  /// Send batch of sensor data for efficiency
  /// Returns number of packets successfully sent
  Future<int> sendBatch(List<SensorData> dataList);

  /// Scan/discover available devices or endpoints
  /// Returns a list of available addresses/identifiers
  Future<List<String>> scan();

  /// Check if the service is currently available on the device
  Future<bool> isAvailable();

  /// Check if currently connected
  bool get isConnected;

  /// Dispose resources and cleanup
  Future<void> dispose();

  /// Retry logic with exponential backoff for transient failures
  /// [operation] is the async operation to retry
  /// [shouldRetry] determines if error is retryable (default: all exceptions)
  /// [maxRetries] defaults to 3
  /// [baseDelay] initial delay before first retry
  Future<T> retryWithBackoff<T>(
    Future<T> Function() operation, {
    bool Function(Object error)? shouldRetry,
    int maxRetries = _defaultRetryCount,
    Duration? baseDelay,
  }) async {
    final logger = AppLogger.getLogger(runtimeType.toString());
    final delay = baseDelay ?? _baseRetryDelay;
    int attempt = 0;

    while (true) {
      try {
        final result = await operation();
        if (attempt > 0) {
          logger.info('Operation succeeded after $attempt retry(ies)');
        }
        return result;
      } catch (e, stackTrace) {
        final isRetryable = shouldRetry?.call(e) ?? true;

        if (!isRetryable || attempt >= maxRetries) {
          logger.severe(
            'Operation failed after $attempt retry(ies): $e',
            e,
            stackTrace,
          );
          rethrow;
        }

        attempt++;
        final backoff = delay * (1 << (attempt - 1)); // 100ms, 200ms, 400ms
        logger.warning(
          'Retry $attempt/$maxRetries after ${backoff.inMilliseconds}ms due to: $e',
        );
        await Future.delayed(backoff);
      }
    }
  }
}
