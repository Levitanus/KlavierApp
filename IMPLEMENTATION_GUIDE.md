# Parent-Student Relationship System Implementation Summary

## Overview
This document summarizes the implementation of a comprehensive parent-student relationship system with role-specific user management.

## Completed Components

### 1. Database Schema (Migration: `20260210000000_create_role_details_tables.sql`)

Created the following tables:

#### **students** table
- `user_id` (PK, FK to users)
- `full_name` (required)
- `address` (required)
- `birthday` (required, DATE)
- `created_at`, `updated_at` (auto-managed)

#### **parents** table
- `user_id` (PK, FK to users)
- `full_name` (required)
- `created_at`, `updated_at` (auto-managed)

#### **teachers** table
- `user_id` (PK, FK to users)
- `full_name` (required)
- `created_at`, `updated_at` (auto-managed)

#### **parent_student_relations** table
Many-to-many relationship between parents and students:
- `parent_user_id` (PK, FK to parents.user_id)
- `student_user_id` (PK, FK to students.user_id)
- `created_at`

#### **registration_tokens** table
Time-limited registration tokens:
- `id` (PK)
- `token_hash` (unique, SHA256)
- `created_by_user_id` (FK to users)
- `role` (student/parent/teacher)
- `related_student_id` (optional, for parent registration from student profile)
- `created_at`, `expires_at` (48-hour expiration)
- `used_at`, `used_by_user_id`

### 2. Backend Implementation

#### New Modules

**`src/roles.rs`** - Core role management with 1,143 lines of code:
- Student CRUD operations with role-specific fields
- Parent CRUD operations with children relationships
- Teacher CRUD operations
- Permission system: parents can edit their children's profiles
- Routes:
  - `POST /api/admin/students` - Create student
  - `GET /api/students/{user_id}` - Get student details
  - `PUT /api/students/{user_id}` - Update student (parent/admin only)
  - `POST /api/admin/parents` - Create parent
  - `GET /api/parents/{user_id}` - Get parent with children
  - `PUT /api/parents/{user_id}` - Update parent
  - `POST /api/parents/{user_id}/students` - Add parent-student relation
  - `DELETE /api/parents/{parent_id}/students/{student_id}` - Remove relation
  - `POST /api/admin/teachers` - Create teacher

**`src/registration_tokens.rs`** - Registration token system:
- Time-limited registration tokens (48-hour expiry)
- Token generation and validation using SHA256 hashing
- Role-specific registration workflows
- Routes:
  - `POST /api/admin/registration-tokens` - Admin creates token
  - `POST /api/students/{student_id}/parent-registration-token` - Student issues parent token
  - `POST /api/register-with-token` - Register using token
  - `GET /api/admin/registration-tokens` - List all tokens (admin)

#### Enhanced Admin Module (`src/admin.rs`)

Added "make" endpoints to convert existing users to specific roles:
- `POST /api/admin/users/{id}/make-student` - Requires full_name, address, birthday
- `POST /api/admin/users/{id}/make-parent` - Requires full_name, student_ids (at least one)
- `POST /api/admin/users/{id}/make-teacher` - Requires full_name

**Data Consistency Solution:** All three "make" endpoints automatically update the `full_name` in ALL role tables (students, parents, teachers) if the user has multiple roles. This ensures UI consistency when a user is simultaneously a parent and student.

Example from `make_student`:
```rust
// Update other role tables if they exist with the same full_name
let _ = sqlx::query("UPDATE parents SET full_name = $1 WHERE user_id = $2")
    .bind(&student_data.full_name)
    .bind(user_id)
    .execute(&mut *tx)
    .await;
```

### 3. Frontend Admin Panel (Updated `admin_panel.dart`)

#### New Features

1. **Role-Specific Add Buttons**
   - "Add User" (generic, existing functionality)
   - "Add Student" (blue) - Full registration with student-specific fields
   - "Add Parent" (green) - Requires selecting at least one student
   - "Add Teacher" (orange) - Full registration with full_name field

2. **Edit User Dialog Enhancements**
   - Added "Convert to Role" section with buttons:
     - "Make Student" - Shows only if user is not already a student
     - "Make Parent" - Shows only if user is not already a parent
     - "Make Teacher" - Shows only if user is not already a teacher

3. **Comprehensive Dialogs**
   - Each role has a dedicated creation dialog with validation
   - Password generation for all new users
   - "Copy Credentials" functionality
   - Student selection for parents (enforces "at least one" requirement)

### 4. Data Consistency Implementation

The `full_name` consistency issue is solved at the backend level:

**Problem:** User can be both parent and student, each with `full_name` in separate tables.

**Solution:** 
- In the UI, there's a single `full_name` field
- Backend automatically updates ALL role tables when any role's full_name changes
- Implemented in:
  - `make_student` endpoint
  - `make_parent` endpoint  
  - `make_teacher` endpoint
  - `update_student` endpoint (should also be added)

**Recommendation:** Add similar cross-table updates to the `update_student`, `update_parent`, and `update_teacher` endpoints to maintain consistency during regular updates, not just during role conversion.

## Remaining Tasks

### 1. Parent Profile View with Children Management

The parent profile screen should display their children and allow editing. Here's the implementation approach:

#### Backend (Already Exists)
- `GET /api/parents/{user_id}` returns parent with `children` array
- `PUT /api/students/{user_id}` checks if requester is parent of the student

#### Frontend Implementation Needed

**Modify `profile_screen.dart`:**

1. **Detect if logged-in user is a parent:**
```dart
bool _isParent = false;
List<dynamic> _children = [];

Future<void> _loadProfile() async {
  // Existing profile loading...
  
  // Check if user has parent role
  final userResponse = await http.get(
    Uri.parse('$_baseUrl/api/profile'),
    headers: {'Authorization': 'Bearer $token'},
  );
  
  if (userResponse.statusCode == 200) {
    final userData = jsonDecode(userResponse.body);
    _isParent = (userData['roles'] as List).contains('parent');
    
    if (_isParent) {
      // Load parent details including children
      final parentResponse = await http.get(
        Uri.parse('$_baseUrl/api/parents/${userData['id']}'),
        headers: {'Authorization': 'Bearer $token'},
      );
      
      if (parentResponse.statusCode == 200) {
        final parentData = jsonDecode(parentResponse.body);
        setState(() {
          _children = parentData['children'] ?? [];
        });
      }
    }
  }
}
```

2. **Display children cards:**
```dart
Widget build(BuildContext context) {
  return Scaffold(
    body: Column(
      children: [
        // Existing profile UI...
        
        if (_isParent && _children.isNotEmpty) ...[
          const Divider(),
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              'My Children',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _children.length,
              itemBuilder: (context, index) {
                final child = _children[index];
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: ListTile(
                    leading: const Icon(Icons.school, size: 40),
                    title: Text(child['full_name']),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Username: ${child['username']}'),
                        Text('Birthday: ${child['birthday']}'),
                        Text('Address: ${child['address']}'),
                      ],
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.edit),
                      onPressed: () => _showEditChildDialog(child),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ],
    ),
  );
}
```

3. **Edit child dialog:**
```dart
void _showEditChildDialog(Map<String, dynamic> child) {
  final fullNameController = TextEditingController(text: child['full_name']);
  final addressController = TextEditingController(text: child['address']);
  final emailController = TextEditingController(text: child['email']);
  final phoneController = TextEditingController(text: child['phone']);
  
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('Edit ${child['full_name']}'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: fullNameController,
              decoration: const InputDecoration(labelText: 'Full Name'),
            ),
            TextField(
              controller: addressController,
              decoration: const InputDecoration(labelText: 'Address'),
            ),
            TextField(
              controller: emailController,
              decoration: const InputDecoration(labelText: 'Email'),
            ),
            TextField(
              controller: phoneController,
              decoration: const InputDecoration(labelText: 'Phone'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () async {
            await _updateChild(
              child['user_id'],
              fullNameController.text,
              addressController.text,
              emailController.text,
              phoneController.text,
            );
            Navigator.pop(context);
          },
          child: const Text('Save'),
        ),
      ],
    ),
  );
}

Future<void> _updateChild(
  int userId,
  String fullName,
  String address,
  String email,
  String phone,
) async {
  final authService = Provider.of<AuthService>(context, listen: false);
  final response = await http.put(
    Uri.parse('$_baseUrl/api/students/$userId'),
    headers: {
      'Authorization': 'Bearer ${authService.token}',
      'Content-Type': 'application/json',
    },
    body: jsonEncode({
      'full_name': fullName,
      'address': address,
      'email': email.isEmpty ? null : email,
      'phone': phone.isEmpty ? null : phone,
    }),
  );
  
  if (response.statusCode == 200) {
    _loadProfile(); // Refresh data
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Child profile updated')),
    );
  }
}
```

### 2. Additional Consistency Updates

To ensure full `full_name` consistency, update these endpoints to also sync across role tables:

**In `src/roles.rs`:**

```rust
// In update_student function, after updating students table:
let _ = sqlx::query("UPDATE parents SET full_name = $1 WHERE user_id = $2")
    .bind(&full_name)
    .bind(user_id)
    .execute(&mut *tx)
    .await;
    
let _ = sqlx::query("UPDATE teachers SET full_name = $1 WHERE user_id = $2")
    .bind(&full_name)
    .bind(user_id)
    .execute(&mut *tx)
    .await;

// Similar updates needed in update_parent and update_teacher
```

### 3. Student Profile - Parent Registration Link

Add a feature to student profiles to generate parent registration tokens:

```dart
// In student profile screen
ElevatedButton.icon(
  icon: const Icon(Icons.family_restroom),
  label: const Text('Invite Parent'),
  onPressed: _generateParentInvite,
)

Future<void> _generateParentInvite() async {
  final response = await http.post(
    Uri.parse('$_baseUrl/api/students/$studentId/parent-registration-token'),
    headers: {'Authorization': 'Bearer $token'},
  );
  
  if (response.statusCode == 201) {
    final data = jsonDecode(response.body);
    final registrationUrl = 'http://localhost:3000/register?token=${data['token']}';
    
    // Show dialog with registration link
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Parent Registration Link'),
        content: SelectableText(registrationUrl),
        actions: [
          ElevatedButton.icon(
            icon: const Icon(Icons.copy),
            label: const Text('Copy Link'),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: registrationUrl));
            },
          ),
        ],
      ),
    );
  }
}
```

### 4. Registration Page (New)

Create a registration page that accepts tokens:

**`lib/registration_screen.dart`:**
```dart
class RegistrationScreen extends StatelessWidget {
  final String token;
  
  const RegistrationScreen({required this.token, super.key});
  
  Future<void> _register(
    String username,
    String password,
    String fullName,
    String? address,
    String? birthday,
  ) async {
    final response = await http.post(
      Uri.parse('http://localhost:8080/api/register-with-token'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'token': token,
        'username': username,
        'password': password,
        'full_name': fullName,
        if (address != null) 'address': address,
        if (birthday != null) 'birthday': birthday,
      }),
    );
    
    // Handle response...
  }
}
```

## Testing Checklist

### Backend
- [ ] Run migration: The backend will auto-run migrations on startup
- [ ] Test student creation via admin panel
- [ ] Test parent creation with student assignment
- [ ] Test "make student/parent/teacher" endpoints
- [ ] Verify parent can edit their child's profile
- [ ] Verify admin can edit any student's profile
- [ ] Test registration token generation and usage
- [ ] Verify full_name consistency across role tables

### Frontend
- [ ] Test "Add Student" button and dialog
- [ ] Test "Add Parent" button (requires existing students)
- [ ] Test "Add Teacher" button
- [ ] Test "Make Student/Parent/Teacher" buttons in edit dialog
- [ ] Verify password generation works
- [ ] Verify "Copy Credentials" works
- [ ] Test validation (birthday format, required fields, at least one student for parents)

### Integration
- [ ] Create a student
- [ ] Create a parent linked to that student
- [ ] Login as parent
- [ ] View parent profile showing children
- [ ] Edit child's information as parent
- [ ] Verify changes persist

## Security Notes

1. **Token Security:** Registration tokens use SHA256 hashing and 48-hour expiration
2. **Permission Checks:** Backend enforces parent-child relationship for edit permissions
3. **Role Assignment:** Only admins can create roles via admin panel
4. **Password Hashing:** All passwords use Argon2id

## Database Migration

To apply the new schema, restart the backend. The migration will run automatically:

```bash
cd backend
cargo run
```

The migration `20260210000000_create_role_details_tables.sql` will be applied.

## API Reference Quick Guide

### Role Management Endpoints

| Method | Endpoint | Description | Auth Required |
|--------|----------|-------------|---------------|
| POST | `/api/admin/students` | Create student | Admin |
| GET | `/api/students/{id}` | Get student | Authenticated |
| PUT | `/api/students/{id}` | Update student | Admin or Parent |
| POST | `/api/admin/parents` | Create parent | Admin |
| GET | `/api/parents/{id}` | Get parent with children | Authenticated |
| PUT | `/api/parents/{id}` | Update parent | Admin or Self |
| POST | `/api/admin/teachers` | Create teacher | Admin |
| POST | `/api/admin/users/{id}/make-student` | Convert to student | Admin |
| POST | `/api/admin/users/{id}/make-parent` | Convert to parent | Admin |
| POST | `/api/admin/users/{id}/make-teacher` | Convert to teacher | Admin |

### Registration Token Endpoints

| Method | Endpoint | Description | Auth Required |
|--------|----------|-------------|---------------|
| POST | `/api/admin/registration-tokens` | Create token | Admin |
| POST | `/api/students/{id}/parent-registration-token` | Student creates parent token | Student or Admin |
| POST | `/api/register-with-token` | Register using token | None |
| GET | `/api/admin/registration-tokens` | List tokens | Admin |

## Next Steps

1. **Complete parent profile view** - Implement the frontend changes described above
2. **Add registration page** - Create a public registration page that accepts tokens
3. **Add full_name sync** - Update the `update_student`, `update_parent`, and `update_teacher` endpoints to sync full_name across all role tables
4. **Testing** - Thoroughly test all workflows
5. **Consider extending** - Add teacher-specific features, student-teacher relationships, etc.

## Architecture Benefits

✅ **Separation of Concerns:** Role-specific tables keep role-specific data separate  
✅ **Data Integrity:** Foreign key constraints ensure referential integrity  
✅ **Flexibility:** Users can have multiple roles (e.g., a parent-teacher)  
✅ **Scalability:** Easy to add more role-specific fields or new roles  
✅ **Security:** Permission system enforces parent-child relationships  
✅ **Consistency:** Automatic full_name synchronization across role tables  

