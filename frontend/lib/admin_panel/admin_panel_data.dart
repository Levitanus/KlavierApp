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
}
