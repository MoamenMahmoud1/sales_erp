import 'dart:convert';

import 'package:flutter/foundation.dart';

class SyncOutboxSuccessEvent {
  final int outboxId;
  final String operationKey;
  final String method;
  final String path;
  final Map<String, dynamic>? response;

  const SyncOutboxSuccessEvent({
    required this.outboxId,
    required this.operationKey,
    required this.method,
    required this.path,
    required this.response,
  });

  factory SyncOutboxSuccessEvent.fromResponse({
    required int outboxId,
    required String operationKey,
    required String method,
    required String path,
    String? responseBody,
  }) {
    Map<String, dynamic>? response;
    if (responseBody != null && responseBody.isNotEmpty) {
      final decoded = jsonDecode(responseBody);
      if (decoded is Map) {
        response = Map<String, dynamic>.from(decoded);
      }
    }
    return SyncOutboxSuccessEvent(
      outboxId: outboxId,
      operationKey: operationKey,
      method: method,
      path: path,
      response: response,
    );
  }
}

class SyncOutboxEventBus extends ChangeNotifier {
  SyncOutboxEventBus._();

  static final SyncOutboxEventBus instance = SyncOutboxEventBus._();

  SyncOutboxSuccessEvent? _lastSuccess;

  SyncOutboxSuccessEvent? get lastSuccess => _lastSuccess;

  void emitSuccess(SyncOutboxSuccessEvent event) {
    _lastSuccess = event;
    notifyListeners();
  }
}
