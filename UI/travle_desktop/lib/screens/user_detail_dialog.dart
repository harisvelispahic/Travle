import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:travle_core/travle_core.dart';
import 'package:travle_ui/travle_ui.dart';

import '../widgets/user_detail_card.dart';

/// Admin user-detail dialog: the read-only [UserDetailCard] plus the admin
/// actions — suspend/unsuspend (reason required to suspend) and role grant/revoke.
/// Returns `true` when anything changed so the caller reloads its list.
Future<bool?> showUserDetailDialog(BuildContext context, UserResponse user) {
  return showDialog<bool>(
    context: context,
    builder: (_) => _UserDetailDialog(initial: user),
  );
}

class _UserDetailDialog extends StatefulWidget {
  const _UserDetailDialog({required this.initial});
  final UserResponse initial;

  @override
  State<_UserDetailDialog> createState() => _UserDetailDialogState();
}

class _UserDetailDialogState extends State<_UserDetailDialog> {
  late UserResponse _user = widget.initial;
  bool _changed = false;
  bool _busy = false;

  List<RoleOptionResponse> _allRoles = [];
  bool _loadingRoles = true;
  int? _roleToAdd;

  @override
  void initState() {
    super.initState();
    _loadRoles();
  }

  bool get _isSelf => context.read<AuthProvider>().userId == _user.id;

  Future<void> _loadRoles() async {
    try {
      final roles = await context.read<RoleProvider>().getAll();
      if (!mounted) return;
      setState(() {
        _allRoles = roles;
        _loadingRoles = false;
      });
    } on ApiClientException {
      // Non-fatal: without the lookup the add-role picker is simply unavailable.
      if (!mounted) return;
      setState(() => _loadingRoles = false);
    }
  }

  List<RoleOptionResponse> get _addableRoles =>
      _allRoles.where((r) => !_user.roles.contains(r.name)).toList();

  Future<void> _run(Future<UserResponse> Function() action, String success) async {
    final auth = context.read<AuthProvider>();
    final wasSelf = _isSelf;
    setState(() => _busy = true);
    try {
      final updated = await action();
      if (!mounted) return;
      setState(() {
        _user = updated;
        _changed = true;
        _roleToAdd = null;
      });
      // Changing your own roles rolled your security stamp, so the current access token is now stale.
      // Silently refresh (a self non-admin role change keeps the refresh token) so the new permissions
      // apply immediately — the sidebar picks them up — without a visible logout.
      if (wasSelf) {
        unawaited(auth.tryRefresh());
      }
      AppSnackbars.success(context, success);
    } on ApiClientException catch (e) {
      if (!mounted) return;
      AppSnackbars.error(context, e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _suspend() async {
    final provider = context.read<UserProvider>();
    final reason = await _promptReason();
    if (reason == null) return;
    await _run(() => provider.suspend(_user.id, reason), 'User suspended.');
  }

  Future<void> _unsuspend() async {
    final provider = context.read<UserProvider>();
    final confirmed = await showConfirmDialog(
      context,
      title: 'Lift suspension',
      message: 'Restore access for ${_user.fullName.trim().isNotEmpty ? _user.fullName : _user.username}?',
      confirmLabel: 'Unsuspend',
    );
    if (!confirmed) return;
    await _run(() => provider.unsuspend(_user.id), 'Suspension lifted.');
  }

  Future<void> _grant() async {
    final roleId = _roleToAdd;
    if (roleId == null) return;
    final provider = context.read<UserProvider>();
    await _run(() => provider.grantRole(_user.id, roleId), 'Role granted.');
  }

  Future<void> _revoke(String roleName) async {
    final matches = _allRoles.where((r) => r.name == roleName);
    if (matches.isEmpty) {
      // The lookup didn't load; we can't resolve the id to revoke.
      AppSnackbars.error(context, 'Roles are still loading — try again.');
      return;
    }
    final role = matches.first;
    final provider = context.read<UserProvider>();
    final isSelf = _isSelf;
    final who = _user.fullName.trim().isNotEmpty ? _user.fullName : _user.username;
    final confirmed = await showConfirmDialog(
      context,
      title: 'Remove role',
      message: isSelf
          ? 'Remove the $roleName role from your own account? Your access updates immediately.'
          : 'Remove the $roleName role from $who? They lose access to its features immediately.',
      confirmLabel: 'Remove',
      destructive: true,
    );
    if (!confirmed) return;
    await _run(() => provider.revokeRole(_user.id, role.id), 'Role removed.');
  }

  Future<String?> _promptReason() {
    final controller = TextEditingController();
    String? errorText;
    return showDialog<String>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setLocal) {
            return AlertDialog(
              title: const Text('Suspend user'),
              content: TextField(
                controller: controller,
                autofocus: true,
                minLines: 2,
                maxLines: 4,
                maxLength: 500,
                decoration: InputDecoration(
                  labelText: 'Reason (emailed to the user)',
                  errorText: errorText,
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.error,
                    foregroundColor: Theme.of(context).colorScheme.onError,
                  ),
                  onPressed: () {
                    final text = controller.text.trim();
                    if (text.isEmpty) {
                      setLocal(() => errorText = 'A reason is required');
                      return;
                    }
                    Navigator.of(context).pop(text);
                  },
                  child: const Text('Suspend'),
                ),
              ],
            );
          },
        );
      },
    ).whenComplete(controller.dispose);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      titlePadding: const EdgeInsets.fromLTRB(
        TravleTokens.space24,
        TravleTokens.space16,
        TravleTokens.space8,
        0,
      ),
      title: Row(
        children: [
          const Expanded(child: Text('User details')),
          IconButton(
            tooltip: 'Close',
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.of(context).pop(_changed),
          ),
        ],
      ),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              UserDetailCard(user: _user),
              const Divider(height: TravleTokens.space32),
              _buildRoleManagement(theme),
            ],
          ),
        ),
      ),
      actions: [
        if (_busy)
          const Padding(
            padding: EdgeInsets.only(right: TravleTokens.space8),
            child: SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        if (_isSelf)
          const Padding(
            padding: EdgeInsets.only(right: TravleTokens.space8),
            child: Text('This is your own account'),
          )
        else if (_user.isSuspended)
          FilledButton.icon(
            onPressed: _busy ? null : _unsuspend,
            icon: const Icon(Icons.lock_open_outlined),
            label: const Text('Unsuspend'),
          )
        else
          FilledButton.icon(
            onPressed: _busy ? null : _suspend,
            style: FilledButton.styleFrom(
              backgroundColor: theme.colorScheme.error,
              foregroundColor: theme.colorScheme.onError,
            ),
            icon: const Icon(Icons.block),
            label: const Text('Suspend'),
          ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(_changed),
          child: const Text('Done'),
        ),
      ],
    );
  }

  Widget _buildRoleManagement(ThemeData theme) {
    // Managing your own roles is allowed now that a self non-admin role change keeps your refresh token
    // — the app silently refreshes to the new permissions instead of signing you out. Removing your own
    // Admin role (and the last Admin) stays blocked (guarded on the server; the Admin chip below isn't
    // removable for yourself).
    final isSelf = _isSelf;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Manage roles', style: theme.textTheme.titleSmall),
        const SizedBox(height: TravleTokens.space8),
        if (_user.roles.isEmpty)
          Text(
            'This user holds no roles.',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          )
        else
          Wrap(
            spacing: TravleTokens.space8,
            runSpacing: TravleTokens.space8,
            children: [
              for (final role in _user.roles) _roleChip(theme, role, isSelf),
            ],
          ),
        const SizedBox(height: TravleTokens.space16),
        _buildAddRole(theme),
      ],
    );
  }

  Widget _roleChip(ThemeData theme, String role, bool isSelf) {
    // You can't remove your own Admin role (self-lockout guard, also enforced on the server) — that chip
    // stays fixed. Every other role, on any account, is removable.
    final locked = isSelf && role == AppRole.admin;
    if (locked) {
      return Chip(
        label: Text(role),
        avatar: const Icon(Icons.lock_outline, size: 16),
        visualDensity: VisualDensity.compact,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      );
    }
    return InputChip(
      label: Text(role),
      onDeleted: _busy ? null : () => _revoke(role),
      deleteIcon: const Icon(Icons.close, size: 18),
      tooltip: 'Remove role',
    );
  }

  Widget _buildAddRole(ThemeData theme) {
    if (_loadingRoles) {
      return const SizedBox(
        height: 20,
        width: 20,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }
    final addable = _addableRoles;
    if (addable.isEmpty) {
      return Text(
        'This user already holds every role.',
        style: theme.textTheme.bodySmall
            ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
      );
    }
    return Row(
      children: [
        Expanded(
          child: DropdownButtonFormField<int>(
            isExpanded: true,
            initialValue: _roleToAdd,
            decoration: const InputDecoration(
              isDense: true,
              labelText: 'Add a role',
            ),
            items: [
              for (final r in addable)
                DropdownMenuItem(value: r.id, child: Text(r.name)),
            ],
            onChanged:
                _busy ? null : (id) => setState(() => _roleToAdd = id),
          ),
        ),
        const SizedBox(width: TravleTokens.space12),
        FilledButton.icon(
          onPressed: _busy || _roleToAdd == null ? null : _grant,
          icon: const Icon(Icons.add),
          label: const Text('Add'),
        ),
      ],
    );
  }
}
