import 'package:flutter/foundation.dart';

import 'data_mode.dart';

/// Configuration settings for the API and operational modes.
class ApiConfig {
  static const _configuredBaseUrl = String.fromEnvironment('API_BASE_URL');
  static const _developmentBaseUrl = 'http://127.0.0.1:8000/api/v1';

  static String get baseUrl {
    final configured = _configuredBaseUrl.trim();
    if (configured.isNotEmpty) {
      return configured.replaceFirst(RegExp(r'/+$'), '');
    }
    if (kReleaseMode) {
      throw StateError('API_BASE_URL must be provided for release builds.');
    }
    return _developmentBaseUrl;
  }

  /// Hybrid is the default: Django remains authoritative while cached local data
  /// and durable offline commands keep the mobile client usable during outages.
  static const DataMode defaultDataMode = DataMode.hybrid;

  const ApiConfig._();
}
