library;

export 'src/app/olt_social.dart';
export 'src/app/olt_social_dependencies.dart';
export 'src/app/olt_social_scope.dart';
export 'src/app/olt_support_scope.dart';
export 'src/core/auth/social_session.dart';
export 'src/core/error/olt_social_exception.dart';
export 'src/core/network/authorized_image.dart';
export 'src/core/network/realtime_status.dart';
export 'src/core/paging/paged.dart';
export 'src/core/text/social_text_parser.dart'
    show
        CashtagSegment,
        MentionSegment,
        PlainSegment,
        SocialTextSegment,
        extractCashtags,
        extractMentions,
        parseSocialText;
export 'src/features/chat/domain/entities/chat_events.dart';
export 'src/features/chat/domain/entities/chat_message.dart';
export 'src/features/chat/domain/entities/chat_room.dart';
export 'src/features/chat/domain/entities/receipt.dart';
export 'src/features/chat/domain/repositories/chat_repository.dart';
export 'src/features/chat/presentation/builders/olt_chat_builders.dart'
    show OltChatBuilders, OltChatBuildersScope, OltPartBuilder;
export 'src/features/chat/presentation/builders/olt_chat_details.dart';
export 'src/features/chat/presentation/cubit/chat_room_cubit.dart' show ChatRoomCubit, ChatRoomState;
export 'src/features/chat/presentation/widgets/olt_chat_badge.dart' show OltChatBadge;
export 'src/features/chat/presentation/widgets/olt_chat_list.dart' show OltChatList;
export 'src/features/chat/presentation/widgets/olt_chat_room.dart' show OltChatRoom;
export 'src/features/chat/presentation/widgets/receipt_icon.dart';
export 'src/features/chat/presentation/widgets/room_visuals.dart' show OltRoomAvatar;
export 'src/features/compose/presentation/widgets/olt_compose_post.dart' show OltComposePost, showOltComposer;
export 'src/features/feed/domain/entities/post.dart';
export 'src/features/feed/domain/repositories/feed_repository.dart';
export 'src/features/feed/presentation/widgets/olt_feed_list.dart' show OltFeedList;
export 'src/features/feed/presentation/widgets/olt_stream_feed.dart' show OltFeedTab, OltStreamFeed;
export 'src/features/feed/presentation/widgets/sentiment_badge.dart';
export 'src/features/media/domain/repositories/media_repository.dart';
export 'src/features/media/presentation/widgets/attachment_grid.dart';
export 'src/features/moderation/domain/entities/report.dart';
export 'src/features/moderation/domain/repositories/moderation_repository.dart';
export 'src/features/notifications/domain/entities/app_notification.dart';
export 'src/features/notifications/domain/repositories/notification_repository.dart';
export 'src/features/notifications/presentation/widgets/olt_notifications.dart'
    show OltNotificationBadge, OltNotificationList;
export 'src/features/poll/domain/entities/poll.dart';
export 'src/features/poll/domain/repositories/poll_repository.dart';
export 'src/features/poll/presentation/widgets/olt_poll_view.dart' show OltPollView;
export 'src/features/post/domain/entities/thread_comment.dart';
export 'src/features/post/domain/repositories/comment_repository.dart';
export 'src/features/post/presentation/widgets/olt_post_detail.dart' show OltPostDetail;
export 'src/features/profile/domain/entities/user_profile.dart';
export 'src/features/profile/domain/repositories/profile_repository.dart';
export 'src/features/profile/presentation/widgets/olt_user_profile.dart' show OltUserProfile;
export 'src/features/stocks/domain/entities/stock.dart';
export 'src/features/stocks/domain/entities/stock_suggestion.dart';
export 'src/features/stocks/domain/repositories/stock_repository.dart';
export 'src/features/stocks/presentation/widgets/olt_stock_feed.dart' show OltStockFeed;
export 'src/features/support/domain/entities/support_ticket.dart';
export 'src/features/support/domain/repositories/support_repository.dart';
export 'src/features/support/presentation/widgets/olt_support_badge.dart' show OltSupportBadge;
export 'src/features/support/presentation/widgets/olt_support_chat.dart' show OltSupportChat, OltSupportPage, openOltSupport;
export 'src/features/support/presentation/widgets/olt_support_tickets.dart' show OltSupportTickets;
export 'src/features/support/presentation/widgets/support_message_actions.dart';
export 'src/features/support/presentation/widgets/support_message_parts.dart' show OfficialBadge;
export 'src/shared/domain/entities/attachment.dart';
export 'src/shared/domain/entities/user.dart';
export 'src/shared/presentation/l10n/l10n.dart' show OltErrorText, OltL10nContext, OltSocialLocalizations;
export 'src/shared/presentation/load_status.dart';
export 'src/shared/presentation/theme/olt_social_theme.dart';
export 'src/shared/presentation/widgets/olt_avatar.dart';
export 'src/shared/presentation/widgets/olt_composer_field.dart';
export 'src/shared/presentation/widgets/olt_count_badge.dart';
export 'src/shared/presentation/widgets/olt_disclaimer.dart';
export 'src/shared/presentation/widgets/social_text.dart';
