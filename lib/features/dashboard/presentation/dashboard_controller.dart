import 'package:flutter/foundation.dart';

import '../domain/dashboard_repository.dart';
import '../domain/dashboard_snapshot.dart';

enum DashboardStatus { initial, loading, ready, error }

class DashboardController extends ChangeNotifier {
  final DashboardRepository repository;

  DashboardStatus _status = DashboardStatus.initial;
  DashboardSnapshot? _snapshot;
  String? _errorMessage;

  DashboardController({required this.repository});

  DashboardStatus get status => _status;
  DashboardSnapshot? get snapshot => _snapshot;
  String? get errorMessage => _errorMessage;

  Future<void> load() async {
    _status = DashboardStatus.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      final loadedSnapshot = await repository.loadSnapshot();
      _snapshot = loadedSnapshot;
      _status = DashboardStatus.ready;
    } catch (_) {
      _status = DashboardStatus.error;
      _errorMessage = 'Unable to load dashboard data.';
    }
    notifyListeners();
  }
}
