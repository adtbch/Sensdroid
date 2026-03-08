import 'package:flutter/material.dart';
import 'package:sensdroid/core/app_settings.dart';

/// Dialog for configuring WiFi endpoint settings
/// Allows user to specify host, port, and endpoint path
class WiFiEndpointConfigDialog extends StatefulWidget {
  final AppSettings settings;

  const WiFiEndpointConfigDialog({
    super.key,
    required this.settings,
  });

  @override
  State<WiFiEndpointConfigDialog> createState() => _WiFiEndpointConfigDialogState();
}

class _WiFiEndpointConfigDialogState extends State<WiFiEndpointConfigDialog> {
  final TextEditingController _hostController = TextEditingController();
  final TextEditingController _portController = TextEditingController();
  final TextEditingController _endpointController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Load current settings
    final host = widget.settings.wifiEndpoint.split(':').first;
    final port = widget.settings.wifiPort;
    final endpoint = widget.settings.wifiEndpoint;
    
    _hostController.text = host;
    _portController.text = port.toString();
    _endpointController.text = endpoint;
  }

  @override
  void dispose() {
    _hostController.dispose();
    _portController.dispose();
    _endpointController.dispose();
    super.dispose();
  }

  Future<void> _saveSettings() async {
    try {
      final host = _hostController.text.trim();
      final portStr = _portController.text.trim();
      final endpoint = _endpointController.text.trim();

      if (host.isEmpty || endpoint.isEmpty) {
        _showError('Host and endpoint cannot be empty');
        return;
      }

      final port = int.tryParse(portStr) ?? 8080;
      if (port < 1 || port > 65535) {
        _showError('Port must be between 1 and 65535');
        return;
      }

      // Update settings
      widget.settings.wifiPort = port;
      widget.settings.wifiEndpoint = 'http://$host:$port$endpoint';

      // Show success
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('WiFi settings saved successfully'),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.of(context).pop();
    } catch (e) {
      _showError('Failed to save settings: $e');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Error: $message'),
        backgroundColor: Colors.red,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('WiFi Endpoint Configuration'),
      content: SingleChildScrollView(
        child: ListBody(
          children: [
            const Text(
              'Configure the endpoint where sensor data will be sent:',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            
            TextField(
              controller: _hostController,
              decoration: const InputDecoration(
                labelText: 'Host (IP address or hostname)',
                hintText: 'e.g., 192.168.1.100',
              ),
              keyboardType: TextInputType.text,
            ),
            const SizedBox(height: 8),
            
            TextField(
              controller: _portController,
              decoration: const InputDecoration(
                labelText: 'Port',
                hintText: 'e.g., 8080',
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 8),
            
            TextField(
              controller: _endpointController,
              decoration: const InputDecoration(
                labelText: 'Endpoint Path',
                hintText: 'e.g., /sensor-data',
              ),
              keyboardType: TextInputType.text,
            ),
            
            const SizedBox(height: 16),
            const Text(
              'Note: This will be used to construct the URL: http://host:port/endpoint',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: _saveSettings,
          child: const Text('Save'),
        ),
      ],
    );
  }
}
