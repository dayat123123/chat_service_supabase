import 'package:rendezvous_community/src/core/network/social_remote_data_source.dart';
import 'package:rendezvous_community/src/features/notifications/domain/entities/notification_event.dart';
import 'package:rendezvous_community/src/features/notifications/domain/repositories/notification_event_repository.dart';

class NotificationEventRepositoryImpl implements NotificationEventRepository {
  NotificationEventRepositoryImpl(this._api);

  final SocialRemoteDataSource _api;

  @override
  Future<void> report(NotificationEvent event, NotificationSource source) =>
      _api.rpcValue('report_notification_event', {
        'p_event': event.name,
        'p_notification_id': source.notificationId,
        'p_campaign_id': source.campaignId,
        'p_broadcast_id': source.broadcastId,
      });
}
