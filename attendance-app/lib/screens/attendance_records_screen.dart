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

class _AttendanceRecordsScreenState extends State<AttendanceRecordsScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Attendance Records'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primary,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
          labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          tabs: const [
            Tab(text: 'Total Scanned (Present)'),
            Tab(text: 'Registered List (Form)'),
          ],
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            const StatusBanner(),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: const [
                  _ScannedPresentTab(),
                  _RegisteredListTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Tab 1: Total Scanned / Marked Present
class _ScannedPresentTab extends StatefulWidget {
  const _ScannedPresentTab();

  @override
  State<_ScannedPresentTab> createState() => _ScannedPresentTabState();
}

class _ScannedPresentTabState extends State<_ScannedPresentTab> {
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
      if (reset) _error = null;
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
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final stats = app.stats;

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          color: AppColors.surface,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
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
              const SizedBox(height: 12),
              TextField(
                controller: _searchController,
                onChanged: _onSearchChanged,
                decoration: InputDecoration(
                  hintText: 'Search present student by SRN or Name',
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
              const SizedBox(height: 10),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildFilterChip('all', 'All (${_filter == 'all' ? _total : stats.present})'),
                    const SizedBox(width: 8),
                    _buildFilterChip('pre_registered', 'Pre-registered (${stats.preRegisteredPresent})'),
                    const SizedBox(width: 8),
                    _buildFilterChip('walk_in', 'Walk-in (${stats.walkIns})'),
                  ],
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
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
    );
  }

  Widget _buildFilterChip(String value, String label) {
    final selected = _filter == value;
    return ChoiceChip(
      label: Text(label, style: TextStyle(fontSize: 12, color: selected ? AppColors.primary : AppColors.textSecondary)),
      selected: selected,
      selectedColor: AppColors.tint,
      backgroundColor: AppColors.surface,
      side: BorderSide(color: selected ? AppColors.primary : AppColors.border),
      showCheckmark: false,
      onSelected: (bool s) {
        if (s && _filter != value) {
          setState(() => _filter = value);
          _fetch(reset: true);
        }
      },
    );
  }

  Widget _buildList() {
    if (_loading && _items.isEmpty) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
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
              OutlinedButton(onPressed: () => _fetch(reset: true), child: const Text('Try Again')),
            ],
          ),
        ),
      );
    }
    if (_items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.search_off, size: 40, color: AppColors.textSecondary),
              const SizedBox(height: 12),
              Text(
                _searchController.text.isNotEmpty
                    ? 'No attendee found matching "${_searchController.text}"'
                    : 'No attendance marked yet',
                style: AppText.meta,
                textAlign: TextAlign.center,
              ),
            ],
          ),
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
              child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
            ),
          );
        }
        final record = _items[index];
        final isWalkIn = record.registrationStatus == 'walk_in';

        return Container(
          color: AppColors.surface,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(record.name, style: AppText.bodyMedium, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 2),
                    Text(record.srn, style: AppText.srn.copyWith(color: AppColors.textSecondary)),
                  ],
                ),
              ),
              const SizedBox(width: 12),
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

/// Tab 2: Registered List (Google Form Responses)
class _RegisteredListTab extends StatefulWidget {
  const _RegisteredListTab();

  @override
  State<_RegisteredListTab> createState() => _RegisteredListTabState();
}

class _RegisteredListTabState extends State<_RegisteredListTab> {
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  Timer? _debounceTimer;

  List<RegisteredParticipant> _items = [];
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
      if (reset) _error = null;
    });

    try {
      final app = context.read<AppState>();
      final pageData = await app.api.listParticipants(
        page: targetPage,
        search: _searchController.text,
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
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          color: AppColors.surface,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: StatFigure(label: 'Total Registered (Form)', value: '$_total'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _searchController,
                onChanged: _onSearchChanged,
                decoration: InputDecoration(
                  hintText: 'Search by SRN, Name, or Branch',
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
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () => _fetch(reset: true),
            child: _buildList(),
          ),
        ),
      ],
    );
  }

  Widget _buildList() {
    if (_loading && _items.isEmpty) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
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
              OutlinedButton(onPressed: () => _fetch(reset: true), child: const Text('Try Again')),
            ],
          ),
        ),
      );
    }
    if (_items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.folder_open, size: 40, color: AppColors.textSecondary),
              const SizedBox(height: 12),
              Text(
                _searchController.text.isNotEmpty
                    ? 'No registered student found matching "${_searchController.text}"'
                    : 'No registration form responses recorded yet',
                style: AppText.meta,
                textAlign: TextAlign.center,
              ),
            ],
          ),
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
              child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
            ),
          );
        }
        final p = _items[index];
        final isWalkIn = p.registrationSource.contains('walk_in');

        return Container(
          color: AppColors.surface,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(p.name, style: AppText.bodyMedium, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Text(p.srn, style: AppText.srn.copyWith(color: AppColors.textSecondary, fontSize: 13)),
                        if (p.branch.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(
                              color: AppColors.background,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Text(p.branch, style: AppText.meta.copyWith(fontSize: 10, fontWeight: FontWeight.w600)),
                          ),
                        ],
                      ],
                    ),
                    if (p.email.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(p.email, style: AppText.meta.copyWith(fontSize: 12), overflow: TextOverflow.ellipsis),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: isWalkIn ? AppColors.warningTint : AppColors.tint,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      isWalkIn ? 'Walk-in Form' : 'Google Form',
                      style: AppText.meta.copyWith(
                        fontSize: 11,
                        color: isWalkIn ? AppColors.warning : AppColors.primary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  if (p.registeredAt != null) ...[
                    const SizedBox(height: 4),
                    Text(formatTime(p.registeredAt), style: AppText.meta.copyWith(fontSize: 11)),
                  ],
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
