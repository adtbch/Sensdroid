import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';

/// Application-wide logger utility
/// Provides structured logging with different levels
class AppLogger {
  static final Map<String, Logger> _loggers = {};

  /// Get or create a logger for a specific class/module
  static Logger getLogger(String name) {
    // Enable hierarchical logging untuk non-root loggers
    hierarchicalLoggingEnabled = true;

    return _loggers.putIfAbsent(name, () {
      final logger = Logger(name);

      // Configure logger level (adjust as needed)
      logger.level = Level.ALL;

      // Add a simple listener for development
      logger.onRecord.listen((record) {
        // In dev mode, print to console
        // In production, could send to remote logging service
        final timestamp = record.time.toIso8601String();
        final level = record.level.name.toUpperCase();
        final message = record.message;

        // Simple colored output for terminal
        String prefix;
        switch (record.level) {
          case Level.SEVERE:
            prefix = '\x1B[31m[$level]\x1B[0m'; // Red
            break;
          case Level.WARNING:
            prefix = '\x1B[33m[$level]\x1B[0m'; // Yellow
            break;
          case Level.INFO:
            prefix = '\x1B[36m[$level]\x1B[0m'; // Cyan
            break;
          default:
            prefix = '[$level]';
        }

        // Use debugPrint to avoid `avoid_print` lint — output only in debug builds
        debugPrint('$timestamp $prefix $message');

        // Print stack trace if present
        if (record.stackTrace != null) {
          debugPrint('Stack trace: ${record.stackTrace}');
        }
      });

      return logger;
    });
  }

  /// Clean shutdown (if needed for remote logging services)
  static void dispose() {
    _loggers.clear();
  }
}

/// Extension to add convenient logging to any class
extension LoggerExtension on Object {
  Logger get log => AppLogger.getLogger(runtimeType.toString());
}
