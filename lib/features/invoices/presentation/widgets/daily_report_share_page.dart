import 'package:flutter/material.dart';

import '../../../../core/services/share_image.dart';
import 'daily_report_card.dart';

/// صفحة تظهر تقرير اليوم كمعاينة + زر مشاركة كصورة.
class DailyReportSharePage extends StatefulWidget {
  final DailyReportData data;

  const DailyReportSharePage({
    super.key,
    required this.data,
  });

  @override
  State<DailyReportSharePage> createState() => _DailyReportSharePageState();
}

class _DailyReportSharePageState extends State<DailyReportSharePage> {
  final _cardKey = GlobalKey();
  bool _sharing = false;

  Future<void> _share() async {
    setState(() => _sharing = true);
    try {
      final ok = await ShareImageService.instance.share(
        _cardKey,
        fileName: 'daily_report_${widget.data.date.year}'
            '${widget.data.date.month}${widget.data.date.day}.png',
        subject: 'Daily Business Report',
        text: 'Daily Business Report from Sales ERP',
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
    return Scaffold(
      appBar: AppBar(title: const Text('Daily report')),
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
                      child: DailyReportCard(data: widget.data),
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
                style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}