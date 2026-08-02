import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:travle_core/travle_core.dart';
import 'package:travle_ui/travle_ui.dart';

import 'create_user_dialog.dart';
import 'user_detail_dialog.dart';

/// Admin user management: a searchable, filterable, paginated list of accounts
/// (avatar, name, roles, suspended state). "Create user" opens the create form;
/// tapping a row opens the detail dialog (suspend/unsuspend + role management).
/// There is no delete — accounts are suspended, never removed.
class UsersScreen extends StatefulWidget {
  const UsersScreen({super.key});

  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> {
  static const int _pageSize = 15;

  final _searchController = TextEditingController();
  Timer? _debounce;

  String _search = '';
  String? _roleFilter; // null = any role
  bool? _statusFilter; // null = all, true = suspended, false = active
  int _page = 1;

  bool _loading = true;
  String? _error;
  List<UserResponse> _items = [];
  int? _totalCount;

  List<RoleOptionResponse> _roles = [];

  @override
  void initState() {
    super.initState();
    _loadRoles();
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadRoles() async {
    try {
      final roles = await context.read<RoleProvider>().getAll();
      if (!mounted) return;
      setState(() => _roles = roles);
    } on ApiClientException {
      // Non-fatal: the role filter simply stays empty.
    }
  }

  Map<String, dynamic> _query() {
    final query = <String, dynamic>{
      'page': _page,
      'pageSize': _pageSize,
      'includeTotalCount': true,
      'sortBy': 'CreatedAt desc',
    };
    if (_search.isNotEmpty) query['name'] = _search;
    if (_roleFilter != null) query['roleName'] = _roleFilter;
    if (_statusFilter != null) query['isSuspended'] = _statusFilter;
    return query;
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await context.read<UserProvider>().get(filter: _query());
      if (!mounted) return;
      setState(() {
        _items = result.items;
        _totalCount = result.totalCount;
        _loading = false;
      });
    } on ApiClientException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    }
  }

  void _onSearchChanged(String value) {
    setState(() {});
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      setState(() {
        _search = value.trim();
        _page = 1;
      });
      _load();
    });
  }

  Future<void> _openDetail(UserResponse user) async {
    final changed = await showUserDetailDialog(context, user);
    if (changed == true) await _load();
  }

  Future<void> _create() async {
    final created = await showCreateUserDialog(context);
    if (created == true) {
      if (mounted) AppSnackbars.success(context, 'User created.');
      setState(() => _page = 1);
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(TravleTokens.space16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildToolbar(context),
          const SizedBox(height: TravleTokens.space16),
          Expanded(child: _buildBody(Theme.of(context))),
          const Divider(height: 1),
          _buildPager(Theme.of(context)),
        ],
      ),
    );
  }

  Widget _buildToolbar(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 300,
          child: TextField(
            controller: _searchController,
            onChanged: _onSearchChanged,
            decoration: InputDecoration(
              isDense: true,
              prefixIcon: const Icon(Icons.search),
              hintText: 'Search by name…',
              suffixIcon: _searchController.text.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.close),
                      tooltip: 'Clear',
                      onPressed: () {
                        _searchController.clear();
                        _debounce?.cancel();
                        setState(() {
                          _search = '';
                          _page = 1;
                        });
                        _load();
                      },
                    ),
            ),
          ),
        ),
        const SizedBox(width: TravleTokens.space12),
        _buildRoleFilter(),
        const SizedBox(width: TravleTokens.space12),
        _buildStatusFilter(),
        const Spacer(),
        if (_loading)
          const Padding(
            padding: EdgeInsets.only(right: TravleTokens.space16),
            child: SizedBox(
              height: 18,
              width: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        FilledButton.icon(
          onPressed: _create,
          icon: const Icon(Icons.person_add_alt_1),
          label: const Text('Create user'),
        ),
      ],
    );
  }

  Widget _buildRoleFilter() {
    return SizedBox(
      width: 180,
      child: DropdownButtonFormField<String?>(
        isExpanded: true,
        initialValue: _roleFilter,
        decoration: const InputDecoration(isDense: true, labelText: 'Role'),
        items: [
          const DropdownMenuItem(value: null, child: Text('All roles')),
          for (final r in _roles)
            DropdownMenuItem(value: r.name, child: Text(r.name)),
        ],
        onChanged: (value) {
          setState(() {
            _roleFilter = value;
            _page = 1;
          });
          _load();
        },
      ),
    );
  }

  Widget _buildStatusFilter() {
    return SizedBox(
      width: 160,
      child: DropdownButtonFormField<bool?>(
        isExpanded: true,
        initialValue: _statusFilter,
        decoration: const InputDecoration(isDense: true, labelText: 'Status'),
        items: const [
          DropdownMenuItem(value: null, child: Text('All')),
          DropdownMenuItem(value: false, child: Text('Active')),
          DropdownMenuItem(value: true, child: Text('Suspended')),
        ],
        onChanged: (value) {
          setState(() {
            _statusFilter = value;
            _page = 1;
          });
          _load();
        },
      ),
    );
  }

  Widget _buildBody(ThemeData theme) {
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 40, color: theme.colorScheme.error),
            const SizedBox(height: TravleTokens.space12),
            Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
            const SizedBox(height: TravleTokens.space16),
            ElevatedButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      );
    }
    if (_loading && _items.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_items.isEmpty) {
      return const EmptyState(
        message: 'No users match the current search and filters.',
        icon: Icons.person_search_outlined,
      );
    }
    final selfId = context.watch<AuthProvider>().userId;
    return ListView.separated(
      itemCount: _items.length,
      separatorBuilder: (_, _) => const SizedBox(height: TravleTokens.space8),
      itemBuilder: (context, i) => _UserRow(
        user: _items[i],
        isSelf: _items[i].id == selfId,
        onTap: () => _openDetail(_items[i]),
      ),
    );
  }

  Widget _buildPager(ThemeData theme) {
    final total = _totalCount;
    final hasPrev = _page > 1;
    final hasNext = total != null
        ? _page * _pageSize < total
        : _items.length == _pageSize;

    String label;
    if (total != null) {
      final totalPages =
          total == 0 ? 1 : ((total + _pageSize - 1) ~/ _pageSize);
      label = 'Page $_page of $totalPages · $total total';
    } else {
      label = 'Page $_page';
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: TravleTokens.space8),
      child: Row(
        children: [
          Text(label, style: theme.textTheme.bodySmall),
          const Spacer(),
          IconButton(
            tooltip: 'Previous page',
            onPressed: hasPrev && !_loading
                ? () {
                    setState(() => _page -= 1);
                    _load();
                  }
                : null,
            icon: const Icon(Icons.chevron_left),
          ),
          IconButton(
            tooltip: 'Next page',
            onPressed: hasNext && !_loading
                ? () {
                    setState(() => _page += 1);
                    _load();
                  }
                : null,
            icon: const Icon(Icons.chevron_right),
          ),
        ],
      ),
    );
  }
}

class _UserRow extends StatelessWidget {
  const _UserRow({
    required this.user,
    required this.isSelf,
    required this.onTap,
  });

  final UserResponse user;
  final bool isSelf;
  final VoidCallback onTap;

  String get _initials {
    final a = user.firstName.trim().isNotEmpty ? user.firstName.trim()[0] : '';
    final b = user.lastName.trim().isNotEmpty ? user.lastName.trim()[0] : '';
    final initials = (a + b).toUpperCase();
    if (initials.isNotEmpty) return initials;
    return user.username.trim().isNotEmpty
        ? user.username.trim()[0].toUpperCase()
        : '';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final displayName =
        user.fullName.trim().isNotEmpty ? user.fullName : user.username;
    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(TravleTokens.radius),
        child: Padding(
          padding: const EdgeInsets.all(TravleTokens.space12),
          child: Row(
            children: [
              ProfileAvatar(
                base64Image: user.profileImageThumbnail,
                radius: 22,
                initials: _initials,
              ),
              const SizedBox(width: TravleTokens.space16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            displayName,
                            style: theme.textTheme.titleSmall,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isSelf) ...[
                          const SizedBox(width: TravleTokens.space8),
                          Text(
                            '(you)',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '@${user.username} · ${user.roles.isEmpty ? 'No roles' : user.roles.join(' · ')}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (user.isSuspended) ...[
                const SizedBox(width: TravleTokens.space12),
                _SuspendedPill(theme: theme),
              ],
              const SizedBox(width: TravleTokens.space8),
              Icon(Icons.chevron_right, color: theme.colorScheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

class _SuspendedPill extends StatelessWidget {
  const _SuspendedPill({required this.theme});
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final color = theme.colorScheme.error;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: TravleTokens.space8,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(TravleTokens.radius),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.block, size: 14, color: color),
          const SizedBox(width: TravleTokens.space4),
          Text(
            'Suspended',
            style: theme.textTheme.labelSmall?.copyWith(color: color),
          ),
        ],
      ),
    );
  }
}
