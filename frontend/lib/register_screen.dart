import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'auth.dart';
import 'config/app_config.dart';

class RegisterScreen extends StatefulWidget {
  final String token;

  const RegisterScreen({super.key, required this.token});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  static String get _baseUrl => AppConfig.instance.baseUrl;
  static const String _consentKey = 'consent_accepted_v1';

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
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _consentAccepted = false;
  String _consentText = '';
  String? _errorMessage;
  
  // Token info
  bool _tokenValid = false;
  String? _role;
  Map<String, dynamic>? _relatedStudent;

  @override
  void initState() {
    super.initState();
    _validateToken();
    _loadConsentText();
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

  Future<void> _loadConsentText() async {
    try {
      final text = await rootBundle.loadString('assets/consent.txt');
      if (mounted) {
        setState(() {
          _consentText = text.trim();
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _consentText = '';
        });
      }
    }
  }

  String get _consentTextFallback {
    return 'Consent (short)\n'
        '- Music learning content only.\n'
        '- You can edit or delete your profile.\n'
        '- Data is protected with TLS.\n'
        '- No sharing except email delivery (SendGrid).\n'
        'If registering a child, you confirm you are a parent/guardian or authorized.';
  }

  Future<void> _validateToken() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/api/registration-token-info/${widget.token}'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _tokenValid = data['valid'] ?? false;
          _role = data['role'];
          _relatedStudent = data['related_student'];
          _isLoading = false;

          if (!_tokenValid) {
            _errorMessage = 'Invalid or expired registration token';
          }
        });
      } else {
        setState(() {
          _tokenValid = false;
          _errorMessage = 'Failed to validate token';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _tokenValid = false;
        _errorMessage = 'Network error: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_passwordController.text != _confirmPasswordController.text) {
      setState(() {
        _errorMessage = 'Passwords do not match';
      });
      return;
    }

    if (!_consentAccepted) {
      setState(() {
        _errorMessage = 'Please accept the consent to continue';
      });
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final requestBody = {
        'token': widget.token,
        'username': _usernameController.text,
        'password': _passwordController.text,
        'email': _emailController.text.isEmpty ? null : _emailController.text,
        'phone': _phoneController.text.isEmpty ? null : _phoneController.text,
        'full_name': _fullNameController.text,
      };

      // Add role-specific fields
      if (_role == 'student') {
        requestBody['birthday'] = _birthdayController.text;
      }

      final response = await http.post(
        Uri.parse('$_baseUrl/api/register-with-token'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      );

      if (response.statusCode == 201) {
        // Registration successful
        final authService = Provider.of<AuthService>(context, listen: false);

        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool(_consentKey, true);
        
        // Auto-login after registration
        final loginResult = await authService.login(
          _usernameController.text,
          _passwordController.text,
        );

        if (!loginResult.success) {
          setState(() {
            _errorMessage = loginResult.errorMessage ?? 'Login failed';
            _isSubmitting = false;
          });
          return;
        }

        if (mounted) {
          Navigator.of(context).pushReplacementNamed('/');
        }
      } else {
        final error = jsonDecode(response.body);
        setState(() {
          _errorMessage = error['error'] ?? 'Registration failed';
          _isSubmitting = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Network error: $e';
        _isSubmitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Show loading while validating token
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    // Show error if token is invalid
    if (!_tokenValid) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.error_outline,
                  size: 64,
                  color: Colors.red,
                ),
                const SizedBox(height: 16),
                Text(
                  _errorMessage ?? 'Invalid Registration Token',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                const Text(
                  'This registration link may be expired or already used.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pushReplacementNamed('/');
                  },
                  child: const Text('Go to Login'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Card(
              elevation: 8,
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Header
                      Icon(
                        _role == 'student' ? Icons.school :
                        _role == 'parent' ? Icons.family_restroom :
                        _role == 'teacher' ? Icons.person :
                        Icons.person_add,
                        size: 64,
                        color: _role == 'student' ? Colors.blue :
                               _role == 'parent' ? Colors.green :
                               _role == 'teacher' ? Colors.orange :
                               Colors.blue,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Register as ${_role?.toUpperCase()}',
                        style: Theme.of(context).textTheme.headlineMedium,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      
                      // Show related student for parent registration
                      if (_role == 'parent' && _relatedStudent != null) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.green[50],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.green[300]!),
                          ),
                          child: Column(
                            children: [
                              Text(
                                'You will be registered as parent of:',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.green[800],
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _relatedStudent!['full_name'],
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green[900],
                                ),
                              ),
                              Text(
                                '@${_relatedStudent!['username']}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.green[700],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ] else ...[
                        Text(
                          'Complete your registration',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Colors.grey[600],
                              ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                      const SizedBox(height: 32),

                      // Error message
                      if (_errorMessage != null) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.red[50],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.red[300]!),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.error_outline, color: Colors.red[700]),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  _errorMessage!,
                                  style: TextStyle(color: Colors.red[700]),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Username field
                      TextFormField(
                        controller: _usernameController,
                        decoration: const InputDecoration(
                          labelText: 'Username',
                          prefixIcon: Icon(Icons.person),
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter a username';
                          }
                          if (value.length < 3) {
                            return 'Username must be at least 3 characters';
                          }
                          return null;
                        },
                        enabled: !_isSubmitting,
                      ),
                      const SizedBox(height: 16),

                      // Full Name field (required for all roles except admin)
                      TextFormField(
                        controller: _fullNameController,
                        decoration: const InputDecoration(
                          labelText: 'Full Name',
                          prefixIcon: Icon(Icons.badge),
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter your full name';
                          }
                          return null;
                        },
                        enabled: !_isSubmitting,
                      ),
                      const SizedBox(height: 16),

                      // Birthday field (required for students)
                      if (_role == 'student') ...[
                        TextFormField(
                          controller: _birthdayController,
                          decoration: const InputDecoration(
                            labelText: 'Birthday (YYYY-MM-DD)',
                            prefixIcon: Icon(Icons.cake),
                            border: OutlineInputBorder(),
                            hintText: '2010-01-31',
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter your birthday';
                            }
                            // Basic date format validation
                            final dateRegex = RegExp(r'^\d{4}-\d{2}-\d{2}$');
                            if (!dateRegex.hasMatch(value)) {
                              return 'Use format: YYYY-MM-DD';
                            }
                            return null;
                          },
                          enabled: !_isSubmitting,
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Email field (optional)
                      TextFormField(
                        controller: _emailController,
                        decoration: const InputDecoration(
                          labelText: 'Email (optional)',
                          prefixIcon: Icon(Icons.email),
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.emailAddress,
                        enabled: !_isSubmitting,
                      ),
                      const SizedBox(height: 16),

                      // Phone field (optional)
                      TextFormField(
                        controller: _phoneController,
                        decoration: const InputDecoration(
                          labelText: 'Phone (optional)',
                          prefixIcon: Icon(Icons.phone),
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.phone,
                        enabled: !_isSubmitting,
                      ),
                      const SizedBox(height: 16),

                      // Password field
                      TextFormField(
                        controller: _passwordController,
                        decoration: InputDecoration(
                          labelText: 'Password',
                          prefixIcon: const Icon(Icons.lock),
                          border: const OutlineInputBorder(),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                            ),
                            onPressed: () {
                              setState(() {
                                _obscurePassword = !_obscurePassword;
                              });
                            },
                          ),
                        ),
                        obscureText: _obscurePassword,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter a password';
                          }
                          if (value.length < 6) {
                            return 'Password must be at least 6 characters';
                          }
                          return null;
                        },
                        enabled: !_isSubmitting,
                      ),
                      const SizedBox(height: 16),

                      // Confirm Password field
                      TextFormField(
                        controller: _confirmPasswordController,
                        decoration: InputDecoration(
                          labelText: 'Confirm Password',
                          prefixIcon: const Icon(Icons.lock_outline),
                          border: const OutlineInputBorder(),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscureConfirmPassword
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                            ),
                            onPressed: () {
                              setState(() {
                                _obscureConfirmPassword = !_obscureConfirmPassword;
                              });
                            },
                          ),
                        ),
                        obscureText: _obscureConfirmPassword,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please confirm your password';
                          }
                          return null;
                        },
                        enabled: !_isSubmitting,
                      ),
                      const SizedBox(height: 24),

                      Card(
                        elevation: 0,
                        color: Theme.of(context).colorScheme.surface,
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _consentText.isNotEmpty
                                    ? _consentText
                                    : _consentTextFallback,
                              ),
                              const SizedBox(height: 12),
                              CheckboxListTile(
                                contentPadding: EdgeInsets.zero,
                                value: _consentAccepted,
                                onChanged: _isSubmitting
                                    ? null
                                    : (value) {
                                        setState(() {
                                          _consentAccepted = value ?? false;
                                        });
                                      },
                                title: const Text(
                                  'If you register a child, you confirm that you are a parent, legal guardian, or otherwise authorized person.',
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Register button
                      ElevatedButton(
                        onPressed: _isSubmitting ? null : _register,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: _isSubmitting
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text('Register'),
                      ),
                      const SizedBox(height: 16),

                      // Back to login link
                      TextButton(
                        onPressed: _isSubmitting
                            ? null
                            : () {
                                Navigator.of(context).pushReplacementNamed('/');
                              },
                        child: const Text('Back to Login'),
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
