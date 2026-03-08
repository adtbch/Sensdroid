import 'dart:async';
import 'dart:convert';
import 'package:logging/logging.dart';
import 'package:dio/dio.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:sensdroid/models/sensor_data.dart';
import 'package:sensdroid/models/connection_info.dart';
import 'package:sensdroid/services/communication_service.dart';
import 'package:sensdroid/core/app_constants.dart';
import 'package:sensdroid/core/logger.dart';

/// WiFi (HTTP/REST) communication service implementation
/// Transmits data to ESP32 or PC over local network
class WiFiService extends CommunicationService {
  final Dio _dio = Dio();
  String? _baseUrl;
  
  final StreamController<ConnectionInfo> _connectionController =
      StreamController<ConnectionInfo>.broadcast();
  
  ConnectionInfo _connectionInfo = ConnectionInfo(
    protocol: AppConstants.protocolWiFi,
    state: ConnectionState.disconnected,
  );

  late final Logger _logger;

  WiFiService() {
    _logger = AppLogger.getLogger(runtimeType.toString());
  }

  Logger get log => _logger;

  @override
  ConnectionInfo get connectionInfo => _connectionInfo;

  @override
  Stream<ConnectionInfo> get connectionStream => _connectionController.stream;

  @override
  bool get isConnected => _connectionInfo.isConnected && _baseUrl != null;

  void _updateConnectionInfo(ConnectionInfo info) {
    _connectionInfo = info;
    _connectionController.add(info);
  }

  @override
  Future<bool> initialize() async {
    try {
      _logger.info('Initializing WiFi service');
      // Configure Dio with timeouts suitable for batch payloads
      _dio.options = BaseOptions(
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
        sendTimeout: const Duration(seconds: 10),
      );
      return true;
    } catch (e, stackTrace) {
      _logger.severe('Failed to initialize WiFi service', e, stackTrace);
      _updateConnectionInfo(
        _connectionInfo.copyWith(
          state: ConnectionState.error,
          errorMessage: e.toString(),
        ),
      );
      return false;
    }
  }

  @override
  Future<bool> isAvailable() async {
    // Check if WiFi is connected
    final connectivityResult = await Connectivity().checkConnectivity();
    final isWifi = connectivityResult.contains(ConnectivityResult.wifi);
    _logger.fine('WiFi availability check: $isWifi (connectivity: $connectivityResult)');
    return isWifi;
  }

  @override
  Future<List<String>> scan() async {
    // WiFi scan is not directly supported
    // User needs to manually input IP address
    // This could be enhanced with mDNS/Bonjour service discovery
    _logger.info('WiFi scan requested - not implemented (manual IP entry required)');
    return [];
  }

  @override
  Future<bool> connect(String address) async {
    try {
      _logger.info('Connecting to WiFi device: $address');
      _updateConnectionInfo(
        _connectionInfo.copyWith(
          state: ConnectionState.connecting,
          address: address,
        ),
      );

      // Check WiFi connectivity
      if (!await isAvailable()) {
        _logger.severe('WiFi is not connected on this device');
        _updateConnectionInfo(
          _connectionInfo.copyWith(
            state: ConnectionState.error,
            errorMessage: AppConstants.errorWiFiNotConnected,
          ),
        );
        return false;
      }

      // Parse address - expected format: "192.168.1.100:8080" or "192.168.1.100"
      String host = address;
      int port = AppConstants.wifiDefaultPort;
      
      if (address.contains(':')) {
        final parts = address.split(':');
        host = parts[0];
        port = int.tryParse(parts[1]) ?? AppConstants.wifiDefaultPort;
      }

      // Construct base URL
      _baseUrl = 'http://$host:$port';
      _logger.info('WiFi base URL: $_baseUrl');

      // Test connection with a ping/health check
      try {
        _logger.fine('Testing connection with ping to $_baseUrl/ping');
        final response = await _dio.get(
          '$_baseUrl/ping',
          options: Options(
            validateStatus: (status) => status != null && status < 500,
          ),
        ).timeout(const Duration(seconds: 5));
        
        _logger.fine('Ping response status: ${response.statusCode}');
        // Consider connection successful even if endpoint doesn't exist
        // (404 means server is reachable)
        if (response.statusCode != null) {
          _updateConnectionInfo(
            _connectionInfo.copyWith(
              state: ConnectionState.connected,
              address: '$host:$port',
              deviceName: 'WiFi Device',
              connectedAt: DateTime.now(),
            ),
          );
          _logger.info('WiFi connection established');
          return true;
        }
      } catch (e, stackTrace) {
        // If ping fails, still allow connection
        // The actual endpoint might be different
        _logger.warning('Ping failed but proceeding with connection', e, stackTrace);
        _updateConnectionInfo(
          _connectionInfo.copyWith(
            state: ConnectionState.connected,
            address: '$host:$port',
            deviceName: 'WiFi Device',
            connectedAt: DateTime.now(),
          ),
        );
        _logger.info('WiFi connection established (ping failed)');
        return true;
      }

      return false;
    } catch (e, stackTrace) {
      _logger.severe('WiFi connection failed', e, stackTrace);
      _updateConnectionInfo(
        _connectionInfo.copyWith(
          state: ConnectionState.error,
          errorMessage: e.toString(),
        ),
      );
      return false;
    }
  }

  @override
  Future<void> disconnect() async {
    _logger.info('Disconnecting from WiFi');
    _baseUrl = null;
    _updateConnectionInfo(
      _connectionInfo.copyWith(
        state: ConnectionState.disconnected,
      ),
    );
    _logger.info('WiFi disconnected');
  }

  @override
  Future<bool> sendData(SensorData data) async {
    if (!isConnected || _baseUrl == null) {
      _logger.warning('Cannot send WiFi data: not connected');
      return false;
    }

    try {
      _logger.fine('Sending single data packet to $_baseUrl${AppConstants.wifiDefaultEndpoint}');
      final payload = data.toJson();
      _logger.fine('Payload: $payload');
      
      final response = await _dio.post(
        '$_baseUrl${AppConstants.wifiDefaultEndpoint}',
        data: jsonEncode(payload),
        options: Options(
          headers: {'Content-Type': 'application/json'},
        ),
      );
      
      final success = response.statusCode == 200 || response.statusCode == 201;
      if (success) {
        _logger.fine('Single packet sent successfully');
      } else {
        _logger.warning('Single packet send failed with status: ${response.statusCode}');
      }
      return success;
    } catch (e, stackTrace) {
      _logger.warning('Failed to send single WiFi packet', e, stackTrace);
      return false;
    }
  }

  @override
  Future<int> sendBatch(List<SensorData> dataList) async {
    if (!isConnected || _baseUrl == null) {
      _logger.warning('Cannot send WiFi batch: not connected');
      return 0;
    }

    try {
      _logger.fine('Sending batch of ${dataList.length} packets to $_baseUrl${AppConstants.wifiDefaultEndpoint}');
      final jsonData = dataList.map((d) => d.toJson()).toList();

      final response = await retryWithBackoff(
        () async => await _dio.post(
          '$_baseUrl${AppConstants.wifiDefaultEndpoint}',
          data: jsonEncode(jsonData),
          options: Options(
            headers: {'Content-Type': 'application/json'},
          ),
        ),
        maxRetries: 3,
        shouldRetry: (error) => error.toString().contains('timeout') || error.toString().contains('SocketException'),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        _logger.info('WiFi batch sent successfully: ${dataList.length} packets');
        return dataList.length;
      }
      // Non-success status — fall through to individual sends
      _logger.warning('Batch send returned status ${response.statusCode}, falling back to individual sends');
    } catch (e, stackTrace) {
      _logger.warning('Batch send failed after retries, falling back to individual sends', e, stackTrace);
    }

    // Fallback: send each packet individually with retry
    int successCount = 0;
    for (final data in dataList) {
      if (await sendData(data)) {
        successCount++;
      }
    }
    _logger.info('WiFi individual send fallback: $successCount/${dataList.length} packets sent');
    return successCount;
  }

  @override
  Future<void> dispose() async {
    await disconnect();
    _dio.close();
    await _connectionController.close();
    _logger.info('WiFi service disposed');
  }
}
