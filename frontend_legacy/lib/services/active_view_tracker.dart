class ActiveViewTracker {
  static int? _activeChatThreadId;
  static int? _activeFeedPostId;

  static void setActiveChatThread(int threadId) {
    _activeChatThreadId = threadId;
  }

  static void clearActiveChatThread(int threadId) {
    if (_activeChatThreadId == threadId) {
      _activeChatThreadId = null;
    }
  }

  static int? get activeChatThreadId => _activeChatThreadId;

  static void setActiveFeedPost(int postId) {
    _activeFeedPostId = postId;
  }

  static void clearActiveFeedPost(int postId) {
    if (_activeFeedPostId == postId) {
      _activeFeedPostId = null;
    }
  }

  static int? get activeFeedPostId => _activeFeedPostId;
}
