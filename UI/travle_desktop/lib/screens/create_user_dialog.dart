import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:travle_core/travle_core.dart';
import 'package:travle_ui/travle_ui.dart';

/// Admin "create user" form dialog. Collects the personal fields, an initial
/// password (the admin sets it — the new user can change it later), and a
/// **multi-select** of roles loaded from the database (`GET /Roles`). Returns
/// `true` when an account was created so the caller refreshes its list.
Future<bool?> showCreateUserDialog(BuildContext context) {
  return showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const _CreateUserDialog(),
  );
}

class _CreateUserDialog extends StatefulWidget {
  const _CreateUserDialog();

  @override
  State<_CreateUserDialog> createState() => _CreateUserDialogState();
}

class _CreateUserDialogState extends State<_CreateUserDialog> {
  final _formKey = GlobalKey<FormState>();
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _email = TextEditingController();
  final _username = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();

  List<RoleOptionResponse> _roles = [];
  final Set<int> _selectedRoleIds = {};

  bool _loadingRoles = true;
  String? _loadError;
  bool _rolesTouched = false; // to show the "pick a role" message only after submit
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadRoles();
  }

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    _email.dispose();
    _username.dispose();
    _phone.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _loadRoles() async {
    setState(() {
      _loadingRoles = true;
      _loadError = null;
    });
    try {
      final roles = await context.read<RoleProvider>().getAll();
      if (!mounted) return;
      setState(() {
        _roles = roles;
        _loadingRoles = false;
      });
    } on ApiClientException catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = e.message;
        _loadingRoles = false;
      });
    }
  }

  Future<void> _submit() async {
    setState(() {
      _error = null;
      _rolesTouched = true;
    });
    final formValid = _formKey.currentState!.validate();
    if (!formValid || _selectedRoleIds.isEmpty) return;

    final userProvider = context.read<UserProvider>();
    final navigator = Navigator.of(context);
    setState(() => _busy = true);
    try {
      await userProvider.createUser(
        AdminCreateUserRequest(
          firstName: _firstName.text.trim(),
          lastName: _lastName.text.trim(),
          email: _email.text.trim(),
          username: _username.text.trim(),
          password: _password.text,
          phoneNumber: _phone.text.trim().isEmpty ? null : _phone.text.trim(),
          roleIds: _selectedRoleIds.toList(),
        ),
      );
      navigator.pop(true);
    } on ApiClientException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
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
          const Expanded(child: Text('Create user')),
          IconButton(
            tooltip: 'Close',
            icon: const Icon(Icons.close),
            onPressed: _busy ? null : () => Navigator.of(context).pop(),
          ),
        ],
      ),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            autovalidateMode: AutovalidateMode.onUnfocus,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                TravleTextField(
                  controller: _firstName,
                  label: 'First name',
                  prefixIcon: Icons.person_outline,
                  textInputAction: TextInputAction.next,
                  validator: (v) => Validators.required(v, field: 'First name'),
                ),
                const SizedBox(height: TravleTokens.space16),
                TravleTextField(
                  controller: _lastName,
                  label: 'Last name',
                  prefixIcon: Icons.person_outline,
                  textInputAction: TextInputAction.next,
                  validator: (v) => Validators.required(v, field: 'Last name'),
                ),
                const SizedBox(height: TravleTokens.space16),
                TravleTextField(
                  controller: _email,
                  label: 'Email',
                  prefixIcon: Icons.mail_outline,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  validator: Validators.email,
                ),
                const SizedBox(height: TravleTokens.space16),
                TravleTextField(
                  controller: _username,
                  label: 'Username',
                  prefixIcon: Icons.badge_outlined,
                  textInputAction: TextInputAction.next,
                  validator: (v) => Validators.minLength(v, 3, field: 'Username'),
                ),
                const SizedBox(height: TravleTokens.space16),
                TravleTextField(
                  controller: _phone,
                  label: 'Phone (optional)',
                  prefixIcon: Icons.phone_outlined,
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.next,
                  validator: (v) =>
                      Validators.maxLength(v, 20, field: 'Phone number'),
                ),
                const SizedBox(height: TravleTokens.space16),
                TravleTextField(
                  controller: _password,
                  label: 'Initial password',
                  prefixIcon: Icons.lock_outline,
                  helperText: 'At least 8 characters',
                  obscure: true,
                  textInputAction: TextInputAction.next,
                  validator: (v) => Validators.password(v, field: 'Password'),
                ),
                const SizedBox(height: TravleTokens.space16),
                TravleTextField(
                  controller: _confirm,
                  label: 'Confirm password',
                  prefixIcon: Icons.lock_outline,
                  obscure: true,
                  textInputAction: TextInputAction.done,
                  validator: (v) => Validators.match(v, _password.text),
                ),
                const SizedBox(height: TravleTokens.space24),
                Text('Roles', style: theme.textTheme.titleSmall),
                const SizedBox(height: TravleTokens.space4),
                _buildRoles(theme),
                if (_error != null) ...[
                  const SizedBox(height: TravleTokens.space16),
                  Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _busy || _loadingRoles ? null : _submit,
          child: _busy
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Create'),
        ),
      ],
    );
  }

  Widget _buildRoles(ThemeData theme) {
    if (_loadingRoles) {
      return const Padding(
        padding: EdgeInsets.all(TravleTokens.space12),
        child: Center(
          child: SizedBox(
            height: 20,
            width: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }
    if (_loadError != null) {
      return Row(
        children: [
          Expanded(
            child: Text(_loadError!,
                style: TextStyle(color: theme.colorScheme.error)),
          ),
          TextButton(onPressed: _loadRoles, child: const Text('Retry')),
        ],
      );
    }
    final showError = _rolesTouched && _selectedRoleIds.isEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final role in _roles)
          CheckboxListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            value: _selectedRoleIds.contains(role.id),
            title: Text(role.name),
            onChanged: _busy
                ? null
                : (checked) => setState(() {
                      if (checked ?? false) {
                        _selectedRoleIds.add(role.id);
                      } else {
                        _selectedRoleIds.remove(role.id);
                      }
                    }),
          ),
        if (showError)
          Padding(
            padding: const EdgeInsets.only(top: TravleTokens.space4),
            child: Text(
              'Select at least one role.',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.error),
            ),
          ),
      ],
    );
  }
}
