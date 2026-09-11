import 'dart:convert';

import 'package:flutter/foundation.dart';

Map<String, dynamic>? _decodeResponse(String? responseBody) {
  if (responseBody == null || responseBody.isEmpty) return null;
  try {
    final decoded = jsonDecode(responseBody);
    if (decoded is Map) return Map<String, dynamic>.from(decoded);
  } catch (_) {
    return null;
  }
  return null;
}

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
    return SyncOutboxSuccessEvent(
      outboxId: outboxId,
      operationKey: operationKey,
      method: method,
      path: path,
      response: _decodeResponse(responseBody),
    );
  }
}

class SyncOutboxConflictEvent {
  final int outboxId;
  final String operationKey;
  final String method;
  final String path;
  final String message;
  final Map<String, dynamic>? response;

  const SyncOutboxConflictEvent({
    required this.outboxId,
    required this.operationKey,
    required this.method,
    required this.path,
    required this.message,
    required this.response,
  });

  factory SyncOutboxConflictEvent.fromResponse({
    required int outboxId,
    required String operationKey,
    required String method,
    required String path,
    required String message,
    String? responseBody,
  }) {
    return SyncOutboxConflictEvent(
      outboxId: outboxId,
      operationKey: operationKey,
      method: method,
      path: path,
      message: message,
      response: _decodeResponse(responseBody),
    );
  }
}

class SyncOutboxEventBus extends ChangeNotifier {
  SyncOutboxEventBus._();

  static final SyncOutboxEventBus instance = SyncOutboxEventBus._();

  SyncOutboxSuccessEvent? _lastSuccess;
  SyncOutboxConflictEvent? _lastConflict;

  SyncOutboxSuccessEvent? get lastSuccess => _lastSuccess;
  SyncOutboxConflictEvent? get lastConflict => _lastConflict;

  void emitSuccess(SyncOutboxSuccessEvent event) {
    _lastSuccess = event;
    notifyListeners();
  }

  void emitConflict(SyncOutboxConflictEvent event) {
    _lastConflict = event;
    notifyListeners();
  }
}
