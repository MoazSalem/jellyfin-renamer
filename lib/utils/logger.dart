import 'dart:async';

import 'package:logging/logging.dart';

/// Application logger that wraps the Dart logging package.
class AppLogger {
  /// Creates a new application logger instance.
  ///
  /// [verbose] - If true, enables all log levels.
  /// Otherwise, only INFO and above.
  AppLogger({this.verbose = false}) : _logger = Logger('renamer') {
    if (_subscription == null) {
      hierarchicalLoggingEnabled = true;
      _subscription = _logger.onRecord.listen((record) {
        print('${record.level.name}: ${record.message}');
      });
    }
    _logger.level = verbose ? Level.ALL : Level.INFO;
  }

  static StreamSubscription<LogRecord>? _subscription;
  final Logger _logger;

  /// Whether to enable verbose logging.
  final bool verbose;

  /// Logs an info message.
  void info(String message) {
    _logger.info(message);
  }

  /// Logs a warning message.
  void warning(String message) {
    _logger.warning(message);
  }

  /// Logs an error message.
  void error(String message) {
    _logger.severe(message);
  }

  /// Logs a debug message (only when verbose mode is enabled).
  void debug(String message) {
    if (verbose) {
      _logger.fine(message);
    }
  }
}
