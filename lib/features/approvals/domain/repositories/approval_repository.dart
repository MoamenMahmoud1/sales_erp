import '../entities/approval_request.dart';

abstract class ApprovalRepository {
  Future<List<ApprovalRequest>> fetchPendingApprovals();

  Future<ApprovalReviewResult> reviewApproval({
    required int approvalRequestId,
    required String decision,
    String reason = '',
  });
}
