import 'package:flutter/foundation.dart';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'api_config.dart';

/// Operational mode for data handling inside the application.
///
/// The app can run fully from the local database (SQLite), fetch/post via API,
/// or combine both (hybrid). This mode is preserved across application restarts.
enum DataMode { local, api, hybrid }

/// Manages the current data mode and notifies listeners for UI updates.
class DataModeController extends ChangeNotifier {
  static const _fileName = 'sales_erp_data_mode.txt';

  DataMode _mode = ApiConfig.defaultDataMode;

  DataMode get mode => _mode;

  /// Local or hybrid modes allow offline access without requiring a server.
  bool get offlineAllowed => _mode != DataMode.api;

  Future<File> _file() async {
    final dir = await getApplicationSupportDirectory();
    return File('${dir.path}/$_fileName');
  }

  /// Load the persisted mode, defaulting to the configured server-backed mode.
  Future<void> load() async {
    try {
      final file = await _file();
      if (await file.exists()) {
        final saved = await file.readAsString();
        _mode = DataMode.values.firstWhere(
          (mode) => mode.name == saved,
          orElse: () => ApiConfig.defaultDataMode,
        );
      } else {
        _mode = ApiConfig.defaultDataMode;
      }
    } catch (_) {
      _mode = ApiConfig.defaultDataMode;
    }
    notifyListeners();
  }

  Future<void> setMode(DataMode mode) async {
    if (_mode == mode) return;
    _mode = mode;
    notifyListeners();
    try {
      final file = await _file();
      await file.writeAsString(mode.name);
    } catch (_) {
      // Ignore persistence errors; the selected mode remains active in memory.
    }
  }
}
