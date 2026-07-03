import 'favicon_updater_stub.dart'
    if (dart.library.html) 'favicon_updater_web.dart';

abstract class FaviconUpdater {
  static void update({required int chatCount, required int notificationCount}) {
    FaviconUpdaterImpl.update(
      chatCount: chatCount,
      notificationCount: notificationCount,
    );
  }
}
