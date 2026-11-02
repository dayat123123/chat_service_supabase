// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'community_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class CommunityLocalizationsEn extends CommunityLocalizations {
  CommunityLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get disclaimer => 'This content is a user opinion, not an investment recommendation.';

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
  String get errorUnauthenticated => 'Your session has ended. Please sign in to OLT again.';

  @override
  String get errorRateLimited => 'You\'re going too fast. Try again in a moment.';

  @override
  String get errorContentBlocked => 'Your content contains words or phrases that aren\'t allowed.';

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
    String _temp0 = intl.Intl.pluralLogic(count, locale: localeName, other: '$count new posts', one: '1 new post');
    return '$_temp0';
  }

  @override
  String get composePrompt => 'What\'s your take on the market today?';

  @override
  String get composeTitle => 'New post';

  @override
  String get composeHint => 'Share your analysis. Use \$CODE to tag stocks and @username to mention people.';

  @override
  String get composeSubmit => 'Post';

  @override
  String composeCharsLeft(int count) {
    return '$count characters left';
  }

  @override
  String get composeAddImage => 'Add image';

  @override
  String get composeAddImageOrPdf => 'Attach image or PDF';

  @override
  String get documentTooLarge => 'PDFs can be at most 10 MB.';

  @override
  String get documentOpenFailed => 'The document could not be opened. Try again.';

  @override
  String get documentFallbackName => 'Document.pdf';

  @override
  String openDocument(String name) {
    return 'Open $name';
  }

  @override
  String get errorAttachmentNotAllowed =>
      'This attachment is not supported. Support chat accepts images and PDFs; other chats accept images only.';

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
  String get stockNotFound => 'Invalid stock code.';

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

  @override
  String get typingShort => 'typing…';

  @override
  String get messageDelivered => 'Delivered';

  @override
  String get pollAddTooltip => 'Add poll';

  @override
  String get pollRemove => 'Remove poll';

  @override
  String pollOptionHint(int index) {
    return 'Choice $index';
  }

  @override
  String get pollAddOption => 'Add choice';

  @override
  String get pollDuration => 'Duration';

  @override
  String get pollDuration1h => '1 hour';

  @override
  String get pollDuration6h => '6 hours';

  @override
  String get pollDuration1d => '1 day';

  @override
  String get pollDuration3d => '3 days';

  @override
  String get pollDuration7d => '7 days';

  @override
  String pollVotes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count votes',
      one: '1 vote',
      zero: 'No votes yet',
    );
    return '$_temp0';
  }

  @override
  String pollEndsIn(String time) {
    return '$time left';
  }

  @override
  String get pollEnded => 'Final results';

  @override
  String get pollYourVote => 'Your vote';

  @override
  String get pollInvalidDraft => 'Fill in 2–4 distinct choices, up to 40 characters each.';

  @override
  String pollTimeMinutes(int count) {
    String _temp0 = intl.Intl.pluralLogic(count, locale: localeName, other: '$count minutes', one: '1 minute');
    return '$_temp0';
  }

  @override
  String pollTimeHours(int count) {
    String _temp0 = intl.Intl.pluralLogic(count, locale: localeName, other: '$count hours', one: '1 hour');
    return '$_temp0';
  }

  @override
  String pollTimeDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(count, locale: localeName, other: '$count days', one: '1 day');
    return '$_temp0';
  }

  @override
  String get errorPollClosed => 'This poll has ended.';

  @override
  String get errorAlreadyVoted => 'You already voted in this poll.';

  @override
  String get errorOwnPoll => 'You can\'t vote in your own poll.';

  @override
  String get errorInvalidPoll => 'Invalid poll. Check the choices and duration.';

  @override
  String get errorDuplicateContent => 'You\'ve sent the same content several times. Try again in a few minutes.';

  @override
  String get errorUserMuted => 'Your account is temporarily restricted from posting.';

  @override
  String get today => 'Today';

  @override
  String get yesterday => 'Yesterday';

  @override
  String get supportOfficialBadge => 'Official CS';

  @override
  String get supportOfficialChannel => 'Official support';

  @override
  String get supportOpenLink => 'Open guide';

  @override
  String get supportRatePrompt => 'Rate this service';

  @override
  String get supportRated => 'Thanks for your rating';

  @override
  String get errorSecretRequestBlocked =>
      'Message held: support staff may not ask for OTP, PIN, or passwords. A supervisor has been notified.';

  @override
  String get supportTitle => 'Help / Chat with CS';

  @override
  String get supportPickTopic => 'How can we help?';

  @override
  String get supportPickTopicHint => 'Pick a topic so the right agent can help you right away.';

  @override
  String get supportHistory => 'View chat history';

  @override
  String supportOutOfHours(String time) {
    return 'Support is closed right now. We\'ll reply from $time.';
  }

  @override
  String get supportStatusWaiting => 'Waiting for an agent';

  @override
  String supportQueueAhead(int count) {
    return '$count tickets ahead of you';
  }

  @override
  String supportStatusHandled(String name) {
    return 'Handled by $name – Official CS';
  }

  @override
  String get supportStatusWaitingYou => 'Waiting for your reply';

  @override
  String get supportStatusResolved => 'Resolved';

  @override
  String get supportStatusClosed => 'Closed';

  @override
  String get supportMenu => 'Support menu';

  @override
  String get supportEndChat => 'End chat';

  @override
  String get supportEndConfirm => 'End this chat and mark the ticket as done?';

  @override
  String get supportComplaint => 'File a complaint';

  @override
  String get supportComplaintConfirm =>
      'This ticket will be recorded as a formal complaint with a resolution deadline. Continue?';

  @override
  String get supportReportFake => 'Report a fake agent';

  @override
  String get supportReportFakeHint => 'Tell us what happened: who contacted you, how, and what they asked for.';

  @override
  String get supportSend => 'Send';

  @override
  String get supportMyTickets => 'My tickets';

  @override
  String get supportNoTickets => 'No tickets yet.';

  @override
  String get supportNewTicket => 'New ticket';

  @override
  String get supportRateTitle => 'Rate our support';

  @override
  String get supportRateComment => 'Comment (optional)';

  @override
  String get supportRateSubmit => 'Submit rating';

  @override
  String supportSensitiveWarning(String kinds) {
    return 'This message contains $kinds and will be masked. OLT support never asks for your OTP, PIN, or password.';
  }

  @override
  String get supportKindOtp => 'an OTP code';

  @override
  String get supportKindPassword => 'a password/PIN';

  @override
  String get supportKindCard => 'a card number';

  @override
  String get supportKindNik => 'an ID number';

  @override
  String get supportKindAccount => 'an account number';

  @override
  String get supportComplaintFiled => 'Complaint recorded. The resolution deadline is shown in the chat.';

  @override
  String get supportFakeReported => 'Report sent. Our team will follow up shortly.';

  @override
  String get supportClosed => 'Chat ended.';

  @override
  String get officialAccountBadge => 'Official';

  @override
  String get pinnedLabel => 'Pinned';

  @override
  String get announcementLabel => 'Announcement';

  @override
  String notifAnnouncement(String name) {
    return '$name posted an announcement';
  }

  @override
  String supportTicketClosedNotice(String ticket) {
    return 'Ticket #$ticket is closed and can no longer be answered.';
  }

  @override
  String supportTicketMeta(String date, String status) {
    return '$date · $status';
  }

  @override
  String supportRating(int rating) {
    return 'Rated $rating/5';
  }

  @override
  String get supportUnavailable => 'Support chat is unavailable. Please try again shortly.';
}
