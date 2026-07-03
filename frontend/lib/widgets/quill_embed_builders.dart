import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';
import '../config/app_config.dart';
import '../services/audio_player_service.dart';
import '../services/media_cache_service.dart';
import '../utils/media_download.dart';
import '../l10n/app_localizations.dart';

part 'quill_embed/common.dart';
part 'quill_embed/embed_builders.dart';
part 'quill_embed/video_dialog.dart';
part 'quill_embed/chat_players.dart';
