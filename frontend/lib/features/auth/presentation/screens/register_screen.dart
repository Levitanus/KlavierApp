import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../l10n/app_localizations.dart';
import '../../application/providers/auth_provider.dart';
import '../../application/auth_state.dart';
import '../../domain/entities/registration_token_info.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key, required this.token});

  final String token;

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _fullNameController = TextEditingController();
  final _birthdayController = TextEditingController();

  bool _isLoading = true;
  bool _isSubmitting = false;
  bool _consentAccepted = false;
  String _consentText = '';
  String? _consentLocaleCode;
  String? _errorMessage;
  RegistrationTokenInfo? _tokenInfo;

  @override
  void initState() {
    super.initState();
    _validateToken();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final localeCode = Localizations.localeOf(context).languageCode;
    if (_consentLocaleCode != localeCode) {
      _consentLocaleCode = localeCode;
      _loadConsentText(localeCode);
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _fullNameController.dispose();
    _birthdayController.dispose();
    super.dispose();
  }

  Future<void> _validateToken() async {
    try {
      final tokenInfo = await ref
          .read(authRepositoryProvider)
          .fetchRegistrationTokenInfo(widget.token);
      if (!mounted) {
        return;
      }
      setState(() {
        _tokenInfo = tokenInfo;
        _isLoading = false;
        if (!tokenInfo.valid) {
          _errorMessage = 'This registration link is invalid or already used.';
        }
      });
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

  Future<void> _loadConsentText(String localeCode) async {
    try {
      final localizedPath = 'assets/consent_$localeCode.txt';
      String text;
      try {
        text = await rootBundle.loadString(localizedPath);
      } catch (_) {
        text = await rootBundle.loadString('assets/consent.txt');
      }
      if (!mounted) {
        return;
      }
      setState(() {
        _consentText = text.trim();
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _consentText = '';
      });
    }
  }

  Future<void> _submit() async {
    final valid = _formKey.currentState?.validate() ?? false;
    if (!valid) {
      return;
    }

    final tokenInfo = _tokenInfo;
    if (tokenInfo == null || !tokenInfo.valid) {
      setState(() {
        _errorMessage = 'The registration token is no longer valid.';
      });
      return;
    }

    if (_passwordController.text != _confirmPasswordController.text) {
      setState(() {
        _errorMessage = 'Passwords do not match.';
      });
      return;
    }

    if (!_consentAccepted) {
      setState(() {
        _errorMessage = 'Please accept the consent text to continue.';
      });
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      await ref.read(authRepositoryProvider).registerWithToken(
            token: widget.token,
            username: _usernameController.text.trim(),
            password: _passwordController.text,
            fullName: _fullNameController.text.trim(),
            email: _emailController.text,
            phone: _phoneController.text,
            birthday: tokenInfo.isStudent ? _birthdayController.text.trim() : null,
            consentAccepted: true,
          );

      await ref.read(authControllerProvider.notifier).login(
            username: _usernameController.text.trim(),
            password: _passwordController.text,
          );

      final authState = ref.read(authControllerProvider);
      if (!mounted) {
        return;
      }

      setState(() {
        _isSubmitting = false;
      });

      if (authState.status != AuthStatus.authenticated) {
        setState(() {
          _errorMessage = authState.errorMessage ?? 'Registration succeeded, but login failed.';
        });
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isSubmitting = false;
        _errorMessage = error.toString();
      });
    }
  }

  String _roleLabel(RegistrationTokenInfo tokenInfo) {
    final l10n = AppLocalizations.of(context);
    switch (tokenInfo.role) {
      case 'student':
        return l10n?.registerRoleStudent ?? 'Student';
      case 'parent':
        return l10n?.registerRoleParent ?? 'Parent';
      case 'teacher':
        return l10n?.registerRoleTeacher ?? 'Teacher';
      default:
        return tokenInfo.role ?? 'User';
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final tokenInfo = _tokenInfo;
    if (tokenInfo == null || !tokenInfo.valid) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n?.registerTitle('') ?? 'Register')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 72),
                const SizedBox(height: 16),
                Text(
                  _errorMessage ??
                      l10n?.registerInvalidTokenMessage ??
                      'This registration link is invalid or expired.',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          l10n?.registerTitle(_roleLabel(tokenInfo)) ??
              'Register as ${_roleLabel(tokenInfo)}',
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        l10n?.registerTitle(_roleLabel(tokenInfo)) ??
                            'Complete registration',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 8),
                      Text('Role: ${_roleLabel(tokenInfo)}'),
                      if (tokenInfo.relatedStudent != null) ...[
                        const SizedBox(height: 8),
                        Text('Related student: ${tokenInfo.relatedStudent!.fullName}'),
                      ],
                      if (tokenInfo.relatedTeacher != null) ...[
                        const SizedBox(height: 8),
                        Text('Related teacher: ${tokenInfo.relatedTeacher!.fullName}'),
                      ],
                      const SizedBox(height: 24),
                      TextFormField(
                        controller: _fullNameController,
                        decoration: const InputDecoration(labelText: 'Full name'),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Enter a full name';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _usernameController,
                        decoration: InputDecoration(
                          labelText: l10n?.commonUsername ?? 'Username',
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Enter a username';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _emailController,
                        decoration: const InputDecoration(labelText: 'Email'),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _phoneController,
                        decoration: const InputDecoration(labelText: 'Phone'),
                      ),
                      if (tokenInfo.isStudent) ...[
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _birthdayController,
                          decoration: const InputDecoration(
                            labelText: 'Birthday (YYYY-MM-DD)',
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Enter a birthday';
                            }
                            return null;
                          },
                        ),
                      ],
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _passwordController,
                        decoration: const InputDecoration(labelText: 'Password'),
                        obscureText: true,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Enter a password';
                          }
                          if (value.length < 6) {
                            return 'Password must be at least 6 characters';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _confirmPasswordController,
                        decoration: const InputDecoration(labelText: 'Confirm password'),
                        obscureText: true,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Confirm your password';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 24),
                      Text(
                        _consentText.isNotEmpty
                            ? _consentText
                            : 'Consent text is unavailable. Registration confirms your acceptance of the privacy and usage terms.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 12),
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        value: _consentAccepted,
                        onChanged: (value) {
                          setState(() {
                            _consentAccepted = value ?? false;
                          });
                        },
                        title: Text(l10n?.consentAgree ?? 'I accept the consent text'),
                      ),
                      if (_errorMessage != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          _errorMessage!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ],
                      const SizedBox(height: 24),
                      FilledButton(
                        onPressed: _isSubmitting ? null : _submit,
                        child: _isSubmitting
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
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
    );
  }
}
