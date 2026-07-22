import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:travle_core/travle_core.dart';
import 'package:travle_ui/travle_ui.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _username = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final auth = context.read<AuthProvider>();
    try {
      await auth.login(_username.text.trim(), _password.text);
      if (!auth.hasAnyRole(AppRole.mobile)) {
        await auth.logout();
        if (!mounted) return;
        setState(() => _error =
            "This account can't sign in on the mobile app. Please use the desktop app.");
        return;
      }
      // Success + allowed → AuthGate rebuilds into the shell automatically.
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
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(TravleTokens.space24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(TravleTokens.space24),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Icon(Icons.travel_explore,
                            size: 56, color: theme.colorScheme.primary),
                        const SizedBox(height: TravleTokens.space12),
                        Text('Travle',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.headlineSmall),
                        Text('Discover destinations & book tours',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyMedium),
                        const SizedBox(height: TravleTokens.space24),
                        TextFormField(
                          controller: _username,
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(
                            labelText: 'Username',
                            prefixIcon: Icon(Icons.person_outline),
                          ),
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? 'Username is required'
                              : null,
                        ),
                        const SizedBox(height: TravleTokens.space16),
                        TextFormField(
                          controller: _password,
                          obscureText: true,
                          textInputAction: TextInputAction.done,
                          onFieldSubmitted: (_) => _submit(),
                          decoration: const InputDecoration(
                            labelText: 'Password',
                            prefixIcon: Icon(Icons.lock_outline),
                          ),
                          validator: (v) => (v == null || v.isEmpty)
                              ? 'Password is required'
                              : null,
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
                              : const Text('Sign in'),
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
