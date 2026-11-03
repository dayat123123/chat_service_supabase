import 'package:flutter/foundation.dart';

class CommunityListLoadingDetails {
  const CommunityListLoadingDetails({this.more = false});

  final bool more;
}

class CommunityListEmptyDetails {
  const CommunityListEmptyDetails({required this.message});

  final String message;
}

class CommunityListErrorDetails {
  const CommunityListErrorDetails({required this.error, required this.message, required this.onRetry});

  final Object error;
  final String message;
  final VoidCallback onRetry;
}
