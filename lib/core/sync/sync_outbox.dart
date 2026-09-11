import 'dart:convert';
import 'dart:math';

import 'package:dio/dio.dart';
import 'package:sqflite/sqflite.dart';

import '../network/api_client.dart';
import '../storage/app_database.dart';

class SyncOutboxEntry {
  final int id;
  final String operationKey;
  final int ownerUserId;
  final String method;
  final String path;
  final Map<String, dynamic> body;
  final int attemptCount;
  final String? lastError;

  const SyncOutboxEntry({
    required this.id,
    required this.operationKey,
    required this.ownerUserId,
    required this.method,
    required this.path,
    required this.body,
    required this.attemptCount,
    required this.lastError,
  });

  factory SyncOutboxEntry.fromRow(Map<String, Object?> row) {
    return SyncOutboxEntry(
      id: (row['id'] as num).toInt(),
      operationKey: row['operation_key'] as String,
      ownerUserId: (row['owner_user_id'] as num).toInt(),
      method: row['method'] as String,
      path: row['path'] as String,
      body: Map<String, dynamic>.from(jsonDecode(row['body'] as String) as Map),
      attemptCount: (row['attempt_count'] as num).toInt(),
      lastError: row['last_error'] as String?,
    );
  }
}

class SyncOutbox {
  static final Random _random = Random.secure();

  Future<String> enqueue({
    required String method,
    required String path,
    required Map<String, dynamic> body,
    required int ownerUserId,
    String? operationKey,
    String? lastError,
  }) async {
    if (ownerUserId <= 0) {
      throw StateError('A signed-in user is required to queue an operation.');
    }

    final key = operationKey ?? newOperationKey();
    final now = DateTime.now().toUtc().toIso8601String();
    final db = await AppDatabase.database;
    await db.insert(
      'sync_outbox',
      {
        'operation_key': key,
        'owner_user_id': ownerUserId,
        'method': method.toUpperCase(),
        'path': path,
        'body': jsonEncode(body),
        'status': 'pending',
        'attempt_count': 0,
        'next_attempt_at': now,
        'lease_until': null,
        'last_error': lastError,
        'response_body': null,
        'created_at': now,
        'updated_at': now,
      },
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
    return key;
  }

  Future<SyncOutboxEntry?> claimNext({
    required int ownerUserId,
    Duration leaseDuration = const Duration(minutes: 2),
  }) async {
    if (ownerUserId <= 0) return null;
    final db = await AppDatabase.database;
    final now = DateTime.now().toUtc();
    final nowString = now.toIso8601String();
    final leaseString = now.add(leaseDuration).toIso8601String();

    return db.transaction((txn) async {
      final rows = await txn.rawQuery('''
        SELECT * FROM sync_outbox
        WHERE owner_user_id = ?
          AND (
            (status = 'pending' AND next_attempt_at <= ?)
            OR (status = 'processing' AND (lease_until IS NULL OR lease_until <= ?))
          )
        ORDER BY created_at ASC, id ASC
        LIMIT 1
      ''', [ownerUserId, nowString, nowString]);
      if (rows.isEmpty) return null;

      final row = rows.first;
      final id = (row['id'] as num).toInt();
      await txn.update(
        'sync_outbox',
        {
          'status': 'processing',
          'lease_until': leaseString,
          'updated_at': nowString,
        },
        where: 'id = ?',
        whereArgs: [id],
      );
      return SyncOutboxEntry.fromRow({
        ...row,
        'status': 'processing',
        'lease_until': leaseString,
      });
    });
  }

  Future<void> markSucceeded(int id, {String? responseBody}) async {
    final db = await AppDatabase.database;
    final now = DateTime.now().toUtc().toIso8601String();
    await db.update(
      'sync_outbox',
      {
        'status': 'completed',
        'lease_until': null,
        'last_error': null,
        'response_body': responseBody,
        'updated_at': now,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> markRetry(
    SyncOutboxEntry entry, {
    required String error,
  }) async {
    final db = await AppDatabase.database;
    final attempt = entry.attemptCount + 1;
    final seconds = min(3600, 2 * (1 << min(attempt, 10)));
    final nextAttempt = DateTime.now().toUtc().add(Duration(seconds: seconds));
    await db.update(
      'sync_outbox',
      {
        'status': 'pending',
        'attempt_count': attempt,
        'next_attempt_at': nextAttempt.toIso8601String(),
        'lease_until': null,
        'last_error': error.length > 1000 ? error.substring(0, 1000) : error,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [entry.id],
    );
  }

  Future<void> markPermanentFailure(
    SyncOutboxEntry entry, {
    required String error,
  }) async {
    final db = await AppDatabase.database;
    await db.update(
      'sync_outbox',
      {
        'status': 'failed',
        'lease_until': null,
        'last_error': error.length > 1000 ? error.substring(0, 1000) : error,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [entry.id],
    );
  }

  Future<void> cleanupCompleted({Duration retention = const Duration(days: 14)}) async {
    final db = await AppDatabase.database;
    final cutoff = DateTime.now().toUtc().subtract(retention).toIso8601String();
    await db.delete(
      'sync_outbox',
      where: "status = 'completed' AND updated_at < ?",
      whereArgs: [cutoff],
    );
  }

  Future<int> pendingCount({int? ownerUserId}) async {
    final db = await AppDatabase.database;
    final where = ownerUserId == null
        ? "status IN ('pending', 'processing')"
        : "owner_user_id = ? AND status IN ('pending', 'processing')";
    final rows = await db.rawQuery(
      'SELECT COUNT(*) AS count FROM sync_outbox WHERE $where',
      ownerUserId == null ? null : [ownerUserId],
    );
    return (rows.first['count'] as num).toInt();
  }

  static String newOperationKey() {
    final timestamp = DateTime.now().toUtc().microsecondsSinceEpoch;
    final randomPart = _random.nextInt(1 << 32).toRadixString(16);
    return 'flutter-$timestamp-$randomPart';
  }
}

class ReliableCommandResult {
  final bool completed;
  final bool queued;
  final String operationKey;
  final Map<String, dynamic>? response;

  const ReliableCommandResult({
    required this.completed,
    required this.queued,
    required this.operationKey,
    required this.response,
  });
}

class QueuedOperationException implements Exception {
  final String operationKey;
  final String message;

  const QueuedOperationException(
    this.operationKey, [
    this.message = 'Operation saved locally and queued for synchronization.',
  ]);

  @override
  String toString() => message;
}

class ReliableCommandClient {
  final ApiClient client;
  final SyncOutbox outbox;
  final Future<void> Function()? refreshSession;

  const ReliableCommandClient({
    required this.client,
    required this.outbox,
    this.refreshSession,
  });

  Future<ReliableCommandResult> post(
    String path,
    Map<String, dynamic> body, {
    String? operationKey,
  }) async {
    final key = operationKey ?? SyncOutbox.newOperationKey();
    var refreshed = false;

    while (true) {
      try {
        final response = await client.dio.post(
          path,
          data: body,
          options: Options(headers: {'Idempotency-Key': key}),
        );
        final payload = response.data is Map
            ? Map<String, dynamic>.from(response.data as Map)
            : <String, dynamic>{};
        return ReliableCommandResult(
          completed: true,
          queued: false,
          operationKey: key,
          response: payload,
        );
      } on DioException catch (error) {
        if (error.response?.statusCode == 401 && !refreshed && refreshSession != null) {
          refreshed = true;
          try {
            await refreshSession!.call();
            continue;
          } catch (_) {
            final ownerUserId = await client.currentUserId;
            if (ownerUserId != null) {
              await outbox.enqueue(
                method: 'POST',
                path: path,
                body: body,
                ownerUserId: ownerUserId,
                operationKey: key,
                lastError: 'Authentication refresh failed; operation is waiting for the owning user session.',
              );
              return ReliableCommandResult(
                completed: false,
                queued: true,
                operationKey: key,
                response: null,
              );
            }
          }
        }

        if (error.response?.statusCode == 401) {
          rethrow;
        }
        if (!_isTransientNetworkOrServerError(error)) rethrow;

        final ownerUserId = await client.currentUserId;
        if (ownerUserId == null) rethrow;
        await outbox.enqueue(
          method: 'POST',
          path: path,
          body: body,
          ownerUserId: ownerUserId,
          operationKey: key,
          lastError: error.message,
        );
        return ReliableCommandResult(
          completed: false,
          queued: true,
          operationKey: key,
          response: null,
        );
      }
    }
  }

  bool _isTransientNetworkOrServerError(DioException error) {
    if (error.response == null) return true;
    final status = error.response?.statusCode ?? 0;
    return status == 408 ||
        status == 425 ||
        status == 429 ||
        status == 500 ||
        status == 502 ||
        status == 503 ||
        status == 504;
  }
}
