import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';
import '../widgets/common.dart';
import 'attendance_records_screen.dart';
import 'scanner_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => context.read<AppState>().refreshHome());
  }

  Future<void> _open(Widget screen) async {
    await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => screen));
    if (mounted) context.read<AppState>().refreshHome();
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final stats = app.stats;
    final event = app.event;
    final sync = app.sync;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const StatusBanner(),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async {
                  await app.refreshHome();
                  await app.sync.syncNow();
                },
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Expanded(child: BrandHeader()),
                        PopupMenuButton<String>(
                          icon: const Icon(Icons.more_horiz, color: AppColors.textSecondary),
                          onSelected: (v) {
                            if (v == 'sync') app.sync.syncNow();
                            if (v == 'logout') app.logout();
                          },
                          itemBuilder: (_) => const [
                            PopupMenuItem(value: 'sync', child: Text('Sync now')),
                            PopupMenuItem(value: 'logout', child: Text('Sign out')),
                          ],
                        ),
                      ],
                    ),
                    if (event != null) ...[
                      const SizedBox(height: 8),
                      Text('${event.date} · ${event.time} · ${event.venue}', style: AppText.meta),
                    ],
                    const SizedBox(height: 32),
                    Row(
                      children: [
                        Expanded(child: StatFigure(label: 'Registered', value: '${stats.registered}')),
                        Expanded(child: StatFigure(label: 'Present', value: '${stats.present}')),
                        Expanded(child: StatFigure(label: 'Walk-ins', value: '${stats.walkIns}')),
                      ],
                    ),
                    const SizedBox(height: 32),
                    FilledButton.icon(
                      onPressed: () => _open(const ScannerScreen()),
                      icon: const Icon(Icons.qr_code_scanner, size: 20),
                      label: const Text('Start scanning'),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton(
                      onPressed: () => _open(const AttendanceRecordsScreen()),
                      child: const Text('View attendance'),
                    ),
                    const SizedBox(height: 32),
                    const Divider(),
                    const SizedBox(height: 16),
                    _InfoRow(label: 'Operator', value: app.session?.operatorId ?? ''),
                    _InfoRow(label: 'Device', value: app.deviceId),
                    _InfoRow(
                      label: 'Offline list',
                      value: sync.snapshotCount == 0
                          ? 'Not downloaded yet'
                          : '${sync.snapshotCount} participants'
                              '${sync.lastSnapshotAt != null ? ' · updated ${formatTime(sync.lastSnapshotAt)}' : ''}',
                    ),
                    if (sync.rejectedCount > 0)
                      _InfoRow(
                        label: 'Needs review',
                        value: '${sync.rejectedCount} offline scan(s) were rejected by the server',
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 104, child: Text(label, style: AppText.meta)),
          Expanded(child: Text(value, style: AppText.body.copyWith(fontSize: 14))),
        ],
      ),
    );
  }
}
