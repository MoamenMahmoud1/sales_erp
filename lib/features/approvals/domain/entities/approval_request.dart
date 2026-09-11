class ApprovalRequest {
  final int id;
  final String status;
  final String targetType;
  final int targetId;
  final String operation;
  final int requestedBy;
  final int? approver;
  final Map<String, dynamic> payload;
  final String reason;
  final String decisionReason;
  final DateTime createdAt;
  final DateTime? reviewedAt;

  const ApprovalRequest({
    required this.id,
    required this.status,
    required this.targetType,
    required this.targetId,
    required this.operation,
    required this.requestedBy,
    required this.approver,
    required this.payload,
    required this.reason,
    required this.decisionReason,
    required this.createdAt,
    required this.reviewedAt,
  });
}

class ApprovalReviewResult {
  final bool queued;
  final String operationKey;
  final Map<String, dynamic>? response;

  const ApprovalReviewResult({
    required this.queued,
    required this.operationKey,
    required this.response,
  });
}
