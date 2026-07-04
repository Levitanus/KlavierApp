import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../../shared/widgets/app_body_container.dart';
import '../../application/providers/auth_provider.dart';

class ResetPasswordScreen extends ConsumerStatefulWidget {
  const ResetPasswordScreen({super.key, required this.token});

  final String token;

  @override
  ConsumerState<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends ConsumerState<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isLoading = false;
  bool _isValidating = true;
  bool _isValidToken = false;
  String? _username;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _validateToken();
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _validateToken() async {
    try {
      final result = await ref
          .read(authRepositoryProvider)
          .validateResetToken(widget.token);
      if (!mounted) {
        return;
      }
      setState(() {
        _isValidating = false;
        _isValidToken = result.valid;
        _username = result.username;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isValidating = false;
        _isValidToken = false;
        _errorMessage = error.toString();
      });
    }
  }

  Future<void> _submit() async {
    final valid = _formKey.currentState?.validate() ?? false;
    if (!valid) {
      return;
    }

    final l10n = AppLocalizations.of(context);

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final message = await ref.read(authRepositoryProvider).resetPassword(
            token: widget.token,
            password: _passwordController.text,
          );
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoading = false;
      });
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          titlePadding: const EdgeInsets.fromLTRB(8, 12, 8, 0),
          contentPadding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
          actionsPadding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
          title: Text(l10n?.resetTitle ?? 'Password reset'),
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
      setState(() {
        _isLoading = false;
        _errorMessage = error.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final logoAsset = isDark
        ? 'assets/branding/logo_bright.svg'
        : 'assets/branding/logo_dark.svg';
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n?.resetTitle ?? 'Reset password'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: AppBodyContainer(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SvgPicture.asset('assets/branding/icon_white_note.svg', height: 72, width: 72),
                  const SizedBox(height: 12),
                  SvgPicture.asset(logoAsset, height: 32),
                  const SizedBox(height: 24),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: _isValidating
                          ? Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const CircularProgressIndicator(),
                                const SizedBox(height: 16),
                                Text(l10n?.resetValidating ?? 'Validating reset link...'),
                              ],
                            )
                          : !_isValidToken
                              ? Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.error_outline, size: 72),
                                    const SizedBox(height: 16),
                                    Text(
                                      l10n?.resetInvalidMessage ?? 'This reset link is invalid or expired.',
                                      textAlign: TextAlign.center,
                                    ),
                                    if (_errorMessage != null) ...[
                                      const SizedBox(height: 12),
                                      Text(_errorMessage!, textAlign: TextAlign.center),
                                    ],
                                  ],
                                )
                              : Form(
                                  key: _formKey,
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        l10n?.resetSetNewPassword ?? 'Set a new password',
                                        style: Theme.of(context).textTheme.headlineSmall,
                                      ),
                                      if (_username != null) ...[
                                        const SizedBox(height: 8),
                                        Text('for @$_username'),
                                      ],
                                      const SizedBox(height: 24),
                                      TextFormField(
                                        controller: _passwordController,
                                        decoration: InputDecoration(
                                          labelText: l10n?.resetNewPasswordLabel ?? 'New password',
                                          prefixIcon: const Icon(Icons.lock),
                                        ),
                                        obscureText: true,
                                        validator: (value) {
                                          if (value == null || value.isEmpty) {
                                            return l10n?.resetPasswordRequired ?? 'Enter a new password';
                                          }
                                          if (value.length < 6) {
                                            return l10n?.resetPasswordMin ?? 'Password must be at least 6 characters';
                                          }
                                          return null;
                                        },
                                      ),
                                      const SizedBox(height: 16),
                                      TextFormField(
                                        controller: _confirmPasswordController,
                                        decoration: InputDecoration(
                                          labelText: l10n?.resetConfirmPasswordLabel ?? 'Confirm password',
                                          prefixIcon: const Icon(Icons.lock_outline),
                                        ),
                                        obscureText: true,
                                        validator: (value) {
                                          if (value == null || value.isEmpty) {
                                            return l10n?.resetConfirmRequired ?? 'Confirm your password';
                                          }
                                          if (value != _passwordController.text) {
                                            return l10n?.registerPasswordsMismatch ?? 'Passwords do not match';
                                          }
                                          return null;
                                        },
                                      ),
                                      if (_errorMessage != null) ...[
                                        const SizedBox(height: 16),
                                        Text(
                                          _errorMessage!,
                                          style: TextStyle(
                                            color: Theme.of(context).colorScheme.error,
                                          ),
                                        ),
                                      ],
                                      const SizedBox(height: 24),
                                      SizedBox(
                                        width: double.infinity,
                                        child: ElevatedButton(
                                          onPressed: _isLoading ? null : _submit,
                                          child: _isLoading
                                              ? const SizedBox(
                                                  height: 20,
                                                  width: 20,
                                                  child: CircularProgressIndicator(strokeWidth: 2),
                                                )
                                              : Text(l10n?.resetTitle ?? 'Reset password'),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
