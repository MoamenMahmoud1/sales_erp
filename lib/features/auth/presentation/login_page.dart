import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../../core/repositories/app_services.dart';
import 'auth_controller.dart';

class LoginPage extends StatefulWidget {
  final AuthController controller;

  const LoginPage({
    super.key,
    required this.controller,
  });

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _identifier = TextEditingController();
  final _password = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _identifier.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate() || _loading) return;
    setState(() => _loading = true);

    try {
      await widget.controller.login(
        identifier: _identifier.text.trim(),
        password: _password.text,
      );
    } catch (error) {
      if (!mounted) return;
      final message = error is DioException
          ? (error.response?.data is Map
              ? '${error.response?.data['detail'] ?? 'Login failed.'}'
              : 'Could not connect to the server.')
          : 'Login failed.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _enterOffline() {
    widget.controller.markAuthenticated();
  }

  @override
  Widget build(BuildContext context) {
    final offlineAllowed = widget.controller.canAccessOffline;
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Sales ERP',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 8),
                  const Text('Sign in to continue'),
                  const SizedBox(height: 32),
                  TextFormField(
                    controller: _identifier,
                    decoration: const InputDecoration(
                      labelText: 'Email or username',
                    ),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Enter your email or username.'
                        : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _password,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: 'Password'),
                    validator: (value) => value == null || value.isEmpty
                        ? 'Enter your password.'
                        : null,
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: _loading ? null : _login,
                    child: Text(_loading ? 'Signing in...' : 'Sign in'),
                  ),
                  if (offlineAllowed) ...[
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: _loading ? null : _enterOffline,
                      icon: const Icon(Icons.offline_pin_outlined),
                      label: const Text('Continue locally (offline)'),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Current mode: ${AppServices.instance.mode.name.toUpperCase()} — '
                      'using local device data.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
