import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// USB serial device scanner dialog.
class DeviceScanDialog extends StatefulWidget {
  final Future<List<String>> Function() onScan;

  const DeviceScanDialog({super.key, required this.onScan});

  @override
  State<DeviceScanDialog> createState() => _DeviceScanDialogState();
}

class _DeviceScanDialogState extends State<DeviceScanDialog>
    with SingleTickerProviderStateMixin {
  bool _isScanning = false;
  String? _error;
  List<String> _devices = [];
  late AnimationController _listAnimCtrl;

  @override
  void initState() {
    super.initState();
    _listAnimCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _scan();
  }

  @override
  void dispose() {
    _listAnimCtrl.dispose();
    super.dispose();
  }

  Future<void> _scan() async {
    setState(() {
      _isScanning = true;
      _error = null;
      _devices = [];
      _listAnimCtrl.reset();
    });

    try {
      final devices = await widget.onScan();
      if (!mounted) return;
      setState(() {
        _devices = devices;
        _isScanning = false;
      });
      if (devices.isNotEmpty) _listAnimCtrl.forward();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isScanning = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Dialog(
      backgroundColor: Colors.transparent,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 420, maxHeight: 520),
            decoration: BoxDecoration(
              color: cs.surfaceContainer.withOpacity(0.92),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: cs.primary.withOpacity(0.2),
                width: 1,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ─── Header ─────────────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 12, 0),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: cs.primary.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          Icons.usb_rounded,
                          color: cs.primary,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'USB Serial Scanner',
                              style: GoogleFonts.inter(
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                                color: cs.onSurface,
                              ),
                            ),
                            Text(
                              'Select your ESP USB UART port',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                color: cs.onSurfaceVariant,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: Icon(
                          Icons.close_rounded,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Divider(height: 1, color: cs.outline.withOpacity(0.12)),
                // ─── Body ────────────────────────────────────────────────────
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    child: _buildBody(cs),
                  ),
                ),
                // ─── Footer ──────────────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _isScanning ? null : _scan,
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      icon: _isScanning
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.refresh_rounded, size: 18),
                      label: Text(
                        _isScanning ? 'Scanning...' : 'Rescan Devices',
                        style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody(ColorScheme cs) {
    if (_isScanning) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 48,
              height: 48,
              child: CircularProgressIndicator(
                color: cs.primary,
                strokeWidth: 3,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Scanning USB devices...',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: cs.onSurface,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Make sure USB OTG is enabled',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: cs.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cs.errorContainer.withOpacity(0.3),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.usb_off_rounded,
                size: 40,
                color: cs.error,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Scan Failed',
              style: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: cs.error,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _error!,
              style: GoogleFonts.inter(
                fontSize: 12,
                color: cs.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    if (_devices.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest.withOpacity(0.5),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.cable_rounded,
                size: 44,
                color: cs.onSurface.withOpacity(0.2),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'No Devices Found',
              style: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: cs.onSurface.withOpacity(0.5),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Connect your ESP via USB OTG cable\nand tap Rescan',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: cs.onSurfaceVariant.withOpacity(0.6),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return FadeTransition(
      opacity: _listAnimCtrl,
      child: ListView.separated(
        itemCount: _devices.length,
        separatorBuilder: (context, index) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final encoded = _devices[index];
          final parts = encoded.split('||');
          final deviceName = parts.first;
          final address = parts.length > 1 ? parts.last : '-';

          return Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () => Navigator.of(context).pop(encoded),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest.withOpacity(0.35),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: cs.outline.withOpacity(0.15),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: cs.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.memory_rounded,
                        color: cs.primary,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            deviceName,
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              color: cs.onSurface,
                            ),
                          ),
                          Text(
                            address,
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 11,
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 14,
                      color: cs.onSurfaceVariant,
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
