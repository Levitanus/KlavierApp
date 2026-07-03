import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/app_config.dart';

final appConfigProvider = Provider<AppConfig>((ref) => AppConfig.instance);
