import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:travle_core/travle_core.dart';
import 'package:travle_ui/travle_ui.dart';

/// Self-service registration. On success the account is created (Traveler role)
/// and signed in automatically, so this route pops back to the shell.
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _username = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    _username.dispose();
    _email.dispose();
    _phone.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final auth = context.read<AuthProvider>();
    final navigator = Navigator.of(context);
    try {
      await auth.register(
        UserRegisterRequest(
          firstName: _firstName.text.trim(),
          lastName: _lastName.text.trim(),
          email: _email.text.trim(),
          username: _username.text.trim(),
          password: _password.text,
          phoneNumber: _phone.text.trim().isEmpty ? null : _phone.text.trim(),
        ),
      );
      // Registered + signed in → back to the gate, which now routes to the
      // onboarding step (the account is a fresh, not-yet-onboarded traveler).
      navigator.popUntil((route) => route.isFirst);
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
      appBar: AppBar(title: const Text('Create account')),
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
                        // Header.
                        Icon(
                          Icons.person_add_alt_1,
                          size: 48,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(height: TravleTokens.space12),
                        Text(
                          'Join Travle',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.headlineSmall,
                        ),
                        const SizedBox(height: TravleTokens.space4),
                        Text(
                          'Create your account to discover destinations and book tours.',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: TravleTokens.space24),

                        // Your details.
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text('Your details',
                              style: theme.textTheme.titleSmall),
                        ),
                        const SizedBox(height: TravleTokens.space12),
                        TravleTextField(
                          controller: _firstName,
                          label: 'First name',
                          prefixIcon: Icons.person_outline,
                          textInputAction: TextInputAction.next,
                          autofillHints: const [AutofillHints.givenName],
                          validator: (v) =>
                              Validators.required(v, field: 'First name'),
                        ),
                        const SizedBox(height: TravleTokens.space16),
                        TravleTextField(
                          controller: _lastName,
                          label: 'Last name',
                          prefixIcon: Icons.person_outline,
                          textInputAction: TextInputAction.next,
                          autofillHints: const [AutofillHints.familyName],
                          validator: (v) =>
                              Validators.required(v, field: 'Last name'),
                        ),
                        const SizedBox(height: TravleTokens.space16),
                        TravleTextField(
                          controller: _username,
                          label: 'Username',
                          prefixIcon: Icons.badge_outlined,
                          textInputAction: TextInputAction.next,
                          autofillHints: const [AutofillHints.newUsername],
                          validator: (v) =>
                              Validators.minLength(v, 3, field: 'Username'),
                        ),
                        const SizedBox(height: TravleTokens.space16),
                        TravleTextField(
                          controller: _email,
                          label: 'Email',
                          prefixIcon: Icons.mail_outline,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          autofillHints: const [AutofillHints.email],
                          validator: Validators.email,
                        ),
                        const SizedBox(height: TravleTokens.space16),
                        TravleTextField(
                          controller: _phone,
                          label: 'Phone (optional)',
                          prefixIcon: Icons.phone_outlined,
                          keyboardType: TextInputType.phone,
                          textInputAction: TextInputAction.next,
                          autofillHints: const [AutofillHints.telephoneNumber],
                          validator: (v) =>
                              Validators.maxLength(v, 20, field: 'Phone number'),
                        ),
                        const SizedBox(height: TravleTokens.space24),

                        // Security.
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text('Security',
                              style: theme.textTheme.titleSmall),
                        ),
                        const SizedBox(height: TravleTokens.space12),
                        TravleTextField(
                          controller: _password,
                          label: 'Password',
                          prefixIcon: Icons.lock_outline,
                          helperText: 'At least 8 characters',
                          obscure: true,
                          textInputAction: TextInputAction.next,
                          autofillHints: const [AutofillHints.newPassword],
                          validator: (v) => Validators.password(v),
                        ),
                        const SizedBox(height: TravleTokens.space16),
                        TravleTextField(
                          controller: _confirm,
                          label: 'Confirm password',
                          prefixIcon: Icons.lock_outline,
                          obscure: true,
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) => _submit(),
                          validator: (v) => Validators.match(v, _password.text),
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
                              : const Text('Create account'),
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
