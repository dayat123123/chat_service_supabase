// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'olt_social_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class OltSocialLocalizationsEn extends OltSocialLocalizations {
  OltSocialLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get disclaimer =>
      'This content is a user opinion, not an investment recommendation.';

  @override
  String get retry => 'Retry';

  @override
  String get cancel => 'Cancel';

  @override
  String get delete => 'Delete';

  @override
  String get save => 'Save';

  @override
  String get close => 'Close';

  @override
  String get you => 'You';

  @override
  String get edited => '(edited)';

  @override
  String get justNow => 'just now';

  @override
  String minutesAgo(int count) {
    return '${count}m';
  }

  @override
  String hoursAgo(int count) {
    return '${count}h';
  }

  @override
  String daysAgo(int count) {
    return '${count}d';
  }

  @override
  String get errorNetwork => 'No connection. Check your network.';

  @override
  String get errorUnauthenticated =>
      'Your session has ended. Please sign in to OLT again.';

  @override
  String get errorRateLimited =>
      'You\'re going too fast. Try again in a moment.';

  @override
  String get errorContentBlocked =>
      'Your content contains words or phrases that aren\'t allowed.';

  @override
  String get errorInvalidInput => 'Invalid data.';

  @override
  String get errorForbidden => 'You don\'t have access to do this.';

  @override
  String get errorNotFound => 'Content not found or has been deleted.';

  @override
  String get errorUnavailable => 'Service is unavailable. Try again later.';

  @override
  String get errorUnknown => 'Something went wrong. Try again.';

  @override
  String get feedLatest => 'Latest';

  @override
  String get feedFollowing => 'Following';

  @override
  String get feedEmpty => 'No posts yet. Be the first!';

  @override
  String get feedFollowingEmpty => 'No posts from people you follow yet.';

  @override
  String stockFeedEmpty(String code) {
    return 'No discussion about \$$code yet.';
  }

  @override
  String get userFeedEmpty => 'No posts yet.';

  @override
  String newPosts(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count new posts',
      one: '1 new post',
    );
    return '$_temp0';
  }

  @override
  String get composePrompt => 'What\'s your take on the market today?';

  @override
  String get composeTitle => 'New post';

  @override
  String get composeHint =>
      'Share your analysis. Use \$CODE to tag stocks and @username to mention people.';

  @override
  String get composeSubmit => 'Post';

  @override
  String composeCharsLeft(int count) {
    return '$count characters left';
  }

  @override
  String get composeAddImage => 'Add image';

  @override
  String get composeRemoveImage => 'Remove image';

  @override
  String get composeTooManyImages => 'Up to 4 images';

  @override
  String get composeImageTooLarge => 'Images must be 5 MB or smaller';

  @override
  String get composePosted => 'Posted';

  @override
  String get sentimentLabel => 'Sentiment';

  @override
  String get sentimentBullish => 'Bullish';

  @override
  String get sentimentBearish => 'Bearish';

  @override
  String get sentimentNeutral => 'Neutral';

  @override
  String get sentimentNone => 'None';

  @override
  String get like => 'Like';

  @override
  String get unlike => 'Unlike';

  @override
  String get comment => 'Comment';

  @override
  String get reply => 'Reply';

  @override
  String get postDetail => 'Post';

  @override
  String get postNotFound => 'Post not found or has been deleted.';

  @override
  String get postDeleted => 'Post deleted';

  @override
  String get deletePostConfirm => 'Delete this post?';

  @override
  String get deleteCommentConfirm => 'Delete this comment?';

  @override
  String get comments => 'Comments';

  @override
  String get noComments => 'No comments yet. Start the discussion!';

  @override
  String get writeComment => 'Write a comment…';

  @override
  String replyingTo(String name) {
    return 'Replying to $name';
  }

  @override
  String get commentDeleted => '[comment deleted]';

  @override
  String viewMoreReplies(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'View $count more replies',
      one: 'View 1 more reply',
    );
    return '$_temp0';
  }

  @override
  String get loadMoreComments => 'Load more comments';

  @override
  String get continueThread => 'Continue thread';

  @override
  String get threadContext => 'Continuing thread';

  @override
  String get collapse => 'Collapse';

  @override
  String get expand => 'Expand';

  @override
  String hiddenReplies(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count replies hidden',
      one: '1 reply hidden',
    );
    return '$_temp0';
  }

  @override
  String get newCommentsAvailable => 'New comments available';

  @override
  String get report => 'Report';

  @override
  String get reportTitle => 'Report content';

  @override
  String get reportDetailsHint => 'Additional details (optional)';

  @override
  String get reportSent => 'Report sent. Thank you.';

  @override
  String get reasonSpam => 'Spam';

  @override
  String get reasonAbuse => 'Harassment / abuse';

  @override
  String get reasonScam => 'Scam';

  @override
  String get reasonPumpAndDump => 'Pump and dump';

  @override
  String get reasonMisinformation => 'Misleading information';

  @override
  String get reasonOther => 'Other';

  @override
  String get block => 'Block';

  @override
  String get unblock => 'Unblock';

  @override
  String blockConfirm(String name) {
    return 'Block $name? You won\'t see each other\'s posts, comments, or messages.';
  }

  @override
  String blocked(String name) {
    return '$name blocked';
  }

  @override
  String get follow => 'Follow';

  @override
  String get followingLabel => 'Following';

  @override
  String followers(int count) {
    return '$count followers';
  }

  @override
  String followingCount(int count) {
    return '$count following';
  }

  @override
  String postsCount(int count) {
    return '$count posts';
  }

  @override
  String get followsYou => 'Follows you';

  @override
  String get sendMessage => 'Message';

  @override
  String get editProfile => 'Edit profile';

  @override
  String get displayName => 'Display name';

  @override
  String get bio => 'Bio';

  @override
  String get changeAvatar => 'Change photo';

  @override
  String get profileNotFound => 'User not found.';

  @override
  String get watch => 'Watch';

  @override
  String get watching => 'Watching';

  @override
  String watchers(int count) {
    return '$count watchers';
  }

  @override
  String get stockDiscussion => 'Discuss';

  @override
  String get stockNotFound => 'Unknown stock code.';

  @override
  String get chats => 'Chats';

  @override
  String get noChats => 'No conversations yet.';

  @override
  String get selectChat => 'Select a conversation to start chatting.';

  @override
  String get newGroup => 'New group';

  @override
  String get groupName => 'Group name';

  @override
  String get addMembers => 'Add members';

  @override
  String get create => 'Create';

  @override
  String get searchUsers => 'Search users…';

  @override
  String members(int count) {
    return '$count members';
  }

  @override
  String get online => 'Online';

  @override
  String typing(String name) {
    return '$name is typing…';
  }

  @override
  String get typingMany => 'Several people are typing…';

  @override
  String get messageHint => 'Write a message…';

  @override
  String get messageDeleted => '[message deleted]';

  @override
  String get messageFailed => 'Failed to send. Tap to retry.';

  @override
  String get messageRead => 'Read';

  @override
  String get messageSent => 'Sent';

  @override
  String get messageSending => 'Sending…';

  @override
  String get reconnecting => 'Reconnecting…';

  @override
  String get attachment => '[attachment]';

  @override
  String get replyToMessage => 'Reply to message';

  @override
  String get deleteMessageConfirm => 'Delete this message for everyone?';

  @override
  String get leaveRoom => 'Leave';

  @override
  String get mute => 'Mute';

  @override
  String get unmute => 'Unmute';

  @override
  String get sendShortcutHint => 'Enter to send, Shift+Enter for a new line';

  @override
  String get notifications => 'Notifications';

  @override
  String get noNotifications => 'No notifications yet.';

  @override
  String get markAllRead => 'Mark all as read';

  @override
  String notifReply(String name) {
    return '$name replied to you';
  }

  @override
  String notifMention(String name) {
    return '$name mentioned you';
  }

  @override
  String notifLike(String name, int count, int others) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$name and $others others liked your content',
      one: '$name liked your content',
    );
    return '$_temp0';
  }

  @override
  String notifFollow(String name) {
    return '$name started following you';
  }

  @override
  String notifMessage(String name, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count new messages from $name',
      one: 'New message from $name',
    );
    return '$_temp0';
  }

  @override
  String get someone => 'Someone';
}
