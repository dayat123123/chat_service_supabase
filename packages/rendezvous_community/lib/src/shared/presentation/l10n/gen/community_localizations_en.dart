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
  String get messagePending => 'Waiting to send';

  @override
  String get offlineBanner => 'You\'re offline. Showing saved data.';

  @override
  String get offlineChatBanner => 'You\'re offline. Text messages will be sent automatically once you\'re back online.';

  @override
  String get errorAttachmentOffline => 'Images and documents can only be sent while online.';

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

  @override
  String get errorUnsupportedType =>
      'This file type is not supported. Use JPEG, PNG, WebP, or GIF images (no GIF for profile photos), or PDFs in support chat.';

  @override
  String get errorFileTooLarge =>
      'The file is too large. Limits: 5 MB for images, 2 MB for profile photos, and 10 MB for PDFs.';

  @override
  String get errorEmptyFile => 'The file is empty. Choose another file.';

  @override
  String get errorInvalidImage => 'The image is damaged or cannot be read. Try another image.';

  @override
  String get errorImageTooLarge =>
      'The image resolution is too high. The maximum is 10,000 pixels per side and 40 megapixels.';

  @override
  String get errorInvalidPdf => 'The PDF is damaged or cannot be read.';

  @override
  String get errorPdfEncrypted => 'Password-protected PDFs cannot be sent. Remove the password and send it again.';

  @override
  String get errorPdfActiveContent =>
      'The PDF contains scripts, embedded files, or other active content. Save it again as a plain PDF (for example with Print to PDF) and send it again.';

  @override
  String get errorUploadForbidden => 'You are not allowed to upload files here.';

  @override
  String get errorTooManyUploads => 'You have reached the upload limit for today. Please try again tomorrow.';

  @override
  String get errorUploadBusy => 'The upload server is busy. Please try again shortly.';

  @override
  String get errorStorageUnavailable => 'File uploads are unavailable right now. Please try again later.';

  @override
  String get errorConsentRequired => 'Accept the latest Terms and Community Guidelines to post content.';

  @override
  String get consentDeclined => 'Not sent. Accept the latest documents to post; your draft has been kept.';

  @override
  String get consentTitle => 'Your agreement is needed';

  @override
  String get consentIntro => 'Before joining the discussion, please read and accept the following documents.';

  @override
  String consentAgree(String documents) {
    return 'I have read and agree to $documents.';
  }

  @override
  String get consentAccept => 'Agree';

  @override
  String get consentLater => 'Later';

  @override
  String get consentRead => 'Read';

  @override
  String get consentReview => 'Review';

  @override
  String get consentAccepted => 'Thank you. Your agreement has been saved.';

  @override
  String consentBannerUpdated(String documents) {
    return '$documents updated — review and accept.';
  }

  @override
  String consentBannerRequired(String documents) {
    return 'Review and accept $documents to join the discussion.';
  }

  @override
  String legalVersion(int version, String date) {
    return 'Version $version · effective $date';
  }

  @override
  String get legalChanges => 'What changed';

  @override
  String get listAnd => 'and';

  @override
  String get accountSettingsTitle => 'Privacy & account';

  @override
  String get accountLegalSection => 'Legal documents';

  @override
  String get accountDataSection => 'Your data';

  @override
  String get accountExport => 'Download my data';

  @override
  String get accountExportHint => 'A copy of your community data in JSON format. Available 3 times a day.';

  @override
  String get accountExportSaved => 'Your community data has been downloaded.';

  @override
  String get accountExportLimit => 'Data downloads are limited to 3 per day. Please try again tomorrow.';

  @override
  String get accountDelete => 'Delete community account';

  @override
  String get accountDeleteHint => 'Removes your community profile and content. Your trading account is not affected.';

  @override
  String get accountDeleteTitle => 'Delete your community account?';

  @override
  String get accountDeleteIntro => 'What happens when you delete your community account:';

  @override
  String get accountDeleteContent => 'Your posts, comments, and chat messages are removed for everyone.';

  @override
  String get accountDeleteArchive => 'A copy of the content is archived for the regulator as required by law.';

  @override
  String get accountDeleteRelations => 'Your followers, the accounts you follow, blocks, and mutes are removed.';

  @override
  String get accountDeleteSupport =>
      'Customer service tickets stay on record for compliance, but support chat messages and attachments are deleted too.';

  @override
  String get accountDeleteTrading => 'Your OLT trading account is not affected.';

  @override
  String get accountDeleteFresh => 'When you open the community again, a new empty community profile is created.';

  @override
  String accountDeleteTypeToConfirm(String word) {
    return 'Type $word to confirm';
  }

  @override
  String get accountDeleteWord => 'DELETE';

  @override
  String get accountDeleteConfirm => 'Delete account';

  @override
  String get accountDeleteProgress => 'Deleting your community account…';

  @override
  String get accountDeleted => 'Your community account has been deleted.';

  @override
  String get errorNewAccountImage => 'New accounts cannot attach images yet. Please try again in a few days.';

  @override
  String get errorNewAccountLink => 'New accounts cannot share links yet. Please try again in a few days.';

  @override
  String get errorLinkBlocked => 'This link is not allowed.';

  @override
  String get errorContactBlocked => 'This content cannot be sent because it breaks the Community Guidelines.';

  @override
  String errorSlowMode(int seconds) {
    return 'Slow mode is on. Wait $seconds seconds before sending again.';
  }

  @override
  String get errorSlowModeShort => 'Slow mode is on. Wait a moment before sending again.';

  @override
  String get errorDmNotAllowed => 'This user does not accept direct messages from you.';

  @override
  String get errorDmRequestLimit =>
      'Wait until the recipient accepts your message request before sending more messages.';

  @override
  String get errorSocialDisabled =>
      'Community features are temporarily unavailable. Customer support chat still works.';

  @override
  String get errorEditWindowExpired => 'The edit window has passed.';

  @override
  String get errorPollNotEditable => 'Posts with a poll cannot be edited.';

  @override
  String get errorImageBlocked => 'This image cannot be uploaded because it breaks the Community Guidelines.';

  @override
  String get errorImageCheckUnavailable => 'Image checks are unavailable right now. Please try again shortly.';

  @override
  String get errorAppealExists => 'An appeal for this has already been filed.';

  @override
  String get errorAppealWindowClosed => 'The appeal window has closed.';

  @override
  String get errorAppealNotAllowed => 'This decision cannot be appealed.';

  @override
  String get errorAppealReason => 'The appeal reason must be 10–1000 characters.';

  @override
  String get errorQueryTooShort => 'The search term is too short.';

  @override
  String get errorQueryTooLong => 'The search term is too long.';

  @override
  String get errorShareNotAllowed => 'The post cannot be shared to this chat.';

  @override
  String get errorRequestNotFound => 'The message request no longer exists.';

  @override
  String get errorInvalidQuietHours => 'The quiet hours are not valid.';

  @override
  String get socialUnavailableTitle => 'Community is unavailable';

  @override
  String get socialUnavailableBody => 'Community features are under maintenance. Customer support chat still works.';

  @override
  String get featureUnavailable => 'This feature is not available right now.';

  @override
  String get updateRequiredTitle => 'Update the app';

  @override
  String get updateRequiredBody =>
      'This app version is no longer supported by community features. Update the app to continue.';

  @override
  String get moderationHeld => 'Pending review';

  @override
  String get moderationHeldHint => 'Only you can see it until a moderator reviews it.';

  @override
  String get moderationHidden => 'Hidden by a moderator';

  @override
  String get moderationHiddenHint => 'Other people cannot see this content.';

  @override
  String get messageRequests => 'Message requests';

  @override
  String get messageRequestsEmpty => 'No message requests.';

  @override
  String messageRequestMessages(int count) {
    String _temp0 = intl.Intl.pluralLogic(count, locale: localeName, other: '$count messages', one: '1 message');
    return '$_temp0';
  }

  @override
  String messageRequestIntro(String name) {
    return 'You don\'t follow $name. Accept to reply, or decline to hide this request.';
  }

  @override
  String get messageRequestAccept => 'Accept';

  @override
  String get messageRequestDecline => 'Decline';

  @override
  String get messageRequestBlock => 'Block & report';

  @override
  String messageRequestBlockConfirm(String name) {
    return 'Block $name and report this request as spam?';
  }

  @override
  String get messageRequestAccepted => 'Request accepted.';

  @override
  String get messageRequestDeclined => 'Request declined.';

  @override
  String get messageRequestImageHidden => 'Images stay blurred until you accept the request.';

  @override
  String dmRequestSenderNotice(String name, int max) {
    return 'If $name doesn\'t follow you, your messages arrive as a message request. You can send up to $max messages until it is accepted.';
  }

  @override
  String dmRequestLimitNotice(String name, int max) {
    return 'You have sent $max messages. Wait for $name to accept your message request.';
  }

  @override
  String get accountMessagesSection => 'Direct messages';

  @override
  String get dmPolicyTitle => 'Who can send you direct messages';

  @override
  String get dmPolicyEveryone => 'Everyone';

  @override
  String get dmPolicyEveryoneHint => 'People you don\'t follow arrive in Message requests.';

  @override
  String get dmPolicyFollowing => 'Only people I follow';

  @override
  String get dmPolicyNone => 'No one';

  @override
  String get dmPolicyNoneHint => 'Existing conversations keep working.';

  @override
  String get dmPolicySaved => 'Message settings saved.';

  @override
  String get appealAction => 'Appeal';

  @override
  String get appealTitle => 'File an appeal';

  @override
  String get appealHint => 'Explain why you think this decision is wrong (10–1000 characters).';

  @override
  String get appealSubmit => 'Send appeal';

  @override
  String get appealSent => 'Appeal sent. We\'ll let you know the outcome.';

  @override
  String get myAppeals => 'My appeals';

  @override
  String get myAppealsEmpty => 'No appeals yet.';

  @override
  String get appealStatusPending => 'Under review';

  @override
  String get appealStatusAccepted => 'Accepted';

  @override
  String get appealStatusRejected => 'Rejected';

  @override
  String get appealTargetSanction => 'Account sanction';

  @override
  String get appealTargetPost => 'Post';

  @override
  String get appealTargetComment => 'Comment';

  @override
  String get appealTargetMessage => 'Message';

  @override
  String appealDecisionNote(String note) {
    return 'Note: $note';
  }

  @override
  String get activeSanctions => 'Active sanctions';

  @override
  String get noActiveSanctions => 'No active sanctions.';

  @override
  String get sanctionWarning => 'Warning';

  @override
  String get sanctionMute => 'Posting restricted';

  @override
  String get sanctionBan => 'Account banned';

  @override
  String sanctionUntil(String date) {
    return 'Until $date';
  }

  @override
  String get sanctionPermanent => 'No end date';

  @override
  String get accountAppealsSection => 'Appeals & sanctions';

  @override
  String get accountAppealsHint => 'See active sanctions and your appeal status.';

  @override
  String get notifAppealAccepted => 'Your appeal was accepted';

  @override
  String get notifAppealRejected => 'Your appeal was rejected';

  @override
  String get notificationSettings => 'Notifications';

  @override
  String get notificationSettingsHint => 'Choose in-app and push notifications per type, plus quiet hours.';

  @override
  String get notifTypeReply => 'Replies';

  @override
  String get notifTypeMention => 'Mentions';

  @override
  String get notifTypeLike => 'Likes';

  @override
  String get notifTypeFollow => 'New followers';

  @override
  String get notifTypeMessage => 'Chat messages';

  @override
  String get notifTypeAnnouncement => 'Announcements';

  @override
  String get notifTypeAppeal => 'Appeals';

  @override
  String get notifTypeTrade => 'Trades';

  @override
  String get notifTypeTradeHint => 'Orders and stock trades';

  @override
  String get notifTypeFunds => 'Funds';

  @override
  String get notifTypeFundsHint => 'Deposits, withdrawals, and RDN';

  @override
  String get notifTypeMarket => 'Market';

  @override
  String get notifTypeMarketHint => 'Price alerts, IPOs, and corporate actions';

  @override
  String get notifTypeOltInfo => 'Info';

  @override
  String get notifTypeOltInfoHint => 'Other information from OLT';

  @override
  String get notifTypePromo => 'Promotions';

  @override
  String get notifTypePromoHint => 'Promotions and offers';

  @override
  String get notifSectionOlt => 'OLT notifications';

  @override
  String get notifOltImportantHint => 'Important messages from OLT are always delivered, even during quiet hours.';

  @override
  String get notifInApp => 'In app';

  @override
  String get notifPush => 'Push';

  @override
  String get notifSupportAlwaysOn => 'Messages from official support are always delivered.';

  @override
  String get quietHours => 'Quiet hours';

  @override
  String get quietHoursHint => 'Push is delayed during quiet hours (WIB). In-app notifications still arrive.';

  @override
  String get quietHoursStart => 'Start';

  @override
  String get quietHoursEnd => 'End';

  @override
  String quietHoursRange(String start, String end) {
    return '$start–$end WIB';
  }

  @override
  String notifFollowMany(String name, int others) {
    return '$name and $others others started following you';
  }

  @override
  String get searchTitle => 'Search';

  @override
  String get searchHint => 'Search posts, users, \$CODE, #hashtag';

  @override
  String get searchTabAll => 'All';

  @override
  String get searchTabPosts => 'Posts';

  @override
  String get searchTabUsers => 'Users';

  @override
  String get searchTabStocks => 'Stocks';

  @override
  String get searchTabHashtags => 'Hashtags';

  @override
  String searchMinLength(int min) {
    return 'Type at least $min characters.';
  }

  @override
  String searchNoResults(String query) {
    return 'No results for \"$query\".';
  }

  @override
  String get searchSeeAll => 'See all';

  @override
  String postsLast7Days(int count) {
    return '$count posts (7 days)';
  }

  @override
  String get trendingHashtags => 'Trending hashtags';

  @override
  String hashtagFeedEmpty(String tag) {
    return 'No posts with #$tag yet.';
  }

  @override
  String get trendingTitle => 'Trending';

  @override
  String get trendingStocks => 'Stocks';

  @override
  String get trendingRising => 'Rising';

  @override
  String get trendingPosts => 'Popular';

  @override
  String get trendingWindowDay => '24 hours';

  @override
  String get trendingWindowWeek => '7 days';

  @override
  String get trendingEmpty => 'No trending data yet.';

  @override
  String trendingPostCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(count, locale: localeName, other: '$count posts', one: '1 post');
    return '$_temp0';
  }

  @override
  String trendingGrowth(String percent) {
    return '+$percent%';
  }

  @override
  String get sentimentTitle => 'Community sentiment';

  @override
  String get sentimentNoData => 'No posts with a sentiment label yet.';

  @override
  String sentimentBasedOn(int count) {
    String _temp0 = intl.Intl.pluralLogic(count, locale: localeName, other: 'From $count posts', one: 'From 1 post');
    return '$_temp0';
  }

  @override
  String get editAction => 'Edit';

  @override
  String get editPostTitle => 'Edit post';

  @override
  String get editCommentTitle => 'Edit comment';

  @override
  String get editSaved => 'Changes saved.';

  @override
  String get bookmarkAdd => 'Save';

  @override
  String get bookmarkRemove => 'Remove from saved';

  @override
  String get bookmarksTitle => 'Saved';

  @override
  String get bookmarksEmpty => 'No saved posts yet.';

  @override
  String get bookmarkAdded => 'Post saved.';

  @override
  String get bookmarkRemoved => 'Removed from saved.';

  @override
  String get reactionAdd => 'React';

  @override
  String get shareToChat => 'Send to chat';

  @override
  String get sharePickRoom => 'Send to…';

  @override
  String get shareMessageHint => 'Add a message (optional)';

  @override
  String get shareSent => 'Post sent to the chat.';

  @override
  String get shareNoRooms => 'No chats yet. Start a conversation first.';

  @override
  String get sharedPostUnavailable => 'Post unavailable';

  @override
  String get sharedPostLabel => 'Post';

  @override
  String get linkOpenTitle => 'Open link?';

  @override
  String linkOpenBody(String domain) {
    return 'You are about to open $domain outside the app. Make sure you trust this site.';
  }

  @override
  String get linkOpenAction => 'Open';

  @override
  String get linkOpenFailed => 'The link could not be opened.';

  @override
  String get botLabel => 'Bot';

  @override
  String slowModeBanner(int seconds) {
    return 'Slow mode: 1 message every $seconds seconds';
  }

  @override
  String slowModeWait(int seconds) {
    return 'Wait ${seconds}s';
  }

  @override
  String get pinnedMessageLabel => 'Pinned message';

  @override
  String dmRequestPendingSender(String name, int sent, int max) {
    return 'Your messages are still a request ($sent/$max). $name needs to accept it before you can send more.';
  }

  @override
  String dmRequestPendingRecipient(String name) {
    return '$name sent you a message request. Accept it to reply.';
  }

  @override
  String get moderatedContent => 'Moderated content';

  @override
  String get moderatedContentEmpty => 'None of your content was moderated in the last 90 days.';

  @override
  String get moderationRemoved => 'Removed by a moderator';

  @override
  String get stockCardSend => 'Send stock card';

  @override
  String get stockCardHint => 'Stock code, e.g. BBCA, TLKM';

  @override
  String get stockCardAdd => 'Add';

  @override
  String get stockCardInvalid => 'Invalid stock code';

  @override
  String stockCardLimit(int count) {
    return 'Up to $count stocks per message';
  }

  @override
  String get bannerOpen => 'Learn more';

  @override
  String get bannerDismiss => 'Dismiss';

  @override
  String get draftsTitle => 'Post drafts';

  @override
  String get draftsEmpty => 'No drafts yet.';

  @override
  String get draftNoText => '(no text)';

  @override
  String get draftSaved => 'Draft saved';

  @override
  String get draftSavedLocally => 'Draft saved on this device';

  @override
  String get draftReplaced => 'This draft was updated on another device; the newer version was loaded.';

  @override
  String draftLimit(int count) {
    return 'You reached the limit of $count drafts. This draft is only saved on this device.';
  }

  @override
  String notifMentionRoom(String name, String room) {
    return '$name mentioned you in $room';
  }

  @override
  String notifFollowedPost(String name) {
    return '$name published a new post';
  }

  @override
  String notifFollowedPostMany(String name, int count) {
    return '$name published $count new posts';
  }

  @override
  String get notifWatchlistDigest => 'Watchlist digest';

  @override
  String notifWatchlistDigestBody(int count, String stocks, int others) {
    String _temp0 = intl.Intl.pluralLogic(
      others,
      locale: localeName,
      other: ', and $others more stocks',
      one: ', and 1 more stock',
      zero: '',
    );
    return '$count new posts about $stocks$_temp0';
  }

  @override
  String get notifTargetPost => 'post';

  @override
  String get notifTargetComment => 'comment';

  @override
  String get notifTargetMessage => 'message';

  @override
  String notifModerationHidden(String target) {
    return 'Your $target was hidden by a moderator';
  }

  @override
  String notifModerationRemoved(String target) {
    return 'Your $target was removed by a moderator';
  }

  @override
  String get notifModerationAppealable => 'Tap to see details and appeal';

  @override
  String get notifModerationAppealed => 'An appeal for this content was already filed';

  @override
  String notifRoomMuted(String room) {
    return 'A moderator muted you in $room';
  }

  @override
  String notifRoomUnmuted(String room) {
    return 'Your mute in $room was lifted';
  }

  @override
  String notifRoomMutedUntil(String time) {
    return 'You can send messages again after $time';
  }

  @override
  String get notifRoomUnmutedBody => 'You can send messages in this room again';

  @override
  String get notifTypeFollowedPost => 'Posts from accounts you follow';

  @override
  String get notifTypeFollowedPostHint => 'Push is off by default';

  @override
  String get notifTypeWatchlistDigest => 'Watchlist digest';

  @override
  String get notifTypeWatchlistDigestHint => 'Daily at 17:05 WIB';

  @override
  String get notifTypeModeration => 'Moderation';

  @override
  String get notifTypeModerationHint => 'Always shown in the app';

  @override
  String get roomModeratorBadge => 'Moderator';

  @override
  String get roomModeratorNotice => 'You moderate this room. Long-press a member\'s message for moderation actions.';

  @override
  String get roomModHide => 'Hide message';

  @override
  String get roomModMute => 'Mute member';

  @override
  String get roomModEscalate => 'Escalate to staff';

  @override
  String get roomModHideTitle => 'Hide this message?';

  @override
  String get roomModHideBody =>
      'The message is hidden from other members. Staff review every moderator action and the sender can appeal.';

  @override
  String roomModMuteTitle(String name) {
    return 'Mute $name in this room';
  }

  @override
  String get roomModMuteBody => 'The member can still read the room but cannot send messages until the mute ends.';

  @override
  String get roomModEscalateTitle => 'Escalate message to staff';

  @override
  String get roomModEscalateBody => 'The message goes to the staff report queue. It stays visible until staff decide.';

  @override
  String get roomModReason => 'Reason';

  @override
  String get roomModDuration => 'Mute duration';

  @override
  String get roomModNoteHint => 'Note for staff (optional)';

  @override
  String roomModMinutes(int minutes) {
    return '$minutes min';
  }

  @override
  String roomModHours(int hours) {
    return '$hours h';
  }

  @override
  String get roomModHidden => 'Message hidden';

  @override
  String roomModMuted(String name, String time) {
    return '$name muted until $time';
  }

  @override
  String get roomModEscalated => 'Message escalated to staff';

  @override
  String roomModMemberMuted(String time) {
    return 'Muted until $time';
  }

  @override
  String roomMutedBanner(String time) {
    return 'A moderator muted you in this room until $time. You can still read messages.';
  }

  @override
  String get roomMutedComposer => 'You are muted in this room';

  @override
  String get errorRoomMuted => 'A moderator muted you in this room.';

  @override
  String get errorNotRoomModerator => 'You no longer moderate this room.';

  @override
  String get errorRoomModeratorSuspended => 'Your moderator rights are suspended.';

  @override
  String get errorRoomModTarget => 'Official accounts, other moderators, and your own messages cannot be moderated.';

  @override
  String get errorAlreadyModerated => 'This action was already taken.';
}
