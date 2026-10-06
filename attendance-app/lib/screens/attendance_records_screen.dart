import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../services/api_client.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';
import '../widgets/common.dart';

class AttendanceRecordsScreen extends StatefulWidget {
  const AttendanceRecordsScreen({super.key});

  @override
  State<AttendanceRecordsScreen> createState() => _AttendanceRecordsScreenState();
}

class _AttendanceRecordsScreenState extends State<AttendanceRecordsScreen> {
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  Timer? _debounceTimer;

  String _filter = 'all'; // all, pre_registered, walk_in
  List<AttendanceRecord> _items = [];
  int _page = 1;
  int _total = 0;
  bool _loading = false;
  bool _hasMore = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetch(reset: true);
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      if (!_loading && _hasMore) {
        _fetch(reset: false);
      }
    }
  }

  void _onSearchChanged(String val) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 350), () {
      _fetch(reset: true);
    });
  }

  Future<void> _fetch({required bool reset}) async {
    if (_loading) return;
    final targetPage = reset ? 1 : _page + 1;
    setState(() {
      _loading = true;
      if (reset) {
        _error = null;
      }
    });

    try {
      final app = context.read<AppState>();
      final pageData = await app.api.listAttendance(
        page: targetPage,
        search: _searchController.text,
        filter: _filter,
      );

      if (mounted) {
        setState(() {
          _page = targetPage;
          _hasMore = pageData.hasMore;
          _total = pageData.total;
          if (reset) {
            _items = pageData.items;
          } else {
            _items.addAll(pageData.items);
          }
        });
      }
    } on AuthExpiredException {
      if (mounted) context.read<AppState>().handleAuthExpired();
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _error = e.message;
        });
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final stats = app.stats;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Attendance Records'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            const StatusBanner(),
            // Summary header
            Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
              color: AppColors.surface,
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: StatFigure(label: 'Total Present', value: '${stats.present}'),
                      ),
                      Expanded(
                        child: StatFigure(label: 'Pre-registered', value: '${stats.preRegisteredPresent}'),
                      ),
                      Expanded(
                        child: StatFigure(label: 'Walk-ins', value: '${stats.walkIns}'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Search Bar
                  TextField(
                    controller: _searchController,
                    onChanged: _onSearchChanged,
                    decoration: InputDecoration(
                      hintText: 'Search by SRN or Name',
                      prefixIcon: const Icon(Icons.search, size: 20),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              onPressed: () {
                                _searchController.clear();
                                _fetch(reset: true);
                              },
                            )
                          : null,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Filter Chips
                  Row(
                    children: [
                      _buildFilterChip('all', 'All (${_filter == 'all' ? _total : stats.present})'),
                      const SizedBox(width: 8),
                      _buildFilterChip('pre_registered', 'Pre-registered'),
                      const SizedBox(width: 8),
                      _buildFilterChip('walk_in', 'Walk-in'),
                    ],
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            // Records List (Read-Only)
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async {
                  await app.refreshHome();
                  await _fetch(reset: true);
                },
                child: _buildList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String value, String label) {
    final selected = _filter == value;
    return ChoiceChip(
      label: Text(label, style: TextStyle(fontSize: 13, color: selected ? AppColors.primary : AppColors.textSecondary)),
      selected: selected,
      selectedColor: AppColors.tint,
      backgroundColor: AppColors.surface,
      side: BorderSide(color: selected ? AppColors.primary : AppColors.border),
      showCheckmark: false,
      onSelected: (bool s) {
        if (s && _filter != value) {
          setState(() {
            _filter = value;
          });
          _fetch(reset: true);
        }
      },
    );
  }

  Widget _buildList() {
    if (_loading && _items.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }

    if (_error != null && _items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 36, color: AppColors.error),
              const SizedBox(height: 12),
              Text(_error!, style: AppText.body, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: () => _fetch(reset: true),
                child: const Text('Try Again'),
              ),
            ],
          ),
        ),
      );
    }

    if (_items.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.search_off, size: 40, color: AppColors.textSecondary),
            const SizedBox(height: 12),
            Text(
              _searchController.text.isNotEmpty
                  ? 'No attendee found matching "${_searchController.text}"'
                  : 'No attendance records yet',
              style: AppText.meta,
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      controller: _scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: _items.length + (_hasMore ? 1 : 0),
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, index) {
        if (index == _items.length) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        }

        final record = _items[index];
        final isWalkIn = record.registrationStatus == 'walk_in';

        return Container(
          color: AppColors.surface,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(record.name, style: AppText.bodyMedium),
                    const SizedBox(height: 2),
                    Text(record.srn, style: AppText.srn.copyWith(color: AppColors.textSecondary)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(formatTime(record.time), style: AppText.metaMedium),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: isWalkIn ? AppColors.warningTint : AppColors.tint,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      isWalkIn ? 'Walk-in' : 'Pre-registered',
                      style: AppText.meta.copyWith(
                        fontSize: 11,
                        color: isWalkIn ? AppColors.warning : AppColors.primary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
