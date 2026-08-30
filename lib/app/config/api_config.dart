import 'data_mode.dart';

/// Configuration settings for the API and operational modes.
class ApiConfig {
  static const baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://127.0.0.1:8000/api/v1',
  );

  /// The default operational data mode strictly set to local (100% offline).
  static const DataMode defaultDataMode = DataMode.local;

  const ApiConfig._();
}
