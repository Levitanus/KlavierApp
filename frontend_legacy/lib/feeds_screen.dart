import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;

import 'auth.dart';
import 'config/app_config.dart';
import 'models/chat.dart';
import 'models/feed.dart';
import 'services/feed_service.dart';
import 'services/active_view_tracker.dart';
import 'services/audio_player_service.dart';
import 'services/media_cache_service.dart';
import 'utils/media_download.dart';
import 'widgets/quill_embed_builders.dart';
import 'widgets/quill_editor_composer.dart';
import 'widgets/feed_preview_card.dart';
import 'widgets/floating_audio_player.dart';
import 'l10n/app_localizations.dart';
import 'widgets/app_body_container.dart';

part 'feeds_screen/feeds_list.dart';
part 'feeds_screen/feed_overview.dart';
part 'feeds_screen/feed_post_detail.dart';
part 'feeds_screen/feed_post_editors.dart';
part 'feeds_screen/feed_comment_dialogs.dart';
part 'feeds_screen/feed_settings_dialog.dart';
