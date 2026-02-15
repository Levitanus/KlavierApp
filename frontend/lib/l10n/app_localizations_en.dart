// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Musikschule am Thomas-Mann-Platz';

  @override
  String get languageTitle => 'Language';

  @override
  String get languageGerman => 'German';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageRussian => 'Russian';

  @override
  String get securityTitle => 'Security';

  @override
  String get changePasswordTitle => 'Change Password';

  @override
  String get changePasswordSubtitle => 'Update your account password';

  @override
  String get consentTitle => 'Consent to Personal Data Processing';

  @override
  String get consentAgree => 'Agree';

  @override
  String get consentGuardianConfirm =>
      'If you register a child, you confirm that you are a parent, legal guardian, or otherwise authorized person.';

  @override
  String get consentRequired => 'Please accept the consent to continue';

  @override
  String get consentFallback =>
      'Consent (short)\n- Music learning content only.\n- You can edit or delete your profile.\n- Data is protected with TLS.\n- No sharing except email delivery (SendGrid).\nIf registering a child, you confirm you are a parent/guardian or authorized.';

  @override
  String get commonSettings => 'Settings';

  @override
  String get commonOpen => 'Open';

  @override
  String get commonPost => 'Post';

  @override
  String get commonEdit => 'Edit';

  @override
  String get commonReply => 'Reply';

  @override
  String get commonDelete => 'Delete';

  @override
  String get commonAdd => 'Add';

  @override
  String get commonSave => 'Save';

  @override
  String get commonCancel => 'Cancel';

  @override
  String get commonRefresh => 'Refresh';

  @override
  String get commonClose => 'Close';

  @override
  String get commonDownload => 'Download';

  @override
  String get commonDownloadSourceFile => 'Download source file';

  @override
  String get commonDownloadStarted => 'Download started';

  @override
  String get commonDownloadFailed => 'Download failed';

  @override
  String commonSavedToPath(Object path) {
    return 'Saved to $path';
  }

  @override
  String get commonBack5s => 'Back 5s';

  @override
  String get commonForward5s => 'Forward 5s';

  @override
  String get commonBold => 'Bold';

  @override
  String get commonItalic => 'Italic';

  @override
  String get commonUnderline => 'Underline';

  @override
  String get commonStrike => 'Strike';

  @override
  String get commonSubscript => 'Sub';

  @override
  String get commonSuperscript => 'Super';

  @override
  String get commonTitle => 'Title';

  @override
  String get commonSend => 'Send';

  @override
  String get commonApply => 'Apply';

  @override
  String get commonInsertLink => 'Insert link';

  @override
  String get commonUrl => 'URL';

  @override
  String get commonAttachFile => 'Attach file';

  @override
  String get commonAudio => 'Audio';

  @override
  String get commonVideo => 'Video';

  @override
  String get commonImage => 'Image';

  @override
  String get commonFile => 'File';

  @override
  String get commonVoiceMessage => 'Voice message';

  @override
  String get commonTapToPlay => 'Tap to play';

  @override
  String get commonLoading => 'Loading';

  @override
  String get commonFullscreen => 'Fullscreen';

  @override
  String get commonExitFullscreen => 'Exit fullscreen';

  @override
  String get commonPrevious => 'Previous page';

  @override
  String get commonNext => 'Next page';

  @override
  String get commonClearSearch => 'Clear search';

  @override
  String get commonNoResults => 'No results found';

  @override
  String get commonTypeToFilter => 'Type to filter...';

  @override
  String get commonRequired => 'Required';

  @override
  String commonErrorMessage(Object error) {
    return 'Error: $error';
  }

  @override
  String get commonCreated => 'created';

  @override
  String get commonUpdated => 'updated';

  @override
  String get commonCreate => 'create';

  @override
  String get commonUpdate => 'update';

  @override
  String commonVideoLabel(Object filename) {
    return 'Video: $filename';
  }

  @override
  String get feedsTitle => 'Feeds';

  @override
  String get feedsNone => 'No feeds available';

  @override
  String get feedsSchool => 'School';

  @override
  String get feedsTeacherFeeds => 'Teacher feeds';

  @override
  String get feedsOwnerSchool => 'School';

  @override
  String get feedsOwnerTeacher => 'Teacher';

  @override
  String get feedsNewPostTooltip => 'New post';

  @override
  String get feedsMarkAllRead => 'Mark all as read';

  @override
  String get feedsImportant => 'Important';

  @override
  String get feedsLatest => 'Latest';

  @override
  String get feedsNoImportantPosts => 'No important posts yet.';

  @override
  String get feedsAllPosts => 'All posts';

  @override
  String get feedsNoPosts => 'No posts yet.';

  @override
  String feedsPostedAt(Object timestamp) {
    return 'Posted $timestamp';
  }

  @override
  String feedsPostedEditedAt(Object timestamp) {
    return 'Posted $timestamp · edited';
  }

  @override
  String get feedsSubscriptionFailed => 'Failed to update subscription';

  @override
  String get feedsDeleteDenied =>
      'You do not have permission to delete this post';

  @override
  String get feedsDeleteTitle => 'Delete Post';

  @override
  String get feedsDeleteMessage =>
      'Are you sure you want to delete this post? This action cannot be undone.';

  @override
  String get feedsDeleteFailed => 'Failed to delete post';

  @override
  String feedsUnsupportedAttachment(Object type) {
    return 'Unsupported attachment: $type';
  }

  @override
  String get feedsAttachmentActions => 'Attachment actions';

  @override
  String get feedsEditPost => 'Edit post';

  @override
  String get feedsNewPost => 'New post';

  @override
  String get feedsTextTools => 'Text tools';

  @override
  String get feedsTextFormatting => 'Text formatting';

  @override
  String get feedsJustificationTools => 'Justification tools';

  @override
  String get feedsListsPaddingTools => 'Lists and padding tools';

  @override
  String get feedsAttachments => 'Attachments';

  @override
  String get feedsAllowComments => 'Allow comments';

  @override
  String get feedsMarkImportant => 'Mark as important';

  @override
  String get feedsUploadFailed => 'Failed to upload media';

  @override
  String get feedsEditComment => 'Edit comment';

  @override
  String get feedsNewComment => 'New comment';

  @override
  String get feedsComments => 'Comments';

  @override
  String get feedsNoComments => 'No comments yet.';

  @override
  String get feedsAddComment => 'Add Comment';

  @override
  String get feedsSubscribeComments => 'Subscribe to comments';

  @override
  String get feedsUnsubscribeComments => 'Unsubscribe from comments';

  @override
  String feedsAttachmentInline(Object typeLabel) {
    return '$typeLabel (inline)';
  }

  @override
  String get feedsSettingsTitle => 'Feed settings';

  @override
  String get feedsAllowStudentPosts => 'Allow student posts';

  @override
  String get feedsAutoSubscribe => 'Auto-subscribe to new posts';

  @override
  String get feedsNotifyNewPosts => 'Notify on new posts';

  @override
  String get feedsParagraphType => 'Paragraph type';

  @override
  String get feedsFont => 'Font';

  @override
  String get feedsSize => 'Size';

  @override
  String get feedsAttach => 'Attach';

  @override
  String get feedsPostTitle => 'Post';

  @override
  String feedsUnsupportedEmbed(Object data) {
    return 'Unsupported embed: $data';
  }

  @override
  String get feedsUntitledPost => 'Untitled post';

  @override
  String get videoWebLimited =>
      'Web video player is limited. You can download the file or open it separately.';

  @override
  String get videoErrorTitle => 'Video Error';

  @override
  String get videoLoadFailed => 'Failed to load video';

  @override
  String get voiceRecordFailed => 'Failed to record audio';

  @override
  String get voiceRecordUnavailable => 'Voice recording not available';

  @override
  String voiceRecordError(Object error) {
    return 'Voice error: $error';
  }

  @override
  String get voiceStopRecording => 'Stop recording';

  @override
  String get voiceRecord => 'Record voice';

  @override
  String get hometasksChecklistUpdateFailed =>
      'Failed to update checklist item.';

  @override
  String get hometasksItemsSaved => 'Items saved successfully.';

  @override
  String get hometasksItemsSaveFailed => 'Failed to save items.';

  @override
  String get hometasksProgressUpdateFailed => 'Failed to update progress item.';

  @override
  String get hometasksUpdateFailed => 'Failed to update hometask.';

  @override
  String hometasksTeacherFallback(Object teacherId) {
    return 'Teacher #$teacherId';
  }

  @override
  String get hometasksItemNameRequired => 'All items must have a name.';

  @override
  String hometasksDueLabel(Object date) {
    return 'Due: $date';
  }

  @override
  String get hometasksEditItems => 'Edit items';

  @override
  String get hometasksMarkCompleted => 'Mark completed';

  @override
  String get hometasksMarkAccomplished => 'Mark accomplished';

  @override
  String get hometasksReturnActive => 'Return to active';

  @override
  String get hometasksMarkUncompleted => 'Mark uncompleted';

  @override
  String get hometasksProgressNotStarted => 'Not started';

  @override
  String get hometasksProgressInProgress => 'In progress';

  @override
  String get hometasksProgressNearlyDone => 'Nearly done';

  @override
  String get hometasksProgressAlmostComplete => 'Almost complete';

  @override
  String get hometasksProgressComplete => 'Complete';

  @override
  String hometasksItemHint(Object index) {
    return 'Item $index';
  }

  @override
  String get hometasksAddItem => 'Add item';

  @override
  String get notificationsTitle => 'Notifications';

  @override
  String get notificationsUnread => 'Unread';

  @override
  String get notificationsNone => 'No notifications';

  @override
  String get chatNoTeachers => 'No teachers found';

  @override
  String get chatSelectTeacher => 'Select Teacher';

  @override
  String get chatStartFailed => 'Failed to start chat';

  @override
  String get chatAdminOpenFailed => 'Failed to open admin chat';

  @override
  String get chatMessages => 'Messages';

  @override
  String get chatChats => 'Chats';

  @override
  String get chatAdmin => 'Admin';

  @override
  String get chatNoConversations => 'No conversations yet';

  @override
  String get chatStartConversation => 'Start a conversation';

  @override
  String get chatAdministration => 'Administration';

  @override
  String get chatUnknownUser => 'Unknown';

  @override
  String get chatNoMessages => '(No messages)';

  @override
  String get chatTeachers => 'Teachers';

  @override
  String get chatNewChat => 'New Chat';

  @override
  String get chatThreadNotFound => 'Chat created, but thread not found';

  @override
  String get chatStartNew => 'Start New Chat';

  @override
  String get chatSearchUsers => 'Search users...';

  @override
  String get profileAdminControls => 'Admin Controls';

  @override
  String get profileAdminAccess => 'Admin Access';

  @override
  String get profileAdminAccessSubtitle => 'Grant or revoke admin permissions';

  @override
  String get profileAdminAccessUpdate => 'Update Admin Access';

  @override
  String get profileRoleManagement => 'Role Management';

  @override
  String get profileMakeStudent => 'Make Student';

  @override
  String get profileMakeParent => 'Make Parent';

  @override
  String get profileMakeTeacher => 'Make Teacher';

  @override
  String get profileArchiveRoles => 'Archive Roles';

  @override
  String get profileSectionInfo => 'Profile Information';

  @override
  String get profileSectionAdditional => 'Additional Information';

  @override
  String get profileTitleProfile => 'Profile';

  @override
  String get profileTitleUserProfile => 'User Profile';

  @override
  String get profileEditTooltip => 'Edit Profile';

  @override
  String get profileAdminViewLabel => 'Admin View';

  @override
  String get profileEmailLabel => 'Email';

  @override
  String get profilePhoneLabel => 'Phone';

  @override
  String get profileMemberSinceLabel => 'Member Since';

  @override
  String get profileNotSet => 'Not set';

  @override
  String get profileUnknown => 'Unknown';

  @override
  String get profileRolesTitle => 'Roles';

  @override
  String get profileBirthdayLabel => 'Birthday';

  @override
  String get profileBirthdayInputLabel => 'Birthday (YYYY-MM-DD)';

  @override
  String get profileGenerateParentLink => 'Generate Parent Registration Link';

  @override
  String get profileMyChildrenTitle => 'My Children';

  @override
  String get profileChildrenSubtitle =>
      'Tap on a child to view or edit their information';

  @override
  String get profileActionMessage => 'Message';

  @override
  String get profileManageStudentsTitle => 'Manage Students';

  @override
  String get profileActionAddStudent => 'Add Student';

  @override
  String get profileManageStudentsSubtitle => 'Manage students assigned to you';

  @override
  String get profileNoStudentsAssigned => 'No students assigned yet';

  @override
  String get profileActionViewProfile => 'View Profile';

  @override
  String get profileActionAssignHometask => 'Assign Hometask';

  @override
  String get profileActionRemoveStudent => 'Remove from Students';

  @override
  String get profileGenerateStudentLink => 'Generate Student Registration Link';

  @override
  String get profileTeachersTitle => 'Teachers';

  @override
  String get profileTeachersSubtitle =>
      'Tap to view teacher profile or leave teacher';

  @override
  String get profileNoTeachersAssigned => 'No teachers assigned yet';

  @override
  String get profileActionLeaveTeacher => 'Leave Teacher';

  @override
  String get profileArchiveStudent => 'Archive Student';

  @override
  String get profileUnarchiveStudent => 'Unarchive Student';

  @override
  String get profileArchiveParent => 'Archive Parent';

  @override
  String get profileUnarchiveParent => 'Unarchive Parent';

  @override
  String get profileArchiveTeacher => 'Archive Teacher';

  @override
  String get profileUnarchiveTeacher => 'Unarchive Teacher';

  @override
  String get profileParentTools => 'Parent Tools';

  @override
  String get profileAddChildren => 'Add Children';

  @override
  String get adminPanelTitle => 'Admin Panel';

  @override
  String get adminUserManagement => 'User Management';

  @override
  String get adminSearchUsers => 'Search by username or full name';

  @override
  String get adminNoUsers => 'No users found';

  @override
  String get adminAddUser => 'Add User';

  @override
  String get adminUser => 'User';

  @override
  String get adminStudent => 'Student';

  @override
  String get adminParent => 'Parent';

  @override
  String get adminTeacher => 'Teacher';

  @override
  String get adminAddStudent => 'Add Student';

  @override
  String get adminAddParent => 'Add Parent';

  @override
  String get adminAddTeacher => 'Add Teacher';

  @override
  String adminShowingRange(Object start, Object end, Object total) {
    return 'Showing $start-$end of $total';
  }

  @override
  String get adminRows => 'Rows:';

  @override
  String get adminResetLink => 'Reset Link';

  @override
  String get adminViewProfile => 'View Profile';

  @override
  String get adminEditUser => 'Edit User';

  @override
  String get adminDeleteUser => 'Delete User';

  @override
  String get adminFullName => 'Full Name';

  @override
  String get adminUsername => 'Username';

  @override
  String get adminActions => 'Actions';

  @override
  String get adminLoadUsersFailed => 'Failed to load users';

  @override
  String adminUserSaved(Object action) {
    return 'User $action successfully';
  }

  @override
  String adminUserSaveFailed(Object action) {
    return 'Failed to $action user';
  }

  @override
  String get adminResetLinkGenerated => 'Reset Link Generated';

  @override
  String adminResetLinkFor(Object username) {
    return 'Reset link for $username:';
  }

  @override
  String adminResetLinkExpires(Object expires) {
    return 'Expires: $expires';
  }

  @override
  String get adminCopyLink => 'Copy Link';

  @override
  String get adminResetLinkCopied => 'Reset link copied to clipboard';

  @override
  String get adminResetLinkFailed => 'Failed to generate reset link';

  @override
  String adminUserDeleted(Object username) {
    return 'User $username deleted';
  }

  @override
  String get adminDeleteUserFailed => 'Failed to delete user';

  @override
  String get adminConvertedStudent => 'User converted to student';

  @override
  String get adminConvertedParent => 'User converted to parent';

  @override
  String get adminConvertedTeacher => 'User converted to teacher';

  @override
  String get adminStudentCreated => 'Student created successfully';

  @override
  String get adminParentCreated => 'Parent created successfully';

  @override
  String get adminTeacherCreated => 'Teacher created successfully';

  @override
  String get adminDeleteUserTitle => 'Delete User';

  @override
  String adminDeleteUserMessage(Object username) {
    return 'Delete $username? This cannot be undone.';
  }

  @override
  String get adminUsernameRequired => 'Please enter a username';

  @override
  String get adminFullNameRequired => 'Please enter a full name';

  @override
  String get adminPassword => 'Password';

  @override
  String get adminNewPasswordOptional => 'New Password (optional)';

  @override
  String get adminPasswordRequired => 'Please enter a password';

  @override
  String get adminGeneratePassword => 'Generate Password';

  @override
  String get adminEmailOptional => 'Email (optional)';

  @override
  String get adminPhoneOptional => 'Phone (optional)';

  @override
  String get adminRoleAdmin => 'Admin';

  @override
  String get adminConvertRole => 'Convert to Role:';

  @override
  String get adminCopyCredentials => 'Copy Credentials';

  @override
  String get adminCredentialsRequired => 'Fill username and password first';

  @override
  String get adminCredentialsCopied => 'Credentials copied';

  @override
  String adminMakeStudentTitle(Object username) {
    return 'Make $username a Student';
  }

  @override
  String adminMakeParentTitle(Object username) {
    return 'Make $username a Parent';
  }

  @override
  String adminMakeTeacherTitle(Object username) {
    return 'Make $username a Teacher';
  }

  @override
  String get adminMakeTeacherNote =>
      'This will grant teacher privileges to the user.';

  @override
  String get adminBirthdayLabel => 'Birthday (YYYY-MM-DD)';

  @override
  String get adminBirthdayHint => '2010-01-15';

  @override
  String get adminBirthdayFormat => 'Format: YYYY-MM-DD';

  @override
  String get adminConvert => 'Convert';

  @override
  String get adminSelectStudentsLabel => 'Select Students (at least one):';

  @override
  String get adminSelectChildrenLabel => 'Select Children (at least one):';

  @override
  String get adminSearchStudents => 'Search students';

  @override
  String get adminNoStudents => 'No students found';

  @override
  String get adminSelectStudentRequired => 'At least one student required';

  @override
  String get dashboardNoStudents => 'No students available.';

  @override
  String get dashboardTitle => 'Dashboard';

  @override
  String get dashboardTeacherFeeds => 'Teacher feeds';

  @override
  String get dashboardNoTeacherFeeds => 'No teacher feeds yet.';

  @override
  String get dashboardSchoolFeed => 'School feed';

  @override
  String get dashboardNoSchoolFeed => 'No school feed yet.';

  @override
  String get dashboardOwnerSchool => 'School';

  @override
  String get dashboardOwnerTeacher => 'Teacher';

  @override
  String get dashboardStudentLabel => 'Student:';

  @override
  String get dashboardNoActiveHometasks => 'No active hometasks.';

  @override
  String get homeClearAppCacheTitle => 'Clear app data cache';

  @override
  String get homeClearAppCacheBody =>
      'This will remove cached messages, feeds, hometasks, and profile data.';

  @override
  String get homeAppCacheCleared => 'App data cache cleared.';

  @override
  String get homeClearMediaCacheTitle => 'Clear media cache';

  @override
  String get homeClearMediaCacheBody =>
      'This will remove cached images and media files.';

  @override
  String get homeMediaCacheCleared => 'Media cache cleared.';

  @override
  String get homeLogoutTitle => 'Logout';

  @override
  String get homeLogoutBody => 'Are you sure you want to logout?';

  @override
  String get homeMenuTooltip => 'Menu';

  @override
  String homeRolesLabel(Object roles) {
    return 'Roles: $roles';
  }

  @override
  String get homeProfileInfo => 'Your profile information';

  @override
  String get commonClear => 'Clear';

  @override
  String get commonLogout => 'Logout';

  @override
  String get commonNotifications => 'Notifications';

  @override
  String get commonProfile => 'Profile';

  @override
  String get commonUserManagement => 'User Management';

  @override
  String get commonTheme => 'Theme';

  @override
  String get commonSystem => 'System';

  @override
  String get commonLight => 'Light';

  @override
  String get commonDark => 'Dark';

  @override
  String get commonDashboard => 'Dashboard';

  @override
  String get commonHometasks => 'Hometasks';

  @override
  String get commonFeeds => 'Feeds';

  @override
  String get commonChats => 'Chats';

  @override
  String get commonUsername => 'Username';

  @override
  String get commonPassword => 'Password';

  @override
  String get commonFullName => 'Full Name';

  @override
  String get commonEmailOptional => 'Email (optional)';

  @override
  String get commonPhoneOptional => 'Phone (optional)';

  @override
  String get commonConfirmPassword => 'Confirm Password';

  @override
  String get commonBackToLogin => 'Back to Login';

  @override
  String get commonOk => 'OK';

  @override
  String get commonErrorTitle => 'Error';

  @override
  String get registerRoleStudent => 'Student';

  @override
  String get registerRoleParent => 'Parent';

  @override
  String get registerRoleTeacher => 'Teacher';

  @override
  String get registerInvalidTokenTitle => 'Invalid Registration Token';

  @override
  String get registerInvalidTokenMessage =>
      'This registration link may be expired or already used.';

  @override
  String get registerGoToLogin => 'Go to Login';

  @override
  String registerTitle(Object role) {
    return 'Register as $role';
  }

  @override
  String get registerParentOf => 'You will be registered as parent of:';

  @override
  String get registerComplete => 'Complete your registration';

  @override
  String get registerUsernameRequired => 'Please enter a username';

  @override
  String get registerUsernameMin => 'Username must be at least 3 characters';

  @override
  String get registerFullNameRequired => 'Please enter your full name';

  @override
  String get registerBirthdayLabel => 'Birthday (YYYY-MM-DD)';

  @override
  String get registerBirthdayHint => '2010-01-31';

  @override
  String get registerBirthdayRequired => 'Please enter your birthday';

  @override
  String get registerBirthdayFormat => 'Use format: YYYY-MM-DD';

  @override
  String get registerPasswordRequired => 'Please enter a password';

  @override
  String get registerPasswordMin => 'Password must be at least 6 characters';

  @override
  String get registerConfirmRequired => 'Please confirm your password';

  @override
  String get registerPasswordsMismatch => 'Passwords do not match';

  @override
  String get registerButton => 'Register';

  @override
  String get registerLoginFailed => 'Login failed';

  @override
  String get registerFailed => 'Registration failed';

  @override
  String registerNetworkError(Object error) {
    return 'Network error: $error';
  }

  @override
  String get registerValidateFailed => 'Failed to validate token';

  @override
  String resetErrorValidating(Object error) {
    return 'Error validating token: $error';
  }

  @override
  String get resetSuccessTitle => 'Success';

  @override
  String get resetSuccessMessage =>
      'Your password has been reset successfully. You can now log in with your new password.';

  @override
  String get resetFailed => 'Failed to reset password';

  @override
  String resetErrorGeneric(Object error) {
    return 'Error: $error';
  }

  @override
  String get resetTitle => 'Reset Password';

  @override
  String get resetValidating => 'Validating reset token...';

  @override
  String get resetInvalidTitle => 'Invalid or Expired Link';

  @override
  String get resetInvalidMessage =>
      'This password reset link is invalid or has expired. Please request a new password reset link.';

  @override
  String get resetSetNewPassword => 'Set New Password';

  @override
  String resetForUser(Object username) {
    return 'for user: $username';
  }

  @override
  String get resetNewPasswordLabel => 'New Password';

  @override
  String get resetPasswordRequired => 'Please enter a password';

  @override
  String get resetPasswordMin => 'Password must be at least 6 characters';

  @override
  String get resetConfirmPasswordLabel => 'Confirm Password';

  @override
  String get resetConfirmRequired => 'Please confirm your password';

  @override
  String get loginTitle => 'Login';

  @override
  String get loginForgotTitle => 'Forgot Password';

  @override
  String get loginForgotPrompt =>
      'Enter your username to request a password reset.';

  @override
  String get loginUsernameRequired => 'Please enter your username';

  @override
  String get loginPasswordRequired => 'Please enter your password';

  @override
  String get loginButton => 'Login';

  @override
  String get loginForgotPassword => 'Forgot Password?';

  @override
  String get loginRequestSentTitle => 'Request Sent';

  @override
  String get loginRequestSentMessage =>
      'Password reset request sent successfully.';

  @override
  String get loginRequestFailedMessage =>
      'Failed to send password reset request. Please try again.';

  @override
  String loginErrorMessage(Object error) {
    return 'An error occurred: $error';
  }

  @override
  String get loginFailed => 'Login failed';

  @override
  String get commonRetry => 'Retry';

  @override
  String get hometasksNone => 'No hometasks found.';

  @override
  String get hometasksUpdateOrderFailed => 'Failed to update order.';

  @override
  String hometasksAssignTitle(Object studentName) {
    return 'Assign Hometask to $studentName';
  }

  @override
  String get hometasksTitleLabel => 'Title';

  @override
  String get hometasksTitleRequired => 'Title is required';

  @override
  String get hometasksDescriptionLabel => 'Description (optional)';

  @override
  String get hometasksDueDate => 'Due date';

  @override
  String get hometasksNoDueDate => 'No due date';

  @override
  String get hometasksRepeatLabel => 'Repeat';

  @override
  String get hometasksRepeatNone => 'No repeat';

  @override
  String get hometasksRepeatDaily => 'Each day';

  @override
  String get hometasksRepeatWeekly => 'Each week';

  @override
  String get hometasksRepeatCustom => 'Custom interval';

  @override
  String get hometasksRepeatEveryDays => 'Repeat every (days)';

  @override
  String get hometasksRepeatCustomInvalid => 'Enter a positive number of days';

  @override
  String get hometasksTypeLabel => 'Hometask type';

  @override
  String get hometasksTypeSimple => 'Simple';

  @override
  String get hometasksTypeChecklist => 'Checklist';

  @override
  String get hometasksTypeProgress => 'Progress';

  @override
  String get hometasksChecklistItems => 'Checklist items';

  @override
  String get hometasksProgressItems => 'Progress items';

  @override
  String hometasksItemLabel(Object index) {
    return 'Item $index';
  }

  @override
  String get hometasksRequired => 'Required';

  @override
  String hometasksAddAtLeastOne(Object typeLabel) {
    return 'Add at least one $typeLabel item.';
  }

  @override
  String get hometasksRepeatIntervalInvalid => 'Enter a valid repeat interval.';

  @override
  String get hometasksAssigned => 'Hometask assigned.';

  @override
  String get hometasksAssignFailed => 'Failed to assign hometask.';

  @override
  String get hometasksAssignAction => 'Assign';

  @override
  String get hometasksActive => 'Active';

  @override
  String get hometasksArchive => 'Archive';

  @override
  String get hometasksAssign => 'Assign Hometask';
}
