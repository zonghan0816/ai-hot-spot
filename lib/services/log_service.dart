
import 'dart:io';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';

class LogService {
  static final LogService _instance = LogService._internal();
  factory LogService() => _instance;
  LogService._internal();

  static const String _logFileName = 'app_log.txt';

  Future<File> get _logFile async {
    final directory = await getApplicationDocumentsDirectory();
    return File('${directory.path}/$_logFileName');
  }

  Future<void> log(String message) async {
    final timestamp = DateTime.now().toIso8601String();
    final logMessage = '$timestamp: $message\n';

    if (kDebugMode) {
      print(message);
    }

    // Log to Crashlytics
    FirebaseCrashlytics.instance.log(message);

    // Write to local file
    try {
      final file = await _logFile;
      await file.writeAsString(logMessage, mode: FileMode.append);
    } catch (e) {
      FirebaseCrashlytics.instance.recordError(
        e,
        null,
        reason: 'Failed to write to log file',
      );
    }
  }
  
  Future<void> logError(dynamic error, StackTrace? stackTrace, {String? reason}) async {
    final timestamp = DateTime.now().toIso8601String();
    final logMessage = '$timestamp: [ERROR] ${reason ?? 'Unknown reason'}\n$error\n$stackTrace\n';

    if (kDebugMode) {
      print(logMessage);
    }

    // Log to Crashlytics
    FirebaseCrashlytics.instance.recordError(
      error,
      stackTrace,
      reason: reason,
    );

    // Write to local file
    try {
      final file = await _logFile;
      await file.writeAsString(logMessage, mode: FileMode.append);
    } catch (e) {
      // Also log the failure to write the log
       FirebaseCrashlytics.instance.recordError(
        e,
        null,
        reason: 'Failed to write ERROR to log file',
      );
    }
  }

  Future<String> getLogs() async {
    try {
      final file = await _logFile;
      if (await file.exists()) {
        return await file.readAsString();
      }
      return 'Log file does not exist.';
    } catch (e) {
      logError(e, StackTrace.current, reason: 'Failed to read log file');
      return 'Error reading log file: $e';
    }
  }

  Future<void> clearLogs() async {
    try {
      final file = await _logFile;
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
       logError(e, StackTrace.current, reason: 'Failed to clear log file');
    }
  }
}
