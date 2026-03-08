import 'package:flutter/material.dart';

/// Dialog untuk menampilkan error message dengan detail dan opsi retry
class ErrorDialog extends StatefulWidget {
  final String title;
  final String message;
  final String? detail;
  final VoidCallback? onRetry;
  final VoidCallback? onDismiss;

  const ErrorDialog({
    super.key,
    required this.title,
    required this.message,
    this.detail,
    this.onRetry,
    this.onDismiss,
  });

  @override
  State<ErrorDialog> createState() => _ErrorDialogState();
}

class _ErrorDialogState extends State<ErrorDialog> {
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.error, color: Colors.red, size: 30),
          const SizedBox(width: 12),
          Text(widget.title),
        ],
      ),
      content: SingleChildScrollView(
        child: ListBody(
          children: [
            Text(widget.message),
            if (widget.detail != null && widget.detail!.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                'Details:',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                widget.detail!,
                style: TextStyle(
                  fontSize: 12,
                  fontFamily: 'monospace',
                  color: Colors.grey[600],
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        if (widget.onRetry != null) ...[
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              widget.onRetry?.call();
            },
            child: const Text('Retry'),
          ),
        ],
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
            widget.onDismiss?.call();
          },
          child: const Text('Dismiss'),
        ),
      ],
    );
  }
}

/// Helper untuk menampilkan error dialog dengan mudah
class ErrorDialogHelper {
  static Future<void> showErrorDialog(
    BuildContext context,
    String title,
    String message, {
    String? detail,
    VoidCallback? onRetry,
    VoidCallback? onDismiss,
  }) async {
    await showDialog(
      context: context,
      builder: (context) => ErrorDialog(
        title: title,
        message: message,
        detail: detail,
        onRetry: onRetry,
        onDismiss: onDismiss,
      ),
    );
  }

  /// Menampilkan error dialog untuk lastError di SensorViewModel
  static Future<void> showSensorErrorDialog(
    BuildContext context,
    String lastError, {
    VoidCallback? onRetry,
  }) async {
    await showErrorDialog(
      context,
      'Sensor Error',
      'An error occurred during sensor transmission:',
      detail: lastError,
      onRetry: onRetry,
    );
  }
}
