import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../main.dart';

/// ------------------------------
/// Courts - Step B
/// ------------------------------

enum CourtSort {
  nameAZ,
  newest,
}

class CourtsPage extends StatefulWidget {
  const CourtsPage({super.key});

  @override
  State<CourtsPage> createState() => _CourtsPageState();
}

class _CourtsPageState extends State<CourtsPage> {
  final TextEditingController _searchCtrl = TextEditingController();

  bool _loading = false;
  String? _error;

  List<Map<String, dynamic>> _courts = [];

  CourtSort _sort = CourtSort.nameAZ;
  bool _filterActiveOnly = false;
  bool _filterHasRadius = false;

  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(_onSearchChanged);
    _loadCourts();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.removeListener(_onSearchChanged);
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      _loadCourts();
    });
    setState(() {});
  }

  Future<void> _loadCourts() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final term = _searchCtrl.text.trim();

      var q = supabase.from('courts').select('*');

      if (term.isNotEmpty) {
        q = q.ilike('name', '%$term%');
      }

      final res = await q.order('name', ascending: true);

      final list = (res as List).cast<Map<String, dynamic>>();

      setState(() {
        _courts = list;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  void _clearSearch() {
    _searchCtrl.clear();
    FocusScope.of(context).unfocus();
  }

  void _resetAllFilters() {
    setState(() {
      _sort = CourtSort.nameAZ;
      _filterActiveOnly = false;
      _filterHasRadius = false;
    });
  }

  List<Map<String, dynamic>> _applyClientFiltersAndSort(
    List<Map<String, dynamic>> input,
  ) {
    Iterable<Map<String, dynamic>> out = input;

    if (_filterActiveOnly) {
      out = out.where((c) {
        final v = c['is_active'];
        if (v is bool) return v == true;
        return true;
      });
    }

    if (_filterHasRadius) {
      out = out.where((c) {
        final v = c['radius_meters'];
        if (v == null) return false;
        if (v is num) return v > 0;
        return true;
      });
    }

    final list = out.toList();

    switch (_sort) {
      case CourtSort.nameAZ:
        list.sort((a, b) {
          final an = (a['name'] ?? '').toString().toLowerCase();
          final bn = (b['name'] ?? '').toString().toLowerCase();
          return an.compareTo(bn);
        });
        break;

      case CourtSort.newest:
        list.sort((a, b) {
          final ac = a['created_at'];
          final bc = b['created_at'];

          DateTime? ad;
          DateTime? bd;

          if (ac is String) ad = DateTime.tryParse(ac);
          if (bc is String) bd = DateTime.tryParse(bc);

          if (ad != null && bd != null) {
            return bd.compareTo(ad);
          }
          final an = (a['name'] ?? '').toString().toLowerCase();
          final bn = (b['name'] ?? '').toString().toLowerCase();
          return an.compareTo(bn);
        });
        break;
    }

    return list;
  }

  @override
  Widget build(BuildContext context) {
    final visibleCourts = _applyClientFiltersAndSort(_courts);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Courts'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _loading ? null : _loadCourts,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadCourts,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _SearchAndTools(
              controller: _searchCtrl,
              onClear: _clearSearch,
              sort: _sort,
              onSortChanged: (v) {
                if (v == null) return;
                setState(() => _sort = v);
              },
            ),
            const SizedBox(height: 10),
            _FilterChipsRow(
              activeOnly: _filterActiveOnly,
              hasRadius: _filterHasRadius,
              onToggleActiveOnly: () =>
                  setState(() => _filterActiveOnly = !_filterActiveOnly),
              onToggleHasRadius: () =>
                  setState(() => _filterHasRadius = !_filterHasRadius),
              onReset: _resetAllFilters,
            ),
            const SizedBox(height: 16),
            if (_error != null) _ErrorCard(message: _error!),
            if (_loading) ...[
              const SizedBox(height: 12),
              const Center(child: CircularProgressIndicator()),
              const SizedBox(height: 12),
            ] else if (visibleCourts.isEmpty) ...[
              _EmptyState(
                hasSearch: _searchCtrl.text.trim().isNotEmpty,
                hasFilters: _filterActiveOnly || _filterHasRadius,
                onClearSearch: _clearSearch,
                onShowAll: () {
                  _clearSearch();
                  _resetAllFilters();
                },
              ),
            ] else ...[
              Text(
                '${visibleCourts.length} court${visibleCourts.length == 1 ? '' : 's'}',
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: 10),
              ...visibleCourts.map((c) => _CourtCard(
                    court: c,
                    onTap: () {
                      final id = (c['id'] ?? '').toString();
                      if (id.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('Court is missing an id')),
                        );
                        return;
                      }
                      context.push('/courts/$id');
                    },
                  )),
            ],
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _SearchAndTools extends StatelessWidget {
  const _SearchAndTools({
    required this.controller,
    required this.onClear,
    required this.sort,
    required this.onSortChanged,
  });

  final TextEditingController controller;
  final VoidCallback onClear;
  final CourtSort sort;
  final ValueChanged<CourtSort?> onSortChanged;

  @override
  Widget build(BuildContext context) {
    final term = controller.text.trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: controller,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            labelText: 'Search courts by name',
            hintText: 'Ex: “Central Park Court”',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: term.isEmpty
                ? null
                : IconButton(
                    tooltip: 'Clear',
                    onPressed: onClear,
                    icon: const Icon(Icons.close),
                  ),
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 10),
        DropdownButtonFormField<CourtSort>(
          value: sort,
          decoration: const InputDecoration(
            labelText: 'Sort',
            border: OutlineInputBorder(),
          ),
          items: const [
            DropdownMenuItem(
              value: CourtSort.nameAZ,
              child: Text('Name (A–Z)'),
            ),
            DropdownMenuItem(
              value: CourtSort.newest,
              child: Text('Newest'),
            ),
          ],
          onChanged: onSortChanged,
        ),
      ],
    );
  }
}

class _FilterChipsRow extends StatelessWidget {
  const _FilterChipsRow({
    required this.activeOnly,
    required this.hasRadius,
    required this.onToggleActiveOnly,
    required this.onToggleHasRadius,
    required this.onReset,
  });

  final bool activeOnly;
  final bool hasRadius;
  final VoidCallback onToggleActiveOnly;
  final VoidCallback onToggleHasRadius;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    final any = activeOnly || hasRadius;

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        FilterChip(
          label: const Text('Active only'),
          selected: activeOnly,
          onSelected: (_) => onToggleActiveOnly(),
        ),
        FilterChip(
          label: const Text('Has radius'),
          selected: hasRadius,
          onSelected: (_) => onToggleHasRadius(),
        ),
        if (any)
          TextButton.icon(
            onPressed: onReset,
            icon: const Icon(Icons.restart_alt),
            label: const Text('Reset'),
          ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.hasSearch,
    required this.hasFilters,
    required this.onClearSearch,
    required this.onShowAll,
  });

  final bool hasSearch;
  final bool hasFilters;
  final VoidCallback onClearSearch;
  final VoidCallback onShowAll;

  @override
  Widget build(BuildContext context) {
    final title = hasSearch || hasFilters ? 'No courts found' : 'No courts yet';

    final body = hasSearch || hasFilters
        ? 'Try clearing your search or resetting filters.'
        : 'Once courts exist in Supabase, they’ll show up here.';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(
            Icons.sports_basketball,
            size: 44,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 10),
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 6),
          Text(
            body,
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            alignment: WrapAlignment.center,
            children: [
              if (hasSearch)
                OutlinedButton.icon(
                  onPressed: onClearSearch,
                  icon: const Icon(Icons.close),
                  label: const Text('Clear search'),
                ),
              FilledButton.icon(
                onPressed: onShowAll,
                icon: const Icon(Icons.list),
                label: const Text('Show all'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            Icons.error_outline,
            color: Theme.of(context).colorScheme.onErrorContainer,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onErrorContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CourtCard extends StatelessWidget {
  const _CourtCard({
    required this.court,
    required this.onTap,
  });

  final Map<String, dynamic> court;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final name = (court['name'] ?? 'Unnamed court').toString();
    final city = (court['city'] ?? '').toString();
    final state = (court['state'] ?? '').toString();

    String subtitle = '';
    if (city.isNotEmpty && state.isNotEmpty) subtitle = '$city, $state';
    if (subtitle.isEmpty && city.isNotEmpty) subtitle = city;
    if (subtitle.isEmpty && state.isNotEmpty) subtitle = state;

    final radius = court['radius_meters'];
    final radiusText =
        (radius is num && radius > 0) ? '${radius.toInt()}m radius' : null;

    final isActive =
        court['is_active'] is bool ? court['is_active'] as bool : true;

    return Card(
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          child: Text(
            name.isNotEmpty ? name.substring(0, 1).toUpperCase() : 'C',
          ),
        ),
        title: Text(name),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (subtitle.isNotEmpty) Text(subtitle),
            const SizedBox(height: 2),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                if (radiusText != null) _Pill(text: radiusText),
                _Pill(text: isActive ? 'Active' : 'Inactive'),
              ],
            ),
          ],
        ),
        trailing: const Icon(Icons.chevron_right),
        isThreeLine: subtitle.isNotEmpty || radiusText != null,
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Text(text, style: Theme.of(context).textTheme.labelSmall),
    );
  }
}
