import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_de.dart';
import 'app_localizations_en.dart';
import 'app_localizations_ru.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('de'),
    Locale('en'),
    Locale('ru'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Musikschule am Thomas-Mann-Platz'**
  String get appTitle;

  /// No description provided for @languageTitle.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get languageTitle;

  /// No description provided for @languageGerman.
  ///
  /// In en, this message translates to:
  /// **'German'**
  String get languageGerman;

  /// No description provided for @languageEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// No description provided for @languageRussian.
  ///
  /// In en, this message translates to:
  /// **'Russian'**
  String get languageRussian;

  /// No description provided for @securityTitle.
  ///
  /// In en, this message translates to:
  /// **'Security'**
  String get securityTitle;

  /// No description provided for @changePasswordTitle.
  ///
  /// In en, this message translates to:
  /// **'Change Password'**
  String get changePasswordTitle;

  /// No description provided for @changePasswordSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Update your account password'**
  String get changePasswordSubtitle;

  /// No description provided for @consentTitle.
  ///
  /// In en, this message translates to:
  /// **'Consent to Personal Data Processing'**
  String get consentTitle;

  /// No description provided for @consentAgree.
  ///
  /// In en, this message translates to:
  /// **'Agree'**
  String get consentAgree;

  /// No description provided for @consentGuardianConfirm.
  ///
  /// In en, this message translates to:
  /// **'If you register a child, you confirm that you are a parent, legal guardian, or otherwise authorized person.'**
  String get consentGuardianConfirm;

  /// No description provided for @consentRequired.
  ///
  /// In en, this message translates to:
  /// **'Please accept the consent to continue'**
  String get consentRequired;

  /// No description provided for @consentFallback.
  ///
  /// In en, this message translates to:
  /// **'Consent (short)\n- Music learning content only.\n- You can edit or delete your profile.\n- Data is protected with TLS.\n- No sharing except email delivery (SendGrid).\nIf registering a child, you confirm you are a parent/guardian or authorized.'**
  String get consentFallback;

  /// No description provided for @commonSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get commonSettings;

  /// No description provided for @commonOpen.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get commonOpen;

  /// No description provided for @commonPost.
  ///
  /// In en, this message translates to:
  /// **'Post'**
  String get commonPost;

  /// No description provided for @commonEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get commonEdit;

  /// No description provided for @commonReply.
  ///
  /// In en, this message translates to:
  /// **'Reply'**
  String get commonReply;

  /// No description provided for @commonDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get commonDelete;

  /// No description provided for @commonAdd.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get commonAdd;

  /// No description provided for @commonSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get commonSave;

  /// No description provided for @commonCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get commonCancel;

  /// No description provided for @commonRefresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get commonRefresh;

  /// No description provided for @commonClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get commonClose;

  /// No description provided for @commonDownload.
  ///
  /// In en, this message translates to:
  /// **'Download'**
  String get commonDownload;

  /// No description provided for @commonDownloadSourceFile.
  ///
  /// In en, this message translates to:
  /// **'Download source file'**
  String get commonDownloadSourceFile;

  /// No description provided for @commonDownloadStarted.
  ///
  /// In en, this message translates to:
  /// **'Download started'**
  String get commonDownloadStarted;

  /// No description provided for @commonDownloadFailed.
  ///
  /// In en, this message translates to:
  /// **'Download failed'**
  String get commonDownloadFailed;

  /// No description provided for @commonSavedToPath.
  ///
  /// In en, this message translates to:
  /// **'Saved to {path}'**
  String commonSavedToPath(Object path);

  /// No description provided for @commonBack5s.
  ///
  /// In en, this message translates to:
  /// **'Back 5s'**
  String get commonBack5s;

  /// No description provided for @commonForward5s.
  ///
  /// In en, this message translates to:
  /// **'Forward 5s'**
  String get commonForward5s;

  /// No description provided for @commonBold.
  ///
  /// In en, this message translates to:
  /// **'Bold'**
  String get commonBold;

  /// No description provided for @commonItalic.
  ///
  /// In en, this message translates to:
  /// **'Italic'**
  String get commonItalic;

  /// No description provided for @commonUnderline.
  ///
  /// In en, this message translates to:
  /// **'Underline'**
  String get commonUnderline;

  /// No description provided for @commonStrike.
  ///
  /// In en, this message translates to:
  /// **'Strike'**
  String get commonStrike;

  /// No description provided for @commonSubscript.
  ///
  /// In en, this message translates to:
  /// **'Sub'**
  String get commonSubscript;

  /// No description provided for @commonSuperscript.
  ///
  /// In en, this message translates to:
  /// **'Super'**
  String get commonSuperscript;

  /// No description provided for @commonTitle.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get commonTitle;

  /// No description provided for @commonSend.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get commonSend;

  /// No description provided for @commonApply.
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get commonApply;

  /// No description provided for @commonInsertLink.
  ///
  /// In en, this message translates to:
  /// **'Insert link'**
  String get commonInsertLink;

  /// No description provided for @commonUrl.
  ///
  /// In en, this message translates to:
  /// **'URL'**
  String get commonUrl;

  /// No description provided for @commonAttachFile.
  ///
  /// In en, this message translates to:
  /// **'Attach file'**
  String get commonAttachFile;

  /// No description provided for @commonAudio.
  ///
  /// In en, this message translates to:
  /// **'Audio'**
  String get commonAudio;

  /// No description provided for @commonVideo.
  ///
  /// In en, this message translates to:
  /// **'Video'**
  String get commonVideo;

  /// No description provided for @commonImage.
  ///
  /// In en, this message translates to:
  /// **'Image'**
  String get commonImage;

  /// No description provided for @commonFile.
  ///
  /// In en, this message translates to:
  /// **'File'**
  String get commonFile;

  /// No description provided for @commonVoiceMessage.
  ///
  /// In en, this message translates to:
  /// **'Voice message'**
  String get commonVoiceMessage;

  /// No description provided for @commonTapToPlay.
  ///
  /// In en, this message translates to:
  /// **'Tap to play'**
  String get commonTapToPlay;

  /// No description provided for @commonLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading'**
  String get commonLoading;

  /// No description provided for @commonFullscreen.
  ///
  /// In en, this message translates to:
  /// **'Fullscreen'**
  String get commonFullscreen;

  /// No description provided for @commonExitFullscreen.
  ///
  /// In en, this message translates to:
  /// **'Exit fullscreen'**
  String get commonExitFullscreen;

  /// No description provided for @commonPrevious.
  ///
  /// In en, this message translates to:
  /// **'Previous page'**
  String get commonPrevious;

  /// No description provided for @commonNext.
  ///
  /// In en, this message translates to:
  /// **'Next page'**
  String get commonNext;

  /// No description provided for @commonClearSearch.
  ///
  /// In en, this message translates to:
  /// **'Clear search'**
  String get commonClearSearch;

  /// No description provided for @commonNoResults.
  ///
  /// In en, this message translates to:
  /// **'No results found'**
  String get commonNoResults;

  /// No description provided for @commonTypeToFilter.
  ///
  /// In en, this message translates to:
  /// **'Type to filter...'**
  String get commonTypeToFilter;

  /// No description provided for @commonRequired.
  ///
  /// In en, this message translates to:
  /// **'Required'**
  String get commonRequired;

  /// No description provided for @commonErrorMessage.
  ///
  /// In en, this message translates to:
  /// **'Error: {error}'**
  String commonErrorMessage(Object error);

  /// No description provided for @commonCreated.
  ///
  /// In en, this message translates to:
  /// **'created'**
  String get commonCreated;

  /// No description provided for @commonUpdated.
  ///
  /// In en, this message translates to:
  /// **'updated'**
  String get commonUpdated;

  /// No description provided for @commonCreate.
  ///
  /// In en, this message translates to:
  /// **'create'**
  String get commonCreate;

  /// No description provided for @commonUpdate.
  ///
  /// In en, this message translates to:
  /// **'update'**
  String get commonUpdate;

  /// No description provided for @commonVideoLabel.
  ///
  /// In en, this message translates to:
  /// **'Video: {filename}'**
  String commonVideoLabel(Object filename);

  /// No description provided for @feedsTitle.
  ///
  /// In en, this message translates to:
  /// **'Feeds'**
  String get feedsTitle;

  /// No description provided for @feedsNone.
  ///
  /// In en, this message translates to:
  /// **'No feeds available'**
  String get feedsNone;

  /// No description provided for @feedsSchool.
  ///
  /// In en, this message translates to:
  /// **'School'**
  String get feedsSchool;

  /// No description provided for @feedsTeacherFeeds.
  ///
  /// In en, this message translates to:
  /// **'Teacher feeds'**
  String get feedsTeacherFeeds;

  /// No description provided for @feedsOwnerSchool.
  ///
  /// In en, this message translates to:
  /// **'School'**
  String get feedsOwnerSchool;

  /// No description provided for @feedsOwnerTeacher.
  ///
  /// In en, this message translates to:
  /// **'Teacher'**
  String get feedsOwnerTeacher;

  /// No description provided for @feedsNewPostTooltip.
  ///
  /// In en, this message translates to:
  /// **'New post'**
  String get feedsNewPostTooltip;

  /// No description provided for @feedsMarkAllRead.
  ///
  /// In en, this message translates to:
  /// **'Mark all as read'**
  String get feedsMarkAllRead;

  /// No description provided for @feedsImportant.
  ///
  /// In en, this message translates to:
  /// **'Important'**
  String get feedsImportant;

  /// No description provided for @feedsLatest.
  ///
  /// In en, this message translates to:
  /// **'Latest'**
  String get feedsLatest;

  /// No description provided for @feedsNoImportantPosts.
  ///
  /// In en, this message translates to:
  /// **'No important posts yet.'**
  String get feedsNoImportantPosts;

  /// No description provided for @feedsAllPosts.
  ///
  /// In en, this message translates to:
  /// **'All posts'**
  String get feedsAllPosts;

  /// No description provided for @feedsNoPosts.
  ///
  /// In en, this message translates to:
  /// **'No posts yet.'**
  String get feedsNoPosts;

  /// No description provided for @feedsPostedAt.
  ///
  /// In en, this message translates to:
  /// **'Posted {timestamp}'**
  String feedsPostedAt(Object timestamp);

  /// No description provided for @feedsPostedEditedAt.
  ///
  /// In en, this message translates to:
  /// **'Posted {timestamp} · edited'**
  String feedsPostedEditedAt(Object timestamp);

  /// No description provided for @feedsSubscriptionFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to update subscription'**
  String get feedsSubscriptionFailed;

  /// No description provided for @feedsDeleteDenied.
  ///
  /// In en, this message translates to:
  /// **'You do not have permission to delete this post'**
  String get feedsDeleteDenied;

  /// No description provided for @feedsDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete Post'**
  String get feedsDeleteTitle;

  /// No description provided for @feedsDeleteMessage.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete this post? This action cannot be undone.'**
  String get feedsDeleteMessage;

  /// No description provided for @feedsDeleteFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to delete post'**
  String get feedsDeleteFailed;

  /// No description provided for @feedsDeleteCommentTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete Comment'**
  String get feedsDeleteCommentTitle;

  /// No description provided for @feedsDeleteCommentMessage.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete this comment? This action cannot be undone.'**
  String get feedsDeleteCommentMessage;

  /// No description provided for @feedsDeleteCommentFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to delete comment'**
  String get feedsDeleteCommentFailed;

  /// No description provided for @feedsUnsupportedAttachment.
  ///
  /// In en, this message translates to:
  /// **'Unsupported attachment: {type}'**
  String feedsUnsupportedAttachment(Object type);

  /// No description provided for @feedsAttachmentActions.
  ///
  /// In en, this message translates to:
  /// **'Attachment actions'**
  String get feedsAttachmentActions;

  /// No description provided for @feedsCommentActions.
  ///
  /// In en, this message translates to:
  /// **'Comment actions'**
  String get feedsCommentActions;

  /// No description provided for @feedsEditPost.
  ///
  /// In en, this message translates to:
  /// **'Edit post'**
  String get feedsEditPost;

  /// No description provided for @feedsNewPost.
  ///
  /// In en, this message translates to:
  /// **'New post'**
  String get feedsNewPost;

  /// No description provided for @feedsTextTools.
  ///
  /// In en, this message translates to:
  /// **'Text tools'**
  String get feedsTextTools;

  /// No description provided for @feedsTextFormatting.
  ///
  /// In en, this message translates to:
  /// **'Text formatting'**
  String get feedsTextFormatting;

  /// No description provided for @feedsJustificationTools.
  ///
  /// In en, this message translates to:
  /// **'Justification tools'**
  String get feedsJustificationTools;

  /// No description provided for @feedsListsPaddingTools.
  ///
  /// In en, this message translates to:
  /// **'Lists and padding tools'**
  String get feedsListsPaddingTools;

  /// No description provided for @feedsAttachments.
  ///
  /// In en, this message translates to:
  /// **'Attachments'**
  String get feedsAttachments;

  /// No description provided for @feedsAllowComments.
  ///
  /// In en, this message translates to:
  /// **'Allow comments'**
  String get feedsAllowComments;

  /// No description provided for @feedsMarkImportant.
  ///
  /// In en, this message translates to:
  /// **'Mark as important'**
  String get feedsMarkImportant;

  /// No description provided for @feedsUploadFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to upload media'**
  String get feedsUploadFailed;

  /// No description provided for @feedsEditComment.
  ///
  /// In en, this message translates to:
  /// **'Edit comment'**
  String get feedsEditComment;

  /// No description provided for @feedsNewComment.
  ///
  /// In en, this message translates to:
  /// **'New comment'**
  String get feedsNewComment;

  /// No description provided for @feedsComments.
  ///
  /// In en, this message translates to:
  /// **'Comments'**
  String get feedsComments;

  /// No description provided for @feedsNoComments.
  ///
  /// In en, this message translates to:
  /// **'No comments yet.'**
  String get feedsNoComments;

  /// No description provided for @feedsAddComment.
  ///
  /// In en, this message translates to:
  /// **'Add Comment'**
  String get feedsAddComment;

  /// No description provided for @feedsSubscribeComments.
  ///
  /// In en, this message translates to:
  /// **'Subscribe to comments'**
  String get feedsSubscribeComments;

  /// No description provided for @feedsUnsubscribeComments.
  ///
  /// In en, this message translates to:
  /// **'Unsubscribe from comments'**
  String get feedsUnsubscribeComments;

  /// No description provided for @feedsAttachmentInline.
  ///
  /// In en, this message translates to:
  /// **'{typeLabel} (inline)'**
  String feedsAttachmentInline(Object typeLabel);

  /// No description provided for @feedsSettingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Feed settings'**
  String get feedsSettingsTitle;

  /// No description provided for @feedsAllowStudentPosts.
  ///
  /// In en, this message translates to:
  /// **'Allow student posts'**
  String get feedsAllowStudentPosts;

  /// No description provided for @feedsAutoSubscribe.
  ///
  /// In en, this message translates to:
  /// **'Auto-subscribe to new posts'**
  String get feedsAutoSubscribe;

  /// No description provided for @feedsNotifyNewPosts.
  ///
  /// In en, this message translates to:
  /// **'Notify on new posts'**
  String get feedsNotifyNewPosts;

  /// No description provided for @feedsParagraphType.
  ///
  /// In en, this message translates to:
  /// **'Paragraph type'**
  String get feedsParagraphType;

  /// No description provided for @feedsFont.
  ///
  /// In en, this message translates to:
  /// **'Font'**
  String get feedsFont;

  /// No description provided for @feedsSize.
  ///
  /// In en, this message translates to:
  /// **'Size'**
  String get feedsSize;

  /// No description provided for @feedsAttach.
  ///
  /// In en, this message translates to:
  /// **'Attach'**
  String get feedsAttach;

  /// No description provided for @feedsPostTitle.
  ///
  /// In en, this message translates to:
  /// **'Post'**
  String get feedsPostTitle;

  /// No description provided for @feedsUnsupportedEmbed.
  ///
  /// In en, this message translates to:
  /// **'Unsupported embed: {data}'**
  String feedsUnsupportedEmbed(Object data);

  /// No description provided for @feedsUntitledPost.
  ///
  /// In en, this message translates to:
  /// **'Untitled post'**
  String get feedsUntitledPost;

  /// No description provided for @videoWebLimited.
  ///
  /// In en, this message translates to:
  /// **'Web video player is limited. You can download the file or open it separately.'**
  String get videoWebLimited;

  /// No description provided for @videoErrorTitle.
  ///
  /// In en, this message translates to:
  /// **'Video Error'**
  String get videoErrorTitle;

  /// No description provided for @videoLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to load video'**
  String get videoLoadFailed;

  /// No description provided for @voiceRecordFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to record audio'**
  String get voiceRecordFailed;

  /// No description provided for @voiceRecordUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Voice recording not available'**
  String get voiceRecordUnavailable;

  /// No description provided for @voiceRecordError.
  ///
  /// In en, this message translates to:
  /// **'Voice error: {error}'**
  String voiceRecordError(Object error);

  /// No description provided for @voiceStopRecording.
  ///
  /// In en, this message translates to:
  /// **'Stop recording'**
  String get voiceStopRecording;

  /// No description provided for @voiceRecord.
  ///
  /// In en, this message translates to:
  /// **'Record voice'**
  String get voiceRecord;

  /// No description provided for @hometasksChecklistUpdateFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to update checklist item.'**
  String get hometasksChecklistUpdateFailed;

  /// No description provided for @hometasksItemsSaved.
  ///
  /// In en, this message translates to:
  /// **'Items saved successfully.'**
  String get hometasksItemsSaved;

  /// No description provided for @hometasksItemsSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to save items.'**
  String get hometasksItemsSaveFailed;

  /// No description provided for @hometasksProgressUpdateFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to update progress item.'**
  String get hometasksProgressUpdateFailed;

  /// No description provided for @hometasksUpdateFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to update hometask.'**
  String get hometasksUpdateFailed;

  /// No description provided for @hometasksTeacherFallback.
  ///
  /// In en, this message translates to:
  /// **'Teacher #{teacherId}'**
  String hometasksTeacherFallback(Object teacherId);

  /// No description provided for @hometasksItemNameRequired.
  ///
  /// In en, this message translates to:
  /// **'All items must have a name.'**
  String get hometasksItemNameRequired;

  /// No description provided for @hometasksDueLabel.
  ///
  /// In en, this message translates to:
  /// **'Due: {date}'**
  String hometasksDueLabel(Object date);

  /// No description provided for @hometasksEditItems.
  ///
  /// In en, this message translates to:
  /// **'Edit items'**
  String get hometasksEditItems;

  /// No description provided for @hometasksMarkCompleted.
  ///
  /// In en, this message translates to:
  /// **'Mark completed'**
  String get hometasksMarkCompleted;

  /// No description provided for @hometasksMarkAccomplished.
  ///
  /// In en, this message translates to:
  /// **'Mark accomplished'**
  String get hometasksMarkAccomplished;

  /// No description provided for @hometasksReturnActive.
  ///
  /// In en, this message translates to:
  /// **'Return to active'**
  String get hometasksReturnActive;

  /// No description provided for @hometasksMarkUncompleted.
  ///
  /// In en, this message translates to:
  /// **'Mark uncompleted'**
  String get hometasksMarkUncompleted;

  /// No description provided for @hometasksProgressNotStarted.
  ///
  /// In en, this message translates to:
  /// **'Not started'**
  String get hometasksProgressNotStarted;

  /// No description provided for @hometasksProgressInProgress.
  ///
  /// In en, this message translates to:
  /// **'In progress'**
  String get hometasksProgressInProgress;

  /// No description provided for @hometasksProgressNearlyDone.
  ///
  /// In en, this message translates to:
  /// **'Nearly done'**
  String get hometasksProgressNearlyDone;

  /// No description provided for @hometasksProgressAlmostComplete.
  ///
  /// In en, this message translates to:
  /// **'Almost complete'**
  String get hometasksProgressAlmostComplete;

  /// No description provided for @hometasksProgressComplete.
  ///
  /// In en, this message translates to:
  /// **'Complete'**
  String get hometasksProgressComplete;

  /// No description provided for @hometasksItemHint.
  ///
  /// In en, this message translates to:
  /// **'Item {index}'**
  String hometasksItemHint(Object index);

  /// No description provided for @hometasksAddItem.
  ///
  /// In en, this message translates to:
  /// **'Add item'**
  String get hometasksAddItem;

  /// No description provided for @notificationsTitle.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notificationsTitle;

  /// No description provided for @notificationsUnread.
  ///
  /// In en, this message translates to:
  /// **'Unread'**
  String get notificationsUnread;

  /// No description provided for @notificationsNone.
  ///
  /// In en, this message translates to:
  /// **'No notifications'**
  String get notificationsNone;

  /// No description provided for @chatNoTeachers.
  ///
  /// In en, this message translates to:
  /// **'No teachers found'**
  String get chatNoTeachers;

  /// No description provided for @chatSelectTeacher.
  ///
  /// In en, this message translates to:
  /// **'Select Teacher'**
  String get chatSelectTeacher;

  /// No description provided for @chatStartFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to start chat'**
  String get chatStartFailed;

  /// No description provided for @chatAdminOpenFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to open admin chat'**
  String get chatAdminOpenFailed;

  /// No description provided for @chatDeleteMessageTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete message'**
  String get chatDeleteMessageTitle;

  /// No description provided for @chatDeleteMessageBody.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete this message? This action cannot be undone.'**
  String get chatDeleteMessageBody;

  /// No description provided for @chatDeleteMessageFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to delete message'**
  String get chatDeleteMessageFailed;

  /// No description provided for @chatEditMessage.
  ///
  /// In en, this message translates to:
  /// **'Edit message'**
  String get chatEditMessage;

  /// No description provided for @chatMessageActions.
  ///
  /// In en, this message translates to:
  /// **'Message actions'**
  String get chatMessageActions;

  /// No description provided for @chatMessages.
  ///
  /// In en, this message translates to:
  /// **'Messages'**
  String get chatMessages;

  /// No description provided for @chatChats.
  ///
  /// In en, this message translates to:
  /// **'Chats'**
  String get chatChats;

  /// No description provided for @chatAdmin.
  ///
  /// In en, this message translates to:
  /// **'Admin'**
  String get chatAdmin;

  /// No description provided for @chatNoConversations.
  ///
  /// In en, this message translates to:
  /// **'No conversations yet'**
  String get chatNoConversations;

  /// No description provided for @chatStartConversation.
  ///
  /// In en, this message translates to:
  /// **'Start a conversation'**
  String get chatStartConversation;

  /// No description provided for @chatAdministration.
  ///
  /// In en, this message translates to:
  /// **'Administration'**
  String get chatAdministration;

  /// No description provided for @chatUnknownUser.
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get chatUnknownUser;

  /// No description provided for @chatNoMessages.
  ///
  /// In en, this message translates to:
  /// **'(No messages)'**
  String get chatNoMessages;

  /// No description provided for @chatTeachers.
  ///
  /// In en, this message translates to:
  /// **'Teachers'**
  String get chatTeachers;

  /// No description provided for @chatNewChat.
  ///
  /// In en, this message translates to:
  /// **'New Chat'**
  String get chatNewChat;

  /// No description provided for @chatThreadNotFound.
  ///
  /// In en, this message translates to:
  /// **'Chat created, but thread not found'**
  String get chatThreadNotFound;

  /// No description provided for @chatStartNew.
  ///
  /// In en, this message translates to:
  /// **'Start New Chat'**
  String get chatStartNew;

  /// No description provided for @chatSearchUsers.
  ///
  /// In en, this message translates to:
  /// **'Search users...'**
  String get chatSearchUsers;

  /// No description provided for @profileAdminControls.
  ///
  /// In en, this message translates to:
  /// **'Admin Controls'**
  String get profileAdminControls;

  /// No description provided for @profileAdminAccess.
  ///
  /// In en, this message translates to:
  /// **'Admin Access'**
  String get profileAdminAccess;

  /// No description provided for @profileAdminAccessSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Grant or revoke admin permissions'**
  String get profileAdminAccessSubtitle;

  /// No description provided for @profileAdminAccessUpdate.
  ///
  /// In en, this message translates to:
  /// **'Update Admin Access'**
  String get profileAdminAccessUpdate;

  /// No description provided for @profileRoleManagement.
  ///
  /// In en, this message translates to:
  /// **'Role Management'**
  String get profileRoleManagement;

  /// No description provided for @profileMakeStudent.
  ///
  /// In en, this message translates to:
  /// **'Make Student'**
  String get profileMakeStudent;

  /// No description provided for @profileMakeParent.
  ///
  /// In en, this message translates to:
  /// **'Make Parent'**
  String get profileMakeParent;

  /// No description provided for @profileMakeTeacher.
  ///
  /// In en, this message translates to:
  /// **'Make Teacher'**
  String get profileMakeTeacher;

  /// No description provided for @profileArchiveRoles.
  ///
  /// In en, this message translates to:
  /// **'Archive Roles'**
  String get profileArchiveRoles;

  /// No description provided for @profileSectionInfo.
  ///
  /// In en, this message translates to:
  /// **'Profile Information'**
  String get profileSectionInfo;

  /// No description provided for @profileSectionAdditional.
  ///
  /// In en, this message translates to:
  /// **'Additional Information'**
  String get profileSectionAdditional;

  /// No description provided for @profileTitleProfile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profileTitleProfile;

  /// No description provided for @profileTitleUserProfile.
  ///
  /// In en, this message translates to:
  /// **'User Profile'**
  String get profileTitleUserProfile;

  /// No description provided for @profileEditTooltip.
  ///
  /// In en, this message translates to:
  /// **'Edit Profile'**
  String get profileEditTooltip;

  /// No description provided for @profileAdminViewLabel.
  ///
  /// In en, this message translates to:
  /// **'Admin View'**
  String get profileAdminViewLabel;

  /// No description provided for @profileEmailLabel.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get profileEmailLabel;

  /// No description provided for @profilePhoneLabel.
  ///
  /// In en, this message translates to:
  /// **'Phone'**
  String get profilePhoneLabel;

  /// No description provided for @profileMemberSinceLabel.
  ///
  /// In en, this message translates to:
  /// **'Member Since'**
  String get profileMemberSinceLabel;

  /// No description provided for @profileNotSet.
  ///
  /// In en, this message translates to:
  /// **'Not set'**
  String get profileNotSet;

  /// No description provided for @profileUnknown.
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get profileUnknown;

  /// No description provided for @profileRolesTitle.
  ///
  /// In en, this message translates to:
  /// **'Roles'**
  String get profileRolesTitle;

  /// No description provided for @profileBirthdayLabel.
  ///
  /// In en, this message translates to:
  /// **'Birthday'**
  String get profileBirthdayLabel;

  /// No description provided for @profileBirthdayInputLabel.
  ///
  /// In en, this message translates to:
  /// **'Birthday (YYYY-MM-DD)'**
  String get profileBirthdayInputLabel;

  /// No description provided for @profileGenerateParentLink.
  ///
  /// In en, this message translates to:
  /// **'Generate Parent Registration Link'**
  String get profileGenerateParentLink;

  /// No description provided for @profileMyChildrenTitle.
  ///
  /// In en, this message translates to:
  /// **'My Children'**
  String get profileMyChildrenTitle;

  /// No description provided for @profileChildrenSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Tap on a child to view or edit their information'**
  String get profileChildrenSubtitle;

  /// No description provided for @profileActionMessage.
  ///
  /// In en, this message translates to:
  /// **'Message'**
  String get profileActionMessage;

  /// No description provided for @profileManageStudentsTitle.
  ///
  /// In en, this message translates to:
  /// **'Manage Students'**
  String get profileManageStudentsTitle;

  /// No description provided for @profileActionAddStudent.
  ///
  /// In en, this message translates to:
  /// **'Add Student'**
  String get profileActionAddStudent;

  /// No description provided for @profileManageStudentsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Manage students assigned to you'**
  String get profileManageStudentsSubtitle;

  /// No description provided for @profileNoStudentsAssigned.
  ///
  /// In en, this message translates to:
  /// **'No students assigned yet'**
  String get profileNoStudentsAssigned;

  /// No description provided for @profileActionViewProfile.
  ///
  /// In en, this message translates to:
  /// **'View Profile'**
  String get profileActionViewProfile;

  /// No description provided for @profileActionAssignHometask.
  ///
  /// In en, this message translates to:
  /// **'Assign Hometask'**
  String get profileActionAssignHometask;

  /// No description provided for @profileActionRemoveStudent.
  ///
  /// In en, this message translates to:
  /// **'Remove from Students'**
  String get profileActionRemoveStudent;

  /// No description provided for @profileGenerateStudentLink.
  ///
  /// In en, this message translates to:
  /// **'Generate Student Registration Link'**
  String get profileGenerateStudentLink;

  /// No description provided for @profileTeachersTitle.
  ///
  /// In en, this message translates to:
  /// **'Teachers'**
  String get profileTeachersTitle;

  /// No description provided for @profileTeachersSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Tap to view teacher profile or leave teacher'**
  String get profileTeachersSubtitle;

  /// No description provided for @profileNoTeachersAssigned.
  ///
  /// In en, this message translates to:
  /// **'No teachers assigned yet'**
  String get profileNoTeachersAssigned;

  /// No description provided for @profileActionLeaveTeacher.
  ///
  /// In en, this message translates to:
  /// **'Leave Teacher'**
  String get profileActionLeaveTeacher;

  /// No description provided for @profileArchiveStudent.
  ///
  /// In en, this message translates to:
  /// **'Archive Student'**
  String get profileArchiveStudent;

  /// No description provided for @profileUnarchiveStudent.
  ///
  /// In en, this message translates to:
  /// **'Unarchive Student'**
  String get profileUnarchiveStudent;

  /// No description provided for @profileArchiveParent.
  ///
  /// In en, this message translates to:
  /// **'Archive Parent'**
  String get profileArchiveParent;

  /// No description provided for @profileUnarchiveParent.
  ///
  /// In en, this message translates to:
  /// **'Unarchive Parent'**
  String get profileUnarchiveParent;

  /// No description provided for @profileArchiveTeacher.
  ///
  /// In en, this message translates to:
  /// **'Archive Teacher'**
  String get profileArchiveTeacher;

  /// No description provided for @profileUnarchiveTeacher.
  ///
  /// In en, this message translates to:
  /// **'Unarchive Teacher'**
  String get profileUnarchiveTeacher;

  /// No description provided for @profileParentTools.
  ///
  /// In en, this message translates to:
  /// **'Parent Tools'**
  String get profileParentTools;

  /// No description provided for @profileAddChildren.
  ///
  /// In en, this message translates to:
  /// **'Add Children'**
  String get profileAddChildren;

  /// No description provided for @adminPanelTitle.
  ///
  /// In en, this message translates to:
  /// **'Admin Panel'**
  String get adminPanelTitle;

  /// No description provided for @adminUserManagement.
  ///
  /// In en, this message translates to:
  /// **'User Management'**
  String get adminUserManagement;

  /// No description provided for @adminSearchUsers.
  ///
  /// In en, this message translates to:
  /// **'Search by username or full name'**
  String get adminSearchUsers;

  /// No description provided for @adminNoUsers.
  ///
  /// In en, this message translates to:
  /// **'No users found'**
  String get adminNoUsers;

  /// No description provided for @adminAddUser.
  ///
  /// In en, this message translates to:
  /// **'Add User'**
  String get adminAddUser;

  /// No description provided for @adminUser.
  ///
  /// In en, this message translates to:
  /// **'User'**
  String get adminUser;

  /// No description provided for @adminStudent.
  ///
  /// In en, this message translates to:
  /// **'Student'**
  String get adminStudent;

  /// No description provided for @adminParent.
  ///
  /// In en, this message translates to:
  /// **'Parent'**
  String get adminParent;

  /// No description provided for @adminTeacher.
  ///
  /// In en, this message translates to:
  /// **'Teacher'**
  String get adminTeacher;

  /// No description provided for @adminAddStudent.
  ///
  /// In en, this message translates to:
  /// **'Add Student'**
  String get adminAddStudent;

  /// No description provided for @adminAddParent.
  ///
  /// In en, this message translates to:
  /// **'Add Parent'**
  String get adminAddParent;

  /// No description provided for @adminAddTeacher.
  ///
  /// In en, this message translates to:
  /// **'Add Teacher'**
  String get adminAddTeacher;

  /// No description provided for @adminShowingRange.
  ///
  /// In en, this message translates to:
  /// **'Showing {start}-{end} of {total}'**
  String adminShowingRange(Object start, Object end, Object total);

  /// No description provided for @adminRows.
  ///
  /// In en, this message translates to:
  /// **'Rows:'**
  String get adminRows;

  /// No description provided for @adminResetLink.
  ///
  /// In en, this message translates to:
  /// **'Reset Link'**
  String get adminResetLink;

  /// No description provided for @adminViewProfile.
  ///
  /// In en, this message translates to:
  /// **'View Profile'**
  String get adminViewProfile;

  /// No description provided for @adminEditUser.
  ///
  /// In en, this message translates to:
  /// **'Edit User'**
  String get adminEditUser;

  /// No description provided for @adminDeleteUser.
  ///
  /// In en, this message translates to:
  /// **'Delete User'**
  String get adminDeleteUser;

  /// No description provided for @adminFullName.
  ///
  /// In en, this message translates to:
  /// **'Full Name'**
  String get adminFullName;

  /// No description provided for @adminUsername.
  ///
  /// In en, this message translates to:
  /// **'Username'**
  String get adminUsername;

  /// No description provided for @adminActions.
  ///
  /// In en, this message translates to:
  /// **'Actions'**
  String get adminActions;

  /// No description provided for @adminLoadUsersFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to load users'**
  String get adminLoadUsersFailed;

  /// No description provided for @adminUserSaved.
  ///
  /// In en, this message translates to:
  /// **'User {action} successfully'**
  String adminUserSaved(Object action);

  /// No description provided for @adminUserSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to {action} user'**
  String adminUserSaveFailed(Object action);

  /// No description provided for @adminResetLinkGenerated.
  ///
  /// In en, this message translates to:
  /// **'Reset Link Generated'**
  String get adminResetLinkGenerated;

  /// No description provided for @adminResetLinkFor.
  ///
  /// In en, this message translates to:
  /// **'Reset link for {username}:'**
  String adminResetLinkFor(Object username);

  /// No description provided for @adminResetLinkExpires.
  ///
  /// In en, this message translates to:
  /// **'Expires: {expires}'**
  String adminResetLinkExpires(Object expires);

  /// No description provided for @adminCopyLink.
  ///
  /// In en, this message translates to:
  /// **'Copy Link'**
  String get adminCopyLink;

  /// No description provided for @adminResetLinkCopied.
  ///
  /// In en, this message translates to:
  /// **'Reset link copied to clipboard'**
  String get adminResetLinkCopied;

  /// No description provided for @adminResetLinkFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to generate reset link'**
  String get adminResetLinkFailed;

  /// No description provided for @adminUserDeleted.
  ///
  /// In en, this message translates to:
  /// **'User {username} deleted'**
  String adminUserDeleted(Object username);

  /// No description provided for @adminDeleteUserFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to delete user'**
  String get adminDeleteUserFailed;

  /// No description provided for @adminConvertedStudent.
  ///
  /// In en, this message translates to:
  /// **'User converted to student'**
  String get adminConvertedStudent;

  /// No description provided for @adminConvertedParent.
  ///
  /// In en, this message translates to:
  /// **'User converted to parent'**
  String get adminConvertedParent;

  /// No description provided for @adminConvertedTeacher.
  ///
  /// In en, this message translates to:
  /// **'User converted to teacher'**
  String get adminConvertedTeacher;

  /// No description provided for @adminStudentCreated.
  ///
  /// In en, this message translates to:
  /// **'Student created successfully'**
  String get adminStudentCreated;

  /// No description provided for @adminParentCreated.
  ///
  /// In en, this message translates to:
  /// **'Parent created successfully'**
  String get adminParentCreated;

  /// No description provided for @adminTeacherCreated.
  ///
  /// In en, this message translates to:
  /// **'Teacher created successfully'**
  String get adminTeacherCreated;

  /// No description provided for @adminDeleteUserTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete User'**
  String get adminDeleteUserTitle;

  /// No description provided for @adminDeleteUserMessage.
  ///
  /// In en, this message translates to:
  /// **'Delete {username}? This cannot be undone.'**
  String adminDeleteUserMessage(Object username);

  /// No description provided for @adminUsernameRequired.
  ///
  /// In en, this message translates to:
  /// **'Please enter a username'**
  String get adminUsernameRequired;

  /// No description provided for @adminFullNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Please enter a full name'**
  String get adminFullNameRequired;

  /// No description provided for @adminPassword.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get adminPassword;

  /// No description provided for @adminNewPasswordOptional.
  ///
  /// In en, this message translates to:
  /// **'New Password (optional)'**
  String get adminNewPasswordOptional;

  /// No description provided for @adminPasswordRequired.
  ///
  /// In en, this message translates to:
  /// **'Please enter a password'**
  String get adminPasswordRequired;

  /// No description provided for @adminGeneratePassword.
  ///
  /// In en, this message translates to:
  /// **'Generate Password'**
  String get adminGeneratePassword;

  /// No description provided for @adminEmailOptional.
  ///
  /// In en, this message translates to:
  /// **'Email (optional)'**
  String get adminEmailOptional;

  /// No description provided for @adminPhoneOptional.
  ///
  /// In en, this message translates to:
  /// **'Phone (optional)'**
  String get adminPhoneOptional;

  /// No description provided for @adminRoleAdmin.
  ///
  /// In en, this message translates to:
  /// **'Admin'**
  String get adminRoleAdmin;

  /// No description provided for @adminConvertRole.
  ///
  /// In en, this message translates to:
  /// **'Convert to Role:'**
  String get adminConvertRole;

  /// No description provided for @adminCopyCredentials.
  ///
  /// In en, this message translates to:
  /// **'Copy Credentials'**
  String get adminCopyCredentials;

  /// No description provided for @adminCredentialsRequired.
  ///
  /// In en, this message translates to:
  /// **'Fill username and password first'**
  String get adminCredentialsRequired;

  /// No description provided for @adminCredentialsCopied.
  ///
  /// In en, this message translates to:
  /// **'Credentials copied'**
  String get adminCredentialsCopied;

  /// No description provided for @adminMakeStudentTitle.
  ///
  /// In en, this message translates to:
  /// **'Make {username} a Student'**
  String adminMakeStudentTitle(Object username);

  /// No description provided for @adminMakeParentTitle.
  ///
  /// In en, this message translates to:
  /// **'Make {username} a Parent'**
  String adminMakeParentTitle(Object username);

  /// No description provided for @adminMakeTeacherTitle.
  ///
  /// In en, this message translates to:
  /// **'Make {username} a Teacher'**
  String adminMakeTeacherTitle(Object username);

  /// No description provided for @adminMakeTeacherNote.
  ///
  /// In en, this message translates to:
  /// **'This will grant teacher privileges to the user.'**
  String get adminMakeTeacherNote;

  /// No description provided for @adminBirthdayLabel.
  ///
  /// In en, this message translates to:
  /// **'Birthday (YYYY-MM-DD)'**
  String get adminBirthdayLabel;

  /// No description provided for @adminBirthdayHint.
  ///
  /// In en, this message translates to:
  /// **'2010-01-15'**
  String get adminBirthdayHint;

  /// No description provided for @adminBirthdayFormat.
  ///
  /// In en, this message translates to:
  /// **'Format: YYYY-MM-DD'**
  String get adminBirthdayFormat;

  /// No description provided for @adminConvert.
  ///
  /// In en, this message translates to:
  /// **'Convert'**
  String get adminConvert;

  /// No description provided for @adminSelectStudentsLabel.
  ///
  /// In en, this message translates to:
  /// **'Select Students (at least one):'**
  String get adminSelectStudentsLabel;

  /// No description provided for @adminSelectChildrenLabel.
  ///
  /// In en, this message translates to:
  /// **'Select Children (at least one):'**
  String get adminSelectChildrenLabel;

  /// No description provided for @adminSearchStudents.
  ///
  /// In en, this message translates to:
  /// **'Search students'**
  String get adminSearchStudents;

  /// No description provided for @adminNoStudents.
  ///
  /// In en, this message translates to:
  /// **'No students found'**
  String get adminNoStudents;

  /// No description provided for @adminSelectStudentRequired.
  ///
  /// In en, this message translates to:
  /// **'At least one student required'**
  String get adminSelectStudentRequired;

  /// No description provided for @dashboardNoStudents.
  ///
  /// In en, this message translates to:
  /// **'No students available.'**
  String get dashboardNoStudents;

  /// No description provided for @dashboardTitle.
  ///
  /// In en, this message translates to:
  /// **'Dashboard'**
  String get dashboardTitle;

  /// No description provided for @dashboardTeacherFeeds.
  ///
  /// In en, this message translates to:
  /// **'Teacher feeds'**
  String get dashboardTeacherFeeds;

  /// No description provided for @dashboardNoTeacherFeeds.
  ///
  /// In en, this message translates to:
  /// **'No teacher feeds yet.'**
  String get dashboardNoTeacherFeeds;

  /// No description provided for @dashboardSchoolFeed.
  ///
  /// In en, this message translates to:
  /// **'School feed'**
  String get dashboardSchoolFeed;

  /// No description provided for @dashboardNoSchoolFeed.
  ///
  /// In en, this message translates to:
  /// **'No school feed yet.'**
  String get dashboardNoSchoolFeed;

  /// No description provided for @dashboardGroupFeeds.
  ///
  /// In en, this message translates to:
  /// **'Group feeds'**
  String get dashboardGroupFeeds;

  /// No description provided for @dashboardNoGroupFeeds.
  ///
  /// In en, this message translates to:
  /// **'No group feeds yet.'**
  String get dashboardNoGroupFeeds;

  /// No description provided for @dashboardOwnerSchool.
  ///
  /// In en, this message translates to:
  /// **'School'**
  String get dashboardOwnerSchool;

  /// No description provided for @dashboardOwnerTeacher.
  ///
  /// In en, this message translates to:
  /// **'Teacher'**
  String get dashboardOwnerTeacher;

  /// No description provided for @dashboardOwnerGroup.
  ///
  /// In en, this message translates to:
  /// **'Group'**
  String get dashboardOwnerGroup;

  /// No description provided for @dashboardStudentLabel.
  ///
  /// In en, this message translates to:
  /// **'Student:'**
  String get dashboardStudentLabel;

  /// No description provided for @dashboardChildLabel.
  ///
  /// In en, this message translates to:
  /// **'Child:'**
  String get dashboardChildLabel;

  /// No description provided for @dashboardNoActiveHometasks.
  ///
  /// In en, this message translates to:
  /// **'No active hometasks.'**
  String get dashboardNoActiveHometasks;

  /// No description provided for @homeClearAppCacheTitle.
  ///
  /// In en, this message translates to:
  /// **'Clear app data cache'**
  String get homeClearAppCacheTitle;

  /// No description provided for @homeClearAppCacheBody.
  ///
  /// In en, this message translates to:
  /// **'This will remove cached messages, feeds, hometasks, and profile data.'**
  String get homeClearAppCacheBody;

  /// No description provided for @homeAppCacheCleared.
  ///
  /// In en, this message translates to:
  /// **'App data cache cleared.'**
  String get homeAppCacheCleared;

  /// No description provided for @homeClearMediaCacheTitle.
  ///
  /// In en, this message translates to:
  /// **'Clear media cache'**
  String get homeClearMediaCacheTitle;

  /// No description provided for @homeClearMediaCacheBody.
  ///
  /// In en, this message translates to:
  /// **'This will remove cached images and media files.'**
  String get homeClearMediaCacheBody;

  /// No description provided for @homeMediaCacheCleared.
  ///
  /// In en, this message translates to:
  /// **'Media cache cleared.'**
  String get homeMediaCacheCleared;

  /// No description provided for @homeLogoutTitle.
  ///
  /// In en, this message translates to:
  /// **'Logout'**
  String get homeLogoutTitle;

  /// No description provided for @homeLogoutBody.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to logout?'**
  String get homeLogoutBody;

  /// No description provided for @homeMenuTooltip.
  ///
  /// In en, this message translates to:
  /// **'Menu'**
  String get homeMenuTooltip;

  /// No description provided for @homeRolesLabel.
  ///
  /// In en, this message translates to:
  /// **'Roles: {roles}'**
  String homeRolesLabel(Object roles);

  /// No description provided for @homeProfileInfo.
  ///
  /// In en, this message translates to:
  /// **'Your profile information'**
  String get homeProfileInfo;

  /// No description provided for @commonClear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get commonClear;

  /// No description provided for @commonLogout.
  ///
  /// In en, this message translates to:
  /// **'Logout'**
  String get commonLogout;

  /// No description provided for @commonNotifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get commonNotifications;

  /// No description provided for @commonProfile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get commonProfile;

  /// No description provided for @commonUserManagement.
  ///
  /// In en, this message translates to:
  /// **'User Management'**
  String get commonUserManagement;

  /// No description provided for @commonTheme.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get commonTheme;

  /// No description provided for @commonSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get commonSystem;

  /// No description provided for @commonLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get commonLight;

  /// No description provided for @commonDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get commonDark;

  /// No description provided for @commonDashboard.
  ///
  /// In en, this message translates to:
  /// **'Dashboard'**
  String get commonDashboard;

  /// No description provided for @commonHometasks.
  ///
  /// In en, this message translates to:
  /// **'Hometasks'**
  String get commonHometasks;

  /// No description provided for @commonFeeds.
  ///
  /// In en, this message translates to:
  /// **'Feeds'**
  String get commonFeeds;

  /// No description provided for @commonChats.
  ///
  /// In en, this message translates to:
  /// **'Chats'**
  String get commonChats;

  /// No description provided for @commonUsername.
  ///
  /// In en, this message translates to:
  /// **'Username'**
  String get commonUsername;

  /// No description provided for @commonPassword.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get commonPassword;

  /// No description provided for @commonFullName.
  ///
  /// In en, this message translates to:
  /// **'Full Name'**
  String get commonFullName;

  /// No description provided for @commonEmailOptional.
  ///
  /// In en, this message translates to:
  /// **'Email (optional)'**
  String get commonEmailOptional;

  /// No description provided for @commonPhoneOptional.
  ///
  /// In en, this message translates to:
  /// **'Phone (optional)'**
  String get commonPhoneOptional;

  /// No description provided for @commonConfirmPassword.
  ///
  /// In en, this message translates to:
  /// **'Confirm Password'**
  String get commonConfirmPassword;

  /// No description provided for @commonBackToLogin.
  ///
  /// In en, this message translates to:
  /// **'Back to Login'**
  String get commonBackToLogin;

  /// No description provided for @commonOk.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get commonOk;

  /// No description provided for @commonErrorTitle.
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get commonErrorTitle;

  /// No description provided for @registerRoleStudent.
  ///
  /// In en, this message translates to:
  /// **'Student'**
  String get registerRoleStudent;

  /// No description provided for @registerRoleParent.
  ///
  /// In en, this message translates to:
  /// **'Parent'**
  String get registerRoleParent;

  /// No description provided for @registerRoleTeacher.
  ///
  /// In en, this message translates to:
  /// **'Teacher'**
  String get registerRoleTeacher;

  /// No description provided for @registerInvalidTokenTitle.
  ///
  /// In en, this message translates to:
  /// **'Invalid Registration Token'**
  String get registerInvalidTokenTitle;

  /// No description provided for @registerInvalidTokenMessage.
  ///
  /// In en, this message translates to:
  /// **'This registration link may be expired or already used.'**
  String get registerInvalidTokenMessage;

  /// No description provided for @registerGoToLogin.
  ///
  /// In en, this message translates to:
  /// **'Go to Login'**
  String get registerGoToLogin;

  /// No description provided for @registerTitle.
  ///
  /// In en, this message translates to:
  /// **'Register as {role}'**
  String registerTitle(Object role);

  /// No description provided for @registerParentOf.
  ///
  /// In en, this message translates to:
  /// **'You will be registered as parent of:'**
  String get registerParentOf;

  /// No description provided for @registerComplete.
  ///
  /// In en, this message translates to:
  /// **'Complete your registration'**
  String get registerComplete;

  /// No description provided for @registerUsernameRequired.
  ///
  /// In en, this message translates to:
  /// **'Please enter a username'**
  String get registerUsernameRequired;

  /// No description provided for @registerUsernameMin.
  ///
  /// In en, this message translates to:
  /// **'Username must be at least 3 characters'**
  String get registerUsernameMin;

  /// No description provided for @registerFullNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Please enter your full name'**
  String get registerFullNameRequired;

  /// No description provided for @registerBirthdayLabel.
  ///
  /// In en, this message translates to:
  /// **'Birthday (YYYY-MM-DD)'**
  String get registerBirthdayLabel;

  /// No description provided for @registerBirthdayHint.
  ///
  /// In en, this message translates to:
  /// **'2010-01-31'**
  String get registerBirthdayHint;

  /// No description provided for @registerBirthdayRequired.
  ///
  /// In en, this message translates to:
  /// **'Please enter your birthday'**
  String get registerBirthdayRequired;

  /// No description provided for @registerBirthdayFormat.
  ///
  /// In en, this message translates to:
  /// **'Use format: YYYY-MM-DD'**
  String get registerBirthdayFormat;

  /// No description provided for @registerPasswordRequired.
  ///
  /// In en, this message translates to:
  /// **'Please enter a password'**
  String get registerPasswordRequired;

  /// No description provided for @registerPasswordMin.
  ///
  /// In en, this message translates to:
  /// **'Password must be at least 6 characters'**
  String get registerPasswordMin;

  /// No description provided for @registerConfirmRequired.
  ///
  /// In en, this message translates to:
  /// **'Please confirm your password'**
  String get registerConfirmRequired;

  /// No description provided for @registerPasswordsMismatch.
  ///
  /// In en, this message translates to:
  /// **'Passwords do not match'**
  String get registerPasswordsMismatch;

  /// No description provided for @registerButton.
  ///
  /// In en, this message translates to:
  /// **'Register'**
  String get registerButton;

  /// No description provided for @registerLoginFailed.
  ///
  /// In en, this message translates to:
  /// **'Login failed'**
  String get registerLoginFailed;

  /// No description provided for @registerFailed.
  ///
  /// In en, this message translates to:
  /// **'Registration failed'**
  String get registerFailed;

  /// No description provided for @registerNetworkError.
  ///
  /// In en, this message translates to:
  /// **'Network error: {error}'**
  String registerNetworkError(Object error);

  /// No description provided for @registerValidateFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to validate token'**
  String get registerValidateFailed;

  /// No description provided for @resetErrorValidating.
  ///
  /// In en, this message translates to:
  /// **'Error validating token: {error}'**
  String resetErrorValidating(Object error);

  /// No description provided for @resetSuccessTitle.
  ///
  /// In en, this message translates to:
  /// **'Success'**
  String get resetSuccessTitle;

  /// No description provided for @resetSuccessMessage.
  ///
  /// In en, this message translates to:
  /// **'Your password has been reset successfully. You can now log in with your new password.'**
  String get resetSuccessMessage;

  /// No description provided for @resetFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to reset password'**
  String get resetFailed;

  /// No description provided for @resetErrorGeneric.
  ///
  /// In en, this message translates to:
  /// **'Error: {error}'**
  String resetErrorGeneric(Object error);

  /// No description provided for @resetTitle.
  ///
  /// In en, this message translates to:
  /// **'Reset Password'**
  String get resetTitle;

  /// No description provided for @resetValidating.
  ///
  /// In en, this message translates to:
  /// **'Validating reset token...'**
  String get resetValidating;

  /// No description provided for @resetInvalidTitle.
  ///
  /// In en, this message translates to:
  /// **'Invalid or Expired Link'**
  String get resetInvalidTitle;

  /// No description provided for @resetInvalidMessage.
  ///
  /// In en, this message translates to:
  /// **'This password reset link is invalid or has expired. Please request a new password reset link.'**
  String get resetInvalidMessage;

  /// No description provided for @resetSetNewPassword.
  ///
  /// In en, this message translates to:
  /// **'Set New Password'**
  String get resetSetNewPassword;

  /// No description provided for @resetForUser.
  ///
  /// In en, this message translates to:
  /// **'for user: {username}'**
  String resetForUser(Object username);

  /// No description provided for @resetNewPasswordLabel.
  ///
  /// In en, this message translates to:
  /// **'New Password'**
  String get resetNewPasswordLabel;

  /// No description provided for @resetPasswordRequired.
  ///
  /// In en, this message translates to:
  /// **'Please enter a password'**
  String get resetPasswordRequired;

  /// No description provided for @resetPasswordMin.
  ///
  /// In en, this message translates to:
  /// **'Password must be at least 6 characters'**
  String get resetPasswordMin;

  /// No description provided for @resetConfirmPasswordLabel.
  ///
  /// In en, this message translates to:
  /// **'Confirm Password'**
  String get resetConfirmPasswordLabel;

  /// No description provided for @resetConfirmRequired.
  ///
  /// In en, this message translates to:
  /// **'Please confirm your password'**
  String get resetConfirmRequired;

  /// No description provided for @loginTitle.
  ///
  /// In en, this message translates to:
  /// **'Login'**
  String get loginTitle;

  /// No description provided for @loginForgotTitle.
  ///
  /// In en, this message translates to:
  /// **'Forgot Password'**
  String get loginForgotTitle;

  /// No description provided for @loginForgotPrompt.
  ///
  /// In en, this message translates to:
  /// **'Enter your username to request a password reset.'**
  String get loginForgotPrompt;

  /// No description provided for @loginUsernameRequired.
  ///
  /// In en, this message translates to:
  /// **'Please enter your username'**
  String get loginUsernameRequired;

  /// No description provided for @loginPasswordRequired.
  ///
  /// In en, this message translates to:
  /// **'Please enter your password'**
  String get loginPasswordRequired;

  /// No description provided for @loginButton.
  ///
  /// In en, this message translates to:
  /// **'Login'**
  String get loginButton;

  /// No description provided for @loginForgotPassword.
  ///
  /// In en, this message translates to:
  /// **'Forgot Password?'**
  String get loginForgotPassword;

  /// No description provided for @loginRequestSentTitle.
  ///
  /// In en, this message translates to:
  /// **'Request Sent'**
  String get loginRequestSentTitle;

  /// No description provided for @loginRequestSentMessage.
  ///
  /// In en, this message translates to:
  /// **'Password reset request sent successfully.'**
  String get loginRequestSentMessage;

  /// No description provided for @loginRequestFailedMessage.
  ///
  /// In en, this message translates to:
  /// **'Failed to send password reset request. Please try again.'**
  String get loginRequestFailedMessage;

  /// No description provided for @loginErrorMessage.
  ///
  /// In en, this message translates to:
  /// **'An error occurred: {error}'**
  String loginErrorMessage(Object error);

  /// No description provided for @loginFailed.
  ///
  /// In en, this message translates to:
  /// **'Login failed'**
  String get loginFailed;

  /// No description provided for @commonRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get commonRetry;

  /// No description provided for @hometasksNone.
  ///
  /// In en, this message translates to:
  /// **'No hometasks found.'**
  String get hometasksNone;

  /// No description provided for @hometasksUpdateOrderFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to update order.'**
  String get hometasksUpdateOrderFailed;

  /// No description provided for @hometasksAssignTitle.
  ///
  /// In en, this message translates to:
  /// **'Assign Hometask to {studentName}'**
  String hometasksAssignTitle(Object studentName);

  /// No description provided for @hometasksTitleLabel.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get hometasksTitleLabel;

  /// No description provided for @hometasksTitleRequired.
  ///
  /// In en, this message translates to:
  /// **'Title is required'**
  String get hometasksTitleRequired;

  /// No description provided for @hometasksDescriptionLabel.
  ///
  /// In en, this message translates to:
  /// **'Description (optional)'**
  String get hometasksDescriptionLabel;

  /// No description provided for @hometasksDueDate.
  ///
  /// In en, this message translates to:
  /// **'Due date'**
  String get hometasksDueDate;

  /// No description provided for @hometasksNoDueDate.
  ///
  /// In en, this message translates to:
  /// **'No due date'**
  String get hometasksNoDueDate;

  /// No description provided for @hometasksRepeatLabel.
  ///
  /// In en, this message translates to:
  /// **'Repeat'**
  String get hometasksRepeatLabel;

  /// No description provided for @hometasksRepeatNone.
  ///
  /// In en, this message translates to:
  /// **'No repeat'**
  String get hometasksRepeatNone;

  /// No description provided for @hometasksRepeatDaily.
  ///
  /// In en, this message translates to:
  /// **'Each day'**
  String get hometasksRepeatDaily;

  /// No description provided for @hometasksRepeatWeekly.
  ///
  /// In en, this message translates to:
  /// **'Each week'**
  String get hometasksRepeatWeekly;

  /// No description provided for @hometasksRepeatCustom.
  ///
  /// In en, this message translates to:
  /// **'Custom interval'**
  String get hometasksRepeatCustom;

  /// No description provided for @hometasksRepeatEveryDays.
  ///
  /// In en, this message translates to:
  /// **'Repeat every (days)'**
  String get hometasksRepeatEveryDays;

  /// No description provided for @hometasksRepeatCustomInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter a positive number of days'**
  String get hometasksRepeatCustomInvalid;

  /// No description provided for @hometasksTypeLabel.
  ///
  /// In en, this message translates to:
  /// **'Hometask type'**
  String get hometasksTypeLabel;

  /// No description provided for @hometasksTypeSimple.
  ///
  /// In en, this message translates to:
  /// **'Simple'**
  String get hometasksTypeSimple;

  /// No description provided for @hometasksTypeChecklist.
  ///
  /// In en, this message translates to:
  /// **'Checklist'**
  String get hometasksTypeChecklist;

  /// No description provided for @hometasksTypeProgress.
  ///
  /// In en, this message translates to:
  /// **'Progress'**
  String get hometasksTypeProgress;

  /// No description provided for @hometasksChecklistItems.
  ///
  /// In en, this message translates to:
  /// **'Checklist items'**
  String get hometasksChecklistItems;

  /// No description provided for @hometasksProgressItems.
  ///
  /// In en, this message translates to:
  /// **'Progress items'**
  String get hometasksProgressItems;

  /// No description provided for @hometasksItemLabel.
  ///
  /// In en, this message translates to:
  /// **'Item {index}'**
  String hometasksItemLabel(Object index);

  /// No description provided for @hometasksRequired.
  ///
  /// In en, this message translates to:
  /// **'Required'**
  String get hometasksRequired;

  /// No description provided for @hometasksAddAtLeastOne.
  ///
  /// In en, this message translates to:
  /// **'Add at least one {typeLabel} item.'**
  String hometasksAddAtLeastOne(Object typeLabel);

  /// No description provided for @hometasksRepeatIntervalInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid repeat interval.'**
  String get hometasksRepeatIntervalInvalid;

  /// No description provided for @hometasksAssigned.
  ///
  /// In en, this message translates to:
  /// **'Hometask assigned.'**
  String get hometasksAssigned;

  /// No description provided for @hometasksAssignFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to assign hometask.'**
  String get hometasksAssignFailed;

  /// No description provided for @hometasksAssignAction.
  ///
  /// In en, this message translates to:
  /// **'Assign'**
  String get hometasksAssignAction;

  /// No description provided for @hometasksActive.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get hometasksActive;

  /// No description provided for @hometasksArchive.
  ///
  /// In en, this message translates to:
  /// **'Archive'**
  String get hometasksArchive;

  /// No description provided for @hometasksAssign.
  ///
  /// In en, this message translates to:
  /// **'Assign Hometask'**
  String get hometasksAssign;

  /// No description provided for @hometasksAssignToGroup.
  ///
  /// In en, this message translates to:
  /// **'Assign to Group'**
  String get hometasksAssignToGroup;

  /// No description provided for @hometasksSelectGroupTitle.
  ///
  /// In en, this message translates to:
  /// **'Select Group'**
  String get hometasksSelectGroupTitle;

  /// No description provided for @hometasksAssignTitleGroup.
  ///
  /// In en, this message translates to:
  /// **'Assign Hometask to group {groupName}'**
  String hometasksAssignTitleGroup(Object groupName);

  /// No description provided for @hometasksApplyGroupChangesTitle.
  ///
  /// In en, this message translates to:
  /// **'Apply group changes'**
  String get hometasksApplyGroupChangesTitle;

  /// No description provided for @hometasksApplyGroupChangesMessage.
  ///
  /// In en, this message translates to:
  /// **'Apply these edits to all students in this group hometask?'**
  String get hometasksApplyGroupChangesMessage;

  /// No description provided for @hometasksApplyOnlyThisStudent.
  ///
  /// In en, this message translates to:
  /// **'Only this student'**
  String get hometasksApplyOnlyThisStudent;

  /// No description provided for @hometasksApplyToGroup.
  ///
  /// In en, this message translates to:
  /// **'Apply to group'**
  String get hometasksApplyToGroup;

  /// No description provided for @hometasksArchiveGroupTitle.
  ///
  /// In en, this message translates to:
  /// **'Archive group hometask'**
  String get hometasksArchiveGroupTitle;

  /// No description provided for @hometasksArchiveGroupMessage.
  ///
  /// In en, this message translates to:
  /// **'Archive only this student task, or all tasks in this group assignment?'**
  String get hometasksArchiveGroupMessage;

  /// No description provided for @hometasksArchiveForGroup.
  ///
  /// In en, this message translates to:
  /// **'Archive for group'**
  String get hometasksArchiveForGroup;

  /// No description provided for @hometasksReopenGroupTitle.
  ///
  /// In en, this message translates to:
  /// **'Reopen group hometask'**
  String get hometasksReopenGroupTitle;

  /// No description provided for @hometasksReopenGroupMessage.
  ///
  /// In en, this message translates to:
  /// **'Reopen only this student task, or all tasks in this group assignment?'**
  String get hometasksReopenGroupMessage;

  /// No description provided for @hometasksReopenForGroup.
  ///
  /// In en, this message translates to:
  /// **'Reopen for group'**
  String get hometasksReopenForGroup;

  /// No description provided for @feedsGroupFeeds.
  ///
  /// In en, this message translates to:
  /// **'Group feeds'**
  String get feedsGroupFeeds;

  /// No description provided for @feedsOwnerGroup.
  ///
  /// In en, this message translates to:
  /// **'Group'**
  String get feedsOwnerGroup;

  /// No description provided for @profileCreateGroup.
  ///
  /// In en, this message translates to:
  /// **'Create Group'**
  String get profileCreateGroup;

  /// No description provided for @profileGroupsTitle.
  ///
  /// In en, this message translates to:
  /// **'Groups'**
  String get profileGroupsTitle;

  /// No description provided for @profileNoGroupsYet.
  ///
  /// In en, this message translates to:
  /// **'No groups yet'**
  String get profileNoGroupsYet;

  /// No description provided for @profileStudentsLabel.
  ///
  /// In en, this message translates to:
  /// **'students'**
  String get profileStudentsLabel;

  /// No description provided for @profileStatusArchived.
  ///
  /// In en, this message translates to:
  /// **'Archived'**
  String get profileStatusArchived;

  /// No description provided for @profileStatusActive.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get profileStatusActive;

  /// No description provided for @profileEditMembers.
  ///
  /// In en, this message translates to:
  /// **'Edit members'**
  String get profileEditMembers;

  /// No description provided for @profileArchiveGroup.
  ///
  /// In en, this message translates to:
  /// **'Archive'**
  String get profileArchiveGroup;

  /// No description provided for @profileUnarchiveGroup.
  ///
  /// In en, this message translates to:
  /// **'Unarchive'**
  String get profileUnarchiveGroup;

  /// No description provided for @profileDeleteGroupTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete group'**
  String get profileDeleteGroupTitle;

  /// No description provided for @profileDeleteGroupMessage.
  ///
  /// In en, this message translates to:
  /// **'Delete this group permanently? Feed and group history will be removed.'**
  String get profileDeleteGroupMessage;

  /// No description provided for @profileAddStudentsFirstToCreateGroup.
  ///
  /// In en, this message translates to:
  /// **'Add students first to create a group'**
  String get profileAddStudentsFirstToCreateGroup;

  /// No description provided for @profileGroupNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Group name'**
  String get profileGroupNameLabel;

  /// No description provided for @profileFilterStudentsLabel.
  ///
  /// In en, this message translates to:
  /// **'Filter students'**
  String get profileFilterStudentsLabel;

  /// No description provided for @profileNoStudentsFound.
  ///
  /// In en, this message translates to:
  /// **'No students found'**
  String get profileNoStudentsFound;

  /// No description provided for @profileEnterGroupNameAndStudents.
  ///
  /// In en, this message translates to:
  /// **'Enter group name and select students'**
  String get profileEnterGroupNameAndStudents;

  /// No description provided for @profileCreateAction.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get profileCreateAction;

  /// No description provided for @profileEditGroupTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit Group'**
  String get profileEditGroupTitle;

  /// No description provided for @profileArchivedGroupLabel.
  ///
  /// In en, this message translates to:
  /// **'Archived group'**
  String get profileArchivedGroupLabel;

  /// No description provided for @profileGroupCreatedSuccess.
  ///
  /// In en, this message translates to:
  /// **'Group created successfully'**
  String get profileGroupCreatedSuccess;

  /// No description provided for @profileGroupUpdatedSuccess.
  ///
  /// In en, this message translates to:
  /// **'Group updated successfully'**
  String get profileGroupUpdatedSuccess;

  /// No description provided for @profileGroupDeletedSuccess.
  ///
  /// In en, this message translates to:
  /// **'Group deleted successfully'**
  String get profileGroupDeletedSuccess;

  /// No description provided for @profileGroupCreateFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to create group'**
  String get profileGroupCreateFailed;

  /// No description provided for @profileGroupUpdateFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to update group'**
  String get profileGroupUpdateFailed;

  /// No description provided for @profileGroupDeleteFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to delete group'**
  String get profileGroupDeleteFailed;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['de', 'en', 'ru'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'de':
      return AppLocalizationsDe();
    case 'en':
      return AppLocalizationsEn();
    case 'ru':
      return AppLocalizationsRu();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
