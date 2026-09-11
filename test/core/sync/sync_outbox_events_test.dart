import 'package:flutter_test/flutter_test.dart';

import '../../../lib/core/sync/sync_outbox_events.dart';

void main() {
  test('decodes a valid conflict response', () {
    final event = SyncOutboxConflictEvent.fromResponse(
      outboxId: 7,
      operationKey: 'flutter-test-7',
      method: 'POST',
      path: '/invoices/1/confirm/',
      message: 'Invoice changed on the server.',
      responseBody: '{"detail":"Invoice changed on the server."}',
    );

    expect(event.outboxId, 7);
    expect(event.operationKey, 'flutter-test-7');
    expect(event.message, 'Invoice changed on the server.');
    expect(event.response?['detail'], 'Invoice changed on the server.');
  });

  test('treats malformed stored response as absent', () {
    final event = SyncOutboxConflictEvent.fromResponse(
      outboxId: 8,
      operationKey: 'flutter-test-8',
      method: 'POST',
      path: '/invoices/2/confirm/',
      message: 'Conflict',
      responseBody: '{not-json',
    );

    expect(event.response, isNull);
  });
}
