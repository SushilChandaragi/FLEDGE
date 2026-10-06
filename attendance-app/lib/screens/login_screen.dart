import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/api_client.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _operator;
  late final TextEditingController _password;
  late final TextEditingController _device;
  bool _busy = false;
  bool _showPassword = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final app = context.read<AppState>();
    _operator = TextEditingController(text: app.store.lastOperatorId);
    _password = TextEditingController();
    _device = TextEditingController(text: app.deviceId);
    _error = app.loginNotice;
  }

  @override
  void dispose() {
    _operator.dispose();
    _password.dispose();
    _device.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final op = _operator.text.trim().toLowerCase();
      final pwd = _password.text.trim();
      final dev = _device.text.trim().toUpperCase();
      debugPrint('=== [LOGIN BUTTON CLICKED] ===');
      debugPrint('Operator: "$op", Password: "$pwd", Device: "$dev"');
      await context.read<AppState>().login(
            operatorId: op,
            password: pwd,
            deviceId: dev,
          );
      debugPrint('=== [LOGIN SUCCESSFUL] ===');
    } on ApiException catch (e) {
      debugPrint('=== [LOGIN EXCEPTION] ===: ${e.message} (code: ${e.code})');
      setState(() {
        _error = e.network
            ? 'Cannot reach the server. Check your internet connection.'
            : e.message;
      });
    } on AuthExpiredException {
      debugPrint('=== [LOGIN AUTH EXPIRED] ===');
      setState(() => _error = 'Could not sign in.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _form,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const BrandHeader(),
                    const SizedBox(height: 36),
                    if (_error != null) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.errorTint,
                          borderRadius: BorderRadius.circular(AppTheme.radius),
                          border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
                        ),
                        child: Text(_error!, style: AppText.body.copyWith(color: AppColors.error, fontSize: 14)),
                      ),
                      const SizedBox(height: 16),
                    ],
                    TextFormField(
                      controller: _operator,
                      decoration: const InputDecoration(labelText: 'Operator ID'),
                      textInputAction: TextInputAction.next,
                      autocorrect: false,
                      enableSuggestions: false,
                      validator: (v) => (v ?? '').trim().isEmpty ? 'Enter your operator ID' : null,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _password,
                      obscureText: !_showPassword,
                      decoration: InputDecoration(
                        labelText: 'Password',
                        suffixIcon: IconButton(
                          icon: Icon(_showPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 20),
                          onPressed: () => setState(() => _showPassword = !_showPassword),
                        ),
                      ),
                      textInputAction: TextInputAction.next,
                      validator: (v) => (v ?? '').isEmpty ? 'Enter your password' : null,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _device,
                      decoration: const InputDecoration(
                        labelText: 'Device ID',
                        hintText: 'e.g. GATE-A-01',
                        helperText: 'Unique name for this phone at the gate',
                      ),
                      textCapitalization: TextCapitalization.characters,
                      textInputAction: TextInputAction.done,
                      autocorrect: false,
                      enableSuggestions: false,
                      validator: (v) {
                        final s = (v ?? '').trim();
                        if (s.isEmpty) return 'Enter a device ID';
                        if (!RegExp(r'^[A-Za-z0-9_-]{1,32}$').hasMatch(s)) return 'Use letters, numbers, - or _';
                        return null;
                      },
                      onFieldSubmitted: (_) => _submit(),
                    ),
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: _busy ? null : _submit,
                      child: _busy
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Text('Sign in'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
