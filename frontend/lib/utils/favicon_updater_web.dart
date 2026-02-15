import 'package:web/web.dart' as web;

class FaviconUpdaterImpl {
  static String? _lastIcon;

  static void update({
    required int chatCount,
    required int notificationCount,
  }) {
    final iconHref = _selectIcon(chatCount, notificationCount);
    if (_lastIcon == iconHref) {
      return;
    }
    _lastIcon = iconHref;

    final document = web.window.document;
    final link =
      document.querySelector("link[rel~='icon']") as web.HTMLLinkElement?;

    if (link != null) {
      link.href = iconHref;
      return;
    }

    final newLink = document.createElement('link') as web.HTMLLinkElement
      ..rel = 'icon'
      ..type = 'image/png'
      ..href = iconHref;
    final head = document.querySelector('head');
    if (head != null) {
      head.appendChild(newLink);
    } else {
      document.body?.appendChild(newLink);
    }
  }

  static String _selectIcon(int chatCount, int notificationCount) {
    if (chatCount > 0) {
      return 'favicon-unread-chat.png';
    }
    if (notificationCount > 0) {
      return 'favicon-unread-bell.png';
    }
    return 'favicon-default.png';
  }
}
