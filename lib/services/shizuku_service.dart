import 'package:shizuku_api/shizuku_api.dart';

class ShizukuService {
  final ShizukuApi _shizuku = ShizukuApi();
  bool _isAvailable = false;
  bool _hasPermission = false;

  bool get isAvailable => _isAvailable;
  bool get hasPermission => _hasPermission;

  /// Check if Shizuku is installed and running
  Future<bool> checkAvailability() async {
    try {
      _isAvailable = await _shizuku.pingBinder() ?? false;
      if (_isAvailable) {
        _hasPermission = await _shizuku.checkPermission() ?? false;
      }
      return _isAvailable;
    } catch (e) {
      _isAvailable = false;
      _hasPermission = false;
      return false;
    }
  }

  /// Request Shizuku permission
  Future<bool> requestPermission() async {
    if (!_isAvailable) return false;
    try {
      _hasPermission = await _shizuku.requestPermission() ?? false;
      return _hasPermission;
    } catch (e) {
      return false;
    }
  }

  /// Shell commands the agent is allowed to run.
  ///
  /// The LLM decides these strings, and screen text can try to steer it, so
  /// anything outside this list is refused instead of executed.
  static const List<String> allowedCommandPrefixes = [
    'svc wifi',
    'svc data',
    'svc bluetooth',
    'cmd bluetooth_manager',
    'cmd media_session',
    'am force-stop',
    'am start',
    'input keyevent',
    'input tap',
    'input swipe',
    'input text',
    'settings get',
    'settings put',
    'dumpsys',
    'wm size',
    'wm density',
    'media volume',
    'getprop',
    'pidof',
  ];

  static bool isAllowed(String command) {
    final c = command.trim().toLowerCase();
    if (c.isEmpty) return false;
    return allowedCommandPrefixes.any(c.startsWith);
  }

  /// Run an ADB shell command via Shizuku
  Future<String> runCommand(String command) async {
    if (!isAllowed(command)) {
      return 'Blocked: "$command" is not in the Shizuku command allowlist.';
    }
    if (!_isAvailable) {
      return 'Shizuku is not running. Please start Shizuku first.';
    }
    if (!_hasPermission) {
      final granted = await requestPermission();
      if (!granted) {
        return 'Shizuku permission denied.';
      }
    }

    try {
      final result = await _shizuku.runCommand(command);
      return result ?? 'Command executed (no output)';
    } catch (e) {
      return 'Error running command: $e';
    }
  }

  /// Toggle WiFi via Shizuku
  Future<String> toggleWifi(bool enable) async {
    return runCommand('svc wifi ${enable ? 'enable' : 'disable'}');
  }

  /// Toggle Bluetooth via Shizuku
  Future<String> toggleBluetooth(bool enable) async {
    return runCommand(
      'cmd bluetooth_manager ${enable ? 'enable' : 'disable'}',
    );
  }

  /// Force stop an app
  Future<String> forceStopApp(String packageName) async {
    return runCommand('am force-stop $packageName');
  }

  /// Clear app data
  Future<String> clearAppData(String packageName) async {
    return runCommand('pm clear $packageName');
  }
}
