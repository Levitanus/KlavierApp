import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_svg/flutter_svg.dart';
import 'dart:convert';
import 'auth.dart';
import 'home_screen.dart';
import 'config/app_config.dart';
import 'l10n/app_localizations.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    final l10n = AppLocalizations.of(context);
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      final authService = Provider.of<AuthService>(context, listen: false);
      final result = await authService.login(
        _usernameController.text.trim(),
        _passwordController.text,
      );

      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      if (result.success) {
        TextInput.finishAutofillContext();
        // Navigate to home screen
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const HomeScreen()),
        );
      } else {
        setState(() {
          _errorMessage = result.errorMessage ??
              l10n?.loginFailed ?? 'Login failed';
        });
      }
    }
  }

  void _handleForgotPassword() {
    final usernameController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final l10n = AppLocalizations.of(context);

    showDialog(
      context: context,
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
          ElevatedButton(
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                Navigator.of(context).pop();
                await _sendPasswordResetRequest(usernameController.text.trim());
              }
            },
            child: Text(l10n?.commonSend ?? 'Send'),
          ),
        ],
      ),
    );
  }

  Future<void> _sendPasswordResetRequest(String username) async {
    final l10n = AppLocalizations.of(context);
    try {
      final response = await http.post(
        Uri.parse('${AppConfig.instance.baseUrl}/api/auth/forgot-password'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'username': username}),
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            insetPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            titlePadding: const EdgeInsets.fromLTRB(8, 12, 8, 0),
            contentPadding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
            actionsPadding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
            title: Text(l10n?.loginRequestSentTitle ?? 'Request Sent'),
            content: Text(
              data['message'] ??
                  l10n?.loginRequestSentMessage ??
                  'Password reset request sent successfully.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(l10n?.commonOk ?? 'OK'),
              ),
            ],
          ),
        );
      } else {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            insetPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            titlePadding: const EdgeInsets.fromLTRB(8, 12, 8, 0),
            contentPadding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
            actionsPadding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
            title: Text(l10n?.commonErrorTitle ?? 'Error'),
            content: Text(
              l10n?.loginRequestFailedMessage ??
                  'Failed to send password reset request. Please try again.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(l10n?.commonOk ?? 'OK'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          titlePadding: const EdgeInsets.fromLTRB(8, 12, 8, 0),
          contentPadding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
          actionsPadding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
          title: Text(l10n?.commonErrorTitle ?? 'Error'),
          content: Text(
            l10n?.loginErrorMessage(e.toString()) ??
                'An error occurred: $e',
          ),
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
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Form(
              key: _formKey,
              child: AutofillGroup(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Logo or App Title
                    SvgPicture.asset(
                      'assets/branding/icon_white_note.svg',
                      height: 72,
                      width: 72,
                    ),
                    const SizedBox(height: 12),
                    SvgPicture.asset(
                      logoAsset,
                      height: 32,
                    ),
                    const SizedBox(height: 48),

                    // Username Field
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
                      enabled: !_isLoading,
                    ),
                    const SizedBox(height: 16),

                    // Password Field
                    TextFormField(
                      controller: _passwordController,
                      autofillHints: const [AutofillHints.password],
                      decoration: InputDecoration(
                        labelText: l10n?.commonPassword ?? 'Password',
                        prefixIcon: const Icon(Icons.lock),
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword ? Icons.visibility : Icons.visibility_off,
                          ),
                          onPressed: () {
                            setState(() {
                              _obscurePassword = !_obscurePassword;
                            });
                          },
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
                      enabled: !_isLoading,
                      onFieldSubmitted: (_) => _handleLogin(),
                    ),
                    const SizedBox(height: 24),

                    // Error Message
                    if (_errorMessage != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(
                            color: Colors.red,
                            fontSize: 14,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),

                    // Login Button
                    ElevatedButton(
                      onPressed: _isLoading ? null : _handleLogin,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: _isLoading
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
                    const SizedBox(height: 16),

                    // Forgot Password Button
                    TextButton(
                      onPressed: _isLoading ? null : _handleForgotPassword,
                      child: Text(
                        l10n?.loginForgotPassword ?? 'Forgot Password?',
                      ),
                    ),
                ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
