// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for German (`de`).
class AppLocalizationsDe extends AppLocalizations {
  AppLocalizationsDe([String locale = 'de']) : super(locale);

  @override
  String get appTitle => 'Musikschule am Thomas-Mann-Platz';

  @override
  String get languageTitle => 'Sprache';

  @override
  String get languageGerman => 'Deutsch';

  @override
  String get languageEnglish => 'Englisch';

  @override
  String get languageRussian => 'Russisch';

  @override
  String get securityTitle => 'Sicherheit';

  @override
  String get changePasswordTitle => 'Passwort aendern';

  @override
  String get changePasswordSubtitle => 'Konto-Passwort aktualisieren';

  @override
  String get consentTitle =>
      'Einwilligung zur Verarbeitung personenbezogener Daten';

  @override
  String get consentAgree => 'Zustimmen';

  @override
  String get consentGuardianConfirm =>
      'Wenn Sie ein Kind registrieren, bestaetigen Sie, dass Sie Elternteil, gesetzlicher Vertreter oder anderweitig berechtigt sind.';

  @override
  String get consentRequired =>
      'Bitte stimmen Sie der Einwilligung zu, um fortzufahren';

  @override
  String get consentFallback =>
      'Einwilligung (kurz)\n- Nur Inhalte zum Musiklernen.\n- Sie koennen Ihr Profil bearbeiten oder loeschen.\n- Daten sind mit TLS geschuetzt.\n- Keine Weitergabe ausser fuer E-Mail-Zustellung (SendGrid).\nWenn Sie ein Kind registrieren, bestaetigen Sie, dass Sie Elternteil/Erziehungsberechtigter oder autorisiert sind.';

  @override
  String get commonSettings => 'Einstellungen';

  @override
  String get commonOpen => 'Oeffnen';

  @override
  String get commonPost => 'Posten';

  @override
  String get commonEdit => 'Bearbeiten';

  @override
  String get commonReply => 'Antworten';

  @override
  String get commonDelete => 'Loeschen';

  @override
  String get commonAdd => 'Hinzufuegen';

  @override
  String get commonSave => 'Speichern';

  @override
  String get commonCancel => 'Abbrechen';

  @override
  String get commonRefresh => 'Aktualisieren';

  @override
  String get commonClose => 'Schliessen';

  @override
  String get commonDownload => 'Herunterladen';

  @override
  String get commonDownloadSourceFile => 'Quelldatei herunterladen';

  @override
  String get commonDownloadStarted => 'Download gestartet';

  @override
  String get commonDownloadFailed => 'Download fehlgeschlagen';

  @override
  String commonSavedToPath(Object path) {
    return 'Gespeichert unter $path';
  }

  @override
  String get commonBack5s => '5s zurueck';

  @override
  String get commonForward5s => '5s vor';

  @override
  String get commonBold => 'Fett';

  @override
  String get commonItalic => 'Kursiv';

  @override
  String get commonUnderline => 'Unterstrichen';

  @override
  String get commonStrike => 'Durchgestrichen';

  @override
  String get commonSubscript => 'Tiefgestellt';

  @override
  String get commonSuperscript => 'Hochgestellt';

  @override
  String get commonTitle => 'Titel';

  @override
  String get commonSend => 'Senden';

  @override
  String get commonApply => 'Anwenden';

  @override
  String get commonInsertLink => 'Link einfuegen';

  @override
  String get commonHeading2 => 'H2';

  @override
  String get commonHeading5 => 'H5';

  @override
  String get commonQuote => 'Zitat';

  @override
  String get commonUrl => 'URL';

  @override
  String get commonAttachFile => 'Datei anhaengen';

  @override
  String get commonAudio => 'Audio';

  @override
  String get commonVideo => 'Video';

  @override
  String get commonImage => 'Bild';

  @override
  String get commonFile => 'Datei';

  @override
  String get commonVoiceMessage => 'Sprachnachricht';

  @override
  String get commonTapToPlay => 'Zum Abspielen tippen';

  @override
  String get commonLoading => 'Laedt';

  @override
  String get commonFullscreen => 'Vollbild';

  @override
  String get commonExitFullscreen => 'Vollbild beenden';

  @override
  String get commonPrevious => 'Vorherige Seite';

  @override
  String get commonNext => 'Naechste Seite';

  @override
  String get commonClearSearch => 'Suche leeren';

  @override
  String get commonNoResults => 'Keine Ergebnisse gefunden';

  @override
  String get commonTypeToFilter => 'Zum Filtern tippen...';

  @override
  String get commonRequired => 'Erforderlich';

  @override
  String commonErrorMessage(Object error) {
    return 'Fehler: $error';
  }

  @override
  String get commonCreated => 'erstellt';

  @override
  String get commonUpdated => 'aktualisiert';

  @override
  String get commonCreate => 'erstellen';

  @override
  String get commonUpdate => 'aktualisieren';

  @override
  String commonVideoLabel(Object filename) {
    return 'Video: $filename';
  }

  @override
  String get feedsTitle => 'Feeds';

  @override
  String get feedsNone => 'Keine Feeds verfuegbar';

  @override
  String get feedsSchool => 'Schule';

  @override
  String get feedsTeacherFeeds => 'Lehrer-Feeds';

  @override
  String get feedsOwnerSchool => 'Schule';

  @override
  String get feedsOwnerTeacher => 'Lehrer';

  @override
  String get feedsNewPostTooltip => 'Neuer Beitrag';

  @override
  String get feedsMarkAllRead => 'Alle als gelesen markieren';

  @override
  String get feedsImportant => 'Wichtig';

  @override
  String get feedsLatest => 'Neueste';

  @override
  String get feedsNoImportantPosts => 'Noch keine wichtigen Beitraege.';

  @override
  String get feedsAllPosts => 'Alle Beitraege';

  @override
  String get feedsNoPosts => 'Noch keine Beitraege.';

  @override
  String get feedsNoTextPreview => 'Keine Textvorschau verfuegbar.';

  @override
  String get feedsReadAndDiscuss => 'Lesen und diskutieren';

  @override
  String feedsPostedAt(Object timestamp) {
    return 'Gepostet $timestamp';
  }

  @override
  String feedsPostedEditedAt(Object timestamp) {
    return 'Gepostet $timestamp · bearbeitet';
  }

  @override
  String get feedsSubscriptionFailed => 'Abo konnte nicht aktualisiert werden';

  @override
  String get feedsDeleteDenied =>
      'Sie haben keine Berechtigung, diesen Beitrag zu loeschen';

  @override
  String get feedsDeleteTitle => 'Beitrag loeschen';

  @override
  String get feedsDeleteMessage =>
      'Sind Sie sicher, dass Sie diesen Beitrag loeschen moechten? Diese Aktion kann nicht rueckgaengig gemacht werden.';

  @override
  String get feedsDeleteFailed => 'Beitrag konnte nicht geloescht werden';

  @override
  String get feedsDeleteCommentTitle => 'Kommentar loeschen';

  @override
  String get feedsDeleteCommentMessage =>
      'Sind Sie sicher, dass Sie diesen Kommentar loeschen moechten? Diese Aktion kann nicht rueckgaengig gemacht werden.';

  @override
  String get feedsDeleteCommentFailed =>
      'Kommentar konnte nicht geloescht werden';

  @override
  String feedsUnsupportedAttachment(Object type) {
    return 'Nicht unterstuetzter Anhang: $type';
  }

  @override
  String get feedsAttachmentActions => 'Anhangaktionen';

  @override
  String get feedsCommentActions => 'Kommentaraktionen';

  @override
  String get feedsEditPost => 'Beitrag bearbeiten';

  @override
  String get feedsNewPost => 'Neuer Beitrag';

  @override
  String get feedsTextTools => 'Textwerkzeuge';

  @override
  String get feedsTextFormatting => 'Textformatierung';

  @override
  String get feedsJustificationTools => 'Ausrichtungswerkzeuge';

  @override
  String get feedsListsPaddingTools => 'Listen- und Einrueckungswerkzeuge';

  @override
  String get feedsAttachments => 'Anhaenge';

  @override
  String get feedsAllowComments => 'Kommentare erlauben';

  @override
  String get feedsMarkImportant => 'Als wichtig markieren';

  @override
  String get feedsUploadFailed => 'Medien konnten nicht hochgeladen werden';

  @override
  String get feedsEditComment => 'Kommentar bearbeiten';

  @override
  String get feedsNewComment => 'Neuer Kommentar';

  @override
  String get feedsComments => 'Kommentare';

  @override
  String get feedsNoComments => 'Noch keine Kommentare.';

  @override
  String get feedsAddComment => 'Kommentar hinzufuegen';

  @override
  String get feedsSubscribeComments => 'Kommentare abonnieren';

  @override
  String get feedsUnsubscribeComments => 'Kommentar-Abo beenden';

  @override
  String feedsAttachmentInline(Object typeLabel) {
    return '$typeLabel (inline)';
  }

  @override
  String get feedsSettingsTitle => 'Feed-Einstellungen';

  @override
  String get feedsAllowStudentPosts => 'Beitraege von Schuelern erlauben';

  @override
  String get feedsAutoSubscribe => 'Neue Beitraege automatisch abonnieren';

  @override
  String get feedsNotifyNewPosts => 'Bei neuen Beitraegen benachrichtigen';

  @override
  String get feedsParagraphType => 'Absatztyp';

  @override
  String get feedsFont => 'Schriftart';

  @override
  String get feedsSize => 'Groesse';

  @override
  String get feedsAttach => 'Anhaengen';

  @override
  String get feedsPostTitle => 'Beitrag';

  @override
  String feedsUnsupportedEmbed(Object data) {
    return 'Nicht unterstuetztes Embed: $data';
  }

  @override
  String get feedsUntitledPost => 'Unbenannter Beitrag';

  @override
  String get videoWebLimited =>
      'Der Web-Video-Player ist eingeschraenkt. Sie koennen die Datei herunterladen oder separat oeffnen.';

  @override
  String get videoErrorTitle => 'Video-Fehler';

  @override
  String get videoLoadFailed => 'Video konnte nicht geladen werden';

  @override
  String get voiceRecordFailed => 'Audioaufnahme fehlgeschlagen';

  @override
  String get voiceRecordUnavailable => 'Audioaufnahme nicht verfuegbar';

  @override
  String voiceRecordError(Object error) {
    return 'Sprachfehler: $error';
  }

  @override
  String get voiceStopRecording => 'Aufnahme stoppen';

  @override
  String get voiceRecord => 'Sprache aufnehmen';

  @override
  String get hometasksChecklistUpdateFailed =>
      'Checklistenpunkt konnte nicht aktualisiert werden.';

  @override
  String get hometasksItemsSaved => 'Elemente erfolgreich gespeichert.';

  @override
  String get hometasksItemsSaveFailed =>
      'Elemente konnten nicht gespeichert werden.';

  @override
  String get hometasksProgressUpdateFailed =>
      'Fortschritt konnte nicht aktualisiert werden.';

  @override
  String get hometasksUpdateFailed =>
      'Hausaufgabe konnte nicht aktualisiert werden.';

  @override
  String hometasksTeacherFallback(Object teacherId) {
    return 'Lehrer #$teacherId';
  }

  @override
  String get hometasksItemNameRequired =>
      'Alle Elemente muessen einen Namen haben.';

  @override
  String hometasksDueLabel(Object date) {
    return 'Faellig: $date';
  }

  @override
  String get hometasksEditItems => 'Elemente bearbeiten';

  @override
  String get hometasksMarkCompleted => 'Als erledigt markieren';

  @override
  String get hometasksMarkAccomplished => 'Als abgeschlossen markieren';

  @override
  String get hometasksReturnActive => 'Zurueck zu aktiv';

  @override
  String get hometasksMarkUncompleted => 'Als nicht erledigt markieren';

  @override
  String get hometasksProgressNotStarted => 'Nicht begonnen';

  @override
  String get hometasksProgressInProgress => 'In Bearbeitung';

  @override
  String get hometasksProgressNearlyDone => 'Fast fertig';

  @override
  String get hometasksProgressAlmostComplete => 'Beinahe abgeschlossen';

  @override
  String get hometasksProgressComplete => 'Abgeschlossen';

  @override
  String hometasksItemHint(Object index) {
    return 'Element $index';
  }

  @override
  String get hometasksAddItem => 'Element hinzufuegen';

  @override
  String get notificationsTitle => 'Benachrichtigungen';

  @override
  String get notificationsUnread => 'Ungelesen';

  @override
  String get notificationsNone => 'Keine Benachrichtigungen';

  @override
  String get chatNoTeachers => 'Keine Lehrer gefunden';

  @override
  String get chatSelectTeacher => 'Lehrer waehlen';

  @override
  String get chatStartFailed => 'Chat konnte nicht gestartet werden';

  @override
  String get chatAdminOpenFailed => 'Admin-Chat konnte nicht geoeffnet werden';

  @override
  String get chatDeleteMessageTitle => 'Nachricht loeschen';

  @override
  String get chatDeleteMessageBody =>
      'Sind Sie sicher, dass Sie diese Nachricht loeschen moechten? Diese Aktion kann nicht rueckgaengig gemacht werden.';

  @override
  String get chatDeleteMessageFailed =>
      'Nachricht konnte nicht geloescht werden';

  @override
  String get chatEditMessage => 'Nachricht bearbeiten';

  @override
  String get chatMessageActions => 'Nachrichtenaktionen';

  @override
  String get chatMessages => 'Nachrichten';

  @override
  String get chatChats => 'Chats';

  @override
  String get chatAdmin => 'Admin';

  @override
  String get chatNoConversations => 'Noch keine Unterhaltungen';

  @override
  String get chatStartConversation => 'Unterhaltung starten';

  @override
  String get chatAdministration => 'Administration';

  @override
  String get chatUnknownUser => 'Unbekannt';

  @override
  String get chatNoMessages => '(Keine Nachrichten)';

  @override
  String get chatTeachers => 'Lehrer';

  @override
  String get chatNewChat => 'Neuer Chat';

  @override
  String get chatThreadNotFound => 'Chat erstellt, aber Thread nicht gefunden';

  @override
  String get chatStartNew => 'Neuen Chat starten';

  @override
  String get chatSearchUsers => 'Benutzer suchen...';

  @override
  String get profileAdminControls => 'Admin-Steuerung';

  @override
  String get profileAdminAccess => 'Admin-Zugriff';

  @override
  String get profileAdminAccessSubtitle =>
      'Admin-Berechtigungen erteilen oder entziehen';

  @override
  String get profileAdminAccessUpdate => 'Admin-Zugriff aktualisieren';

  @override
  String get profileRoleManagement => 'Rollenverwaltung';

  @override
  String get profileMakeStudent => 'Zum Schueler machen';

  @override
  String get profileMakeParent => 'Zum Elternteil machen';

  @override
  String get profileMakeTeacher => 'Zum Lehrer machen';

  @override
  String get profileArchiveRoles => 'Rollen archivieren';

  @override
  String get profileSectionInfo => 'Profilinformationen';

  @override
  String get profileSectionAdditional => 'Zusaetzliche Informationen';

  @override
  String get profileTitleProfile => 'Profil';

  @override
  String get profileTitleUserProfile => 'Benutzerprofil';

  @override
  String get profileEditTooltip => 'Profil bearbeiten';

  @override
  String get profileAdminViewLabel => 'Admin-Ansicht';

  @override
  String get profileEmailLabel => 'E-Mail';

  @override
  String get profilePhoneLabel => 'Telefon';

  @override
  String get profileMemberSinceLabel => 'Mitglied seit';

  @override
  String get profileNotSet => 'Nicht gesetzt';

  @override
  String get profileUnknown => 'Unbekannt';

  @override
  String get profileRolesTitle => 'Rollen';

  @override
  String get profileBirthdayLabel => 'Geburtstag';

  @override
  String get profileBirthdayInputLabel => 'Geburtstag (JJJJ-MM-TT)';

  @override
  String get profileGenerateParentLink => 'Eltern-Registrierungslink erstellen';

  @override
  String get profileMyChildrenTitle => 'Meine Kinder';

  @override
  String get profileChildrenSubtitle =>
      'Tippen Sie auf ein Kind, um die Informationen anzuzeigen oder zu bearbeiten';

  @override
  String get profileActionMessage => 'Nachricht';

  @override
  String get profileManageStudentsTitle => 'Schueler verwalten';

  @override
  String get profileActionAddStudent => 'Schueler hinzufuegen';

  @override
  String get profileManageStudentsSubtitle =>
      'Schueler verwalten, die Ihnen zugeordnet sind';

  @override
  String get profileNoStudentsAssigned => 'Noch keine Schueler zugeordnet';

  @override
  String get profileActionViewProfile => 'Profil ansehen';

  @override
  String get profileActionAssignHometask => 'Hausaufgabe zuweisen';

  @override
  String get profileActionRemoveStudent => 'Aus Schuelern entfernen';

  @override
  String get profileGenerateStudentLink =>
      'Schueler-Registrierungslink erstellen';

  @override
  String get profileTeachersTitle => 'Lehrer';

  @override
  String get profileTeachersSubtitle =>
      'Tippen, um das Lehrerprofil anzusehen oder den Lehrer zu verlassen';

  @override
  String get profileNoTeachersAssigned => 'Noch keine Lehrer zugeordnet';

  @override
  String get profileActionLeaveTeacher => 'Lehrer verlassen';

  @override
  String get profileArchiveStudent => 'Schueler archivieren';

  @override
  String get profileUnarchiveStudent => 'Schueler wiederherstellen';

  @override
  String get profileArchiveParent => 'Eltern archivieren';

  @override
  String get profileUnarchiveParent => 'Eltern wiederherstellen';

  @override
  String get profileArchiveTeacher => 'Lehrer archivieren';

  @override
  String get profileUnarchiveTeacher => 'Lehrer wiederherstellen';

  @override
  String get profileParentTools => 'Eltern-Werkzeuge';

  @override
  String get profileAddChildren => 'Kinder hinzufuegen';

  @override
  String get adminPanelTitle => 'Admin-Panel';

  @override
  String get adminUserManagement => 'Benutzerverwaltung';

  @override
  String get adminSearchUsers => 'Nach Benutzername oder vollem Namen suchen';

  @override
  String get adminNoUsers => 'Keine Benutzer gefunden';

  @override
  String get adminAddUser => 'Benutzer hinzufuegen';

  @override
  String get adminUser => 'Benutzer';

  @override
  String get adminStudent => 'Schueler';

  @override
  String get adminParent => 'Eltern';

  @override
  String get adminTeacher => 'Lehrer';

  @override
  String get adminAddStudent => 'Schueler hinzufuegen';

  @override
  String get adminAddParent => 'Eltern hinzufuegen';

  @override
  String get adminAddTeacher => 'Lehrer hinzufuegen';

  @override
  String adminShowingRange(Object start, Object end, Object total) {
    return 'Anzeige $start-$end von $total';
  }

  @override
  String get adminRows => 'Zeilen:';

  @override
  String get adminResetLink => 'Reset-Link';

  @override
  String get adminViewProfile => 'Profil anzeigen';

  @override
  String get adminEditUser => 'Benutzer bearbeiten';

  @override
  String get adminDeleteUser => 'Benutzer loeschen';

  @override
  String get adminFullName => 'Voller Name';

  @override
  String get adminUsername => 'Benutzername';

  @override
  String get adminActions => 'Aktionen';

  @override
  String get adminLoadUsersFailed => 'Benutzer konnten nicht geladen werden';

  @override
  String adminUserSaved(Object action) {
    return 'Benutzer $action erfolgreich';
  }

  @override
  String adminUserSaveFailed(Object action) {
    return 'Benutzer konnte nicht $action werden';
  }

  @override
  String get adminResetLinkGenerated => 'Reset-Link erstellt';

  @override
  String adminResetLinkFor(Object username) {
    return 'Reset-Link fuer $username:';
  }

  @override
  String adminResetLinkExpires(Object expires) {
    return 'Laeuft ab: $expires';
  }

  @override
  String get adminCopyLink => 'Link kopieren';

  @override
  String get adminResetLinkCopied => 'Reset-Link in Zwischenablage kopiert';

  @override
  String get adminResetLinkFailed => 'Reset-Link konnte nicht erstellt werden';

  @override
  String adminUserDeleted(Object username) {
    return 'Benutzer $username geloescht';
  }

  @override
  String get adminDeleteUserFailed => 'Benutzer konnte nicht geloescht werden';

  @override
  String get adminConvertedStudent => 'Benutzer zum Schueler umgewandelt';

  @override
  String get adminConvertedParent => 'Benutzer zum Elternteil umgewandelt';

  @override
  String get adminConvertedTeacher => 'Benutzer zum Lehrer umgewandelt';

  @override
  String get adminStudentCreated => 'Schueler erfolgreich erstellt';

  @override
  String get adminParentCreated => 'Eltern erfolgreich erstellt';

  @override
  String get adminTeacherCreated => 'Lehrer erfolgreich erstellt';

  @override
  String get adminDeleteUserTitle => 'Benutzer loeschen';

  @override
  String adminDeleteUserMessage(Object username) {
    return '$username loeschen? Dies kann nicht rueckgaengig gemacht werden.';
  }

  @override
  String get adminUsernameRequired => 'Bitte Benutzernamen eingeben';

  @override
  String get adminFullNameRequired => 'Bitte vollen Namen eingeben';

  @override
  String get adminPassword => 'Passwort';

  @override
  String get adminNewPasswordOptional => 'Neues Passwort (optional)';

  @override
  String get adminPasswordRequired => 'Bitte Passwort eingeben';

  @override
  String get adminGeneratePassword => 'Passwort generieren';

  @override
  String get adminEmailOptional => 'E-Mail (optional)';

  @override
  String get adminPhoneOptional => 'Telefon (optional)';

  @override
  String get adminRoleAdmin => 'Admin';

  @override
  String get adminConvertRole => 'In Rolle umwandeln:';

  @override
  String get adminCopyCredentials => 'Zugangsdaten kopieren';

  @override
  String get adminCredentialsRequired =>
      'Bitte zuerst Benutzername und Passwort ausfuellen';

  @override
  String get adminCredentialsCopied => 'Zugangsdaten kopiert';

  @override
  String adminMakeStudentTitle(Object username) {
    return '$username zum Schueler machen';
  }

  @override
  String adminMakeParentTitle(Object username) {
    return '$username zum Elternteil machen';
  }

  @override
  String adminMakeTeacherTitle(Object username) {
    return '$username zum Lehrer machen';
  }

  @override
  String get adminMakeTeacherNote => 'Dies gibt dem Benutzer Lehrerrechte.';

  @override
  String get adminBirthdayLabel => 'Geburtstag (JJJJ-MM-TT)';

  @override
  String get adminBirthdayHint => '2010-01-15';

  @override
  String get adminBirthdayFormat => 'Format: JJJJ-MM-TT';

  @override
  String get adminConvert => 'Umwandeln';

  @override
  String get adminSelectStudentsLabel =>
      'Schueler auswaehlen (mindestens einen):';

  @override
  String get adminSelectChildrenLabel => 'Kinder auswaehlen (mindestens ein):';

  @override
  String get adminSearchStudents => 'Schueler suchen';

  @override
  String get adminNoStudents => 'Keine Schueler gefunden';

  @override
  String get adminSelectStudentRequired =>
      'Mindestens ein Schueler erforderlich';

  @override
  String get dashboardNoStudents => 'Keine Schueler verfuegbar.';

  @override
  String get dashboardTitle => 'Uebersicht';

  @override
  String get dashboardTeacherFeeds => 'Lehrer-Feeds';

  @override
  String get dashboardNoTeacherFeeds => 'Noch keine Lehrer-Feeds.';

  @override
  String get dashboardSchoolFeed => 'Schul-Feed';

  @override
  String get dashboardNoSchoolFeed => 'Noch kein Schul-Feed.';

  @override
  String get dashboardGroupFeeds => 'Gruppen-Feeds';

  @override
  String get dashboardNoGroupFeeds => 'Noch keine Gruppen-Feeds.';

  @override
  String get dashboardOwnerSchool => 'Schule';

  @override
  String get dashboardOwnerTeacher => 'Lehrer';

  @override
  String get dashboardOwnerGroup => 'Gruppe';

  @override
  String get dashboardStudentLabel => 'Schueler:';

  @override
  String get dashboardChildLabel => 'Kind:';

  @override
  String get dashboardNoActiveHometasks => 'Keine aktiven Hausaufgaben.';

  @override
  String get homeClearAppCacheTitle => 'App-Daten-Cache leeren';

  @override
  String get homeClearAppCacheBody =>
      'Dies entfernt zwischengespeicherte Nachrichten, Feeds, Hausaufgaben und Profildaten.';

  @override
  String get homeAppCacheCleared => 'App-Daten-Cache geleert.';

  @override
  String get homeClearMediaCacheTitle => 'Medien-Cache leeren';

  @override
  String get homeClearMediaCacheBody =>
      'Dies entfernt zwischengespeicherte Bilder und Mediendateien.';

  @override
  String get homeMediaCacheCleared => 'Medien-Cache geleert.';

  @override
  String get homeLogoutTitle => 'Abmelden';

  @override
  String get homeLogoutBody => 'Moechten Sie sich wirklich abmelden?';

  @override
  String get homeMenuTooltip => 'Menue';

  @override
  String homeRolesLabel(Object roles) {
    return 'Rollen: $roles';
  }

  @override
  String get homeProfileInfo => 'Ihre Profilinformationen';

  @override
  String get commonClear => 'Leeren';

  @override
  String get commonLogout => 'Abmelden';

  @override
  String get commonNotifications => 'Benachrichtigungen';

  @override
  String get commonProfile => 'Profil';

  @override
  String get commonUserManagement => 'Benutzerverwaltung';

  @override
  String get commonTheme => 'Design';

  @override
  String get commonSystem => 'System';

  @override
  String get commonLight => 'Hell';

  @override
  String get commonDark => 'Dunkel';

  @override
  String get commonDashboard => 'Uebersicht';

  @override
  String get commonHometasks => 'Hausaufgaben';

  @override
  String get commonFeeds => 'Feeds';

  @override
  String get commonChats => 'Chats';

  @override
  String get commonUsername => 'Benutzername';

  @override
  String get commonPassword => 'Passwort';

  @override
  String get commonFullName => 'Voller Name';

  @override
  String get commonEmailOptional => 'E-Mail (optional)';

  @override
  String get commonPhoneOptional => 'Telefon (optional)';

  @override
  String get commonConfirmPassword => 'Passwort bestaetigen';

  @override
  String get commonBackToLogin => 'Zurueck zur Anmeldung';

  @override
  String get commonOk => 'OK';

  @override
  String get commonErrorTitle => 'Fehler';

  @override
  String get registerRoleStudent => 'Schueler';

  @override
  String get registerRoleParent => 'Elternteil';

  @override
  String get registerRoleTeacher => 'Lehrer';

  @override
  String get registerInvalidTokenTitle => 'Ungueltiger Registrierungs-Token';

  @override
  String get registerInvalidTokenMessage =>
      'Dieser Registrierungslink ist abgelaufen oder wurde bereits verwendet.';

  @override
  String get registerGoToLogin => 'Zur Anmeldung';

  @override
  String registerTitle(Object role) {
    return 'Registrieren als $role';
  }

  @override
  String get registerParentOf => 'Sie werden als Elternteil registriert fuer:';

  @override
  String get registerComplete => 'Registrierung abschliessen';

  @override
  String get registerUsernameRequired => 'Bitte Benutzernamen eingeben';

  @override
  String get registerUsernameMin =>
      'Benutzername muss mindestens 3 Zeichen haben';

  @override
  String get registerFullNameRequired => 'Bitte vollen Namen eingeben';

  @override
  String get registerBirthdayLabel => 'Geburtstag (JJJJ-MM-TT)';

  @override
  String get registerBirthdayHint => '2010-01-31';

  @override
  String get registerBirthdayRequired => 'Bitte Geburtstag eingeben';

  @override
  String get registerBirthdayFormat => 'Format: JJJJ-MM-TT';

  @override
  String get registerPasswordRequired => 'Bitte Passwort eingeben';

  @override
  String get registerPasswordMin => 'Passwort muss mindestens 6 Zeichen haben';

  @override
  String get registerConfirmRequired => 'Bitte Passwort bestaetigen';

  @override
  String get registerPasswordsMismatch => 'Passwoerter stimmen nicht ueberein';

  @override
  String get registerButton => 'Registrieren';

  @override
  String get registerLoginFailed => 'Anmeldung fehlgeschlagen';

  @override
  String get registerFailed => 'Registrierung fehlgeschlagen';

  @override
  String registerNetworkError(Object error) {
    return 'Netzwerkfehler: $error';
  }

  @override
  String get registerValidateFailed => 'Token konnte nicht validiert werden';

  @override
  String resetErrorValidating(Object error) {
    return 'Fehler beim Validieren des Tokens: $error';
  }

  @override
  String get resetSuccessTitle => 'Erfolg';

  @override
  String get resetSuccessMessage =>
      'Ihr Passwort wurde erfolgreich zurueckgesetzt. Sie koennen sich jetzt mit dem neuen Passwort anmelden.';

  @override
  String get resetFailed => 'Passwort konnte nicht zurueckgesetzt werden';

  @override
  String resetErrorGeneric(Object error) {
    return 'Fehler: $error';
  }

  @override
  String get resetTitle => 'Passwort zuruecksetzen';

  @override
  String get resetValidating => 'Reset-Token wird geprueft...';

  @override
  String get resetInvalidTitle => 'Ungueltiger oder abgelaufener Link';

  @override
  String get resetInvalidMessage =>
      'Dieser Link zum Zuruecksetzen ist ungueltig oder abgelaufen. Bitte fordern Sie einen neuen Link an.';

  @override
  String get resetSetNewPassword => 'Neues Passwort setzen';

  @override
  String resetForUser(Object username) {
    return 'fuer Benutzer: $username';
  }

  @override
  String get resetNewPasswordLabel => 'Neues Passwort';

  @override
  String get resetPasswordRequired => 'Bitte Passwort eingeben';

  @override
  String get resetPasswordMin => 'Passwort muss mindestens 6 Zeichen haben';

  @override
  String get resetConfirmPasswordLabel => 'Passwort bestaetigen';

  @override
  String get resetConfirmRequired => 'Bitte Passwort bestaetigen';

  @override
  String get loginTitle => 'Anmelden';

  @override
  String get loginForgotTitle => 'Passwort vergessen';

  @override
  String get loginForgotPrompt =>
      'Geben Sie Ihren Benutzernamen ein, um das Zuruecksetzen anzufordern.';

  @override
  String get loginUsernameRequired => 'Bitte Benutzernamen eingeben';

  @override
  String get loginPasswordRequired => 'Bitte Passwort eingeben';

  @override
  String get loginButton => 'Anmelden';

  @override
  String get loginForgotPassword => 'Passwort vergessen?';

  @override
  String get loginRequestSentTitle => 'Anfrage gesendet';

  @override
  String get loginRequestSentMessage =>
      'Anfrage zum Zuruecksetzen wurde gesendet.';

  @override
  String get loginRequestFailedMessage =>
      'Anfrage zum Zuruecksetzen fehlgeschlagen. Bitte erneut versuchen.';

  @override
  String loginErrorMessage(Object error) {
    return 'Ein Fehler ist aufgetreten: $error';
  }

  @override
  String get loginFailed => 'Anmeldung fehlgeschlagen';

  @override
  String get commonRetry => 'Erneut versuchen';

  @override
  String get hometasksNone => 'Keine Hausaufgaben gefunden.';

  @override
  String get hometasksUpdateOrderFailed =>
      'Reihenfolge konnte nicht aktualisiert werden.';

  @override
  String hometasksAssignTitle(Object studentName) {
    return 'Hausaufgabe an $studentName zuweisen';
  }

  @override
  String get hometasksTitleLabel => 'Titel';

  @override
  String get hometasksTitleRequired => 'Titel ist erforderlich';

  @override
  String get hometasksDescriptionLabel => 'Beschreibung (optional)';

  @override
  String get hometasksDueDate => 'Faelligkeitsdatum';

  @override
  String get hometasksNoDueDate => 'Kein Faelligkeitsdatum';

  @override
  String get hometasksRepeatLabel => 'Wiederholen';

  @override
  String get hometasksRepeatNone => 'Keine Wiederholung';

  @override
  String get hometasksRepeatDaily => 'Taeglich';

  @override
  String get hometasksRepeatWeekly => 'Woechentlich';

  @override
  String get hometasksRepeatCustom => 'Benutzerdefiniertes Intervall';

  @override
  String get hometasksRepeatEveryDays => 'Alle (Tage) wiederholen';

  @override
  String get hometasksRepeatCustomInvalid =>
      'Bitte positive Anzahl Tage eingeben';

  @override
  String get hometasksTypeLabel => 'Aufgabentyp';

  @override
  String get hometasksTypeSimple => 'Einfach';

  @override
  String get hometasksTypeChecklist => 'Checkliste';

  @override
  String get hometasksTypeProgress => 'Fortschritt';

  @override
  String get hometasksChecklistItems => 'Checklistenpunkte';

  @override
  String get hometasksProgressItems => 'Fortschrittspunkte';

  @override
  String hometasksItemLabel(Object index) {
    return 'Element $index';
  }

  @override
  String get hometasksRequired => 'Erforderlich';

  @override
  String hometasksAddAtLeastOne(Object typeLabel) {
    return 'Mindestens ein $typeLabel-Element hinzufuegen.';
  }

  @override
  String get hometasksRepeatIntervalInvalid => 'Gueltiges Intervall eingeben.';

  @override
  String get hometasksAssigned => 'Hausaufgabe zugewiesen.';

  @override
  String get hometasksAssignFailed =>
      'Hausaufgabe konnte nicht zugewiesen werden.';

  @override
  String get hometasksAssignAction => 'Zuweisen';

  @override
  String get hometasksActive => 'Aktiv';

  @override
  String get hometasksArchive => 'Archiv';

  @override
  String get hometasksAssign => 'Hausaufgabe zuweisen';

  @override
  String get hometasksAssignToGroup => 'An Gruppe zuweisen';

  @override
  String get hometasksSelectGroupTitle => 'Gruppe auswaehlen';

  @override
  String hometasksAssignTitleGroup(Object groupName) {
    return 'Hausaufgabe an Gruppe $groupName zuweisen';
  }

  @override
  String get hometasksApplyGroupChangesTitle => 'Gruppenaenderungen anwenden';

  @override
  String get hometasksApplyGroupChangesMessage =>
      'Diese Aenderungen auf alle Schueler dieser Gruppen-Hausaufgabe anwenden?';

  @override
  String get hometasksApplyOnlyThisStudent => 'Nur dieser Schueler';

  @override
  String get hometasksApplyToGroup => 'Auf Gruppe anwenden';

  @override
  String get hometasksArchiveGroupTitle => 'Gruppen-Hausaufgabe archivieren';

  @override
  String get hometasksArchiveGroupMessage =>
      'Nur diese Schueleraufgabe archivieren oder alle Aufgaben in dieser Gruppenzuweisung?';

  @override
  String get hometasksArchiveForGroup => 'Fuer Gruppe archivieren';

  @override
  String get hometasksReopenGroupTitle => 'Gruppen-Hausaufgabe wiedereroeffnen';

  @override
  String get hometasksReopenGroupMessage =>
      'Nur diese Schueleraufgabe wiedereroeffnen oder alle Aufgaben in dieser Gruppenzuweisung?';

  @override
  String get hometasksReopenForGroup => 'Fuer Gruppe wiedereroeffnen';

  @override
  String get feedsGroupFeeds => 'Gruppen-Feeds';

  @override
  String get feedsOwnerGroup => 'Gruppe';

  @override
  String get profileCreateGroup => 'Gruppe erstellen';

  @override
  String get profileGroupsTitle => 'Gruppen';

  @override
  String get profileNoGroupsYet => 'Noch keine Gruppen';

  @override
  String get profileStudentsLabel => 'Schueler';

  @override
  String get profileStatusArchived => 'Archiviert';

  @override
  String get profileStatusActive => 'Aktiv';

  @override
  String get profileEditMembers => 'Mitglieder bearbeiten';

  @override
  String get profileArchiveGroup => 'Archivieren';

  @override
  String get profileUnarchiveGroup => 'Wiederherstellen';

  @override
  String get profileDeleteGroupTitle => 'Gruppe loeschen';

  @override
  String get profileDeleteGroupMessage =>
      'Diese Gruppe dauerhaft loeschen? Feed- und Gruppenverlauf werden entfernt.';

  @override
  String get profileAddStudentsFirstToCreateGroup =>
      'Fuegen Sie zuerst Schueler hinzu, um eine Gruppe zu erstellen';

  @override
  String get profileGroupNameLabel => 'Gruppenname';

  @override
  String get profileFilterStudentsLabel => 'Schueler filtern';

  @override
  String get profileNoStudentsFound => 'Keine Schueler gefunden';

  @override
  String get profileEnterGroupNameAndStudents =>
      'Gruppennamen eingeben und Schueler auswaehlen';

  @override
  String get profileCreateAction => 'Erstellen';

  @override
  String get profileEditGroupTitle => 'Gruppe bearbeiten';

  @override
  String get profileArchivedGroupLabel => 'Gruppe archiviert';

  @override
  String get profileGroupCreatedSuccess => 'Gruppe erfolgreich erstellt';

  @override
  String get profileGroupUpdatedSuccess => 'Gruppe erfolgreich aktualisiert';

  @override
  String get profileGroupDeletedSuccess => 'Gruppe erfolgreich geloescht';

  @override
  String get profileGroupCreateFailed => 'Gruppe konnte nicht erstellt werden';

  @override
  String get profileGroupUpdateFailed =>
      'Gruppe konnte nicht aktualisiert werden';

  @override
  String get profileGroupDeleteFailed => 'Gruppe konnte nicht geloescht werden';
}
