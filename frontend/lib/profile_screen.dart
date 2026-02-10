import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:html' as html;
import 'package:file_picker/file_picker.dart';
import 'auth.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  static const String _baseUrl = 'http://localhost:8080';
  
  bool _isLoading = true;
  bool _isEditing = false;
  bool _isSaving = false;
  String? _errorMessage;
  
  // Profile data
  int? _userId;
  String _username = '';
  String? _email;
  String? _phone;
  String? _profileImage;
  DateTime? _createdAt;
  
  // Role data
  List<String> _roles = [];
  Map<String, dynamic>? _studentData;
  Map<String, dynamic>? _parentData;
  Map<String, dynamic>? _teacherData;
  
  // Text controllers for editing
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _birthdayController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _phoneController.dispose();
    _fullNameController.dispose();
    _addressController.dispose();
    _birthdayController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final authService = Provider.of<AuthService>(context, listen: false);
    final token = authService.token;

    if (token == null) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Not authenticated';
      });
      return;
    }

    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/api/profile'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('Profile data received: $data');
        setState(() {
          _userId = data['id'];
          _username = data['username'];
          _email = data['email'];
          _phone = data['phone'];
          // profile_image now contains just the filename, we need to construct the full URL
          _profileImage = data['profile_image'] != null && data['profile_image'].toString().isNotEmpty
              ? '$_baseUrl/uploads/profile_images/${data['profile_image']}'
              : null;
          print('Profile image URL: $_profileImage');
          _createdAt = DateTime.fromMillisecondsSinceEpoch(data['created_at'] * 1000);
          
          // Parse roles
          _roles = data['roles'] != null ? List<String>.from(data['roles']) : [];
          _studentData = data['student_data'];
          _parentData = data['parent_data'];
          _teacherData = data['teacher_data'];
          
          _emailController.text = _email ?? '';
          _phoneController.text = _phone ?? '';
          
          // Set role-specific controllers
          if (_studentData != null) {
            _fullNameController.text = _studentData!['full_name'] ?? '';
            _addressController.text = _studentData!['address'] ?? '';
            _birthdayController.text = _studentData!['birthday'] ?? '';
          } else if (_parentData != null) {
            _fullNameController.text = _parentData!['full_name'] ?? '';
          } else if (_teacherData != null) {
            _fullNameController.text = _teacherData!['full_name'] ?? '';
          }
          
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Failed to load profile: ${response.statusCode}';
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error loading profile: $e';
      });
    }
  }

  Future<void> _saveProfile() async {
    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    final authService = Provider.of<AuthService>(context, listen: false);
    final token = authService.token;

    if (token == null) {
      setState(() {
        _isSaving = false;
        _errorMessage = 'Not authenticated';
      });
      return;
    }

    try {
      final updateData = {
        'email': _emailController.text.isEmpty ? null : _emailController.text,
        'phone': _phoneController.text.isEmpty ? null : _phoneController.text,
      };
      
      // Add role-specific fields if applicable
      if (_fullNameController.text.isNotEmpty) {
        updateData['full_name'] = _fullNameController.text;
      }
      if (_studentData != null && _addressController.text.isNotEmpty) {
        updateData['address'] = _addressController.text;
      }
      if (_studentData != null && _birthdayController.text.isNotEmpty) {
        updateData['birthday'] = _birthdayController.text;
      }
      
      final response = await http.put(
        Uri.parse('$_baseUrl/api/profile'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(updateData),
      );

      if (response.statusCode == 200) {
        // Reload profile to get updated data
        await _loadProfile();
        setState(() {
          _isSaving = false;
          _isEditing = false;
        });
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Profile updated successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        setState(() {
          _isSaving = false;
          _errorMessage = 'Failed to update profile: ${response.statusCode}';
        });
      }
    } catch (e) {
      setState(() {
        _isSaving = false;
        _errorMessage = 'Error updating profile: $e';
      });
    }
  }

  void _cancelEditing() {
    setState(() {
      _isEditing = false;
      _emailController.text = _email ?? '';
      _phoneController.text = _phone ?? '';
      
      // Reset role-specific controllers
      if (_studentData != null) {
        _fullNameController.text = _studentData!['full_name'] ?? '';
        _addressController.text = _studentData!['address'] ?? '';
        _birthdayController.text = _studentData!['birthday'] ?? '';
      } else if (_parentData != null) {
        _fullNameController.text = _parentData!['full_name'] ?? '';
      } else if (_teacherData != null) {
        _fullNameController.text = _teacherData!['full_name'] ?? '';
      }
      
      _errorMessage = null;
    });
  }

  Future<void> _pickImage() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        withData: true, // Important for web
      );

      if (result == null || result.files.isEmpty) return;

      final file = result.files.first;
      
      // Validate file size (5MB max)
      if (file.size > 5 * 1024 * 1024) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('File too large. Maximum size is 5MB.'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      final authService = Provider.of<AuthService>(context, listen: false);
      final token = authService.token;

      if (token == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Not authenticated'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      // Upload the image
      setState(() {
        _isSaving = true;
      });

      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$_baseUrl/api/profile/upload-image'),
      );
      
      request.headers['Authorization'] = 'Bearer $token';
      
      // For web, use bytes; for mobile, use path
      if (file.bytes != null) {
        request.files.add(http.MultipartFile.fromBytes(
          'image',
          file.bytes!,
          filename: file.name,
        ));
      } else if (file.path != null) {
        request.files.add(await http.MultipartFile.fromPath('image', file.path!));
      } else {
        setState(() {
          _isSaving = false;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to read file'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      setState(() {
        _isSaving = false;
      });

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('Upload response: $data');
        setState(() {
          _profileImage = '$_baseUrl${data['url']}';
          print('New profile image URL: $_profileImage');
        });
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Profile image updated'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        if (mounted) {
          final error = jsonDecode(response.body)['error'] ?? 'Failed to upload image';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(error),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      setState(() {
        _isSaving = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error picking image: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _removeImage() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final token = authService.token;

    if (token == null) return;

    setState(() {
      _isSaving = true;
    });

    try {
      final response = await http.delete(
        Uri.parse('$_baseUrl/api/profile/image'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      setState(() {
        _isSaving = false;
      });

      if (response.statusCode == 200) {
        setState(() {
          _profileImage = null;
        });
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Profile image removed'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      setState(() {
        _isSaving = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error removing image: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildProfileImage() {
    return Center(
      child: Stack(
        children: [
          CircleAvatar(
            radius: 60,
            backgroundColor: Colors.grey[300],
            backgroundImage: _profileImage != null && _profileImage!.isNotEmpty
                ? NetworkImage(_profileImage!)
                : null,
            child: _profileImage == null || _profileImage!.isEmpty
                ? const Icon(Icons.person, size: 60, color: Colors.grey)
                : null,
          ),
          if (_isEditing && !_isSaving)
            Positioned(
              bottom: 0,
              right: 0,
              child: Row(
                children: [
                  if (_profileImage != null && _profileImage!.isNotEmpty)
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.delete, color: Colors.white, size: 20),
                        onPressed: _removeImage,
                        padding: const EdgeInsets.all(8),
                        constraints: const BoxConstraints(),
                      ),
                    ),
                  const SizedBox(width: 4),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.blue,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.camera_alt, color: Colors.white, size: 20),
                      onPressed: _pickImage,
                      padding: const EdgeInsets.all(8),
                      constraints: const BoxConstraints(),
                    ),
                  ),
                ],
              ),
            ),
          if (_isSaving)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.black.withOpacity(0.5),
                ),
                child: const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _generateParentRegistrationLink() async {
    if (_userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('User ID not available'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final authService = Provider.of<AuthService>(context, listen: false);
    final token = authService.token;

    if (token == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Not authenticated'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/api/students/$_userId/parent-registration-token'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      // Close loading dialog
      if (mounted) Navigator.of(context).pop();

      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        final registrationToken = data['token'];
        final expiresAt = DateTime.parse(data['expires_at']);
        
        // Generate registration link using current origin
        // For web, this will be something like http://localhost:8081
        final origin = html.window.location.origin;
        final registrationLink = '$origin/register?token=$registrationToken';
        
        print('DEBUG - Registration link origin: $origin');
        print('DEBUG - Full registration link: $registrationLink');

        if (mounted) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Parent Registration Link'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Share this link with your parent to register:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey[400]!),
                    ),
                    child: SelectableText(
                      registrationLink,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Expires: ${expiresAt.day}/${expiresAt.month}/${expiresAt.year} ${expiresAt.hour}:${expiresAt.minute.toString().padLeft(2, '0')}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'This link is valid for 48 hours.',
                    style: TextStyle(
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Close'),
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    // Copy to clipboard
                    final data = ClipboardData(text: registrationLink);
                    Clipboard.setData(data);
                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Link copied to clipboard'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  },
                  icon: const Icon(Icons.copy),
                  label: const Text('Copy Link'),
                ),
              ],
            ),
          );
        }
      } else {
        if (mounted) {
          final error = jsonDecode(response.body)['error'] ?? 'Failed to generate link';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(error),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      // Close loading dialog
      if (mounted) Navigator.of(context).pop();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error generating link: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showChangePasswordDialog() {
    showDialog(
      context: context,
      builder: (context) => ChangePasswordDialog(
        onPasswordChanged: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Password changed successfully'),
              backgroundColor: Colors.green,
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
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
              _errorMessage!,
              style: const TextStyle(color: Colors.red),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadProfile,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Profile Image
          _buildProfileImage(),
          const SizedBox(height: 24),
          
          // Header
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      'Profile',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    Text(
                      _username,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: Colors.grey[600],
                          ),
                    ),
                  ],
                ),
              ),
              if (!_isEditing && !_isSaving)
                IconButton(
                  icon: const Icon(Icons.edit),
                  onPressed: () {
                    setState(() {
                      _isEditing = true;
                    });
                  },
                  tooltip: 'Edit Profile',
                ),
            ],
          ),
          const SizedBox(height: 24),

          // Profile Information Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Profile Information',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const Divider(),
                  const SizedBox(height: 16),
                  
                  // Username (read-only)
                  _buildProfileField(
                    label: 'Username',
                    value: _username,
                    icon: Icons.person_outline,
                    isEditable: false,
                  ),
                  const SizedBox(height: 16),
                  
                  // Email
                  if (_isEditing)
                    _buildEditableField(
                      label: 'Email',
                      controller: _emailController,
                      icon: Icons.email_outlined,
                      keyboardType: TextInputType.emailAddress,
                    )
                  else
                    _buildProfileField(
                      label: 'Email',
                      value: _email ?? 'Not set',
                      icon: Icons.email_outlined,
                      isEditable: true,
                    ),
                  const SizedBox(height: 16),
                  
                  // Phone
                  if (_isEditing)
                    _buildEditableField(
                      label: 'Phone',
                      controller: _phoneController,
                      icon: Icons.phone_outlined,
                      keyboardType: TextInputType.phone,
                    )
                  else
                    _buildProfileField(
                      label: 'Phone',
                      value: _phone ?? 'Not set',
                      icon: Icons.phone_outlined,
                      isEditable: true,
                    ),
                  const SizedBox(height: 16),
                  
                  // Created At (read-only)
                  _buildProfileField(
                    label: 'Member Since',
                    value: _createdAt != null
                        ? '${_createdAt!.day}/${_createdAt!.month}/${_createdAt!.year}'
                        : 'Unknown',
                    icon: Icons.calendar_today_outlined,
                    isEditable: false,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Roles Section
          if (_roles.isNotEmpty) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Roles',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const Divider(),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _roles.map((role) {
                        return Chip(
                          label: Text(
                            role.toUpperCase(),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          backgroundColor: role == 'student'
                              ? Colors.blue
                              : role == 'parent'
                                  ? Colors.green
                                  : role == 'teacher'
                                      ? Colors.orange
                                      : role == 'admin'
                                          ? Colors.red
                                          : Colors.grey,
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Role-specific Information Card
          if (_studentData != null || _parentData != null || _teacherData != null) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Additional Information',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const Divider(),
                    const SizedBox(height: 16),
                    
                    // Unified Full Name (appears once for all roles)
                    if (_studentData != null || _parentData != null || _teacherData != null) ...[
                      if (_isEditing)
                        _buildEditableField(
                          label: 'Full Name',
                          controller: _fullNameController,
                          icon: Icons.badge_outlined,
                        )
                      else
                        _buildProfileField(
                          label: 'Full Name',
                          value: (_studentData?['full_name'] ?? 
                                  _parentData?['full_name'] ?? 
                                  _teacherData?['full_name']) ?? 'Not set',
                          icon: Icons.badge_outlined,
                          isEditable: true,
                        ),
                      const SizedBox(height: 16),
                    ],
                    
                    // Student-specific fields
                    if (_studentData != null) ...[
                      // Address
                      if (_isEditing)
                        _buildEditableField(
                          label: 'Address',
                          controller: _addressController,
                          icon: Icons.home_outlined,
                        )
                      else
                        _buildProfileField(
                          label: 'Address',
                          value: _studentData!['address'] ?? 'Not set',
                          icon: Icons.home_outlined,
                          isEditable: true,
                        ),
                      const SizedBox(height: 16),
                      
                      // Birthday
                      if (_isEditing)
                        _buildEditableField(
                          label: 'Birthday (YYYY-MM-DD)',
                          controller: _birthdayController,
                          icon: Icons.cake_outlined,
                        )
                      else
                        _buildProfileField(
                          label: 'Birthday',
                          value: _studentData!['birthday'] ?? 'Not set',
                          icon: Icons.cake_outlined,
                          isEditable: true,
                        ),
                      const SizedBox(height: 16),
                      
                      // Parent Registration Button
                      if (!_isEditing) ...[
                        const Divider(),
                        const SizedBox(height: 16),
                        OutlinedButton.icon(
                          onPressed: _generateParentRegistrationLink,
                          icon: const Icon(Icons.person_add),
                          label: const Text('Generate Parent Registration Link'),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size.fromHeight(48),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                    ],
                    
                    // Parent-specific: Children list
                    if (_parentData != null && _parentData!['children'] != null) ...[
                      const Divider(),
                      const SizedBox(height: 16),
                      Text(
                        'My Children',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Tap on a child to view or edit their information',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ...(_parentData!['children'] as List).map((child) {
                        return Card(
                          color: Colors.blue.shade50,
                          margin: const EdgeInsets.only(bottom: 12),
                          child: InkWell(
                            onTap: () => _showChildDetailsDialog(child),
                            borderRadius: BorderRadius.circular(12),
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      _buildChildAvatar(
                                        child['profile_image'],
                                        child['full_name'],
                                        24,
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              child['full_name'],
                                              style: const TextStyle(
                                                fontSize: 18,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              '@${child['username']}',
                                              style: TextStyle(
                                                fontSize: 13,
                                                color: Colors.grey[700],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Icon(
                                        Icons.chevron_right,
                                        color: Colors.grey[600],
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  const Divider(),
                                  const SizedBox(height: 8),
                                  _buildInfoRow(
                                    Icons.cake_outlined,
                                    'Birthday',
                                    child['birthday'],
                                  ),
                                  const SizedBox(height: 8),
                                  _buildInfoRow(
                                    Icons.home_outlined,
                                    'Address',
                                    child['address'],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ],
                    
                    // Edit mode buttons at the bottom of role-specific area
                    if (_isEditing) ...[
                      const SizedBox(height: 16),
                      const Divider(),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: _isSaving ? null : _cancelEditing,
                            child: const Text('Cancel'),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: _isSaving ? null : _saveProfile,
                            child: _isSaving
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Text('Save'),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Security Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Security',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const Divider(),
                  const SizedBox(height: 16),
                  ListTile(
                    leading: const Icon(Icons.lock_outline),
                    title: const Text('Change Password'),
                    subtitle: const Text('Update your account password'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: _isEditing ? null : _showChangePasswordDialog,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileField({
    required String label,
    required String value,
    required IconData icon,
    required bool isEditable,
  }) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.grey[600]),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEditableField({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    TextInputType? keyboardType,
  }) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.grey[600]),
        const SizedBox(width: 12),
        Expanded(
          child: TextField(
            controller: controller,
            keyboardType: keyboardType,
            decoration: InputDecoration(
              labelText: label,
              border: const OutlineInputBorder(),
              isDense: true,
            ),
          ),
        ),
      ],
    );
  }
  
  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey[600]),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: TextStyle(
            fontSize: 13,
            color: Colors.grey[700],
            fontWeight: FontWeight.w500,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 13,
            ),
          ),
        ),
      ],
    );
  }
  
  Widget _buildChildAvatar(String? profileImage, String fullName, double radius) {
    final imageUrl = profileImage != null && profileImage.isNotEmpty
        ? '$_baseUrl/uploads/profile_images/$profileImage'
        : null;

    return CircleAvatar(
      backgroundColor: Colors.blue,
      radius: radius,
      backgroundImage: imageUrl != null ? NetworkImage(imageUrl) : null,
      child: imageUrl == null
          ? Text(
              fullName[0].toUpperCase(),
              style: TextStyle(
                color: Colors.white,
                fontSize: radius * 0.8,
                fontWeight: FontWeight.bold,
              ),
            )
          : null,
    );
  }

  void _showChildDetailsDialog(Map<String, dynamic> child) {
    final fullNameController = TextEditingController(text: child['full_name']);
    final addressController = TextEditingController(text: child['address']);
    final birthdayController = TextEditingController(text: child['birthday']);
    bool isEditing = false;
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: Row(
              children: [
                _buildChildAvatar(
                  child['profile_image'],
                  child['full_name'],
                  20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        child['full_name'],
                        style: const TextStyle(fontSize: 20),
                      ),
                      Text(
                        '@${child['username']}',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: 500,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (isEditing) ...[
                      TextField(
                        controller: fullNameController,
                        decoration: const InputDecoration(
                          labelText: 'Full Name',
                          prefixIcon: Icon(Icons.badge),
                          border: OutlineInputBorder(),
                        ),
                        enabled: !isSaving,
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: addressController,
                        decoration: const InputDecoration(
                          labelText: 'Address',
                          prefixIcon: Icon(Icons.home),
                          border: OutlineInputBorder(),
                        ),
                        enabled: !isSaving,
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: birthdayController,
                        decoration: const InputDecoration(
                          labelText: 'Birthday (YYYY-MM-DD)',
                          prefixIcon: Icon(Icons.cake),
                          border: OutlineInputBorder(),
                          hintText: '2010-01-31',
                        ),
                        enabled: !isSaving,
                      ),
                    ] else ...[
                      ListTile(
                        leading: const Icon(Icons.badge),
                        title: const Text('Full Name'),
                        subtitle: Text(child['full_name']),
                        contentPadding: EdgeInsets.zero,
                      ),
                      const Divider(),
                      ListTile(
                        leading: const Icon(Icons.home),
                        title: const Text('Address'),
                        subtitle: Text(child['address']),
                        contentPadding: EdgeInsets.zero,
                      ),
                      const Divider(),
                      ListTile(
                        leading: const Icon(Icons.cake),
                        title: const Text('Birthday'),
                        subtitle: Text(child['birthday']),
                        contentPadding: EdgeInsets.zero,
                      ),
                      const Divider(),
                      ListTile(
                        leading: const Icon(Icons.person),
                        title: const Text('Username'),
                        subtitle: Text(child['username']),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              if (isEditing) ...[
                TextButton(
                  onPressed: isSaving
                      ? null
                      : () {
                          setState(() {
                            isEditing = false;
                            fullNameController.text = child['full_name'];
                            addressController.text = child['address'];
                            birthdayController.text = child['birthday'];
                          });
                        },
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: isSaving
                      ? null
                      : () async {
                          setState(() {
                            isSaving = true;
                          });

                          await _updateChildData(
                            child['user_id'],
                            fullNameController.text,
                            addressController.text,
                            birthdayController.text,
                          );

                          setState(() {
                            isSaving = false;
                          });

                          if (context.mounted) {
                            Navigator.of(context).pop();
                            _loadProfile();
                          }
                        },
                  child: isSaving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Save'),
                ),
              ] else ...[
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Close'),
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    setState(() {
                      isEditing = true;
                    });
                  },
                  icon: const Icon(Icons.edit),
                  label: const Text('Edit'),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  Future<void> _updateChildData(
    int childUserId,
    String fullName,
    String address,
    String birthday,
  ) async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final token = authService.token;

    if (token == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Not authenticated'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    try {
      final response = await http.put(
        Uri.parse('$_baseUrl/api/students/$childUserId'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'full_name': fullName,
          'address': address,
          'birthday': birthday,
        }),
      );

      if (mounted) {
        if (response.statusCode == 200) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Child information updated successfully'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          final error = jsonDecode(response.body)['error'] ?? 'Update failed';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(error),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating child data: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

class ChangePasswordDialog extends StatefulWidget {
  final VoidCallback onPasswordChanged;

  const ChangePasswordDialog({
    super.key,
    required this.onPasswordChanged,
  });

  @override
  State<ChangePasswordDialog> createState() => _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends State<ChangePasswordDialog> {
  static const String _baseUrl = 'http://localhost:8080';
  
  final _formKey = GlobalKey<FormState>();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  
  bool _isChanging = false;
  bool _obscureCurrentPassword = true;
  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;
  String? _errorMessage;

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _changePassword() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isChanging = true;
      _errorMessage = null;
    });

    final authService = Provider.of<AuthService>(context, listen: false);
    final token = authService.token;

    if (token == null) {
      setState(() {
        _isChanging = false;
        _errorMessage = 'Not authenticated';
      });
      return;
    }

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/api/profile/change-password'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'current_password': _currentPasswordController.text,
          'new_password': _newPasswordController.text,
        }),
      );

      if (response.statusCode == 200) {
        if (mounted) {
          Navigator.of(context).pop();
          widget.onPasswordChanged();
        }
      } else {
        final data = jsonDecode(response.body);
        setState(() {
          _isChanging = false;
          _errorMessage = data['error'] ?? 'Failed to change password';
        });
      }
    } catch (e) {
      setState(() {
        _isChanging = false;
        _errorMessage = 'Error changing password: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Change Password'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red[50],
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: Colors.red, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
              
              // Current Password
              TextFormField(
                controller: _currentPasswordController,
                obscureText: _obscureCurrentPassword,
                decoration: InputDecoration(
                  labelText: 'Current Password',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureCurrentPassword ? Icons.visibility : Icons.visibility_off,
                    ),
                    onPressed: () {
                      setState(() {
                        _obscureCurrentPassword = !_obscureCurrentPassword;
                      });
                    },
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your current password';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              
              // New Password
              TextFormField(
                controller: _newPasswordController,
                obscureText: _obscureNewPassword,
                decoration: InputDecoration(
                  labelText: 'New Password',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureNewPassword ? Icons.visibility : Icons.visibility_off,
                    ),
                    onPressed: () {
                      setState(() {
                        _obscureNewPassword = !_obscureNewPassword;
                      });
                    },
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a new password';
                  }
                  if (value.length < 6) {
                    return 'Password must be at least 6 characters';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              
              // Confirm Password
              TextFormField(
                controller: _confirmPasswordController,
                obscureText: _obscureConfirmPassword,
                decoration: InputDecoration(
                  labelText: 'Confirm New Password',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureConfirmPassword ? Icons.visibility : Icons.visibility_off,
                    ),
                    onPressed: () {
                      setState(() {
                        _obscureConfirmPassword = !_obscureConfirmPassword;
                      });
                    },
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please confirm your new password';
                  }
                  if (value != _newPasswordController.text) {
                    return 'Passwords do not match';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isChanging ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isChanging ? null : _changePassword,
          child: _isChanging
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                  ),
                )
              : const Text('Change Password'),
        ),
      ],
    );
  }
}
