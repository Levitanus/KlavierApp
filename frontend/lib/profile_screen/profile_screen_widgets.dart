part of '../profile_screen.dart';

mixin _ProfileScreenWidgets on _ProfileScreenStateBase {
  Widget _buildProfileImage({required bool allowEditing}) {
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
          if (allowEditing && _isEditing && !_isSaving)
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
                            color: Colors.black.withValues(alpha: 51),
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
                          color: Colors.black.withValues(alpha: 51),
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
                  color: Colors.black.withValues(alpha: 128),
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

  Widget _buildAdminControlsCard() {
    final hasUserId = _userId != null;
    final canUpdate = !_isSaving && hasUserId;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Admin Controls',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const Divider(),
            CheckboxListTile(
              title: const Text('Admin Access'),
              subtitle: const Text('Grant or revoke admin permissions'),
              value: _adminRoleSelected,
              onChanged: canUpdate
                  ? (checked) {
                      setState(() {
                        _adminRoleSelected = checked ?? false;
                      });
                    }
                  : null,
              dense: true,
              contentPadding: EdgeInsets.zero,
            ),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton.icon(
                onPressed: canUpdate ? _updateAdminRole : null,
                icon: const Icon(Icons.save),
                label: const Text('Update Admin Access'),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Role Management',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (!_roles.contains('student'))
                  OutlinedButton.icon(
                    icon: const Icon(Icons.school, size: 16),
                    label: const Text('Make Student'),
                    onPressed: canUpdate ? _showMakeStudentDialog : null,
                  ),
                if (!_roles.contains('parent'))
                  OutlinedButton.icon(
                    icon: const Icon(Icons.family_restroom, size: 16),
                    label: const Text('Make Parent'),
                    onPressed: canUpdate ? _showMakeParentDialog : null,
                  ),
                if (!_roles.contains('teacher'))
                  OutlinedButton.icon(
                    icon: const Icon(Icons.person, size: 16),
                    label: const Text('Make Teacher'),
                    onPressed: canUpdate ? _showMakeTeacherDialog : null,
                  ),
              ],
            ),
            const SizedBox(height: 16),
            if (_roles.any((role) => role == 'student' || role == 'parent' || role == 'teacher')) ...[
              Text(
                'Archive Roles',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (_roles.contains('student'))
                    OutlinedButton.icon(
                      icon: Icon(
                        _isRoleArchived('student') ? Icons.unarchive : Icons.archive,
                        size: 16,
                      ),
                      label: Text(
                        _isRoleArchived('student')
                            ? 'Unarchive Student'
                            : 'Archive Student',
                      ),
                      onPressed: canUpdate
                          ? () => _toggleRoleArchive('student')
                          : null,
                    ),
                  if (_roles.contains('parent'))
                    OutlinedButton.icon(
                      icon: Icon(
                        _isRoleArchived('parent') ? Icons.unarchive : Icons.archive,
                        size: 16,
                      ),
                      label: Text(
                        _isRoleArchived('parent')
                            ? 'Unarchive Parent'
                            : 'Archive Parent',
                      ),
                      onPressed: canUpdate
                          ? () => _toggleRoleArchive('parent')
                          : null,
                    ),
                  if (_roles.contains('teacher'))
                    OutlinedButton.icon(
                      icon: Icon(
                        _isRoleArchived('teacher') ? Icons.unarchive : Icons.archive,
                        size: 16,
                      ),
                      label: Text(
                        _isRoleArchived('teacher')
                            ? 'Unarchive Teacher'
                            : 'Archive Teacher',
                      ),
                      onPressed: canUpdate
                          ? () => _toggleRoleArchive('teacher')
                          : null,
                    ),
                ],
              ),
            ],
            if (_roles.contains('parent')) ...[
              const SizedBox(height: 16),
              Text(
                'Parent Tools',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                icon: const Icon(Icons.person_add_alt_1),
                label: const Text('Add Children'),
                onPressed: canUpdate ? _showAddChildrenDialog : null,
              ),
            ],
          ],
        ),
      ),
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
        ? '${_ProfileScreenStateBase._baseUrl}/uploads/profile_images/$profileImage'
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
}
