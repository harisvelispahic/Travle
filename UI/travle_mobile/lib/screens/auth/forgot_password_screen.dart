import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:travle_core/travle_core.dart';
import 'package:travle_ui/travle_ui.dart';

/// Two-step password reset: request a code by email, then set a new password
/// with that code. On success it returns to the login screen.
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _code = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _busy = false;
  bool _codeSent = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _code.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  String? _emailValidator(String? v) {
    if (v == null || v.trim().isEmpty) return 'Email is required';
    final ok = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v.trim());
    return ok ? null : 'Enter a valid email address';
  }

  Future<void> _sendCode() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final auth = context.read<AuthProvider>();
    try {
      await auth.forgotPassword(_email.text.trim());
      if (!mounted) return;
      setState(() => _codeSent = true);
    } on ApiClientException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reset() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final auth = context.read<AuthProvider>();
    final navigator = Navigator.of(context);
    try {
      await auth.resetPassword(
        ResetPasswordRequest(
          email: _email.text.trim(),
          code: _code.text.trim(),
          newPassword: _password.text,
          confirmNewPassword: _confirm.text,
        ),
      );
      if (!mounted) return;
      AppSnackbars.success(context, 'Password updated. Please sign in.');
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
      appBar: AppBar(title: const Text('Reset password')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(TravleTokens.space16),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(TravleTokens.space24),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          _codeSent
                              ? 'Enter the code sent to your email and choose a new password.'
                              : 'Enter your email and we\'ll send a reset code.',
                          style: theme.textTheme.bodyMedium,
                        ),
                        const SizedBox(height: TravleTokens.space24),
                        TextFormField(
                          controller: _email,
                          enabled: !_codeSent,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.done,
                          decoration: const InputDecoration(labelText: 'Email'),
                          validator: _emailValidator,
                        ),
                        if (_codeSent) ...[
                          const SizedBox(height: TravleTokens.space16),
                          TextFormField(
                            controller: _code,
                            textInputAction: TextInputAction.next,
                            decoration:
                                const InputDecoration(labelText: 'Reset code'),
                            validator: (v) => (v == null || v.trim().isEmpty)
                                ? 'Enter the code from your email'
                                : null,
                          ),
                          const SizedBox(height: TravleTokens.space16),
                          TextFormField(
                            controller: _password,
                            obscureText: true,
                            textInputAction: TextInputAction.next,
                            decoration: const InputDecoration(
                                labelText: 'New password'),
                            validator: (v) => (v == null || v.length < 8)
                                ? 'Password must be at least 8 characters'
                                : null,
                          ),
                          const SizedBox(height: TravleTokens.space16),
                          TextFormField(
                            controller: _confirm,
                            obscureText: true,
                            textInputAction: TextInputAction.done,
                            onFieldSubmitted: (_) => _reset(),
                            decoration: const InputDecoration(
                                labelText: 'Confirm new password'),
                            validator: (v) => (v != _password.text)
                                ? 'Passwords do not match'
                                : null,
                          ),
                        ],
                        if (_error != null) ...[
                          const SizedBox(height: TravleTokens.space16),
                          Text(_error!,
                              style:
                                  TextStyle(color: theme.colorScheme.error)),
                        ],
                        const SizedBox(height: TravleTokens.space24),
                        ElevatedButton(
                          onPressed: _busy
                              ? null
                              : (_codeSent ? _reset : _sendCode),
                          child: _busy
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
                                )
                              : Text(_codeSent
                                  ? 'Reset password'
                                  : 'Send reset code'),
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
