import 'dart:ui';
import 'package:flutter/material.dart';
import 'dart:async';

/// Modern scanning dialog with glassmorphism and device name display
class DeviceScanDialog extends StatefulWidget {
  final Future<List<String>> Function() onScan;
  final String protocolType;

  const DeviceScanDialog({
    super.key,
    required this.onScan,
    required this.protocolType,
  });

  @override
  State<DeviceScanDialog> createState() => _DeviceScanDialogState();
}

class _DeviceScanDialogState extends State<DeviceScanDialog>
    with TickerProviderStateMixin {
  bool _isScanning = true;
  bool _hasError = false;
  String _errorMessage = '';
  List<String> _foundDevices = [];
  int _scanDuration = 0;
  Timer? _timer;
  late AnimationController _pulseController;
  late AnimationController _rotateController;

  @override
  void initState() {
    super.initState();
    
    // Pulse animation for scanner icon
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    // Rotate animation for progress
    _rotateController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();

    _startScan();
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pulseController.dispose();
    _rotateController.dispose();
    super.dispose();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _scanDuration++;
        });
      }
    });
  }

  Future<void> _startScan() async {
    setState(() {
      _isScanning = true;
      _hasError = false;
      _errorMessage = '';
      _foundDevices.clear();
      _scanDuration = 0;
    });

    try {
      final devices = await widget.onScan();
      
      if (mounted) {
        setState(() {
          _foundDevices = devices;
          _isScanning = false;
        });
        _timer?.cancel();
        _pulseController.stop();
        _rotateController.stop();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isScanning = false;
          _hasError = true;
          _errorMessage = e.toString();
        });
        _timer?.cancel();
        _pulseController.stop();
        _rotateController.stop();
      }
    }
  }

  void _retryScan() {
    _startScan();
    _startTimer();
    _pulseController.repeat(reverse: true);
    _rotateController.repeat();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return Dialog(
      backgroundColor: Colors.transparent,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 400, maxHeight: 550),
            decoration: BoxDecoration(
              color: colorScheme.surface.withOpacity(0.9),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: colorScheme.primary.withOpacity(0.3),
                width: 1.5,
              ),
            ),
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                _buildHeader(colorScheme),
                const SizedBox(height: 24),
                
                // Content
                Expanded(
                  child: _hasError
                      ? _buildErrorState(colorScheme)
                      : _isScanning
                          ? _buildScanningState(colorScheme)
                          : _buildResultsState(colorScheme),
                ),
                
                const SizedBox(height: 16),
                
                // Actions
                _buildActions(colorScheme),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(ColorScheme colorScheme) {
    return Row(
      children: [
        if (_isScanning)
          RotationTransition(
            turns: _rotateController,
            child: Icon(
              Icons.radar,
              color: colorScheme.primary,
              size: 32,
            ),
          )
        else if (_hasError)
          Icon(
            Icons.error_outline,
            color: colorScheme.error,
            size: 32,
          )
        else
          Icon(
            Icons.check_circle_outline,
            color: colorScheme.primary,
            size: 32,
          ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _isScanning
                    ? 'SCANNING'
                    : _hasError
                        ? 'SCAN FAILED'
                        : 'SCAN COMPLETE',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                  color: _isScanning
                      ? colorScheme.primary
                      : _hasError
                          ? colorScheme.error
                          : colorScheme.primary,
                ),
              ),
              Text(
                widget.protocolType.toUpperCase(),
                style: TextStyle(
                  fontSize: 12,
                  color: colorScheme.onSurface.withOpacity(0.6),
                ),
              ),
            ],
          ),
        ),
        if (_isScanning)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: colorScheme.primary.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: colorScheme.primary.withOpacity(0.5),
              ),
            ),
            child: Text(
              '${_scanDuration}s',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: colorScheme.primary,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildScanningState(ColorScheme colorScheme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              // Animated pulses
              ScaleTransition(
                scale: Tween<double>(begin: 1.0, end: 1.6).animate(
                  CurvedAnimation(
                    parent: _pulseController,
                    curve: Curves.easeOut,
                  ),
                ),
                child: FadeTransition(
                  opacity: Tween<double>(begin: 0.5, end: 0.0).animate(
                    CurvedAnimation(
                      parent: _pulseController,
                      curve: Curves.easeOut,
                    ),
                  ),
                  child: Container(
                    width: 140,
                    height: 140,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: colorScheme.primary,
                        width: 2,
                      ),
                    ),
                  ),
                ),
              ),
              // Center icon
              ClipOval(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                  child: Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          colorScheme.primary.withOpacity(0.3),
                          colorScheme.primary.withOpacity(0.1),
                        ],
                      ),
                      border: Border.all(
                        color: colorScheme.primary.withOpacity(0.4),
                        width: 2,
                      ),
                    ),
                    child: RotationTransition(
                      turns: _rotateController,
                      child: Icon(
                        Icons.bluetooth_searching,
                        size: 48,
                        color: colorScheme.primary,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          Text(
            'Searching for ${widget.protocolType} devices...',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurface,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),
          Text(
            'Please wait while we scan the area',
            style: TextStyle(
              fontSize: 14,
              color: colorScheme.onSurface.withOpacity(0.6),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 28),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              width: 220,
              height: 4,
              child: LinearProgressIndicator(
                backgroundColor: colorScheme.surfaceContainerHighest.withOpacity(0.5),
                valueColor: AlwaysStoppedAnimation(colorScheme.primary),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultsState(ColorScheme colorScheme) {
    if (_foundDevices.isEmpty) {
      return _buildEmptyState(colorScheme);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Device count header
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: colorScheme.primary.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: colorScheme.primary.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.devices,
                    size: 18,
                    color: colorScheme.primary,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    '${_foundDevices.length} Device${_foundDevices.length > 1 ? 's' : ''} Found',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                      color: colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        
        // Device list
        Expanded(
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: _foundDevices.length,
            itemBuilder: (context, index) {
              final device = _foundDevices[index];
              final parts = device.split('||');
              final deviceName = parts.isNotEmpty ? parts.first : device;
              final deviceAddress = parts.length > 1 ? parts.last : '';
              final isNamedDevice = deviceName != 'BLE Device' && deviceName != 'USB Device';
              
              return TweenAnimationBuilder<double>(
                duration: Duration(milliseconds: 300 + (index * 80)),
                tween: Tween(begin: 0.0, end: 1.0),
                builder: (context, value, child) {
                  return Opacity(
                    opacity: value,
                    child: Transform.translate(
                      offset: Offset(0, 20 * (1 - value)),
                      child: child,
                    ),
                  );
                },
                child: Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 3, sigmaY: 3),
                      child: Container(
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceContainerHighest.withOpacity(0.6),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: colorScheme.primary.withOpacity(0.2),
                            width: 1,
                          ),
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () => Navigator.pop(context, device),
                            borderRadius: BorderRadius.circular(16),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                children: [
                                  // Device icon
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          colorScheme.primary.withOpacity(0.3),
                                          colorScheme.primary.withOpacity(0.1),
                                        ],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: colorScheme.primary.withOpacity(0.4),
                                        width: 1,
                                      ),
                                    ),
                                    child: Icon(
                                      isNamedDevice 
                                          ? Icons.bluetooth_connected 
                                          : Icons.bluetooth_searching,
                                      color: colorScheme.primary,
                                      size: 24,
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  
                                  // Device info
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Flexible(
                                              child: Text(
                                                deviceName,
                                                style: TextStyle(
                                                  fontWeight: FontWeight.w700,
                                                  fontSize: 15,
                                                  color: colorScheme.onSurface,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            if (isNamedDevice) ...[
                                              const SizedBox(width: 6),
                                              Container(
                                                padding: const EdgeInsets.symmetric(
                                                  horizontal: 6,
                                                  vertical: 2,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: colorScheme.primary.withOpacity(0.2),
                                                  borderRadius: BorderRadius.circular(4),
                                                ),
                                                child: Text(
                                                  'NAMED',
                                                  style: TextStyle(
                                                    fontSize: 9,
                                                    fontWeight: FontWeight.w800,
                                                    letterSpacing: 0.5,
                                                    color: colorScheme.primary,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                        if (deviceAddress.isNotEmpty) ...[
                                          const SizedBox(height: 4),
                                          Row(
                                            children: [
                                              Icon(
                                                Icons.place,
                                                size: 12,
                                                color: colorScheme.onSurface.withOpacity(0.5),
                                              ),
                                              const SizedBox(width: 4),
                                              Flexible(
                                                child: Text(
                                                  deviceAddress,
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    fontFamily: 'monospace',
                                                    color: colorScheme.onSurface.withOpacity(0.6),
                                                    letterSpacing: 0.5,
                                                  ),
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  
                                  // Arrow
                                  Icon(
                                    Icons.arrow_forward_ios_rounded,
                                    size: 18,
                                    color: colorScheme.primary,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(ColorScheme colorScheme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: colorScheme.onSurface.withOpacity(0.05),
            ),
            child: Icon(
              Icons.search_off_rounded,
              size: 64,
              color: colorScheme.onSurface.withOpacity(0.4),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'No Devices Found',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              'Make sure your device is:\n• Powered on\n• In pairing mode\n• Within range',
              style: TextStyle(
                fontSize: 14,
                height: 1.5,
                color: colorScheme.onSurface.withOpacity(0.6),
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(ColorScheme colorScheme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: colorScheme.error.withOpacity(0.1),
            ),
            child: Icon(
              Icons.error_outline_rounded,
              size: 64,
              color: colorScheme.error,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Scanning Error',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: colorScheme.error,
            ),
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 3, sigmaY: 3),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 24),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: colorScheme.error.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: colorScheme.error.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Text(
                  _errorMessage,
                  style: TextStyle(
                    fontSize: 13,
                    color: colorScheme.onSurface.withOpacity(0.8),
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActions(ColorScheme colorScheme) {
    return Row(
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 3, sigmaY: 3),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: colorScheme.onSurface.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => Navigator.pop(context),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.close_rounded,
                            size: 20,
                            color: colorScheme.onSurface.withOpacity(0.8),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _isScanning ? 'CANCEL' : 'CLOSE',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.5,
                              color: colorScheme.onSurface.withOpacity(0.8),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        if (!_isScanning) ...[
          const SizedBox(width: 12),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 3, sigmaY: 3),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        colorScheme.primary,
                        colorScheme.primary.withOpacity(0.8),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: _retryScan,
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Icon(
                              Icons.refresh_rounded,
                              size: 20,
                              color: Colors.white,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'RETRY',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.5,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
