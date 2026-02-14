part of '../admin_panel.dart';

mixin _AdminPanelData on _AdminPanelStateBase {
  Future<void> _loadUsers() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final queryParameters = <String, String>{
        'page': _currentPage.toString(),
        'page_size': _pageSize.toString(),
        if (_searchQuery.isNotEmpty) 'search': _searchQuery,
      };
      final uri = Uri.parse('${AppConfig.instance.baseUrl}/api/admin/users')
          .replace(queryParameters: queryParameters);
      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer ${authService.token}',
        },
      );

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        final UsersPageResponse pageData;
        if (decoded is List) {
          final users = decoded.map((json) => User.fromJson(json)).toList();
          pageData = UsersPageResponse(
            users: users,
            total: users.length,
            page: 1,
            pageSize: users.length,
          );
        } else {
          pageData = UsersPageResponse.fromJson(decoded);
        }
        setState(() {
          _users = pageData.users;
          _totalUsers = pageData.total;
          _currentPage = pageData.page;
          _pageSize = pageData.pageSize;
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
