import '../../../core/network/api_client.dart';
import '../../../core/sync/sync_outbox.dart';
import '../../../core/repositories/app_services.dart';
import '../domain/entities/approval_request.dart';
import '../domain/repositories/approval_repository.dart';

class DioApprovalRepository implements ApprovalRepository {
  final ApiClient client;

  const DioApprovalRepository(this.client);

  ReliableCommandClient get _commands => ReliableCommandClient(
        client: client,
        outbox: SyncOutbox(),
        refreshSession: AppServices.instance.authRepository.refresh,
      );

  @override
  Future<List<ApprovalRequest>> fetchPendingApprovals() async {
    final response = await client.dio.get('/approvals/');
    final rows = response.data is Map<String, dynamic>
        ? (response.data['results'] as List? ?? const [])
        : const [];

    return [
      for (final item in rows)
        if (item is Map) _mapRequest(Map<String, dynamic>.from(item)),
    ];
  }

  @override
  Future<ApprovalReviewResult> reviewApproval({
    required int approvalRequestId,
    required String decision,
    String reason = '',
  }) async {
    final result = await _commands.post(
      '/approvals/$approvalRequestId/$decision/',
      {'reason': reason},
    );

    return ApprovalReviewResult(
      queued: result.queued,
      operationKey: result.operationKey,
      response: result.response,
    );
  }

  ApprovalRequest _mapRequest(Map<String, dynamic> row) {
    final payload = row['payload'];
    return ApprovalRequest(
      id: _readInt(row['id']),
      status: _readString(row['status']),
      targetType: _readString(row['target_type']),
      targetId: _readInt(row['target_id']),
      operation: _readString(row['operation']),
      requestedBy: _readInt(row['requested_by']),
      approver: _readNullableInt(row['approver']),
      payload: payload is Map ? Map<String, dynamic>.from(payload) : const {},
      reason: _readString(row['reason']),
      decisionReason: _readString(row['decision_reason']),
      createdAt: DateTime.tryParse(_readString(row['created_at'])) ?? DateTime.fromMillisecondsSinceEpoch(0),
      reviewedAt: DateTime.tryParse(_readString(row['reviewed_at'])),
    );
  }

  String _readString(dynamic value) => value?.toString() ?? '';

  int _readInt(dynamic value) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  int? _readNullableInt(dynamic value) {
    if (value == null) return null;
    return _readInt(value);
  }
}
