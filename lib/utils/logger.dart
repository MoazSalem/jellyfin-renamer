import 'package:logging/logging.dart';

/// Application logger that wraps the Dart logging package.
class AppLogger {
  /// Creates a new application logger instance.
  AppLogger({String name = 'MediaRenamer'}) : _logger = Logger(name);

  final Logger _logger;

  /// Logs an info message.
  void info(String message) {
    _logger.info(message);
  }

  /// Logs a warning message.
  void warning(String message) {
    _logger.warning(message);
  }

  /// Logs an error message.
  void error(String message, [Object? error, StackTrace? stackTrace]) =>
      _logger.severe(message, error, stackTrace);

  /// Logs a debug message.
  void debug(String message) {
    _logger.fine(message);
  }
}
