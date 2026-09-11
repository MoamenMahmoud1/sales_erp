import 'package:flutter/foundation.dart';

import '../domain/entities/approval_request.dart';
import '../domain/repositories/approval_repository.dart';

class ApprovalCenterController extends ChangeNotifier {
  final ApprovalRepository repository;

  ApprovalCenterController({required this.repository});

  List<ApprovalRequest> requests = const [];
  bool isLoading = false;
  String? errorMessage;
  String? processingRequestKey;

  Future<void> load() async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      requests = await repository.fetchPendingApprovals();
    } catch (error) {
      errorMessage = error.toString();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<ApprovalReviewResult?> review({
    required ApprovalRequest request,
    required String decision,
    String reason = '',
  }) async {
    final operationKey = '${request.id}:$decision';
    processingRequestKey = operationKey;
    errorMessage = null;
    notifyListeners();

    try {
      final result = await repository.reviewApproval(
        approvalRequestId: request.id,
        decision: decision,
        reason: reason,
      );
      if (!result.queued) {
        requests = [
          for (final item in requests)
            if (item.id != request.id) item,
        ];
      }
      return result;
    } catch (error) {
      errorMessage = error.toString();
      return null;
    } finally {
      processingRequestKey = null;
      notifyListeners();
    }
  }
}
