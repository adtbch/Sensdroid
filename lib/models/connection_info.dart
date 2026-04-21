/// Sentinel used to distinguish "not supplied" from an explicit null in copyWith
const Object _absent = Object();

/// Represents the current state of a communication connection
enum ConnectionState { disconnected, connecting, connected, error }

/// Model for communication connection status and information
class ConnectionInfo {
  final String protocol;
  final ConnectionState state;
  final String? deviceName;
  final String? address;
  final String? errorMessage;
  final DateTime? connectedAt;

  ConnectionInfo({
    required this.protocol,
    required this.state,
    this.deviceName,
    this.address,
    this.errorMessage,
    this.connectedAt,
  });

  ConnectionInfo copyWith({
    String? protocol,
    ConnectionState? state,
    String? deviceName,
    String? address,
    // Use `copyWith(errorMessage: null)` to explicitly clear; omitting keeps old value
    Object? errorMessage = _absent,
    DateTime? connectedAt,
  }) {
    return ConnectionInfo(
      protocol: protocol ?? this.protocol,
      state: state ?? this.state,
      deviceName: deviceName ?? this.deviceName,
      address: address ?? this.address,
      errorMessage: identical(errorMessage, _absent)
          ? this.errorMessage
          : errorMessage as String?,
      connectedAt: connectedAt ?? this.connectedAt,
    );
  }

  bool get isConnected => state == ConnectionState.connected;
  bool get isConnecting => state == ConnectionState.connecting;
  bool get hasError => state == ConnectionState.error;

  @override
  String toString() {
    return 'ConnectionInfo(protocol: $protocol, state: $state, device: $deviceName, address: $address)';
  }
}
