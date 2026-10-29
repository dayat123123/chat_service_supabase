/// Fitur sosial & chat Rendezvous OLT.
///
/// Mulai dengan [OltSocial.initialize], lalu tempatkan widget siap pakai:
/// [OltStreamFeed], [OltStockFeed], [OltPostDetail], [OltComposePost],
/// [OltChatList], [OltChatRoom], [OltNotificationList], [OltUserProfile].
library;

export 'src/core/errors/olt_social_exception.dart';
export 'src/core/olt_social.dart';
export 'src/core/utils/social_text_parser.dart'
    show
        CashtagSegment,
        MentionSegment,
        PlainSegment,
        SocialTextSegment,
        extractCashtags,
        extractMentions,
        parseSocialText;
export 'src/domain/entities/chat.dart';
export 'src/domain/entities/comment.dart';
export 'src/domain/entities/notification.dart';
export 'src/domain/entities/paged.dart';
export 'src/domain/entities/post.dart';
export 'src/domain/entities/stock.dart';
export 'src/domain/entities/user.dart';
export 'src/domain/repositories/repositories.dart';
export 'src/presentation/chat/olt_chat_list.dart' show OltChatList;
export 'src/presentation/chat/olt_chat_room.dart' show OltChatRoom;
export 'src/presentation/compose/olt_compose_post.dart' show OltComposePost, showOltComposer;
export 'src/presentation/feed/feed_list.dart' show OltFeedList;
export 'src/presentation/feed/olt_stock_feed.dart' show OltStockFeed;
export 'src/presentation/feed/olt_stream_feed.dart' show OltFeedTab, OltStreamFeed;
export 'src/presentation/feed/olt_user_profile.dart' show OltUserProfile;
export 'src/presentation/l10n/l10n.dart' show OltL10nContext, OltSocialLocalizations;
export 'src/presentation/notifications/olt_notifications.dart' show OltNotificationBadge, OltNotificationList;
export 'src/presentation/olt_social_scope.dart';
export 'src/presentation/post/olt_post_detail.dart' show OltPostDetail;
export 'src/presentation/theme/olt_social_theme.dart';
export 'src/presentation/widgets/common.dart'
    show OltAvatar, OltCountBadge, OltDisclaimer, SentimentBadge, SocialText;
