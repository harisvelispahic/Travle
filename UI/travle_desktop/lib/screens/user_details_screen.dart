import 'package:travle_desktop/layouts/master_screen.dart';
import 'package:travle_desktop/models/user.dart';
import 'package:travle_desktop/providers/user_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:provider/provider.dart';

class UserDetailsScreen extends StatefulWidget {
  final User? user;

  const UserDetailsScreen({super.key, this.user});

  @override
  State<UserDetailsScreen> createState() => _UserDetailsScreenState();
}

class _UserDetailsScreenState extends State<UserDetailsScreen> {
  final _formKey = GlobalKey<FormBuilderState>();
  Map<String, dynamic> _initialValue = {};

  late UserProvider _userProvider;

  @override
  void initState() {
    super.initState();

    _initialValue = {
      'firstName': widget.user?.firstName ?? '',
      'lastName': widget.user?.lastName ?? '',
      'email': widget.user?.email ?? '',
      'username': widget.user?.username ?? '',
      'phoneNumber': widget.user?.phoneNumber ?? '',
      'isActive': widget.user?.isActive ?? true,
      'password': '',
    };

    _userProvider = context.read<UserProvider>();
  }

  bool get _isEditing => widget.user != null;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return MasterScreen(
      title: _isEditing ? 'Edit User' : 'Create User',
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32.0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildHeader(theme),
                const SizedBox(height: 24),
                _buildPersonalSection(theme),
                const SizedBox(height: 16),
                _buildAccountSection(theme),
                const SizedBox(height: 16),
                _buildStatusSection(theme),
                const SizedBox(height: 24),
                _buildActions(theme),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    final fullName =
        '${widget.user?.firstName ?? ''} ${widget.user?.lastName ?? ''}'.trim();
    return Row(
      children: [
        CircleAvatar(
          radius: 32,
          backgroundColor: theme.colorScheme.primaryContainer,
          child: _isEditing
              ? Text(
                  _initials(widget.user?.firstName, widget.user?.lastName),
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                )
              : Icon(
                  Icons.person_add_outlined,
                  size: 28,
                  color: theme.colorScheme.onPrimaryContainer,
                ),
        ),
        const SizedBox(width: 18),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _isEditing
                  ? (fullName.isEmpty ? 'Edit User' : fullName)
                  : 'New User',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              _isEditing
                  ? 'Update profile and account settings'
                  : 'Fill in the details to create a new user',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSectionCard({
    required ThemeData theme,
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
            const Divider(height: 20),
            child,
          ],
        ),
      ),
    );
  }

  Widget _buildPersonalSection(ThemeData theme) {
    return _buildSectionCard(
      theme: theme,
      title: 'Personal Information',
      icon: Icons.badge_outlined,
      child: FormBuilder(
        key: _formKey,
        initialValue: _initialValue,
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: FormBuilderTextField(
                    name: 'firstName',
                    decoration: _inputDecoration(
                      'First Name',
                      Icons.person_outline,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: FormBuilderTextField(
                    name: 'lastName',
                    decoration: _inputDecoration(
                      'Last Name',
                      Icons.person_outline,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            FormBuilderTextField(
              name: 'phoneNumber',
              decoration: _inputDecoration(
                'Phone Number',
                Icons.phone_outlined,
              ),
              keyboardType: TextInputType.phone,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAccountSection(ThemeData theme) {
    return _buildSectionCard(
      theme: theme,
      title: 'Account Details',
      icon: Icons.manage_accounts_outlined,
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: FormBuilderTextField(
                  name: 'username',
                  decoration: _inputDecoration(
                    'Username',
                    Icons.alternate_email,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: FormBuilderTextField(
                  name: 'email',
                  decoration: _inputDecoration('Email', Icons.email_outlined),
                  keyboardType: TextInputType.emailAddress,
                ),
              ),
            ],
          ),
          if (!_isEditing) ...[
            const SizedBox(height: 16),
            FormBuilderTextField(
              name: 'password',
              decoration: _inputDecoration('Password', Icons.lock_outline),
              obscureText: true,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatusSection(ThemeData theme) {
    return _buildSectionCard(
      theme: theme,
      title: 'Account Status',
      icon: Icons.toggle_on_outlined,
      child: FormBuilderCheckbox(
        name: 'isActive',
        title: const Text("Active account"),
        subtitle: const Text("User can log in and access the system"),
        activeColor: theme.colorScheme.primary,
        decoration: const InputDecoration(border: InputBorder.none),
      ),
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, size: 20),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      isDense: true,
    );
  }

  Widget _buildActions(ThemeData theme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        OutlinedButton.icon(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.close),
          label: const Text("Cancel"),
        ),
        const SizedBox(width: 12),
        FilledButton.icon(
          onPressed: _save,
          icon: Icon(
            _isEditing ? Icons.save_outlined : Icons.person_add_outlined,
          ),
          label: Text(_isEditing ? "Save Changes" : "Create User"),
        ),
      ],
    );
  }

  Future _save() async {
    if (_formKey.currentState?.saveAndValidate() ?? false) {
      var formData = Map<String, dynamic>.from(_formKey.currentState!.value);

      if (_isEditing) {
        formData.remove('password');
      }

      try {
        if (_isEditing) {
          await _userProvider.update(widget.user!.id!, formData);
        } else {
          await _userProvider.insert(formData);
        }

        if (!mounted) return;
        Navigator.of(context).pop("reload");
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error saving user: $e"),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  String _initials(String? first, String? last) {
    final f = (first?.isNotEmpty == true) ? first![0].toUpperCase() : '';
    final l = (last?.isNotEmpty == true) ? last![0].toUpperCase() : '';
    return '$f$l';
  }
}
