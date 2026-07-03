import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../l10n/app_localizations.dart';
import '../../application/providers/auth_provider.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key, this.errorMessage});

  final String? errorMessage;

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final valid = _formKey.currentState?.validate() ?? false;
    if (!valid) {
      return;
    }

    await ref.read(authControllerProvider.notifier).login(
          username: _usernameController.text.trim(),
          password: _passwordController.text,
        );
  }

  Future<void> _openForgotPasswordDialog() async {
    final usernameController = TextEditingController(
      text: _usernameController.text.trim(),
    );
    final formKey = GlobalKey<FormState>();

    final username = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Forgot password'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: usernameController,
            decoration: const InputDecoration(labelText: 'Username'),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Enter your username';
              }
              return null;
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final valid = formKey.currentState?.validate() ?? false;
              if (!valid) {
                return;
              }
              Navigator.of(context).pop(usernameController.text.trim());
            },
            child: const Text('Send'),
          ),
        ],
      ),
    );

    usernameController.dispose();

    if (!mounted || username == null || username.isEmpty) {
      return;
    }

    try {
      final message = await ref
          .read(authRepositoryProvider)
          .requestPasswordReset(username: username);
      if (!mounted) {
        return;
      }
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Request sent'),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Request failed'),
          content: Text(error.toString()),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final authState = ref.watch(authControllerProvider);
    final errorMessage = authState.errorMessage ?? widget.errorMessage;

    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n?.loginTitle ?? 'Login',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Sign in against the existing backend using the new frontend architecture.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 24),
                      TextFormField(
                        controller: _usernameController,
                        decoration: InputDecoration(
                          labelText: l10n?.commonUsername ?? 'Username',
                        ),
                        textInputAction: TextInputAction.next,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return l10n?.commonUsername ?? 'Enter your username';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _passwordController,
                        decoration: InputDecoration(
                          labelText: l10n?.commonPassword ?? 'Password',
                        ),
                        obscureText: true,
                        onFieldSubmitted: (_) => _submit(),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return l10n?.commonPassword ?? 'Enter your password';
                          }
                          return null;
                        },
                      ),
                      if (errorMessage != null) ...[
                        const SizedBox(height: 16),
                        Text(
                          errorMessage,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ],
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: authState.isSubmitting ? null : _submit,
                          child: authState.isSubmitting
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Text('Sign in'),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: authState.isSubmitting
                              ? null
                              : _openForgotPasswordDialog,
                          child: Text(l10n?.loginForgotTitle ?? 'Forgot Password'),
                        ),
                      ),
                    ],
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
