import 'package:flutter/material.dart';

import '../../../core/data/car_demo_data_seeder.dart';
import 'car_daily_dashboard_page.dart';

/// Prepares the local Car demo dataset before mounting the daily dashboard.
///
/// This keeps database preparation out of application startup and makes any
/// initialization failure visible inside the Car feature instead of leaving
/// the whole app unmounted.
class CarDashboardBootstrapPage extends StatefulWidget {
  final ValueChanged<int>? onNavigate;

  const CarDashboardBootstrapPage({super.key, this.onNavigate});

  @override
  State<CarDashboardBootstrapPage> createState() =>
      _CarDashboardBootstrapPageState();
}

class _CarDashboardBootstrapPageState extends State<CarDashboardBootstrapPage> {
  late Future<void> _bootstrap;

  @override
  void initState() {
    super.initState();
    _bootstrap = CarDemoDataSeeder().seedIfNeeded();
  }

  void _retry() {
    setState(() {
      _bootstrap = CarDemoDataSeeder().seedIfNeeded();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _bootstrap,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline_rounded, size: 44),
                  const SizedBox(height: 12),
                  const Text(
                    'Car dashboard could not initialize',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${snapshot.error}',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: _retry,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Retry'),
                  ),
                ],
              ),
            ),
          );
        }

        return CarDailyDashboardPage(onNavigate: widget.onNavigate);
      },
    );
  }
}
