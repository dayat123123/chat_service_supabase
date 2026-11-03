import 'package:rendezvous_community/src/features/config/domain/entities/client_config.dart';

abstract interface class ClientConfigRepository {
  Future<ClientConfig> fetch({String? platform, String? appVersion});
}
