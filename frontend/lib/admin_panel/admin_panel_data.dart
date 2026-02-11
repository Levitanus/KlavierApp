part of '../admin_panel.dart';

mixin _AdminPanelData on _AdminPanelStateBase {
  Future<void> _loadUsers() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final response = await http.get(
        Uri.parse('http://localhost:8080/api/admin/users'),
        headers: {
          'Authorization': 'Bearer ${authService.token}',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        setState(() {
          _users = data.map((json) => User.fromJson(json)).toList();
          _isLoading = false;
        });

        _loadUserFullNames(_users);

        if (widget.username != null && !_hasOpenedDialog && mounted) {
          _hasOpenedDialog = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            final matchingUsers = _users.where((u) => u.username == widget.username);
            if (matchingUsers.isNotEmpty && mounted) {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) =>
                      AdminUserProfilePage(userId: matchingUsers.first.id),
                ),
              );
            }
          });
        }
      } else {
        setState(() {
          _errorMessage = 'Failed to load users';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _loadUserFullNames(List<User> users) async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final token = authService.token;

    if (token == null) return;

    for (final user in users) {
      if (!mounted) return;
      final fullName = await _fetchUserFullName(user, token);
      if (!mounted) return;

      setState(() {
        _userFullNames[user.id] = fullName ?? user.username;
      });
    }
  }

  Future<String?> _fetchUserFullName(User user, String token) async {
    Future<String?> fetchFrom(String url) async {
      try {
        final response = await http.get(
          Uri.parse(url),
          headers: {'Authorization': 'Bearer $token'},
        );
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          return data['full_name']?.toString();
        }
      } catch (_) {}
      return null;
    }

    if (user.roles.contains('student')) {
      return fetchFrom('http://localhost:8080/api/students/${user.id}');
    }

    if (user.roles.contains('parent')) {
      return fetchFrom('http://localhost:8080/api/parents/${user.id}');
    }

    if (user.roles.contains('teacher')) {
      return fetchFrom('http://localhost:8080/api/teachers/${user.id}');
    }

    return null;
  }
}
