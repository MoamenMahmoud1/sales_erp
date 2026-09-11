import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/ui/app_card.dart';
import '../../../core/ui/status_badge.dart';
import '../domain/entities/approval_request.dart';
import 'approval_center_controller.dart';

class ApprovalCenterPage extends StatefulWidget {
  final ApprovalCenterController controller;

  const ApprovalCenterPage({
    super.key,
    required this.controller,
  });

  @override
  State<ApprovalCenterPage> createState() => _ApprovalCenterPageState();
}

class _ApprovalCenterPageState extends State<ApprovalCenterPage> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_refresh);
    widget.controller.load();
  }

  @override
  void dispose() {
    widget.controller.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  Future<void> _review(ApprovalRequest request, String decision) async {
    final reasonController = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(decision == 'approve' ? 'Approve request?' : 'Reject request?'),
          content: TextField(
            controller: reasonController,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Reason',
              hintText: 'Optional',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(null),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(reasonController.text.trim()),
              child: Text(decision == 'approve' ? 'Approve' : 'Reject'),
            ),
          ],
        );
      },
    );
    reasonController.dispose();
    if (reason == null || !mounted) return;

    final result = await widget.controller.review(
      request: request,
      decision: decision,
      reason: reason,
    );
    if (!mounted || result == null) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result.queued
              ? 'Saved locally. It will be submitted when the connection returns.'
              : decision == 'approve'
                  ? 'Request approved.'
                  : 'Request rejected.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    return Scaffold(
      appBar: AppBar(title: const Text('Approval Center')),
      body: RefreshIndicator(
        onRefresh: controller.load,
        child: controller.isLoading && controller.requests.isEmpty
            ? const ListView(children: [SizedBox(height: 240), Center(child: CircularProgressIndicator())])
            : controller.requests.isEmpty
                ? const ListView(children: [SizedBox(height: 240), Center(child: Text('No pending approvals.'))])
                : ListView.separated(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    itemCount: controller.requests.length,
                    separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
                    itemBuilder: (context, index) {
                      final request = controller.requests[index];
                      return _ApprovalCard(
                        request: request,
                        busy: controller.processingRequestKey?.startsWith('${request.id}:') == true,
                        onApprove: () => _review(request, 'approve'),
                        onReject: () => _review(request, 'reject'),
                      );
                    },
                  ),
      ),
    );
  }
}

class _ApprovalCard extends StatelessWidget {
  final ApprovalRequest request;
  final bool busy;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  const _ApprovalCard({
    required this.request,
    required this.busy,
    required this.onApprove,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final subtitle = '${request.targetType} #${request.targetId} · ${request.operation}';

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Request #${request.id}',
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                ),
              ),
              const StatusBadge(
                type: StatusType.warning,
                label: 'Pending',
                icon: Icons.hourglass_top_rounded,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(subtitle, style: TextStyle(color: colors.textSecondary, fontSize: 13)),
          const SizedBox(height: AppSpacing.md),
          Text('Requested by: ${request.requestedBy}'),
          if (request.reason.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xs),
            Text('Reason: ${request.reason}'),
          ],
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: busy ? null : onReject,
                  icon: const Icon(Icons.close_rounded),
                  label: const Text('Reject'),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: FilledButton.icon(
                  onPressed: busy ? null : onApprove,
                  icon: busy
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.check_rounded),
                  label: const Text('Approve'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
