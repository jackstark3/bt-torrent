import 'package:flutter/foundation.dart';

/// 简单日志工具
enum LogLevel { debug, info, warning, error }

class AppLogger {
  final String tag;
  static LogLevel _minLevel = kDebugMode ? LogLevel.debug : LogLevel.info;

  AppLogger(this.tag);

  static void setLogLevel(LogLevel level) {
    _minLevel = level;
  }

  void debug(String message) => _log(LogLevel.debug, message);
  void info(String message) => _log(LogLevel.info, message);
  void warning(String message) => _log(LogLevel.warning, message);
  void error(String message, [Object? error, StackTrace? stack]) =>
      _log(LogLevel.error, message, error, stack);

  void _log(LogLevel level, String message, [Object? error, StackTrace? stack]) {
    if (level.index < _minLevel.index) return;

    final prefix = switch (level) {
      LogLevel.debug => '🐛',
      LogLevel.info => '📘',
      LogLevel.warning => '⚠️',
      LogLevel.error => '❌',
    };

    final log = '[$prefix $tag] $message';
    switch (level) {
      case LogLevel.debug:
        debugPrint(log);
      case LogLevel.info:
        debugPrint(log);
      case LogLevel.warning:
        debugPrint(log);
      case LogLevel.error:
        debugPrint('$log ${error ?? ''} ${stack ?? ''}');
    }
  }
}
