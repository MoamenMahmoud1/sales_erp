import 'dart:convert';

import 'package:dio/dio.dart';

import '../network/api_client.dart';
import 'sync_outbox.dart';

class SyncOutboxProcessor {
  final ApiClient client;
  final SyncOutbox outbox;
  final Future<void> Function()? refreshSession;

  const SyncOutboxProcessor({
    required this.client,
    required this.outbox,
    this.refreshSession,
  });

  Future<void> flush({int maxOperations = 25}) async {
    final ownerUserId = await client.currentUserId;
    if (ownerUserId == null || ownerUserId <= 0) return;

    for (var index = 0; index < maxOperations; index++) {
      final entry = await outbox.claimNext(ownerUserId: ownerUserId);
      if (entry == null) break;

      final result = await _send(entry);
      switch (result.kind) {
        case _SendKind.success:
          await outbox.markSucceeded(
            entry.id,
            responseBody: result.responseBody,
          );
        case _SendKind.retry:
          await outbox.markRetry(
            entry,
            error: result.error ?? 'Transient network error.',
          );
        case _SendKind.permanent:
          await outbox.markPermanentFailure(
            entry,
            error: result.error ?? 'Permanent server error.',
          );
      }

      if (result.kind == _SendKind.retry) break;
    }

    await outbox.cleanupCompleted();
  }

  Future<_SendResult> _send(SyncOutboxEntry entry) async {
    var refreshed = false;

    while (true) {
      try {
        final response = await client.dio.request<dynamic>(
          entry.path,
          data: entry.body,
          options: Options(
            method: entry.method,
            headers: {
              'Idempotency-Key': entry.operationKey,
            },
          ),
        );
        return _SendResult.success(
          response.data == null ? null : jsonEncode(response.data),
        );
      } on DioException catch (error) {
        if (error.response?.statusCode == 401 &&
            !refreshed &&
            refreshSession != null) {
          refreshed = true;
          try {
            await refreshSession!.call();
            continue;
          } catch (_) {
            return _SendResult.retry('Authentication refresh failed; will retry after the user session is restored.');
          }
        }

        if (_isTransient(error)) {
          return _SendResult.retry(_describe(error));
        }

        return _SendResult.permanent(
          _describe(error),
        );
      } catch (error) {
        return _SendResult.retry('$error');
      }
    }
  }

  bool _isTransient(DioException error) {
    return switch (error.type) {
      DioExceptionType.connectionTimeout ||
      DioExceptionType.sendTimeout ||
      DioExceptionType.receiveTimeout ||
      DioExceptionType.connectionError => true,
      _ => error.response == null,
    };
  }

  String _describe(DioException error) {
    final status = error.response?.statusCode;
    final detail = error.response?.data;
    if (detail is Map && detail['detail'] != null) {
      return status == null
          ? detail['detail'].toString()
          : 'HTTP $status: ${detail['detail']}';
    }
    return status == null
        ? (error.message ?? error.type.name)
        : 'HTTP $status';
  }
}

enum _SendKind { success, retry, permanent }

class _SendResult {
  final _SendKind kind;
  final String? responseBody;
  final String? error;

  const _SendResult._(this.kind, this.responseBody, this.error);

  factory _SendResult.success(String? body) =>
      _SendResult._(_SendKind.success, body, null);

  factory _SendResult.retry(String error) =>
      _SendResult._(_SendKind.retry, null, error);

  factory _SendResult.permanent(String error) =>
      _SendResult._(_SendKind.permanent, null, error);
}
