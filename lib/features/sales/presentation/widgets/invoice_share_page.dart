import 'package:flutter/material.dart';

import '../../../../core/services/share_image.dart';
import 'invoice_share_card.dart';

class InvoiceSharePage extends StatefulWidget {
  final ShareInvoiceData data;

  const InvoiceSharePage({
    super.key,
    required this.data,
  });

  @override
  State<InvoiceSharePage> createState() => _InvoiceSharePageState();
}

class _InvoiceSharePageState extends State<InvoiceSharePage> {
  final _cardKey = GlobalKey();
  bool _sharing = false;

  Future<void> _share() async {
    if (_sharing) return;
    setState(() => _sharing = true);
    try {
      final number = widget.data.displayNumber;
      final ok = await ShareImageService.instance.share(
        _cardKey,
        fileName: 'invoice_$number.png',
        subject: 'Invoice $number',
        text: 'Invoice $number from Sales ERP',
      );
      if (!ok && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not capture the image.')),
        );
      }
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text('Share ${widget.data.displayNumber}')),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Center(
                  child: RepaintBoundary(
                    key: _cardKey,
                    child: Material(
                      color: Colors.transparent,
                      child: InvoiceShareCard(data: widget.data),
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: FilledButton.icon(
                onPressed: _sharing ? null : _share,
                icon: _sharing
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.share),
                label: Text(_sharing ? 'Sharing...' : 'Share as image'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                  backgroundColor: scheme.primary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
