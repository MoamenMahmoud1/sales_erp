import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'data_mode.dart';

/// Configuration settings for the API and operational modes.
class ApiConfig {
  static const String fallbackBaseUrl = 'http://127.0.0.1:8000/api/v1';

  static String get baseUrl {
    final configuredBaseUrl = dotenv.maybeGet('API_BASE_URL')?.trim();
    if (configuredBaseUrl == null || configuredBaseUrl.isEmpty) {
      return fallbackBaseUrl;
    }

    return configuredBaseUrl.replaceFirst(RegExp(r'/+$'), '');
  }

  /// Server-backed mode is the default so authentication and RBAC come from Django.
  static const DataMode defaultDataMode = DataMode.api;

  const ApiConfig._();
}
