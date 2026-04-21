import 'package:logging/logging.dart';
import 'package:sensdroid/models/sensor_data.dart';

/// Mixin to provide batch sending functionality with retry logic
/// Reduces code duplication across communication services
abstract class BatchSender {
  Logger get log;

  /// Send a batch of sensor data with retry logic and error handling
  /// Returns number of packets successfully sent
  Future<int> sendBatchWithRetry(
    List<SensorData> dataList, {
    required Future<bool> Function(SensorData data) sendSingle,
    required Future<bool> Function(List<SensorData> batch) sendBatch,
  });
}

/// Default implementation of BatchSender
class DefaultBatchSender implements BatchSender {
  final Logger _logger;

  DefaultBatchSender(this._logger);

  @override
  Logger get log => _logger;

  @override
  Future<int> sendBatchWithRetry(
    List<SensorData> dataList, {
    required Future<bool> Function(SensorData data) sendSingle,
    required Future<bool> Function(List<SensorData> batch) sendBatch,
  }) async {
    const maxRetries = 3;
    const baseRetryDelay = 100; // milliseconds

    if (dataList.isEmpty) {
      log.fine('Batch send skipped: empty data list');
      return 0;
    }

    // Try batch send first (more efficient)
    try {
      log.fine('Attempting batch send of ${dataList.length} packets');

      final success = await sendBatch(dataList);
      if (success) {
        log.info('Batch send successful: ${dataList.length} packets');
        return dataList.length;
      }

      log.warning('Batch send failed, falling back to individual sends');
    } catch (e) {
      log.warning('Batch send error: $e, falling back to individual sends');
    }

    // Fallback: send individually with retry
    int successCount = 0;
    for (final data in dataList) {
      bool sent = false;
      for (int attempt = 0; attempt < maxRetries; attempt++) {
        try {
          sent = await sendSingle(data);
          if (sent) {
            successCount++;
            if (attempt > 0) {
              log.info('Individual packet sent after $attempt retry(ies)');
            }
            break; // Success, move to next packet
          }
        } catch (e) {
          final delay = baseRetryDelay * (1 << attempt);
          log.warning('Retry $attempt/$maxRetries after $delay ms due to: $e');
          await Future.delayed(Duration(milliseconds: delay));
        }
      }
    }

    log.info(
      'Batch send completed: $successCount/${dataList.length} packets sent',
    );
    return successCount;
  }
}
