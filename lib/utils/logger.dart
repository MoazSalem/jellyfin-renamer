import 'dart:async';
import 'package:logging/logging.dart';

class AppLogger {
  static StreamSubscription? _subscription;
  final Logger _logger;
  final bool verbose;

  AppLogger({this.verbose = false}) : _logger = Logger('renamer') {
    if (_subscription == null) {
      hierarchicalLoggingEnabled = true;
      _subscription = _logger.onRecord.listen((record) {
        print('${record.level.name}: ${record.message}');
      });
    }
    _logger.level = verbose ? Level.ALL : Level.INFO;
  }

  void info(String message) {
    _logger.info(message);
  }

  void warning(String message) {
    _logger.warning(message);
  }

  void error(String message) {
    _logger.severe(message);
  }

  void debug(String message) {
    if (verbose) {
      _logger.fine(message);
    }
  }
}