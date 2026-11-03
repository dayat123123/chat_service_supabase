import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';
import 'package:rendezvous_community/src/core/error/community_exception.dart';
import 'package:rendezvous_community/src/core/error/error_mapper.dart';
import 'package:rendezvous_community/src/shared/presentation/l10n/gen/community_localizations.dart';

export 'gen/community_localizations.dart';

extension CommunityL10nContext on BuildContext {
  CommunityLocalizations get communityL10n =>
      CommunityLocalizations.of(this) ?? lookupCommunityLocalizations(const Locale('id'));
}

extension CommunityErrorText on CommunityLocalizations {
  String errorMessage(Object error) {
    final mapped = mapError(error);
    return switch (mapped.code) {
      'poll_closed' => errorPollClosed,
      'already_voted' => errorAlreadyVoted,
      'own_poll' => errorOwnPoll,
      'invalid_poll' ||
      'invalid_poll_options' ||
      'invalid_poll_option' ||
      'duplicate_poll_option' ||
      'invalid_poll_duration' ||
      'poll_with_attachments' => errorInvalidPoll,
      'duplicate_content' => errorDuplicateContent,
      'user_muted' => errorUserMuted,
      'secret_request_blocked' => errorSecretRequestBlocked,
      'attachment_not_allowed' => errorAttachmentNotAllowed,
      'attachment_too_large' => documentTooLarge,
      'consent_required' => errorConsentRequired,
      'consent_declined' => consentDeclined,
      'unsupported_type' => errorUnsupportedType,
      'file_too_large' => errorFileTooLarge,
      'empty_file' => errorEmptyFile,
      'invalid_image' => errorInvalidImage,
      'image_too_large' => errorImageTooLarge,
      'invalid_pdf' => errorInvalidPdf,
      'pdf_encrypted' => errorPdfEncrypted,
      'pdf_active_content' => errorPdfActiveContent,
      'upload_forbidden' => errorUploadForbidden,
      'too_many_uploads' => errorTooManyUploads,
      'busy' => errorUploadBusy,
      'storage_unavailable' || 'storage_error' || 'media_unavailable' => errorStorageUnavailable,
      'new_account_restricted' => mapped.message == 'link' ? errorNewAccountLink : errorNewAccountImage,
      'link_blocked' => errorLinkBlocked,
      'contact_blocked' => errorContactBlocked,
      'content_blocked' => errorContentBlocked,
      'slow_mode' => switch (mapped.retryAfter) {
        final Duration wait when wait.inSeconds > 0 => errorSlowMode(wait.inSeconds),
        _ => errorSlowModeShort,
      },
      'dm_not_allowed' => errorDmNotAllowed,
      'dm_request_limit' => errorDmRequestLimit,
      'social_disabled' => errorSocialDisabled,
      'edit_window_expired' => errorEditWindowExpired,
      'poll_not_editable' => errorPollNotEditable,
      'image_blocked' => errorImageBlocked,
      'classifier_unavailable' || 'moderation_unavailable' => errorImageCheckUnavailable,
      'appeal_exists' => errorAppealExists,
      'appeal_window_closed' => errorAppealWindowClosed,
      'appeal_not_allowed' => errorAppealNotAllowed,
      'invalid_reason' => errorAppealReason,
      'query_too_short' => errorQueryTooShort,
      'query_too_long' => errorQueryTooLong,
      'share_not_allowed' => errorShareNotAllowed,
      'reactions_not_supported' => featureUnavailable,
      'request_not_found' => errorRequestNotFound,
      'invalid_quiet_hours' => errorInvalidQuietHours,
      'attachment_offline' => errorAttachmentOffline,
      'room_muted' => errorRoomMuted,
      'not_room_moderator' => errorNotRoomModerator,
      'room_moderator_suspended' => errorRoomModeratorSuspended,
      'protected_account' || 'moderator_target' || 'self_target' => errorRoomModTarget,
      'already_moderated' || 'already_muted' || 'already_escalated' => errorAlreadyModerated,
      _ => switch (mapped.kind) {
        CommunityErrorKind.network => errorNetwork,
        CommunityErrorKind.unauthenticated => errorUnauthenticated,
        CommunityErrorKind.rateLimited => errorRateLimited,
        CommunityErrorKind.contentBlocked => errorContentBlocked,
        CommunityErrorKind.invalidInput => errorInvalidInput,
        CommunityErrorKind.forbidden => errorForbidden,
        CommunityErrorKind.notFound => errorNotFound,
        CommunityErrorKind.unavailable => errorUnavailable,
        CommunityErrorKind.unknown => errorUnknown,
      },
    };
  }

  String relativeTime(DateTime time, {DateTime? now}) {
    final current = now ?? DateTime.now();
    final diff = current.difference(time);
    if (diff.inSeconds < 60) return justNow;
    if (diff.inMinutes < 60) return minutesAgo(diff.inMinutes);
    if (diff.inHours < 24) return hoursAgo(diff.inHours);
    if (diff.inDays < 7) return daysAgo(diff.inDays);
    final local = time.toLocal();
    final pattern = local.year == current.year ? DateFormat.MMMd(localeName) : DateFormat.yMMMd(localeName);
    return pattern.format(local);
  }

  String clockTime(DateTime time) => DateFormat.Hm(localeName).format(time.toLocal());

  String dayLabel(DateTime time, {DateTime? now}) {
    final local = time.toLocal();
    final current = (now ?? DateTime.now()).toLocal();
    final day = DateTime(local.year, local.month, local.day);
    final days = DateTime(current.year, current.month, current.day).difference(day).inDays;
    if (days == 0) return today;
    if (days == 1) return yesterday;
    final pattern = local.year == current.year ? DateFormat.MMMMEEEEd(localeName) : DateFormat.yMMMMEEEEd(localeName);
    return pattern.format(local);
  }

  String remainingTime(Duration left) {
    if (left.inDays >= 1) return pollTimeDays(left.inDays);
    if (left.inHours >= 1) return pollTimeHours(left.inHours);
    return pollTimeMinutes(left.inMinutes < 1 ? 1 : left.inMinutes);
  }
}
