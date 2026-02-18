part of '../profile_screen.dart';

mixin _ProfileScreenData on _ProfileScreenStateBase {
  void _applyProfileData(Map<String, dynamic> data) {
    _userId = data['id'];
    _username = data['username'] ?? '';
    _email = data['email'];
    _phone = data['phone'];
    _profileImage =
        data['profile_image'] != null &&
            data['profile_image'].toString().isNotEmpty
        ? '${_ProfileScreenStateBase._baseUrl}/uploads/profile_images/${data['profile_image']}'
        : null;
    _createdAt = data['created_at'] != null
        ? DateTime.fromMillisecondsSinceEpoch(data['created_at'] * 1000)
        : null;

    _roles = data['roles'] != null ? List<String>.from(data['roles']) : [];
    _adminRoleSelected = _roles.contains('admin');
    _studentData = data['student_data'];
    _parentData = data['parent_data'];
    _teacherData = data['teacher_data'];

    _emailController.text = _email ?? '';
    _phoneController.text = _phone ?? '';

    if (_studentData != null) {
      _fullNameController.text = _studentData!['full_name'] ?? '';
      _birthdayController.text = _studentData!['birthday'] ?? '';
    } else if (_parentData != null) {
      _fullNameController.text = _parentData!['full_name'] ?? '';
    } else if (_teacherData != null) {
      _fullNameController.text = _teacherData!['full_name'] ?? '';
    } else {
      _fullNameController.text = data['full_name'] ?? '';
    }
  }

  Future<void> _loadProfile() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    if (_isAdminView) {
      await _loadAdminUserProfile();
      return;
    }

    final authService = Provider.of<AuthService>(context, listen: false);
    final token = authService.token;

    if (token == null) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Not authenticated';
      });
      return;
    }

    final cachedProfile = await AppDataCacheService.instance.readJsonMap(
      'profile',
      authService.userId,
    );
    final hasCached = cachedProfile != null;

    if (cachedProfile != null && mounted) {
      setState(() {
        _applyProfileData(cachedProfile);
        _isLoading = false;
      });
    }

    try {
      final response = await http.get(
        Uri.parse('${_ProfileScreenStateBase._baseUrl}/api/profile'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        await AppDataCacheService.instance.writeJson(
          'profile',
          authService.userId,
          data,
        );
        setState(() {
          _applyProfileData(data);
          _isLoading = false;
        });

        if (_teacherData != null) {
          await _loadTeacherStudents();
        }

        if (_studentData != null) {
          await _loadStudentTeachers();
        }
      } else {
        if (!hasCached) {
          setState(() {
            _isLoading = false;
            _errorMessage = 'Failed to load profile: ${response.statusCode}';
          });
        } else if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (!hasCached) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Error loading profile: $e';
        });
      } else if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadAdminUserProfile() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final token = authService.token;

    if (token == null) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Not authenticated';
      });
      return;
    }

    _studentData = null;
    _parentData = null;
    _teacherData = null;
    _studentStatus = null;
    _parentStatus = null;
    _teacherStatus = null;
    _profileImage = null;
    _createdAt = null;
    _teacherStudents = [];
    _teacherGroups = [];
    _studentTeachers = [];

    try {
      final response = await http.get(
        Uri.parse(
          '${_ProfileScreenStateBase._baseUrl}/api/admin/users/${widget.userId}',
        ),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode != 200) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Failed to load user: ${response.statusCode}';
        });
        return;
      }

      final decoded = jsonDecode(response.body);
      Map<String, dynamic>? userData;
      if (decoded is Map<String, dynamic>) {
        if (decoded['user'] is Map<String, dynamic>) {
          userData = decoded['user'] as Map<String, dynamic>;
        } else {
          userData = decoded;
        }
      }

      if (userData == null) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'User not found';
        });
        return;
      }

      _userId = userData['id'];
      _username = userData['username'] ?? '';
      _email = userData['email'];
      _phone = userData['phone'];
      _roles = List<String>.from(userData['roles'] ?? []);
      _studentStatus = userData['student_status']?.toString();
      _parentStatus = userData['parent_status']?.toString();
      _teacherStatus = userData['teacher_status']?.toString();
      _adminRoleSelected = _roles.contains('admin');

      _emailController.text = _email ?? '';
      _phoneController.text = _phone ?? '';

      await _loadAdminRoleDetails(token);

      final unifiedFullName =
          _studentData?['full_name'] ??
          _parentData?['full_name'] ??
          _teacherData?['full_name'] ??
          userData['full_name'] ??
          '';
      _fullNameController.text = unifiedFullName.toString();

      if (_studentData != null) {
        _birthdayController.text = _studentData!['birthday'] ?? '';
      }

      setState(() {
        _isLoading = false;
      });

      if (_teacherData != null) {
        await _loadTeacherStudents();
      }

      if (_studentData != null) {
        await _loadStudentTeachers();
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error loading user: $e';
      });
    }
  }

  Future<void> _loadAdminRoleDetails(String token) async {
    if (_userId == null) return;

    if (_roles.contains('student')) {
      try {
        final response = await http.get(
          Uri.parse(
            '${_ProfileScreenStateBase._baseUrl}/api/students/$_userId',
          ),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
        );
        if (response.statusCode == 200) {
          _studentData = jsonDecode(response.body);
        }
      } catch (_) {}
    }

    if (_roles.contains('parent')) {
      try {
        final response = await http.get(
          Uri.parse('${_ProfileScreenStateBase._baseUrl}/api/parents/$_userId'),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
        );
        if (response.statusCode == 200) {
          _parentData = jsonDecode(response.body);
        }
      } catch (_) {}
    }

    if (_roles.contains('teacher')) {
      try {
        final response = await http.get(
          Uri.parse(
            '${_ProfileScreenStateBase._baseUrl}/api/teachers/$_userId',
          ),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
        );
        if (response.statusCode == 200) {
          _teacherData = jsonDecode(response.body);
        }
      } catch (_) {}
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

    if (_isAdminView) {
      await _saveAdminProfile(token);
      return;
    }

    try {
      final updateData = {
        'email': _emailController.text.isEmpty ? null : _emailController.text,
        'phone': _phoneController.text.isEmpty ? null : _phoneController.text,
      };

      if (_fullNameController.text.isNotEmpty) {
        updateData['full_name'] = _fullNameController.text;
      }
      if (_studentData != null && _birthdayController.text.isNotEmpty) {
        updateData['birthday'] = _birthdayController.text;
      }

      final response = await http.put(
        Uri.parse('${_ProfileScreenStateBase._baseUrl}/api/profile'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(updateData),
      );

      if (response.statusCode == 200) {
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

  Future<void> _saveAdminProfile(String token) async {
    if (_userId == null) {
      setState(() {
        _isSaving = false;
        _errorMessage = 'User ID not available';
      });
      return;
    }

    http.Response? response;

    try {
      if (_roles.contains('student')) {
        final updateData = {
          if (_emailController.text.isNotEmpty) 'email': _emailController.text,
          if (_phoneController.text.isNotEmpty) 'phone': _phoneController.text,
          if (_fullNameController.text.isNotEmpty)
            'full_name': _fullNameController.text,
          if (_birthdayController.text.isNotEmpty)
            'birthday': _birthdayController.text,
        };

        response = await http.put(
          Uri.parse(
            '${_ProfileScreenStateBase._baseUrl}/api/students/$_userId',
          ),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
          body: jsonEncode(updateData),
        );
      } else if (_roles.contains('parent')) {
        final updateData = {
          if (_emailController.text.isNotEmpty) 'email': _emailController.text,
          if (_phoneController.text.isNotEmpty) 'phone': _phoneController.text,
          if (_fullNameController.text.isNotEmpty)
            'full_name': _fullNameController.text,
        };

        response = await http.put(
          Uri.parse('${_ProfileScreenStateBase._baseUrl}/api/parents/$_userId'),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
          body: jsonEncode(updateData),
        );
      } else if (_roles.contains('teacher')) {
        final updateData = {
          if (_emailController.text.isNotEmpty) 'email': _emailController.text,
          if (_phoneController.text.isNotEmpty) 'phone': _phoneController.text,
          if (_fullNameController.text.isNotEmpty)
            'full_name': _fullNameController.text,
        };

        response = await http.put(
          Uri.parse(
            '${_ProfileScreenStateBase._baseUrl}/api/teachers/$_userId',
          ),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
          body: jsonEncode(updateData),
        );
      } else {
        final updateData = {
          if (_emailController.text.isNotEmpty) 'email': _emailController.text,
          if (_phoneController.text.isNotEmpty) 'phone': _phoneController.text,
        };

        response = await http.put(
          Uri.parse(
            '${_ProfileScreenStateBase._baseUrl}/api/admin/users/$_userId',
          ),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
          body: jsonEncode(updateData),
        );
      }

      if (response.statusCode == 200) {
        await _loadAdminUserProfile();
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
          _errorMessage = 'Failed to update profile';
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

      if (_studentData != null) {
        _fullNameController.text = _studentData!['full_name'] ?? '';
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
        withData: true,
      );

      if (result == null || result.files.isEmpty) return;

      final file = result.files.first;

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

      setState(() {
        _isSaving = true;
      });

      final request = http.MultipartRequest(
        'POST',
        Uri.parse(
          '${_ProfileScreenStateBase._baseUrl}/api/profile/upload-image',
        ),
      );

      request.headers['Authorization'] = 'Bearer $token';

      if (file.bytes != null) {
        request.files.add(
          http.MultipartFile.fromBytes(
            'image',
            file.bytes!,
            filename: file.name,
          ),
        );
      } else if (file.path != null) {
        request.files.add(
          await http.MultipartFile.fromPath('image', file.path!),
        );
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
          _profileImage = '${_ProfileScreenStateBase._baseUrl}${data['url']}';
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
          final error =
              jsonDecode(response.body)['error'] ?? 'Failed to upload image';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(error), backgroundColor: Colors.red),
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
        Uri.parse('${_ProfileScreenStateBase._baseUrl}/api/profile/image'),
        headers: {'Authorization': 'Bearer $token'},
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

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final response = await http.post(
        Uri.parse(
          '${_ProfileScreenStateBase._baseUrl}/api/students/$_userId/parent-registration-token',
        ),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (mounted) Navigator.of(context).pop();

      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        final registrationToken = data['token'];
        final expiresAt = DateTime.parse(data['expires_at']);

        final origin = kIsWeb
            ? Uri.base.origin
            : _ProfileScreenStateBase._baseUrl;
        final registrationLink = '$origin/register?token=$registrationToken';

        print('DEBUG - Registration link origin: $origin');
        print('DEBUG - Full registration link: $registrationLink');

        if (mounted) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              insetPadding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 8,
              ),
              titlePadding: const EdgeInsets.fromLTRB(8, 12, 8, 0),
              contentPadding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
              actionsPadding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
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
                      border: Border.all(
                        color: Theme.of(context).colorScheme.outline,
                      ),
                    ),
                    child: SelectableText(
                      registrationLink,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Expires: ${expiresAt.day}/${expiresAt.month}/${expiresAt.year} ${expiresAt.hour}:${expiresAt.minute.toString().padLeft(2, '0')}',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'This link is valid for 48 hours.',
                    style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
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
          final error =
              jsonDecode(response.body)['error'] ?? 'Failed to generate link';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(error), backgroundColor: Colors.red),
          );
        }
      }
    } catch (e) {
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

  Future<void> _loadTeacherStudents() async {
    if (_userId == null) return;
    final authService = Provider.of<AuthService>(context, listen: false);
    final token = authService.token;
    if (token == null) return;

    try {
      final response = await http.get(
        Uri.parse(
          '${_ProfileScreenStateBase._baseUrl}/api/teachers/$_userId/students',
        ),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        setState(() {
          _teacherStudents = data
              .whereType<Map<String, dynamic>>()
              .map((item) => Map<String, dynamic>.from(item))
              .toList();
        });
      }
    } catch (_) {}

    await _loadTeacherGroups();
  }

  Future<void> _loadTeacherGroups() async {
    if (_userId == null) return;
    final authService = Provider.of<AuthService>(context, listen: false);
    final token = authService.token;
    if (token == null) return;

    try {
      final response = await http.get(
        Uri.parse(
          '${_ProfileScreenStateBase._baseUrl}/api/teachers/$_userId/groups?include_archived=true',
        ),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        if (!mounted) return;
        setState(() {
          _teacherGroups = data
              .whereType<Map<String, dynamic>>()
              .map((item) => Map<String, dynamic>.from(item))
              .toList();
        });
      }
    } catch (_) {}
  }

  Future<List<Map<String, dynamic>>> _fetchTeacherStudents(
    int teacherId,
  ) async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final token = authService.token;
    if (token == null) return [];

    try {
      final response = await http.get(
        Uri.parse(
          '${_ProfileScreenStateBase._baseUrl}/api/teachers/$teacherId/students',
        ),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data
            .whereType<Map<String, dynamic>>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList();
      }
    } catch (_) {}

    return [];
  }

  Future<List<Map<String, dynamic>>> _fetchStudentTeachers(
    int studentId,
  ) async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final token = authService.token;
    if (token == null) return [];

    try {
      final response = await http.get(
        Uri.parse(
          '${_ProfileScreenStateBase._baseUrl}/api/students/$studentId/teachers',
        ),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data
            .whereType<Map<String, dynamic>>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList();
      }
    } catch (_) {}

    return [];
  }

  Future<void> _loadStudentTeachers() async {
    if (_userId == null) return;
    final teachers = await _fetchStudentTeachers(_userId!);
    if (mounted) {
      setState(() {
        _studentTeachers = teachers;
      });
    }
  }

  Future<List<Map<String, dynamic>>> _fetchStudentParents(int studentId) async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final token = authService.token;
    if (token == null) return [];

    try {
      final response = await http.get(
        Uri.parse(
          '${_ProfileScreenStateBase._baseUrl}/api/students/$studentId/parents',
        ),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data
            .whereType<Map<String, dynamic>>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList();
      }
    } catch (_) {}

    return [];
  }

  Future<void> _addStudentsToTeacher(List<int> studentIds) async {
    if (_userId == null || studentIds.isEmpty) return;
    final authService = Provider.of<AuthService>(context, listen: false);

    try {
      for (final studentId in studentIds) {
        final response = await http.post(
          Uri.parse(
            '${_ProfileScreenStateBase._baseUrl}/api/teachers/$_userId/students',
          ),
          headers: {
            'Authorization': 'Bearer ${authService.token}',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({'student_id': studentId}),
        );

        if (response.statusCode != 201 && response.statusCode != 200) {
          if (mounted) {
            final error = jsonDecode(response.body)['error'] ?? 'Unknown error';
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text('Error: $error')));
          }
          return;
        }
      }

      await _loadTeacherStudents();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Students added successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _createTeacherGroup(String name, List<int> studentIds) async {
    if (_userId == null || name.trim().isEmpty || studentIds.isEmpty) return;

    final authService = Provider.of<AuthService>(context, listen: false);
    final l10n = AppLocalizations.of(context);

    try {
      final response = await http.post(
        Uri.parse(
          '${_ProfileScreenStateBase._baseUrl}/api/teachers/$_userId/groups',
        ),
        headers: {
          'Authorization': 'Bearer ${authService.token}',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'name': name.trim(), 'student_ids': studentIds}),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        await _loadTeacherGroups();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                l10n?.profileGroupCreatedSuccess ??
                    'Group created successfully',
              ),
            ),
          );
        }
      } else if (mounted) {
        final error =
            jsonDecode(response.body)['error'] ??
            l10n?.profileGroupCreateFailed ??
            'Failed to create group';
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _updateTeacherGroup({
    required int groupId,
    String? name,
    List<int>? studentIds,
    bool? archived,
  }) async {
    if (_userId == null) return;

    final authService = Provider.of<AuthService>(context, listen: false);
    final l10n = AppLocalizations.of(context);

    final body = <String, dynamic>{};
    if (name != null) {
      body['name'] = name.trim();
    }
    if (studentIds != null) {
      body['student_ids'] = studentIds;
    }
    if (archived != null) {
      body['archived'] = archived;
    }

    if (body.isEmpty) return;

    try {
      final response = await http.put(
        Uri.parse(
          '${_ProfileScreenStateBase._baseUrl}/api/teachers/$_userId/groups/$groupId',
        ),
        headers: {
          'Authorization': 'Bearer ${authService.token}',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        await _loadTeacherGroups();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                l10n?.profileGroupUpdatedSuccess ??
                    'Group updated successfully',
              ),
            ),
          );
        }
      } else if (mounted) {
        final error =
            jsonDecode(response.body)['error'] ??
            l10n?.profileGroupUpdateFailed ??
            'Failed to update group';
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _deleteTeacherGroup(int groupId) async {
    if (_userId == null) return;

    final authService = Provider.of<AuthService>(context, listen: false);
    final l10n = AppLocalizations.of(context);

    try {
      final response = await http.delete(
        Uri.parse(
          '${_ProfileScreenStateBase._baseUrl}/api/teachers/$_userId/groups/$groupId',
        ),
        headers: {
          'Authorization': 'Bearer ${authService.token}',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        await _loadTeacherGroups();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                l10n?.profileGroupDeletedSuccess ??
                    'Group deleted successfully',
              ),
            ),
          );
        }
      } else if (mounted) {
        final error =
            jsonDecode(response.body)['error'] ??
            l10n?.profileGroupDeleteFailed ??
            'Failed to delete group';
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _removeStudentFromTeacher(int studentId) async {
    if (_userId == null) return;

    final confirmed = await _showLockedConfirmationDialog(
      title: 'Remove student',
      content: 'Remove this student from your list?',
      confirmLabel: 'Remove',
    );

    if (!confirmed) return;

    final authService = Provider.of<AuthService>(context, listen: false);

    try {
      final response = await http.delete(
        Uri.parse(
          '${_ProfileScreenStateBase._baseUrl}/api/teachers/$_userId/students/$studentId',
        ),
        headers: {'Authorization': 'Bearer ${authService.token}'},
      );

      if (response.statusCode == 200) {
        await _loadTeacherStudents();
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Student removed')));
        }
      } else if (mounted) {
        final error =
            jsonDecode(response.body)['error'] ?? 'Failed to remove student';
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _removeTeacherFromStudent(int studentId, int teacherId) async {
    final confirmed = await _showLockedConfirmationDialog(
      title: 'Leave teacher',
      content: 'Are you sure you want to leave this teacher?',
      confirmLabel: 'Leave',
    );

    if (!confirmed) return;

    final authService = Provider.of<AuthService>(context, listen: false);

    try {
      final response = await http.delete(
        Uri.parse(
          '${_ProfileScreenStateBase._baseUrl}/api/students/$studentId/teachers/$teacherId',
        ),
        headers: {'Authorization': 'Bearer ${authService.token}'},
      );

      if (response.statusCode == 200) {
        if (studentId == _userId) {
          await _loadStudentTeachers();
        }
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Teacher removed')));
        }
      } else if (mounted) {
        final error =
            jsonDecode(response.body)['error'] ?? 'Failed to remove teacher';
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _generateStudentRegistrationLinkForTeacher() async {
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

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final response = await http.post(
        Uri.parse(
          '${_ProfileScreenStateBase._baseUrl}/api/teachers/$_userId/student-registration-token',
        ),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (mounted) Navigator.of(context).pop();

      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        final registrationToken = data['token'];
        final expiresAt = DateTime.parse(data['expires_at']);
        final origin = kIsWeb
            ? Uri.base.origin
            : _ProfileScreenStateBase._baseUrl;
        final registrationLink = '$origin/register?token=$registrationToken';

        if (mounted) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              insetPadding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 8,
              ),
              titlePadding: const EdgeInsets.fromLTRB(8, 12, 8, 0),
              contentPadding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
              actionsPadding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
              title: const Text('Student Registration Link'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Share this link with your student to register:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.outlineVariant,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Theme.of(context).colorScheme.outline,
                      ),
                    ),
                    child: SelectableText(
                      registrationLink,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Expires: ${expiresAt.day}/${expiresAt.month}/${expiresAt.year} ${expiresAt.hour}:${expiresAt.minute.toString().padLeft(2, '0')}',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'This link is valid for 48 hours.',
                    style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
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
      } else if (mounted) {
        final error =
            jsonDecode(response.body)['error'] ?? 'Failed to generate link';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
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

  Future<void> _updateAdminRole() async {
    if (_userId == null) return;

    final authService = Provider.of<AuthService>(context, listen: false);
    final token = authService.token;

    if (token == null) return;

    final rolesToSave = [
      ..._roles.where((role) => role != 'admin'),
      if (_adminRoleSelected) 'admin',
    ];

    try {
      final response = await http.put(
        Uri.parse(
          '${_ProfileScreenStateBase._baseUrl}/api/admin/users/$_userId',
        ),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'roles': rolesToSave}),
      );

      if (response.statusCode == 200) {
        setState(() {
          _roles = rolesToSave;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Admin access updated'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to update admin access')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  String? _statusForRole(String role) {
    switch (role) {
      case 'student':
        return _studentStatus;
      case 'parent':
        return _parentStatus;
      case 'teacher':
        return _teacherStatus;
      default:
        return null;
    }
  }

  bool _isRoleArchived(String role) {
    return _statusForRole(role)?.toLowerCase() == 'archived';
  }

  String? _roleArchiveUrl(String role, int userId, {required bool archive}) {
    switch (role) {
      case 'student':
        return "${_ProfileScreenStateBase._baseUrl}/api/admin/students/$userId/${archive ? 'archive' : 'unarchive'}";
      case 'parent':
        return "${_ProfileScreenStateBase._baseUrl}/api/admin/parents/$userId/${archive ? 'archive' : 'unarchive'}";
      case 'teacher':
        return "${_ProfileScreenStateBase._baseUrl}/api/admin/teachers/$userId/${archive ? 'archive' : 'unarchive'}";
      default:
        return null;
    }
  }

  Future<void> _toggleRoleArchive(String role) async {
    if (_userId == null) return;

    final archive = !_isRoleArchived(role);
    final title = archive ? 'Archive $role role' : 'Unarchive $role role';
    final content = archive
        ? 'Are you sure you want to archive this $role role?'
        : 'Are you sure you want to unarchive this $role role?';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        titlePadding: const EdgeInsets.fromLTRB(8, 12, 8, 0),
        contentPadding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
        actionsPadding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(archive ? 'Archive' : 'Unarchive'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final url = _roleArchiveUrl(role, _userId!, archive: archive);
    if (url == null) return;

    final authService = Provider.of<AuthService>(context, listen: false);
    final token = authService.token;
    if (token == null) return;

    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        if (_isAdminView) {
          await _loadAdminUserProfile();
        } else {
          await _loadProfile();
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(archive ? 'Role archived' : 'Role unarchived'),
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to update role: ${response.body}')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _makeUserStudent(String birthday) async {
    if (_userId == null) return;
    final authService = Provider.of<AuthService>(context, listen: false);

    try {
      final response = await http.post(
        Uri.parse(
          '${_ProfileScreenStateBase._baseUrl}/api/admin/users/$_userId/make-student',
        ),
        headers: {
          'Authorization': 'Bearer ${authService.token}',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'birthday': birthday}),
      );

      if (response.statusCode == 200) {
        await _loadAdminUserProfile();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('User converted to student')),
          );
        }
      } else {
        if (mounted) {
          final error = jsonDecode(response.body)['error'] ?? 'Unknown error';
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error: $error')));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _makeUserParent(List<int> studentIds) async {
    if (_userId == null) return;
    final authService = Provider.of<AuthService>(context, listen: false);

    try {
      final response = await http.post(
        Uri.parse(
          '${_ProfileScreenStateBase._baseUrl}/api/admin/users/$_userId/make-parent',
        ),
        headers: {
          'Authorization': 'Bearer ${authService.token}',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'student_ids': studentIds}),
      );

      if (response.statusCode == 200) {
        await _loadAdminUserProfile();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('User converted to parent')),
          );
        }
      } else {
        if (mounted) {
          final error = jsonDecode(response.body)['error'] ?? 'Unknown error';
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error: $error')));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _makeUserTeacher() async {
    if (_userId == null) return;
    final authService = Provider.of<AuthService>(context, listen: false);

    try {
      final response = await http.post(
        Uri.parse(
          '${_ProfileScreenStateBase._baseUrl}/api/admin/users/$_userId/make-teacher',
        ),
        headers: {
          'Authorization': 'Bearer ${authService.token}',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({}),
      );

      if (response.statusCode == 200) {
        await _loadAdminUserProfile();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('User converted to teacher')),
          );
        }
      } else {
        if (mounted) {
          final error = jsonDecode(response.body)['error'] ?? 'Unknown error';
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error: $error')));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<List<StudentInfo>> _loadStudentsForSelection() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final token = authService.token;

    if (token == null) return [];

    try {
      final listResponse = await http.get(
        Uri.parse('${_ProfileScreenStateBase._baseUrl}/api/students'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (listResponse.statusCode == 200) {
        final List<dynamic> data = jsonDecode(listResponse.body);
        return data
            .whereType<Map<String, dynamic>>()
            .map((entry) {
              final userId = entry['user_id'] ?? entry['id'];
              final username = entry['username']?.toString() ?? 'unknown';
              final fullName = entry['full_name']?.toString() ?? username;
              return StudentInfo(
                userId: userId is int ? userId : 0,
                username: username,
                fullName: fullName,
              );
            })
            .where((student) => student.userId != 0)
            .toList();
      }

      if (!authService.isAdmin) {
        return [];
      }

      final response = await http.get(
        Uri.parse('${_ProfileScreenStateBase._baseUrl}/api/admin/users'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode != 200) return [];

      final List<dynamic> data = jsonDecode(response.body);
      final studentUsers = data.where((entry) {
        if (entry is Map<String, dynamic>) {
          final roles = List<String>.from(entry['roles'] ?? []);
          return roles.contains('student');
        }
        return false;
      }).toList();

      final List<StudentInfo> students = [];

      for (final entry in studentUsers) {
        if (entry is! Map<String, dynamic>) continue;
        final userId = entry['id'];
        final username = entry['username']?.toString() ?? 'unknown';
        String fullName = username;

        try {
          final studentResponse = await http.get(
            Uri.parse(
              '${_ProfileScreenStateBase._baseUrl}/api/students/$userId',
            ),
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
          );
          if (studentResponse.statusCode == 200) {
            final studentData = jsonDecode(studentResponse.body);
            fullName = studentData['full_name']?.toString() ?? fullName;
          }
        } catch (_) {}

        students.add(
          StudentInfo(userId: userId, username: username, fullName: fullName),
        );
      }

      return students;
    } catch (_) {
      return [];
    }
  }

  Future<void> _addChildrenToParent(List<int> studentIds) async {
    if (_userId == null || studentIds.isEmpty) return;
    final authService = Provider.of<AuthService>(context, listen: false);

    try {
      for (final studentId in studentIds) {
        final response = await http.post(
          Uri.parse(
            '${_ProfileScreenStateBase._baseUrl}/api/parents/$_userId/students',
          ),
          headers: {
            'Authorization': 'Bearer ${authService.token}',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({'student_id': studentId}),
        );

        if (response.statusCode != 201 && response.statusCode != 200) {
          if (mounted) {
            final error = jsonDecode(response.body)['error'] ?? 'Unknown error';
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text('Error: $error')));
          }
          return;
        }
      }

      await _loadAdminUserProfile();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Children added successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _updateChildData(
    int childUserId,
    String fullName,
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
        Uri.parse(
          '${_ProfileScreenStateBase._baseUrl}/api/students/$childUserId',
        ),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'full_name': fullName, 'birthday': birthday}),
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
            SnackBar(content: Text(error), backgroundColor: Colors.red),
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
