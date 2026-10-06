import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../theme/app_theme.dart';

/// "OFFLINE" strip with the pending queue size. Only shown when there is something to say.
class StatusBanner extends StatelessWidget {
  const StatusBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final offline = app.isOffline;
    final pending = app.sync.pendingCount;
    if (!offline && pending == 0) return const SizedBox.shrink();

    final Color bg = offline ? AppColors.warningTint : AppColors.tint;
    final Color fg = offline ? AppColors.warning : AppColors.primaryDark;
    final String title = offline ? 'Offline' : 'Syncing';
    final String detail = [
      if (offline) 'Some registration checks may be delayed.',
      if (pending > 0) '$pending scan${pending == 1 ? '' : 's'} waiting to sync.',
    ].join(' ');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(color: bg, border: Border(bottom: BorderSide(color: fg.withValues(alpha: 0.25)))),
      child: Row(
        children: [
          Icon(offline ? Icons.cloud_off_outlined : Icons.sync, size: 18, color: fg),
          const SizedBox(width: 10),
          Expanded(
            child: Text.rich(
              TextSpan(children: [
                TextSpan(text: '$title  ', style: AppText.bodyMedium.copyWith(color: fg, fontSize: 13)),
                TextSpan(text: detail, style: AppText.meta.copyWith(color: fg)),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

class BrandHeader extends StatelessWidget {
  const BrandHeader({super.key, this.compact = false});
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'CNEST',
          style: AppText.metaMedium.copyWith(color: AppColors.primary, letterSpacing: 1.2, fontSize: 12),
        ),
        const SizedBox(height: 4),
        Text("FLEDGE '26", style: compact ? AppText.section : AppText.title),
        Text('Attendance', style: AppText.meta.copyWith(fontSize: 14)),
      ],
    );
  }
}

class StatFigure extends StatelessWidget {
  const StatFigure({super.key, required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(value, style: AppText.figure),
        ),
        const SizedBox(height: 4),
        Text(label, style: AppText.meta, maxLines: 1, overflow: TextOverflow.ellipsis),
      ],
    );
  }
}
