import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:logging/logging.dart';
import 'package:sensdroid/models/sensor_data.dart';
import 'package:sensdroid/models/connection_info.dart';
import 'package:sensdroid/services/communication_service.dart';
import 'package:sensdroid/core/app_constants.dart';
import 'package:sensdroid/core/logger.dart';

/// PC TCP Socket communication service.
///
/// Sends the same 26-byte binary frames as USBService, but over a TCP socket
/// to 127.0.0.1:<port>. Requires ADB reverse port forwarding set up on the PC:
///
///   adb reverse tcp:<port> tcp:<port>
///
/// The PC listener (e.g. a Python script) must be running and bound to the
/// same port before the user taps "Connect" in the dashboard.
///
/// Design notes:
/// - [writeRaw] is the hot path called by SensorViewModel._drainAndSend().
///   It fire-and-forgets the raw bytes, matching the contract of USBService.
/// - [scan] returns a single static entry so the existing DeviceScanDialog
///   can be reused without changes.
class PcTcpService extends CommunicationService {
  final StreamController<ConnectionInfo> _connectionController =
      StreamController<ConnectionInfo>.broadcast();

  ConnectionInfo _connectionInfo = ConnectionInfo(
    // Re-use 'usb' protocol label for now — UI shows 'PC via TCP' via deviceName.
    protocol: AppConstants.protocolUSB,
    state: ConnectionState.disconnected,
  );

  late final Logger _logger;

  /// Active TCP socket. Null when not connected.
  Socket? _socket;

  /// Target host — always loopback for ADB forwarding.
  String _host = AppConstants.pcTcpHost;

  /// Target port — configurable from Settings.
  int _port = AppConstants.pcTcpDefaultPort;

  PcTcpService() {
    _logger = AppLogger.getLogger(runtimeType.toString());
  }

  // ── public config ──────────────────────────────────────────────────────────

  /// Update the TCP port before connecting.
  /// Has no effect while connected.
  void setPort(int port) {
    if (port > 0 && port <= 65535) {
      _port = port;
      _logger.info('PC TCP port set to $_port');
    }
  }

  int get port => _port;
  String get host => _host;

  // ── CommunicationService contract ─────────────────────────────────────────

  @override
  ConnectionInfo get connectionInfo => _connectionInfo;

  @override
  Stream<ConnectionInfo> get connectionStream => _connectionController.stream;

  @override
  bool get isConnected => _connectionInfo.isConnected && _socket != null;

  @override
  Future<bool> initialize() async {
    _logger.info('PcTcpService initialized (target: $_host:$_port)');
    return true;
  }

  @override
  Future<bool> isAvailable() async {
    // We always report available; actual reachability is determined at connect().
    return true;
  }

  /// Returns a single static scan entry so DeviceScanDialog can reuse the
  /// existing flow without modification.
  /// Format mirrors USBService: "DisplayName||address"
  @override
  Future<List<String>> scan() async {
    _logger.info('PC TCP scan: returning static entry for $_host:$_port');
    return ['PC via ADB TCP||$_host:$_port'];
  }

  @override
  Future<bool> connect(String address) async {
    try {
      // Close any stale socket first.
      if (_socket != null) {
        await _socket!.close();
        _socket = null;
      }

      _updateConnectionInfo(
        _connectionInfo.copyWith(
          state: ConnectionState.connecting,
          address: '$_host:$_port',
          deviceName: 'PC via ADB TCP',
        ),
      );

      _logger.info('Connecting to PC TCP at $_host:$_port …');

      // Socket.connect() throws SocketException if unreachable (ADB not set up).
      _socket = await Socket.connect(
        _host,
        _port,
        timeout: const Duration(seconds: 5),
      );

      // Disable Nagle algorithm for minimum write latency.
      // This is equivalent to TCP_NODELAY and prevents the OS from buffering
      // small packets, which is critical for real-time sensor streaming.
      _socket!.setOption(SocketOption.tcpNoDelay, true);

      // Listen for remote close / errors so we can clean up state.
      _socket!.listen(
        (_) {}, // ignore inbound data (we only send)
        onError: (Object e) {
          _logger.warning('PC TCP socket error: $e');
          _handleDisconnect(errorMessage: e.toString());
        },
        onDone: () {
          _logger.info('PC TCP socket closed by remote');
          _handleDisconnect();
        },
        cancelOnError: true,
      );

      _updateConnectionInfo(
        _connectionInfo.copyWith(
          state: ConnectionState.connected,
          deviceName: 'PC via ADB TCP',
          address: '$_host:$_port',
          connectedAt: DateTime.now(),
        ),
      );

      _logger.info('PC TCP connected at $_host:$_port');
      return true;
    } on SocketException catch (e) {
      final msg =
          'Cannot reach PC at $_host:$_port — '
          'ensure "adb reverse tcp:$_port tcp:$_port" is running. ($e)';
      _logger.severe(msg);
      _updateConnectionInfo(
        _connectionInfo.copyWith(
          state: ConnectionState.error,
          errorMessage: msg,
        ),
      );
      return false;
    } catch (e, st) {
      _logger.severe('PC TCP connect failed', e, st);
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
    try {
      await _socket?.flush();
      await _socket?.close();
    } catch (_) {} finally {
      _socket = null;
      _updateConnectionInfo(
        _connectionInfo.copyWith(state: ConnectionState.disconnected),
      );
      _logger.info('PC TCP disconnected');
    }
  }

  /// Low-latency raw write — fire-and-forget, matching USBService.writeRaw().
  /// SensorViewModel calls this from _drainAndSend() on the hot path.
  @override
  Future<void> writeRaw(Uint8List bytes) async {
    // add() is synchronous; flush is handled by the OS write buffer.
    // We intentionally do NOT await flush() here to keep latency minimal —
    // the same design rationale as USBService.
    _socket!.add(bytes);
  }

  @override
  Future<bool> sendData(SensorData data) async {
    if (!isConnected || _socket == null) return false;
    try {
      _socket!.add(data.toBytes());
      return true;
    } catch (e, st) {
      _logger.warning('PC TCP sendData failed', e, st);
      return false;
    }
  }

  @override
  Future<int> sendBatch(List<SensorData> dataList) async {
    if (!isConnected || _socket == null) return 0;
    try {
      final buffer = BytesBuilder(copy: false);
      for (final d in dataList) {
        buffer.add(d.toBytes());
      }
      _socket!.add(buffer.toBytes());
      return dataList.length;
    } catch (e, st) {
      _logger.warning('PC TCP sendBatch failed', e, st);
      return 0;
    }
  }

  @override
  Future<void> dispose() async {
    await disconnect();
    await _connectionController.close();
    _logger.info('PcTcpService disposed');
  }

  // ── internals ─────────────────────────────────────────────────────────────

  void _updateConnectionInfo(ConnectionInfo info) {
    _connectionInfo = info;
    if (!_connectionController.isClosed) {
      _connectionController.add(info);
    }
  }

  void _handleDisconnect({String? errorMessage}) {
    _socket = null;
    _updateConnectionInfo(
      _connectionInfo.copyWith(
        state: errorMessage != null
            ? ConnectionState.error
            : ConnectionState.disconnected,
        errorMessage: errorMessage,
      ),
    );
  }
}
