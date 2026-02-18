// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Russian (`ru`).
class AppLocalizationsRu extends AppLocalizations {
  AppLocalizationsRu([String locale = 'ru']) : super(locale);

  @override
  String get appTitle => 'Музыкальная школа на Томас-Манн-Плац';

  @override
  String get languageTitle => 'Язык';

  @override
  String get languageGerman => 'Немецкий';

  @override
  String get languageEnglish => 'Английский';

  @override
  String get languageRussian => 'Русский';

  @override
  String get securityTitle => 'Безопасность';

  @override
  String get changePasswordTitle => 'Сменить пароль';

  @override
  String get changePasswordSubtitle => 'Обновить пароль учетной записи';

  @override
  String get consentTitle => 'Согласие на обработку персональных данных';

  @override
  String get consentAgree => 'Согласен';

  @override
  String get consentGuardianConfirm =>
      'Если вы регистрируете ребенка, вы подтверждаете, что являетесь родителем, законным представителем или иным уполномоченным лицом.';

  @override
  String get consentRequired =>
      'Пожалуйста, подтвердите согласие, чтобы продолжить';

  @override
  String get consentFallback =>
      'Согласие (кратко)\n- Только материалы для обучения музыке.\n- Вы можете редактировать или удалить профиль.\n- Данные защищены TLS.\n- Передача только для отправки email (SendGrid).\nЕсли регистрируете ребенка, подтверждаете, что вы родитель/опекун или уполномочены.';

  @override
  String get commonSettings => 'Настройки';

  @override
  String get commonOpen => 'Открыть';

  @override
  String get commonPost => 'Опубликовать';

  @override
  String get commonEdit => 'Редактировать';

  @override
  String get commonReply => 'Ответить';

  @override
  String get commonDelete => 'Удалить';

  @override
  String get commonAdd => 'Добавить';

  @override
  String get commonSave => 'Сохранить';

  @override
  String get commonCancel => 'Отмена';

  @override
  String get commonRefresh => 'Обновить';

  @override
  String get commonClose => 'Закрыть';

  @override
  String get commonDownload => 'Скачать';

  @override
  String get commonDownloadSourceFile => 'Скачать исходный файл';

  @override
  String get commonDownloadStarted => 'Загрузка начата';

  @override
  String get commonDownloadFailed => 'Загрузка не удалась';

  @override
  String commonSavedToPath(Object path) {
    return 'Сохранено в $path';
  }

  @override
  String get commonBack5s => 'Назад 5с';

  @override
  String get commonForward5s => 'Вперед 5с';

  @override
  String get commonBold => 'Жирный';

  @override
  String get commonItalic => 'Курсив';

  @override
  String get commonUnderline => 'Подчеркнутый';

  @override
  String get commonStrike => 'Зачеркнутый';

  @override
  String get commonSubscript => 'Нижний индекс';

  @override
  String get commonSuperscript => 'Верхний индекс';

  @override
  String get commonTitle => 'Заголовок';

  @override
  String get commonSend => 'Отправить';

  @override
  String get commonApply => 'Применить';

  @override
  String get commonInsertLink => 'Вставить ссылку';

  @override
  String get commonUrl => 'URL';

  @override
  String get commonAttachFile => 'Прикрепить файл';

  @override
  String get commonAudio => 'Аудио';

  @override
  String get commonVideo => 'Видео';

  @override
  String get commonImage => 'Изображение';

  @override
  String get commonFile => 'Файл';

  @override
  String get commonVoiceMessage => 'Голосовое сообщение';

  @override
  String get commonTapToPlay => 'Нажмите чтобы воспроизвести';

  @override
  String get commonLoading => 'Загрузка';

  @override
  String get commonFullscreen => 'Полноэкранный режим';

  @override
  String get commonExitFullscreen => 'Выйти из полноэкранного режима';

  @override
  String get commonPrevious => 'Предыдущая страница';

  @override
  String get commonNext => 'Следующая страница';

  @override
  String get commonClearSearch => 'Очистить поиск';

  @override
  String get commonNoResults => 'Ничего не найдено';

  @override
  String get commonTypeToFilter => 'Введите для фильтра...';

  @override
  String get commonRequired => 'Обязательно';

  @override
  String commonErrorMessage(Object error) {
    return 'Ошибка: $error';
  }

  @override
  String get commonCreated => 'создан';

  @override
  String get commonUpdated => 'обновлен';

  @override
  String get commonCreate => 'создать';

  @override
  String get commonUpdate => 'обновить';

  @override
  String commonVideoLabel(Object filename) {
    return 'Видео: $filename';
  }

  @override
  String get feedsTitle => 'Ленты';

  @override
  String get feedsNone => 'Нет доступных лент';

  @override
  String get feedsSchool => 'Школа';

  @override
  String get feedsTeacherFeeds => 'Ленты учителей';

  @override
  String get feedsOwnerSchool => 'Школа';

  @override
  String get feedsOwnerTeacher => 'Учитель';

  @override
  String get feedsNewPostTooltip => 'Новый пост';

  @override
  String get feedsMarkAllRead => 'Пометить все как прочитанные';

  @override
  String get feedsImportant => 'Важно';

  @override
  String get feedsLatest => 'Последние';

  @override
  String get feedsNoImportantPosts => 'Пока нет важных постов.';

  @override
  String get feedsAllPosts => 'Все посты';

  @override
  String get feedsNoPosts => 'Пока нет постов.';

  @override
  String feedsPostedAt(Object timestamp) {
    return 'Опубликовано $timestamp';
  }

  @override
  String feedsPostedEditedAt(Object timestamp) {
    return 'Опубликовано $timestamp · отредактировано';
  }

  @override
  String get feedsSubscriptionFailed => 'Не удалось обновить подписку';

  @override
  String get feedsDeleteDenied => 'У вас нет прав на удаление этого поста';

  @override
  String get feedsDeleteTitle => 'Удалить пост';

  @override
  String get feedsDeleteMessage =>
      'Вы уверены, что хотите удалить этот пост? Это действие нельзя отменить.';

  @override
  String get feedsDeleteFailed => 'Не удалось удалить пост';

  @override
  String get feedsDeleteCommentTitle => 'Удалить комментарий';

  @override
  String get feedsDeleteCommentMessage =>
      'Вы уверены, что хотите удалить этот комментарий? Это действие нельзя отменить.';

  @override
  String get feedsDeleteCommentFailed => 'Не удалось удалить комментарий';

  @override
  String feedsUnsupportedAttachment(Object type) {
    return 'Неподдерживаемое вложение: $type';
  }

  @override
  String get feedsAttachmentActions => 'Действия с вложением';

  @override
  String get feedsEditPost => 'Редактировать пост';

  @override
  String get feedsNewPost => 'Новый пост';

  @override
  String get feedsTextTools => 'Текстовые инструменты';

  @override
  String get feedsTextFormatting => 'Форматирование текста';

  @override
  String get feedsJustificationTools => 'Инструменты выравнивания';

  @override
  String get feedsListsPaddingTools => 'Инструменты списков и отступов';

  @override
  String get feedsAttachments => 'Вложения';

  @override
  String get feedsAllowComments => 'Разрешить комментарии';

  @override
  String get feedsMarkImportant => 'Отметить как важное';

  @override
  String get feedsUploadFailed => 'Не удалось загрузить медиа';

  @override
  String get feedsEditComment => 'Редактировать комментарий';

  @override
  String get feedsNewComment => 'Новый комментарий';

  @override
  String get feedsComments => 'Комментарии';

  @override
  String get feedsNoComments => 'Пока нет комментариев.';

  @override
  String get feedsAddComment => 'Добавить комментарий';

  @override
  String get feedsSubscribeComments => 'Подписаться на комментарии';

  @override
  String get feedsUnsubscribeComments => 'Отписаться от комментариев';

  @override
  String feedsAttachmentInline(Object typeLabel) {
    return '$typeLabel (в тексте)';
  }

  @override
  String get feedsSettingsTitle => 'Настройки ленты';

  @override
  String get feedsAllowStudentPosts => 'Разрешить посты учеников';

  @override
  String get feedsAutoSubscribe => 'Автоподписка на новые посты';

  @override
  String get feedsNotifyNewPosts => 'Уведомлять о новых постах';

  @override
  String get feedsParagraphType => 'Тип абзаца';

  @override
  String get feedsFont => 'Шрифт';

  @override
  String get feedsSize => 'Размер';

  @override
  String get feedsAttach => 'Прикрепить';

  @override
  String get feedsPostTitle => 'Пост';

  @override
  String feedsUnsupportedEmbed(Object data) {
    return 'Неподдерживаемое встраивание: $data';
  }

  @override
  String get feedsUntitledPost => 'Без названия';

  @override
  String get videoWebLimited =>
      'Веб-плеер видео ограничен. Вы можете скачать файл или открыть его отдельно.';

  @override
  String get videoErrorTitle => 'Ошибка видео';

  @override
  String get videoLoadFailed => 'Не удалось загрузить видео';

  @override
  String get voiceRecordFailed => 'Не удалось записать аудио';

  @override
  String get voiceRecordUnavailable => 'Запись голоса недоступна';

  @override
  String voiceRecordError(Object error) {
    return 'Ошибка записи: $error';
  }

  @override
  String get voiceStopRecording => 'Остановить запись';

  @override
  String get voiceRecord => 'Записать голос';

  @override
  String get hometasksChecklistUpdateFailed =>
      'Не удалось обновить пункт списка.';

  @override
  String get hometasksItemsSaved => 'Элементы успешно сохранены.';

  @override
  String get hometasksItemsSaveFailed => 'Не удалось сохранить элементы.';

  @override
  String get hometasksProgressUpdateFailed => 'Не удалось обновить прогресс.';

  @override
  String get hometasksUpdateFailed => 'Не удалось обновить домашнее задание.';

  @override
  String hometasksTeacherFallback(Object teacherId) {
    return 'Учитель #$teacherId';
  }

  @override
  String get hometasksItemNameRequired => 'Все элементы должны иметь название.';

  @override
  String hometasksDueLabel(Object date) {
    return 'Срок: $date';
  }

  @override
  String get hometasksEditItems => 'Редактировать элементы';

  @override
  String get hometasksMarkCompleted => 'Отметить как выполнено';

  @override
  String get hometasksMarkAccomplished => 'Отметить как завершено';

  @override
  String get hometasksReturnActive => 'Вернуть в активные';

  @override
  String get hometasksMarkUncompleted => 'Отметить как не выполнено';

  @override
  String get hometasksProgressNotStarted => 'Не начато';

  @override
  String get hometasksProgressInProgress => 'В процессе';

  @override
  String get hometasksProgressNearlyDone => 'Почти готово';

  @override
  String get hometasksProgressAlmostComplete => 'Почти завершено';

  @override
  String get hometasksProgressComplete => 'Завершено';

  @override
  String hometasksItemHint(Object index) {
    return 'Элемент $index';
  }

  @override
  String get hometasksAddItem => 'Добавить элемент';

  @override
  String get notificationsTitle => 'Уведомления';

  @override
  String get notificationsUnread => 'Непрочитанные';

  @override
  String get notificationsNone => 'Нет уведомлений';

  @override
  String get chatNoTeachers => 'Учителя не найдены';

  @override
  String get chatSelectTeacher => 'Выбрать учителя';

  @override
  String get chatStartFailed => 'Не удалось начать чат';

  @override
  String get chatAdminOpenFailed => 'Не удалось открыть чат с администратором';

  @override
  String get chatDeleteMessageTitle => 'Удалить сообщение';

  @override
  String get chatDeleteMessageBody =>
      'Вы уверены, что хотите удалить это сообщение? Это действие нельзя отменить.';

  @override
  String get chatDeleteMessageFailed => 'Не удалось удалить сообщение';

  @override
  String get chatEditMessage => 'Редактировать сообщение';

  @override
  String get chatMessageActions => 'Действия с сообщением';

  @override
  String get chatMessages => 'Сообщения';

  @override
  String get chatChats => 'Чаты';

  @override
  String get chatAdmin => 'Админ';

  @override
  String get chatNoConversations => 'Пока нет диалогов';

  @override
  String get chatStartConversation => 'Начать разговор';

  @override
  String get chatAdministration => 'Администрация';

  @override
  String get chatUnknownUser => 'Неизвестно';

  @override
  String get chatNoMessages => '(Нет сообщений)';

  @override
  String get chatTeachers => 'Учителя';

  @override
  String get chatNewChat => 'Новый чат';

  @override
  String get chatThreadNotFound => 'Чат создан, но поток не найден';

  @override
  String get chatStartNew => 'Начать новый чат';

  @override
  String get chatSearchUsers => 'Поиск пользователей...';

  @override
  String get profileAdminControls => 'Админ-панель';

  @override
  String get profileAdminAccess => 'Доступ администратора';

  @override
  String get profileAdminAccessSubtitle =>
      'Выдать или отозвать права администратора';

  @override
  String get profileAdminAccessUpdate => 'Обновить доступ администратора';

  @override
  String get profileRoleManagement => 'Управление ролями';

  @override
  String get profileMakeStudent => 'Сделать учеником';

  @override
  String get profileMakeParent => 'Сделать родителем';

  @override
  String get profileMakeTeacher => 'Сделать учителем';

  @override
  String get profileArchiveRoles => 'Архивировать роли';

  @override
  String get profileSectionInfo => 'Информация профиля';

  @override
  String get profileSectionAdditional => 'Дополнительная информация';

  @override
  String get profileTitleProfile => 'Профиль';

  @override
  String get profileTitleUserProfile => 'Профиль пользователя';

  @override
  String get profileEditTooltip => 'Редактировать профиль';

  @override
  String get profileAdminViewLabel => 'Админ-режим';

  @override
  String get profileEmailLabel => 'Email';

  @override
  String get profilePhoneLabel => 'Телефон';

  @override
  String get profileMemberSinceLabel => 'В системе с';

  @override
  String get profileNotSet => 'Не указано';

  @override
  String get profileUnknown => 'Неизвестно';

  @override
  String get profileRolesTitle => 'Роли';

  @override
  String get profileBirthdayLabel => 'Дата рождения';

  @override
  String get profileBirthdayInputLabel => 'Дата рождения (ГГГГ-ММ-ДД)';

  @override
  String get profileGenerateParentLink => 'Создать ссылку регистрации родителя';

  @override
  String get profileMyChildrenTitle => 'Мои дети';

  @override
  String get profileChildrenSubtitle =>
      'Нажмите на ребенка, чтобы посмотреть или редактировать данные';

  @override
  String get profileActionMessage => 'Сообщение';

  @override
  String get profileManageStudentsTitle => 'Управление учениками';

  @override
  String get profileActionAddStudent => 'Добавить ученика';

  @override
  String get profileManageStudentsSubtitle =>
      'Управляйте учениками, закрепленными за вами';

  @override
  String get profileNoStudentsAssigned => 'Пока нет назначенных учеников';

  @override
  String get profileActionViewProfile => 'Открыть профиль';

  @override
  String get profileActionAssignHometask => 'Назначить задание';

  @override
  String get profileActionRemoveStudent => 'Удалить из учеников';

  @override
  String get profileGenerateStudentLink => 'Создать ссылку регистрации ученика';

  @override
  String get profileTeachersTitle => 'Учителя';

  @override
  String get profileTeachersSubtitle =>
      'Нажмите, чтобы открыть профиль учителя или уйти от учителя';

  @override
  String get profileNoTeachersAssigned => 'Пока нет назначенных учителей';

  @override
  String get profileActionLeaveTeacher => 'Покинуть учителя';

  @override
  String get profileArchiveStudent => 'Архивировать ученика';

  @override
  String get profileUnarchiveStudent => 'Восстановить ученика';

  @override
  String get profileArchiveParent => 'Архивировать родителя';

  @override
  String get profileUnarchiveParent => 'Восстановить родителя';

  @override
  String get profileArchiveTeacher => 'Архивировать учителя';

  @override
  String get profileUnarchiveTeacher => 'Восстановить учителя';

  @override
  String get profileParentTools => 'Инструменты для родителей';

  @override
  String get profileAddChildren => 'Добавить детей';

  @override
  String get adminPanelTitle => 'Админ-панель';

  @override
  String get adminUserManagement => 'Управление пользователями';

  @override
  String get adminSearchUsers =>
      'Поиск по имени пользователя или полному имени';

  @override
  String get adminNoUsers => 'Пользователи не найдены';

  @override
  String get adminAddUser => 'Добавить пользователя';

  @override
  String get adminUser => 'Пользователь';

  @override
  String get adminStudent => 'Ученик';

  @override
  String get adminParent => 'Родитель';

  @override
  String get adminTeacher => 'Учитель';

  @override
  String get adminAddStudent => 'Добавить ученика';

  @override
  String get adminAddParent => 'Добавить родителя';

  @override
  String get adminAddTeacher => 'Добавить учителя';

  @override
  String adminShowingRange(Object start, Object end, Object total) {
    return 'Показано $start-$end из $total';
  }

  @override
  String get adminRows => 'Строк:';

  @override
  String get adminResetLink => 'Ссылка сброса';

  @override
  String get adminViewProfile => 'Просмотр профиля';

  @override
  String get adminEditUser => 'Редактировать';

  @override
  String get adminDeleteUser => 'Удалить';

  @override
  String get adminFullName => 'Полное имя';

  @override
  String get adminUsername => 'Имя пользователя';

  @override
  String get adminActions => 'Действия';

  @override
  String get adminLoadUsersFailed => 'Не удалось загрузить пользователей';

  @override
  String adminUserSaved(Object action) {
    return 'Пользователь $action успешно';
  }

  @override
  String adminUserSaveFailed(Object action) {
    return 'Не удалось $action пользователя';
  }

  @override
  String get adminResetLinkGenerated => 'Ссылка сброса создана';

  @override
  String adminResetLinkFor(Object username) {
    return 'Ссылка сброса для $username:';
  }

  @override
  String adminResetLinkExpires(Object expires) {
    return 'Истекает: $expires';
  }

  @override
  String get adminCopyLink => 'Копировать ссылку';

  @override
  String get adminResetLinkCopied => 'Ссылка сброса скопирована в буфер обмена';

  @override
  String get adminResetLinkFailed => 'Не удалось создать ссылку сброса';

  @override
  String adminUserDeleted(Object username) {
    return 'Пользователь $username удален';
  }

  @override
  String get adminDeleteUserFailed => 'Не удалось удалить пользователя';

  @override
  String get adminConvertedStudent => 'Пользователь преобразован в ученика';

  @override
  String get adminConvertedParent => 'Пользователь преобразован в родителя';

  @override
  String get adminConvertedTeacher => 'Пользователь преобразован в учителя';

  @override
  String get adminStudentCreated => 'Ученик успешно создан';

  @override
  String get adminParentCreated => 'Родитель успешно создан';

  @override
  String get adminTeacherCreated => 'Учитель успешно создан';

  @override
  String get adminDeleteUserTitle => 'Удалить пользователя';

  @override
  String adminDeleteUserMessage(Object username) {
    return 'Удалить $username? Это действие нельзя отменить.';
  }

  @override
  String get adminUsernameRequired => 'Введите имя пользователя';

  @override
  String get adminFullNameRequired => 'Введите полное имя';

  @override
  String get adminPassword => 'Пароль';

  @override
  String get adminNewPasswordOptional => 'Новый пароль (необязательно)';

  @override
  String get adminPasswordRequired => 'Введите пароль';

  @override
  String get adminGeneratePassword => 'Сгенерировать пароль';

  @override
  String get adminEmailOptional => 'E-mail (необязательно)';

  @override
  String get adminPhoneOptional => 'Телефон (необязательно)';

  @override
  String get adminRoleAdmin => 'Админ';

  @override
  String get adminConvertRole => 'Преобразовать в роль:';

  @override
  String get adminCopyCredentials => 'Копировать данные';

  @override
  String get adminCredentialsRequired =>
      'Сначала заполните имя пользователя и пароль';

  @override
  String get adminCredentialsCopied => 'Данные скопированы';

  @override
  String adminMakeStudentTitle(Object username) {
    return 'Сделать $username учеником';
  }

  @override
  String adminMakeParentTitle(Object username) {
    return 'Сделать $username родителем';
  }

  @override
  String adminMakeTeacherTitle(Object username) {
    return 'Сделать $username учителем';
  }

  @override
  String get adminMakeTeacherNote => 'Это даст пользователю права учителя.';

  @override
  String get adminBirthdayLabel => 'Дата рождения (ГГГГ-ММ-ДД)';

  @override
  String get adminBirthdayHint => '2010-01-15';

  @override
  String get adminBirthdayFormat => 'Формат: ГГГГ-ММ-ДД';

  @override
  String get adminConvert => 'Преобразовать';

  @override
  String get adminSelectStudentsLabel => 'Выберите учеников (минимум одного):';

  @override
  String get adminSelectChildrenLabel => 'Выберите детей (минимум одного):';

  @override
  String get adminSearchStudents => 'Поиск учеников';

  @override
  String get adminNoStudents => 'Ученики не найдены';

  @override
  String get adminSelectStudentRequired => 'Нужен минимум один ученик';

  @override
  String get dashboardNoStudents => 'Нет доступных учеников.';

  @override
  String get dashboardTitle => 'Панель';

  @override
  String get dashboardTeacherFeeds => 'Ленты учителей';

  @override
  String get dashboardNoTeacherFeeds => 'Пока нет лент учителей.';

  @override
  String get dashboardSchoolFeed => 'Лента школы';

  @override
  String get dashboardNoSchoolFeed => 'Пока нет ленты школы.';

  @override
  String get dashboardOwnerSchool => 'Школа';

  @override
  String get dashboardOwnerTeacher => 'Учитель';

  @override
  String get dashboardStudentLabel => 'Ученик:';

  @override
  String get dashboardChildLabel => 'Ребенок:';

  @override
  String get dashboardNoActiveHometasks => 'Нет активных домашних заданий.';

  @override
  String get homeClearAppCacheTitle => 'Очистить кэш данных приложения';

  @override
  String get homeClearAppCacheBody =>
      'Это удалит кэшированные сообщения, ленты, задания и данные профиля.';

  @override
  String get homeAppCacheCleared => 'Кэш данных приложения очищен.';

  @override
  String get homeClearMediaCacheTitle => 'Очистить кэш медиа';

  @override
  String get homeClearMediaCacheBody =>
      'Это удалит кэшированные изображения и медиафайлы.';

  @override
  String get homeMediaCacheCleared => 'Кэш медиа очищен.';

  @override
  String get homeLogoutTitle => 'Выйти';

  @override
  String get homeLogoutBody => 'Вы уверены, что хотите выйти?';

  @override
  String get homeMenuTooltip => 'Меню';

  @override
  String homeRolesLabel(Object roles) {
    return 'Роли: $roles';
  }

  @override
  String get homeProfileInfo => 'Информация вашего профиля';

  @override
  String get commonClear => 'Очистить';

  @override
  String get commonLogout => 'Выйти';

  @override
  String get commonNotifications => 'Уведомления';

  @override
  String get commonProfile => 'Профиль';

  @override
  String get commonUserManagement => 'Управление пользователями';

  @override
  String get commonTheme => 'Тема';

  @override
  String get commonSystem => 'Системная';

  @override
  String get commonLight => 'Светлая';

  @override
  String get commonDark => 'Темная';

  @override
  String get commonDashboard => 'Панель';

  @override
  String get commonHometasks => 'Домашние задания';

  @override
  String get commonFeeds => 'Ленты';

  @override
  String get commonChats => 'Чаты';

  @override
  String get commonUsername => 'Имя пользователя';

  @override
  String get commonPassword => 'Пароль';

  @override
  String get commonFullName => 'Полное имя';

  @override
  String get commonEmailOptional => 'Email (необязательно)';

  @override
  String get commonPhoneOptional => 'Телефон (необязательно)';

  @override
  String get commonConfirmPassword => 'Подтвердите пароль';

  @override
  String get commonBackToLogin => 'Назад ко входу';

  @override
  String get commonOk => 'ОК';

  @override
  String get commonErrorTitle => 'Ошибка';

  @override
  String get registerRoleStudent => 'Ученик';

  @override
  String get registerRoleParent => 'Родитель';

  @override
  String get registerRoleTeacher => 'Учитель';

  @override
  String get registerInvalidTokenTitle => 'Недействительный токен регистрации';

  @override
  String get registerInvalidTokenMessage =>
      'Эта ссылка регистрации просрочена или уже использована.';

  @override
  String get registerGoToLogin => 'Ко входу';

  @override
  String registerTitle(Object role) {
    return 'Регистрация как $role';
  }

  @override
  String get registerParentOf => 'Вы будете зарегистрированы как родитель для:';

  @override
  String get registerComplete => 'Завершите регистрацию';

  @override
  String get registerUsernameRequired => 'Введите имя пользователя';

  @override
  String get registerUsernameMin =>
      'Имя пользователя должно быть не короче 3 символов';

  @override
  String get registerFullNameRequired => 'Введите полное имя';

  @override
  String get registerBirthdayLabel => 'Дата рождения (ГГГГ-ММ-ДД)';

  @override
  String get registerBirthdayHint => '2010-01-31';

  @override
  String get registerBirthdayRequired => 'Введите дату рождения';

  @override
  String get registerBirthdayFormat => 'Формат: ГГГГ-ММ-ДД';

  @override
  String get registerPasswordRequired => 'Введите пароль';

  @override
  String get registerPasswordMin => 'Пароль должен быть не менее 6 символов';

  @override
  String get registerConfirmRequired => 'Подтвердите пароль';

  @override
  String get registerPasswordsMismatch => 'Пароли не совпадают';

  @override
  String get registerButton => 'Зарегистрироваться';

  @override
  String get registerLoginFailed => 'Вход не выполнен';

  @override
  String get registerFailed => 'Регистрация не удалась';

  @override
  String registerNetworkError(Object error) {
    return 'Ошибка сети: $error';
  }

  @override
  String get registerValidateFailed => 'Не удалось проверить токен';

  @override
  String resetErrorValidating(Object error) {
    return 'Ошибка проверки токена: $error';
  }

  @override
  String get resetSuccessTitle => 'Успех';

  @override
  String get resetSuccessMessage =>
      'Пароль успешно сброшен. Теперь вы можете войти с новым паролем.';

  @override
  String get resetFailed => 'Не удалось сбросить пароль';

  @override
  String resetErrorGeneric(Object error) {
    return 'Ошибка: $error';
  }

  @override
  String get resetTitle => 'Сброс пароля';

  @override
  String get resetValidating => 'Проверка токена сброса...';

  @override
  String get resetInvalidTitle => 'Недействительная или просроченная ссылка';

  @override
  String get resetInvalidMessage =>
      'Эта ссылка для сброса пароля недействительна или просрочена. Пожалуйста, запросите новую ссылку.';

  @override
  String get resetSetNewPassword => 'Установить новый пароль';

  @override
  String resetForUser(Object username) {
    return 'для пользователя: $username';
  }

  @override
  String get resetNewPasswordLabel => 'Новый пароль';

  @override
  String get resetPasswordRequired => 'Введите пароль';

  @override
  String get resetPasswordMin => 'Пароль должен быть не менее 6 символов';

  @override
  String get resetConfirmPasswordLabel => 'Подтвердите пароль';

  @override
  String get resetConfirmRequired => 'Подтвердите пароль';

  @override
  String get loginTitle => 'Вход';

  @override
  String get loginForgotTitle => 'Забыли пароль';

  @override
  String get loginForgotPrompt =>
      'Введите имя пользователя, чтобы запросить сброс пароля.';

  @override
  String get loginUsernameRequired => 'Введите имя пользователя';

  @override
  String get loginPasswordRequired => 'Введите пароль';

  @override
  String get loginButton => 'Войти';

  @override
  String get loginForgotPassword => 'Забыли пароль?';

  @override
  String get loginRequestSentTitle => 'Запрос отправлен';

  @override
  String get loginRequestSentMessage =>
      'Запрос на сброс пароля успешно отправлен.';

  @override
  String get loginRequestFailedMessage =>
      'Не удалось отправить запрос на сброс пароля. Попробуйте еще раз.';

  @override
  String loginErrorMessage(Object error) {
    return 'Произошла ошибка: $error';
  }

  @override
  String get loginFailed => 'Вход не выполнен';

  @override
  String get commonRetry => 'Повторить';

  @override
  String get hometasksNone => 'Домашние задания не найдены.';

  @override
  String get hometasksUpdateOrderFailed => 'Не удалось обновить порядок.';

  @override
  String hometasksAssignTitle(Object studentName) {
    return 'Назначить задание для $studentName';
  }

  @override
  String get hometasksTitleLabel => 'Название';

  @override
  String get hometasksTitleRequired => 'Название обязательно';

  @override
  String get hometasksDescriptionLabel => 'Описание (необязательно)';

  @override
  String get hometasksDueDate => 'Срок';

  @override
  String get hometasksNoDueDate => 'Без срока';

  @override
  String get hometasksRepeatLabel => 'Повтор';

  @override
  String get hometasksRepeatNone => 'Без повтора';

  @override
  String get hometasksRepeatDaily => 'Каждый день';

  @override
  String get hometasksRepeatWeekly => 'Каждую неделю';

  @override
  String get hometasksRepeatCustom => 'Пользовательский интервал';

  @override
  String get hometasksRepeatEveryDays => 'Повторять каждые (дни)';

  @override
  String get hometasksRepeatCustomInvalid => 'Введите положительное число дней';

  @override
  String get hometasksTypeLabel => 'Тип задания';

  @override
  String get hometasksTypeSimple => 'Простое';

  @override
  String get hometasksTypeChecklist => 'Список';

  @override
  String get hometasksTypeProgress => 'Прогресс';

  @override
  String get hometasksChecklistItems => 'Пункты списка';

  @override
  String get hometasksProgressItems => 'Пункты прогресса';

  @override
  String hometasksItemLabel(Object index) {
    return 'Элемент $index';
  }

  @override
  String get hometasksRequired => 'Обязательно';

  @override
  String hometasksAddAtLeastOne(Object typeLabel) {
    return 'Добавьте хотя бы один элемент $typeLabel.';
  }

  @override
  String get hometasksRepeatIntervalInvalid => 'Введите корректный интервал.';

  @override
  String get hometasksAssigned => 'Задание назначено.';

  @override
  String get hometasksAssignFailed => 'Не удалось назначить задание.';

  @override
  String get hometasksAssignAction => 'Назначить';

  @override
  String get hometasksActive => 'Активные';

  @override
  String get hometasksArchive => 'Архив';

  @override
  String get hometasksAssign => 'Назначить задание';
}
