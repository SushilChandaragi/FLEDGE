import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../services/api_client.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../utils/srn.dart';
import 'registration_qr_screen.dart';

class ManualSrnScreen extends StatefulWidget {
  const ManualSrnScreen({super.key});

  @override
  State<ManualSrnScreen> createState() => _ManualSrnScreenState();
}

class _ManualSrnScreenState extends State<ManualSrnScreen> {
  final _controller = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _busy = false;
  ScanOutcome? _outcome;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _checkSrn() async {
    final raw = _controller.text;
    final normalized = normalizeSrn(raw);
    if (normalized.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter an SRN.')),
      );
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _outcome = null;
    });

    try {
      final app = context.read<AppState>();
      final outcome = await app.attendance.process(normalized);
      if (mounted) {
        setState(() {
          _outcome = outcome;
        });
        if (outcome.isSuccess) {
          app.refreshHome();
        }
      }
    } on AuthExpiredException {
      if (mounted) context.read<AppState>().handleAuthExpired();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Manual SRN Entry'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('Enter Student SRN', style: AppText.section),
                  const SizedBox(height: 6),
                  const Text(
                    'Use this if barcode scanning fails or if the ID card is damaged.',
                    style: AppText.meta,
                  ),
                  const SizedBox(height: 24),
                  Form(
                    key: _formKey,
                    child: TextFormField(
                      controller: _controller,
                      autofocus: true,
                      textCapitalization: TextCapitalization.characters,
                      textInputAction: TextInputAction.go,
                      autocorrect: false,
                      enableSuggestions: false,
                      style: AppText.srn.copyWith(fontSize: 16),
                      decoration: InputDecoration(
                        labelText: 'Student SRN',
                        hintText: 'e.g. 02FE23BCS136',
                        suffixIcon: _controller.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 20),
                                onPressed: () {
                                  _controller.clear();
                                  setState(() => _outcome = null);
                                },
                              )
                            : null,
                      ),
                      onChanged: (_) => setState(() {}),
                      onFieldSubmitted: (_) => _checkSrn(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: _busy ? null : _checkSrn,
                    child: _busy
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Text('Check & Mark Attendance'),
                  ),
                  const SizedBox(height: 24),
                  if (_outcome != null) ...[
                    _buildOutcomeCard(_outcome!, app),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOutcomeCard(ScanOutcome outcome, AppState app) {
    switch (outcome.kind) {
      case ScanKind.marked:
      case ScanKind.markedPending:
        final isOffline = outcome.kind == ScanKind.markedPending;
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.successTint,
            borderRadius: BorderRadius.circular(AppTheme.radius),
            border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.check_circle, color: AppColors.success, size: 22),
                  const SizedBox(width: 8),
                  Text(
                    isOffline ? 'Attendance Recorded Locally' : 'Attendance Marked',
                    style: AppText.section.copyWith(color: AppColors.success, fontSize: 16),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(outcome.name, style: AppText.bodyMedium.copyWith(fontSize: 16)),
              const SizedBox(height: 4),
              Text('SRN: ${outcome.srn}', style: AppText.srn),
              if (outcome.registrationStatus.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  outcome.registrationStatus == 'walk_in' ? 'Walk-in' : 'Pre-registered',
                  style: AppText.meta.copyWith(color: AppColors.textSecondary),
                ),
              ],
              if (isOffline) ...[
                const SizedBox(height: 8),
                Text('Waiting for internet to sync with server.', style: AppText.meta.copyWith(color: AppColors.warning)),
              ],
            ],
          ),
        );

      case ScanKind.alreadyAttended:
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.warningTint,
            borderRadius: BorderRadius.circular(AppTheme.radius),
            border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, color: AppColors.warning, size: 22),
                  const SizedBox(width: 8),
                  Text('Already Marked Present', style: AppText.section.copyWith(color: AppColors.warning, fontSize: 16)),
                ],
              ),
              const SizedBox(height: 12),
              if (outcome.name.isNotEmpty) ...[
                Text(outcome.name, style: AppText.bodyMedium.copyWith(fontSize: 16)),
                const SizedBox(height: 4),
              ],
              Text('SRN: ${outcome.srn}', style: AppText.srn),
              if (outcome.time != null) ...[
                const SizedBox(height: 4),
                Text('Original time: ${outcome.time!.toLocal()}', style: AppText.meta),
              ],
            ],
          ),
        );

      case ScanKind.notRegistered:
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.errorTint,
            borderRadius: BorderRadius.circular(AppTheme.radius),
            border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.error_outline, color: AppColors.error, size: 22),
                  const SizedBox(width: 8),
                  Text('Not Registered for FLEDGE \'26', style: AppText.section.copyWith(color: AppColors.error, fontSize: 16)),
                ],
              ),
              const SizedBox(height: 10),
              Text('SRN: ${outcome.srn}', style: AppText.srn),
              const SizedBox(height: 8),
              const Text(
                'This student has not submitted the registration form yet. Ask them to fill the Google Form.',
                style: AppText.meta,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        final formUrl = app.event?.registrationFormUrl ?? '';
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => RegistrationQrScreen(formUrl: formUrl, srn: outcome.srn),
                          ),
                        );
                      },
                      icon: const Icon(Icons.qr_code, size: 18),
                      label: const Text('Show QR'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: _busy ? null : _checkSrn,
                      child: const Text('Check Again'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );

      case ScanKind.offlineUnverified:
      case ScanKind.invalidSrn:
      case ScanKind.error:
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.errorTint,
            borderRadius: BorderRadius.circular(AppTheme.radius),
            border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.error_outline, color: AppColors.error, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  outcome.message.isNotEmpty ? outcome.message : 'An error occurred.',
                  style: AppText.body.copyWith(color: AppColors.error, fontSize: 14),
                ),
              ),
            ],
          ),
        );
    }
  }
}
