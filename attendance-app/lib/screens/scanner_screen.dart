import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';

import '../config/app_config.dart';
import '../models/models.dart';
import '../services/api_client.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';
import '../widgets/common.dart';
import 'manual_srn_screen.dart';
import 'registration_qr_screen.dart';

class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> with WidgetsBindingObserver {
  late final MobileScannerController _scannerController;
  bool _isProcessing = false;
  DateTime? _lastScanTime;
  String? _lastScannedValue;
  ScanOutcome? _activeOutcome;
  Timer? _dismissTimer;

  // Recent scan preview
  String? _recentSrn;
  String? _recentName;
  DateTime? _recentTime;
  bool _recentSuccess = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scannerController = MobileScannerController(
      detectionSpeed: DetectionSpeed.normal,
      facing: CameraFacing.back,
      torchEnabled: false,
      returnImage: false,
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_scannerController.value.isInitialized) return;
    if (state == AppLifecycleState.inactive || state == AppLifecycleState.paused) {
      _scannerController.stop();
    } else if (state == AppLifecycleState.resumed) {
      _scannerController.start();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _dismissTimer?.cancel();
    _scannerController.dispose();
    super.dispose();
  }

  void _onBarcodeDetect(BarcodeCapture capture) {
    final barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;

    final rawValue = barcodes.first.rawValue?.trim();
    if (rawValue == null || rawValue.isEmpty) return;

    final now = DateTime.now();
    // Cooldown check for duplicate rapid camera triggers on same code
    if (_lastScannedValue == rawValue && _lastScanTime != null) {
      if (now.difference(_lastScanTime!) < AppConfig.scanCooldown) {
        return;
      }
    }

    if (_isProcessing) return;

    _lastScannedValue = rawValue;
    _lastScanTime = now;
    _processBarcode(rawValue);
  }

  Future<void> _processBarcode(String raw) async {
    setState(() {
      _isProcessing = true;
      _dismissTimer?.cancel();
    });

    try {
      final app = context.read<AppState>();
      final outcome = await app.attendance.process(raw);

      if (!mounted) return;

      setState(() {
        _activeOutcome = outcome;
        if (outcome.isSuccess || outcome.kind == ScanKind.alreadyAttended) {
          _recentSrn = outcome.srn;
          _recentName = outcome.name.isNotEmpty ? outcome.name : null;
          _recentTime = outcome.time ?? DateTime.now();
          _recentSuccess = outcome.isSuccess;
        }
      });

      if (outcome.isSuccess) {
        app.refreshHome();
        // Auto return to scanning
        _dismissTimer = Timer(AppConfig.successDisplay, () {
          if (mounted) {
            setState(() {
              _activeOutcome = null;
              _isProcessing = false;
            });
          }
        });
      } else if (outcome.kind == ScanKind.alreadyAttended) {
        // Auto return after brief delay
        _dismissTimer = Timer(AppConfig.duplicateDisplay, () {
          if (mounted) {
            setState(() {
              _activeOutcome = null;
              _isProcessing = false;
            });
          }
        });
      } else {
        // Not registered / error / invalid -> Keep outcome visible for user action
      }
    } on AuthExpiredException {
      if (mounted) context.read<AppState>().handleAuthExpired();
    } catch (_) {
      if (mounted) {
        setState(() {
          _activeOutcome = ScanOutcome(
            kind: ScanKind.error,
            srn: raw,
            message: 'Unable to process scan. Please try again.',
          );
        });
      }
    }
  }

  void _dismissOutcomeAndResume() {
    _dismissTimer?.cancel();
    setState(() {
      _activeOutcome = null;
      _isProcessing = false;
      _lastScannedValue = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan Student Barcode'),
        actions: [
          IconButton(
            icon: ValueListenableBuilder<MobileScannerState>(
              valueListenable: _scannerController,
              builder: (context, state, child) {
                return Icon(
                  state.torchState == TorchState.on ? Icons.flash_on : Icons.flash_off,
                  size: 22,
                );
              },
            ),
            onPressed: () => _scannerController.toggleTorch(),
          ),
          IconButton(
            icon: const Icon(Icons.flip_camera_android, size: 22),
            onPressed: () => _scannerController.switchCamera(),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            const StatusBanner(),

            // Top Scanner area
            Expanded(
              flex: 5,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  MobileScanner(
                    controller: _scannerController,
                    onDetect: _onBarcodeDetect,
                    errorBuilder: (context, error) {
                      return Container(
                        color: Colors.black,
                        padding: const EdgeInsets.all(24),
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.camera_alt_outlined, color: Colors.white70, size: 48),
                              const SizedBox(height: 16),
                              const Text(
                                'Camera permission required or camera unavailable.',
                                style: TextStyle(color: Colors.white, fontSize: 15),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 16),
                              FilledButton(
                                onPressed: () => Navigator.of(context).push(
                                  MaterialPageRoute<void>(builder: (_) => const ManualSrnScreen()),
                                ),
                                child: const Text('Enter SRN Manually'),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),

                  // Targeting reticle overlay
                  Center(
                    child: Container(
                      width: 280,
                      height: 160,
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: _isProcessing ? AppColors.primary : Colors.white.withValues(alpha: 0.7),
                          width: 2,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (_isProcessing && _activeOutcome == null) ...[
                            const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Verifying...',
                              style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),

                  // Prompt text overlay
                  Positioned(
                    bottom: 16,
                    left: 20,
                    right: 20,
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.65),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          'Point at barcode on student ID card',
                          style: TextStyle(color: Colors.white, fontSize: 13),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Bottom interactive / outcome area
            Expanded(
              flex: 4,
              child: Container(
                color: AppColors.surface,
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_activeOutcome != null) ...[
                      Expanded(
                        child: SingleChildScrollView(
                          child: _buildOutcomeWidget(_activeOutcome!, app),
                        ),
                      ),
                    ] else ...[
                      // Manual SRN Fallback
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.circular(AppTheme.radius),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Barcode not working?', style: AppText.bodyMedium),
                                  const SizedBox(height: 2),
                                  Text('Enter ID manually if damaged', style: AppText.meta.copyWith(fontSize: 12)),
                                ],
                              ),
                            ),
                            FilledButton.tonal(
                              onPressed: () async {
                                await Navigator.of(context).push(
                                  MaterialPageRoute<void>(builder: (_) => const ManualSrnScreen()),
                                );
                                if (mounted) app.refreshHome();
                              },
                              style: FilledButton.styleFrom(minimumSize: const Size(110, 40)),
                              child: const Text('Enter SRN', style: TextStyle(fontSize: 13)),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),

                      // Recent scan indicator
                      if (_recentSrn != null) ...[
                        const Divider(height: 1),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Icon(
                              _recentSuccess ? Icons.check_circle_outline : Icons.info_outline,
                              size: 16,
                              color: _recentSuccess ? AppColors.success : AppColors.warning,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Recent scan: $_recentSrn${_recentName != null ? ' ($_recentName)' : ''}',
                                style: AppText.meta.copyWith(fontSize: 12),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(formatTime(_recentTime), style: AppText.meta.copyWith(fontSize: 11)),
                          ],
                        ),
                      ],
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOutcomeWidget(ScanOutcome outcome, AppState app) {
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
                    isOffline ? 'Attendance Recorded (Offline)' : 'Attendance Marked',
                    style: AppText.section.copyWith(color: AppColors.success, fontSize: 16),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(outcome.name, style: AppText.bodyMedium.copyWith(fontSize: 16)),
              const SizedBox(height: 2),
              Text('SRN: ${outcome.srn}', style: AppText.srn),
              if (outcome.registrationStatus.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  outcome.registrationStatus == 'walk_in' ? 'Registration: Walk-in' : 'Registration: Google Form (Pre-registered)',
                  style: AppText.meta.copyWith(color: AppColors.textSecondary),
                ),
              ],
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(formatTime(outcome.time), style: AppText.meta),
                  TextButton(
                    onPressed: _dismissOutcomeAndResume,
                    child: const Text('Next Scan'),
                  ),
                ],
              ),
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
              const SizedBox(height: 10),
              if (outcome.name.isNotEmpty) ...[
                Text(outcome.name, style: AppText.bodyMedium.copyWith(fontSize: 16)),
                const SizedBox(height: 2),
              ],
              Text('SRN: ${outcome.srn}', style: AppText.srn),
              if (outcome.time != null) ...[
                const SizedBox(height: 2),
                Text('Original scan: ${formatTime(outcome.time)}', style: AppText.meta),
              ],
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _dismissOutcomeAndResume,
                  child: const Text('Next Scan'),
                ),
              ),
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
                  Text('Not Registered', style: AppText.section.copyWith(color: AppColors.error, fontSize: 16)),
                ],
              ),
              const SizedBox(height: 8),
              Text('SRN: ${outcome.srn}', style: AppText.srn.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              const Text(
                'This student has not registered yet. Ask them to scan the QR to complete the registration form.',
                style: AppText.meta,
              ),
              const SizedBox(height: 14),
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
                      label: const Text('Show QR', style: TextStyle(fontSize: 13)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => _processBarcode(outcome.srn),
                      child: const Text('Check Again', style: TextStyle(fontSize: 13)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Center(
                child: TextButton(
                  onPressed: _dismissOutcomeAndResume,
                  child: const Text('Back to Scanner'),
                ),
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.error_outline, color: AppColors.error, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      outcome.message.isNotEmpty ? outcome.message : 'Error processing barcode.',
                      style: AppText.body.copyWith(color: AppColors.error, fontSize: 14),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        _dismissOutcomeAndResume();
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(builder: (_) => const ManualSrnScreen()),
                        );
                      },
                      child: const Text('Enter Manually', style: TextStyle(fontSize: 13)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton(
                      onPressed: _dismissOutcomeAndResume,
                      child: const Text('Scan Again', style: TextStyle(fontSize: 13)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
    }
  }
}
