import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:travle_core/travle_core.dart';
import 'package:travle_ui/travle_ui.dart';

/// Lets the signed-in user change their own password. The account is taken from
/// the JWT server-side; the current password is re-entered and verified. Mirrors
/// the backend rules (new ≥ 8 chars, differs from current, confirmation matches).
class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _current = TextEditingController();
  final _new = TextEditingController();
  final _confirm = TextEditingController();

  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _current.dispose();
    _new.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _error = null);
    if (!_formKey.currentState!.validate()) return;

    setState(() => _busy = true);
    final userProvider = context.read<UserProvider>();
    final navigator = Navigator.of(context);
    try {
      await userProvider.changePassword(
        UserPasswordChangeRequest(
          currentPassword: _current.text,
          newPassword: _new.text,
          confirmNewPassword: _confirm.text,
        ),
      );
      if (!mounted) return;
      AppSnackbars.success(context, 'Your password has been changed.');
      navigator.pop();
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
    return Scaffold(
      appBar: AppBar(title: const Text('Change password')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(TravleTokens.space16),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(TravleTokens.space24),
                  child: Form(
                    key: _formKey,
                    autovalidateMode: AutovalidateMode.onUnfocus,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TravleTextField(
                          controller: _current,
                          label: 'Current password',
                          prefixIcon: Icons.lock_outline,
                          obscure: true,
                          textInputAction: TextInputAction.next,
                          autofillHints: const [AutofillHints.password],
                          validator: (v) =>
                              Validators.required(v, field: 'Current password'),
                        ),
                        const SizedBox(height: TravleTokens.space16),
                        TravleTextField(
                          controller: _new,
                          label: 'New password',
                          prefixIcon: Icons.lock_reset,
                          helperText: 'At least 8 characters',
                          obscure: true,
                          textInputAction: TextInputAction.next,
                          autofillHints: const [AutofillHints.newPassword],
                          validator: (v) {
                            final tooShort =
                                Validators.password(v, field: 'New password');
                            if (tooShort != null) return tooShort;
                            if (v == _current.text) {
                              return 'New password must differ from the current one';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: TravleTokens.space16),
                        TravleTextField(
                          controller: _confirm,
                          label: 'Confirm new password',
                          prefixIcon: Icons.lock_reset,
                          obscure: true,
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) => _submit(),
                          validator: (v) => Validators.match(v, _new.text),
                        ),
                        if (_error != null) ...[
                          const SizedBox(height: TravleTokens.space16),
                          Text(
                            _error!,
                            style: TextStyle(color: theme.colorScheme.error),
                          ),
                        ],
                        const SizedBox(height: TravleTokens.space24),
                        ElevatedButton(
                          onPressed: _busy ? null : _submit,
                          child: _busy
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Text('Change password'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
