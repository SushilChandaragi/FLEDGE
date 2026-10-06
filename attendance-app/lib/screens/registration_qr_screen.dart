import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme/app_theme.dart';

class RegistrationQrScreen extends StatelessWidget {
  const RegistrationQrScreen({super.key, required this.formUrl, this.srn});

  final String formUrl;
  final String? srn;

  @override
  Widget build(BuildContext context) {
    final hasUrl = formUrl.isNotEmpty && !formUrl.contains('REPLACE_ME');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Event Registration QR'),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  if (srn != null && srn!.isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.tint,
                        borderRadius: BorderRadius.circular(AppTheme.radius),
                        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
                      ),
                      child: Text('SRN: $srn', style: AppText.srn.copyWith(color: AppColors.primaryDark, fontWeight: FontWeight.w600)),
                    ),
                    const SizedBox(height: 20),
                  ],
                  const Text('Scan to Register', style: AppText.section, textAlign: TextAlign.center),
                  const SizedBox(height: 8),
                  const Text(
                    'Ask the participant to scan this QR code with their phone camera to complete the CNEST registration form.',
                    style: AppText.meta,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 28),
                  if (hasUrl) ...[
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(AppTheme.radius),
                        border: Border.all(color: AppColors.border),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          )
                        ],
                      ),
                      child: QrImageView(
                        data: formUrl,
                        version: QrVersions.auto,
                        size: 240.0,
                        backgroundColor: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 24),
                    OutlinedButton.icon(
                      onPressed: () async {
                        final uri = Uri.parse(formUrl);
                        if (await canLaunchUrl(uri)) {
                          await launchUrl(uri, mode: LaunchMode.externalApplication);
                        }
                      },
                      icon: const Icon(Icons.open_in_browser, size: 18),
                      label: const Text('Open link in browser'),
                    ),
                  ] else ...[
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppColors.warningTint,
                        borderRadius: BorderRadius.circular(AppTheme.radius),
                        border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
                      ),
                      child: Text(
                        'Registration form URL is not configured on the server. Please configure REGISTRATION_FORM_URL in the backend environment.',
                        style: AppText.body.copyWith(color: AppColors.warning, fontSize: 14),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                  const SizedBox(height: 28),
                  FilledButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Done / Check Again'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
