import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../../shared/widgets/app_body_container.dart';
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
  bool _obscurePassword = true;

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

    if (!mounted) {
      return;
    }

    TextInput.finishAutofillContext();
  }

  void _togglePasswordVisibility() {
    setState(() {
      _obscurePassword = !_obscurePassword;
    });
  }

  Future<void> _openForgotPasswordDialog() async {
    final usernameController = TextEditingController(
      text: _usernameController.text.trim(),
    );
    final formKey = GlobalKey<FormState>();
    final l10n = AppLocalizations.of(context);

    final username = await showDialog<String>(
      context: context,
      barrierDismissible: true,
      builder: (context) => AlertDialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        titlePadding: const EdgeInsets.fromLTRB(8, 12, 8, 0),
        contentPadding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
        actionsPadding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
        title: Text(l10n?.loginForgotTitle ?? 'Forgot Password'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n?.loginForgotPrompt ??
                    'Enter your username to request a password reset.',
                style: const TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: usernameController,
                autofillHints: const [AutofillHints.username],
                decoration: InputDecoration(
                  labelText: l10n?.commonUsername ?? 'Username',
                  prefixIcon: const Icon(Icons.person),
                  border: const OutlineInputBorder(),
                ),
                textInputAction: TextInputAction.done,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return l10n?.loginUsernameRequired ??
                        'Please enter your username';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n?.commonCancel ?? 'Cancel'),
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
          insetPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          titlePadding: const EdgeInsets.fromLTRB(8, 12, 8, 0),
          contentPadding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
          actionsPadding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
          title: Text(l10n?.loginRequestSentTitle ?? 'Request Sent'),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(l10n?.commonOk ?? 'OK'),
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
          insetPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          titlePadding: const EdgeInsets.fromLTRB(8, 12, 8, 0),
          contentPadding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
          actionsPadding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
          title: Text(l10n?.commonErrorTitle ?? 'Error'),
          content: Text(error.toString()),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(l10n?.commonOk ?? 'OK'),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final logoAsset = isDark
        ? 'assets/branding/logo_bright.svg'
        : 'assets/branding/logo_dark.svg';

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n?.loginTitle ?? 'Login'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: AppBodyContainer(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: AutofillGroup(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SvgPicture.asset(
                        'assets/branding/icon_white_note.svg',
                        height: 72,
                        width: 72,
                      ),
                      const SizedBox(height: 12),
                      SvgPicture.asset(logoAsset, height: 32),
                      const SizedBox(height: 48),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
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
                                autofillHints: const [AutofillHints.username],
                                decoration: InputDecoration(
                                  labelText: l10n?.commonUsername ?? 'Username',
                                  prefixIcon: const Icon(Icons.person),
                                  border: const OutlineInputBorder(),
                                ),
                                textInputAction: TextInputAction.next,
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return l10n?.loginUsernameRequired ??
                                        'Please enter your username';
                                  }
                                  return null;
                                },
                                enabled: !authState.isSubmitting,
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: _passwordController,
                                autofillHints: const [AutofillHints.password],
                                decoration: InputDecoration(
                                  labelText: l10n?.commonPassword ?? 'Password',
                                  prefixIcon: const Icon(Icons.lock),
                                  border: const OutlineInputBorder(),
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _obscurePassword
                                          ? Icons.visibility_off
                                          : Icons.visibility,
                                    ),
                                    onPressed: authState.isSubmitting
                                        ? null
                                        : _togglePasswordVisibility,
                                  ),
                                ),
                                obscureText: _obscurePassword,
                                autocorrect: false,
                                enableSuggestions: false,
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return l10n?.loginPasswordRequired ??
                                        'Please enter your password';
                                  }
                                  return null;
                                },
                                enabled: !authState.isSubmitting,
                                onFieldSubmitted: (_) => _submit(),
                              ),
                              if (errorMessage != null) ...[
                                const SizedBox(height: 16),
                                Text(
                                  errorMessage,
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.error,
                                    fontSize: 14,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                              const SizedBox(height: 24),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed: authState.isSubmitting ? null : _submit,
                                  child: authState.isSubmitting
                                      ? const SizedBox(
                                          height: 20,
                                          width: 20,
                                          child: CircularProgressIndicator(strokeWidth: 2),
                                        )
                                      : Text(
                                          l10n?.loginButton ?? 'Login',
                                          style: const TextStyle(fontSize: 16),
                                        ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton(
                                  onPressed: authState.isSubmitting
                                      ? null
                                      : _openForgotPasswordDialog,
                                  child: Text(
                                    l10n?.loginForgotPassword ?? 'Forgot Password?',
                                  ),
                                ),
                              ),
                            ],
                          ),
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
